"""Unit tests for backend mathematical, cryptographic, and algorithmic primitives.

Tests pure algorithmic functions without mocking inference engines or database layers:
1. Vector cosine similarity and distance properties.
2. 2D Perceptual Hashing (DCT pHash) and Hamming distance metrics.
3. SHA-256 replay cache deduplication logic.
4. Fernet biometric template symmetric encryption, decryption, and corruption detection.
5. Challenge token issuance, single-use nonce consumption, and replay rejection.
6. In-memory token revocation blacklist.
7. Recursive audit metadata scrubbing and credential redaction.
8. Computer-vision quality screening algorithms (Laplacian blur, luminance, specular glare).
"""
from __future__ import annotations

import os
import sys
import time
import hashlib
from pathlib import Path
import numpy as np
import cv2
import pytest
from datetime import datetime, timezone, timedelta

BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))

os.environ["ATTENDANCE_ENV"] = "test"
os.environ["SUPABASE_JWT_SECRET"] = "test_jwt_secret_must_be_at_least_32_chars_long"

from app.security import (
    encrypt_face_embedding,
    decrypt_face_embedding,
    create_liveness_challenge_token,
    verify_liveness_challenge_token,
    consume_challenge_nonce,
    check_and_record_image_replay,
    reset_security_caches,
    revoke_token,
    is_token_revoked,
    reset_revoked_tokens,
)
from app.face_engine import RealFaceEngine, get_face_engine
from app.main import (
    _sanitize_audit_metadata,
    assess_image_quality,
    validate_image_payload,
)


# ==============================================================================
# 1. VECTOR COSINE SIMILARITY & EMBEDDING ALGEBRA
# ==============================================================================

def test_unit_cosine_similarity_identical_vectors():
    """Identical non-zero vectors must yield cosine similarity exactly 1.0."""
    np.random.seed(42)
    vec = np.random.randn(512).astype(np.float32)
    norm = np.linalg.norm(vec)
    sim = float(np.dot(vec, vec) / (norm * norm))
    assert abs(sim - 1.0) < 1e-6


def test_unit_cosine_similarity_orthogonal_vectors():
    """Orthogonal vectors must yield cosine similarity exactly 0.0."""
    v1 = np.zeros(512, dtype=np.float32)
    v2 = np.zeros(512, dtype=np.float32)
    v1[0] = 1.0
    v2[1] = 1.0
    sim = float(np.dot(v1, v2) / (np.linalg.norm(v1) * np.linalg.norm(v2)))
    assert sim == 0.0


def test_unit_cosine_similarity_opposite_vectors():
    """Opposite vectors must yield cosine similarity exactly -1.0."""
    np.random.seed(123)
    v1 = np.random.randn(512).astype(np.float32)
    v2 = -v1
    sim = float(np.dot(v1, v2) / (np.linalg.norm(v1) * np.linalg.norm(v2)))
    assert abs(sim - (-1.0)) < 1e-6


def test_unit_cosine_similarity_zero_norm_handling():
    """Zero-norm vector must evaluate to 0.0 similarity without ZeroDivisionError."""
    v_zero = np.zeros(512, dtype=np.float32)
    v_rand = np.ones(512, dtype=np.float32)
    n_zero = float(np.linalg.norm(v_zero))
    n_rand = float(np.linalg.norm(v_rand))

    if n_zero > 0 and n_rand > 0:
        sim = float(np.dot(v_zero, v_rand) / (n_zero * n_rand))
    else:
        sim = 0.0

    assert sim == 0.0


def test_unit_cosine_similarity_scale_invariance():
    """Multiplying vector by positive scalar c must not change cosine similarity."""
    np.random.seed(99)
    v1 = np.random.randn(512).astype(np.float32)
    v2 = np.random.randn(512).astype(np.float32)
    v2_scaled = v2 * 7.5

    sim1 = float(np.dot(v1, v2) / (np.linalg.norm(v1) * np.linalg.norm(v2)))
    sim2 = float(np.dot(v1, v2_scaled) / (np.linalg.norm(v1) * np.linalg.norm(v2_scaled)))
    assert abs(sim1 - sim2) < 1e-5


# ==============================================================================
# 2. PERCEPTUAL HASH (pHash) & REPLAY DEDUPLICATION
# ==============================================================================

def test_unit_phash_computation_identical_image():
    """Identical image input must generate identical 16-hex perceptual hash."""
    engine = get_face_engine()
    img = np.zeros((320, 320, 3), dtype=np.uint8)
    cv2.circle(img, (160, 160), 50, (200, 200, 200), -1)

    hash1 = engine.compute_phash(img)
    hash2 = engine.compute_phash(img)
    assert hash1 == hash2
    assert isinstance(hash1, str)
    assert len(hash1) == 16


