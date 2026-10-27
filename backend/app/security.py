"""Security, encryption, JWT auth, and rate limiting utilities."""
from __future__ import annotations

import base64
import hashlib
import time
from datetime import datetime, timezone
from typing import Any, Optional

import jwt as pyjwt
from cryptography.fernet import Fernet
from fastapi import HTTPException

import os
from app.config import (
    ATTENDANCE_ENV,
    ATTENDANCE_SECRET_KEY,
    ATTENDANCE_TOKEN_TTL_SECONDS,
    RATE_LIMIT_LOGIN_PER_MIN,
    RATE_LIMIT_SUBMIT_PER_MIN,
    SUPABASE_JWT_SECRET,
)

# ── Encryption for Biometric Face Embeddings ───────────────────────────────────
# Derive a valid 32-byte url-safe base64 Fernet key from ATTENDANCE_SECRET_KEY
_raw_key = hashlib.sha256(ATTENDANCE_SECRET_KEY.encode("utf-8")).digest()
_fernet_key = base64.urlsafe_b64encode(_raw_key)
_cipher = Fernet(_fernet_key)


def encrypt_face_embedding(embedding: Any) -> str:
    """Encrypt a 512-dimensional floating point embedding into an opaque string."""
    import numpy as np
    arr = np.asarray(embedding, dtype=np.float32).tobytes()
    encrypted = _cipher.encrypt(arr)
    return encrypted.decode("utf-8")


def decrypt_face_embedding(encrypted_str: str) -> Any:
    """Decrypt an encrypted embedding string back into a 512-dim float32 NumPy array."""
    import numpy as np
    decrypted_bytes = _cipher.decrypt(encrypted_str.encode("utf-8"))
    return np.frombuffer(decrypted_bytes, dtype=np.float32)


# ── JWT Authentication ────────────────────────────────────────────────────────
def create_access_token(user_id: str, email: str, role: str, name: str) -> str:
    """Generate a JWT token adhering to Supabase-compatible schema."""
    now = int(time.time())
    payload = {
        "sub": user_id,
        "email": email,
        "aud": "authenticated",
        "role": "authenticated",
        "user_metadata": {
            "name": name,
            "role": role,
        },
        "app_metadata": {
            "role": role,
        },
        "iat": now,
        "exp": now + ATTENDANCE_TOKEN_TTL_SECONDS,
    }
    return pyjwt.encode(payload, SUPABASE_JWT_SECRET, algorithm="HS256")


def verify_jwt_token(token: str) -> dict[str, Any]:
    """Decode and verify a JWT signature and audience."""
    try:
        payload = pyjwt.decode(
            token,
            SUPABASE_JWT_SECRET,
            algorithms=["HS256"],
            audience="authenticated",
        )
        return payload
    except pyjwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token has expired")
    except pyjwt.InvalidTokenError as exc:
        raise HTTPException(status_code=401, detail=f"Invalid token: {exc}")


# ── Token Revocation & Blacklist ──────────────────────────────────────────────
_revoked_tokens: set[str] = set()


def revoke_token(token: str) -> None:
    """Add a JWT token's hash to the revocation blacklist."""
    if not token:
        return
    token_hash = hashlib.sha256(token.strip().encode("utf-8")).hexdigest()
    _revoked_tokens.add(token_hash)


def is_token_revoked(token: str) -> bool:
    """Check if token's hash is in the revocation blacklist."""
    if not token:
        return False
    token_hash = hashlib.sha256(token.strip().encode("utf-8")).hexdigest()
    return token_hash in _revoked_tokens


def reset_revoked_tokens() -> None:
    _revoked_tokens.clear()


# ── In-Memory Rate Limiting ───────────────────────────────────────────────────
_rate_limits: dict[str, list[float]] = {}


def reset_rate_limits() -> None:
    _rate_limits.clear()


def check_rate_limit(key: str, max_requests: int, window_seconds: float = 60.0) -> None:
    """Sliding-window rate limiter. Raises 429 if limit exceeded."""
    if (
        os.getenv("ATTENDANCE_ENV", ATTENDANCE_ENV).lower() == "test"
        and not key.startswith("test_rate:")
        and not os.getenv("ATTENDANCE_TEST_RATE_LIMIT")
    ):
        return
    now = time.time()
    history = _rate_limits.setdefault(key, [])
    # Prune timestamps older than window
    _rate_limits[key] = [t for t in history if now - t < window_seconds]
    if len(_rate_limits[key]) >= max_requests:
        raise HTTPException(
            status_code=429,
            detail=f"Rate limit exceeded. Please wait a moment before retrying."
        )
    _rate_limits[key].append(now)


def check_login_rate_limit(client_ip: str) -> None:
    check_rate_limit(f"login:{client_ip}", max_requests=RATE_LIMIT_LOGIN_PER_MIN, window_seconds=60.0)


def check_submit_rate_limit(student_id: str) -> None:
    check_rate_limit(f"submit:{student_id}", max_requests=RATE_LIMIT_SUBMIT_PER_MIN, window_seconds=60.0)


# ── Active Liveness Dynamic Challenge Tokens & Replay Defense ─────────────────
import uuid

_consumed_challenge_nonces: set[str] = set()
_submitted_image_hashes: set[str] = set()
_submitted_phashes: list[str] = []


def create_liveness_challenge_token(
    session_id: str,
    student_id: str,
    challenges: list[str],
    ttl_seconds: int = 90,
) -> str:
    """Issue a cryptographically signed HMAC-SHA256 challenge token."""
    now = int(time.time())
    nonce = str(uuid.uuid4())
    payload = {
        "sub": student_id,
        "session_id": session_id,
        "challenges": challenges,
        "nonce": nonce,
        "iat": now,
        "exp": now + ttl_seconds,
        "type": "liveness_challenge",
    }
    return pyjwt.encode(payload, ATTENDANCE_SECRET_KEY, algorithm="HS256")


def verify_liveness_challenge_token(token: str) -> dict[str, Any]:
    """Verify challenge token signature, type, and expiration."""
    try:
        payload = pyjwt.decode(token, ATTENDANCE_SECRET_KEY, algorithms=["HS256"])
        if payload.get("type") != "liveness_challenge":
            raise HTTPException(status_code=400, detail="Invalid token type; expected liveness challenge.")
        return payload
    except pyjwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=400,
            detail="Liveness challenge token has expired. Please obtain a fresh challenge.",
        )
    except pyjwt.InvalidTokenError as exc:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid or forged liveness challenge token: {exc}",
        )


def consume_challenge_nonce(nonce: str) -> bool:
    """Ensure challenge token can only be redeemed once (single-use nonce)."""
    if not nonce or nonce in _consumed_challenge_nonces:
        return False
    _consumed_challenge_nonces.add(nonce)
    return True


def check_and_record_image_replay(sha256_hash: str, phash: str) -> tuple[bool, str]:
    """Check for exact SHA-256 byte replay or near-duplicate pHash presentation attack."""
    if sha256_hash in _submitted_image_hashes:
        return True, "Exact duplicate image replay detected (identical cryptographic SHA-256 digest)."

    # pHash Hamming distance comparison
    if phash and phash != "0" * 16:
        try:
            curr_val = int(phash, 16)
            for prev in _submitted_phashes:
                prev_val = int(prev, 16)
                diff = bin(curr_val ^ prev_val).count("1")
                if diff <= 3:
                    return True, f"Perceptual image replay detected (pHash Hamming distance {diff} <= 3)."
        except Exception:
            pass

    _submitted_image_hashes.add(sha256_hash)
    if phash and phash != "0" * 16:
        _submitted_phashes.append(phash)
    return False, ""


def reset_security_caches() -> None:
    """Reset security caches for testing isolation."""
    _consumed_challenge_nonces.clear()
    _submitted_image_hashes.clear()
    _submitted_phashes.clear()
    reset_revoked_tokens()
    reset_rate_limits()