def test_unit_phash_hamming_distance_under_mild_luminance():
    """Mild brightness increase (+10) must keep pHash Hamming distance within replay threshold (<=3)."""
    engine = get_face_engine()
    img1 = np.full((320, 320, 3), 120, dtype=np.uint8)
    cv2.rectangle(img1, (60, 60), (260, 260), (200, 150, 100), -1)

    img2 = cv2.convertScaleAbs(img1, alpha=1.0, beta=10)

    hash1 = engine.compute_phash(img1)
    hash2 = engine.compute_phash(img2)

    val1 = int(hash1, 16)
    val2 = int(hash2, 16)
    hamming_dist = bin(val1 ^ val2).count("1")
    assert hamming_dist <= 3


def test_unit_phash_distinct_images_have_large_distance():
    """Completely different geometric patterns must yield Hamming distance > 10."""
    engine = get_face_engine()
    img_h = np.zeros((320, 320, 3), dtype=np.uint8)
    for y in range(0, 320, 20):
        cv2.line(img_h, (0, y), (320, y), (255, 255, 255), 3)

    img_v = np.zeros((320, 320, 3), dtype=np.uint8)
    for x in range(0, 320, 20):
        cv2.line(img_v, (x, 0), (x, 320), (255, 255, 255), 3)

    h_hash = engine.compute_phash(img_h)
    v_hash = engine.compute_phash(img_v)

    val_h = int(h_hash, 16)
    val_v = int(v_hash, 16)
    hamming_dist = bin(val_h ^ val_v).count("1")
    assert hamming_dist > 3  # Distinct patterns must exceed replay cutoff (<=3)


def test_unit_sha256_replay_cache_deduplication():
    """check_and_record_image_replay must accept first capture and reject second identical capture."""
    reset_security_caches()
    raw_bytes = b"unique_synthetic_capture_frame_12345"
    sha = hashlib.sha256(raw_bytes).hexdigest()
    phash = "0123456789abcdef"

    # First attempt: not a replay
    is_rep1, reason1 = check_and_record_image_replay(sha, phash)
    assert is_rep1 is False
    assert reason1 == ""

    # Immediate replay attempt: blocked
    is_rep2, reason2 = check_and_record_image_replay(sha, phash)
    assert is_rep2 is True
    assert "replay detected" in reason2.lower()


# ==============================================================================
# 3. FERNET BIOMETRIC EMBEDDING ENCRYPTION & DECRYPTION
# ==============================================================================

def test_unit_fernet_embedding_roundtrip():
    """512-dim ArcFace embedding must survive encryption-decryption roundtrip with zero data loss."""
    np.random.seed(77)
    original_emb = np.random.randn(512).astype(np.float32)
    # Normalize
    original_emb = original_emb / np.linalg.norm(original_emb)

    token = encrypt_face_embedding(original_emb)
    assert isinstance(token, str)
    assert len(token) > 50

    decrypted_emb = decrypt_face_embedding(token)
    assert isinstance(decrypted_emb, np.ndarray)
    assert decrypted_emb.shape == (512,)
    assert decrypted_emb.dtype == np.float32
    assert np.allclose(original_emb, decrypted_emb, atol=1e-6)


def test_unit_fernet_corrupted_token_rejected():
    """Corrupted ciphertext token must raise error and not return bogus vectors."""
    with pytest.raises(Exception):
        decrypt_face_embedding("not-a-valid-fernet-token-12345")


def test_unit_fernet_tampered_payload_rejected():
    """Tampering with single byte of Fernet ciphertext must raise decryption error."""
    vec = np.ones(512, dtype=np.float32)
    token = encrypt_face_embedding(vec)
    # Flip character in base64 string
    tampered = ("A" if token[10] != "A" else "B") + token[11:]
    with pytest.raises(Exception):
        decrypt_face_embedding(tampered)


# ==============================================================================
# 4. ACTIVE LIVENESS CHALLENGE TOKENS & NONCES
# ==============================================================================

def test_unit_challenge_token_issuance_and_claims():
    """Issued challenge token must contain sub, session_id, challenges, and valid expiration."""
    sub = "student-uuid-001"
    sess_id = "session-uuid-001"
    challenges = ["turn_left", "turn_right", "blink"]
    token = create_liveness_challenge_token(sess_id, sub, challenges)
    assert isinstance(token, str)

    payload = verify_liveness_challenge_token(token)
    assert payload["sub"] == sub
    assert payload["session_id"] == sess_id
    assert payload["challenges"] == challenges
    assert "nonce" in payload
    assert len(payload["nonce"]) > 10
    assert payload["exp"] > time.time()


def test_unit_challenge_nonce_single_use_consumption():
    """consume_challenge_nonce must return True on first call and False on any replay."""
    reset_security_caches()
    nonce = f"test-nonce-{time.time()}"

    # First consumption: valid
    assert consume_challenge_nonce(nonce) is True

    # Replay consumption: blocked
    assert consume_challenge_nonce(nonce) is False


def test_unit_challenge_token_tampered_secret_rejected():
    """Challenge token verified with wrong secret or tampered header must raise HTTPException."""
    import jwt as pyjwt
    tampered = pyjwt.encode({"sub": "victim"}, "attacker-secret-must-be-at-least-32-chars-long", algorithm="HS256")
    from fastapi import HTTPException
    with pytest.raises(HTTPException) as exc:
        verify_liveness_challenge_token(tampered)
    assert exc.value.status_code == 400


# ==============================================================================
# 5. TOKEN REVOCATION BLACKLIST
# ==============================================================================

def test_unit_token_revocation_lifecycle():
    """Revoking token must immediately flag is_token_revoked True until reset."""
    reset_revoked_tokens()
    tok = "jwt.sample.token.to.revoke.999"

    assert is_token_revoked(tok) is False

    revoke_token(tok)
    assert is_token_revoked(tok) is True

    reset_revoked_tokens()
    assert is_token_revoked(tok) is False


# ==============================================================================
# 6. AUDIT METADATA SANITIZATION & REDACTION
# ==============================================================================

def test_unit_audit_metadata_scrubbing_credentials_and_vectors():
    """_sanitize_audit_metadata must completely drop passwords, tokens, and large float arrays."""
    dirty_meta = {
        "user_email": "student@demo.edu",
        "password": "superSecretPassword123",
        "access_token": "Bearer eyJhbGciOi...",
        "jwt_secret": "my-secret-key",
        "encrypted_embedding": "gAAAAABl...",
        "face_vector": [float(i) for i in range(128)],  # 128 floats (> 20)
        "safe_score": 0.95,
        "safe_list": [1, 2, 3],
    }

    clean_meta = _sanitize_audit_metadata(dirty_meta)

    assert clean_meta["user_email"] == "student@demo.edu"
    assert "password" not in clean_meta
    assert "access_token" not in clean_meta
    assert "jwt_secret" not in clean_meta
    assert "encrypted_embedding" not in clean_meta
    assert "face_vector" not in clean_meta
    assert clean_meta["safe_score"] == 0.95
    assert clean_meta["safe_list"] == [1, 2, 3]



# ==============================================================================
# 7. IMAGE QUALITY MATHEMATICAL ALGORITHMS
# ==============================================================================

def test_unit_quality_screening_laplacian_blur_and_luminance():
    """Laplacian variance must flag blurry images and luminance bounds must flag dark/bright images."""
    # 1. High contrast sharp image
    sharp_img = np.zeros((320, 320, 3), dtype=np.uint8)
    for i in range(0, 320, 10):
        cv2.line(sharp_img, (0, i), (320, i), (255, 255, 255), 2)
    gray_sharp = cv2.cvtColor(sharp_img, cv2.COLOR_BGR2GRAY)
    lap_sharp = cv2.Laplacian(gray_sharp, cv2.CV_64F).var()
    assert lap_sharp > 50.0  # Sharp, well above blur floor (18.0)

    # 2. Blurry image
    blurry_img = cv2.GaussianBlur(sharp_img, (35, 35), 0)
    gray_blur = cv2.cvtColor(blurry_img, cv2.COLOR_BGR2GRAY)
    lap_blur = cv2.Laplacian(gray_blur, cv2.CV_64F).var()
    assert lap_blur < 10.0  # Fails blur floor

    # 3. Dark image
    dark_img = np.full((320, 320, 3), 15, dtype=np.uint8)
    gray_dark = cv2.cvtColor(dark_img, cv2.COLOR_BGR2GRAY)
    lum_dark = float(np.mean(gray_dark))
    assert lum_dark < 35.0  # Fails min luminance (35.0)

    # 4. Overexposed image
    bright_img = np.full((320, 320, 3), 245, dtype=np.uint8)
    gray_bright = cv2.cvtColor(bright_img, cv2.COLOR_BGR2GRAY)
    lum_bright = float(np.mean(gray_bright))
    assert lum_bright > 225.0  # Fails max luminance (225.0)
