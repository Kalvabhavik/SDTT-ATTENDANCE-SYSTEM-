"""FaceEngine interface and implementations for detection, alignment, and embeddings.

Supports:
- FaceDetectorYN (YuNet) for lightweight face detection and 5-point landmark extraction.
- ArcFace ONNX Runtime for 512-dimensional facial recognition embeddings.
- Deterministic FakeFaceEngine for test fixtures without heavy weights.
- License disclosure: YuNet (Apache 2.0 / MIT); ArcFace reference weights (non-commercial / academic).
"""
from __future__ import annotations

import abc
import hashlib
import math
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Optional

import numpy as np

try:
    import cv2
except ImportError:
    cv2 = None

try:
    import onnxruntime as ort
except ImportError:
    ort = None


@dataclass
class FaceDetection:
    """Bounding box, confidence, and landmarks for a detected human face."""
    bbox_x: int
    bbox_y: int
    bbox_w: int
    bbox_h: int
    confidence: float
    landmarks: list[tuple[float, float]] = field(default_factory=list)
    ipd_px: float = 0.0

    @property
    def center(self) -> tuple[float, float]:
        return (self.bbox_x + self.bbox_w / 2.0, self.bbox_y + self.bbox_h / 2.0)


class FaceEngine(abc.ABC):
    """Abstract interface for face detection and embedding extraction."""

    @abc.abstractmethod
    def detect_faces(self, img_bgr: np.ndarray) -> list[FaceDetection]:
        """Detect faces in an image and return bounding boxes and landmarks."""
        pass

    @abc.abstractmethod
    def extract_embedding(self, img_bgr: np.ndarray, detection: FaceDetection) -> np.ndarray:
        """Extract a 512-dimensional unit embedding vector for the detected face."""
        pass

    def compute_similarity(self, emb1: np.ndarray, emb2: np.ndarray) -> float:
        """Compute cosine similarity between two unit embedding vectors."""
        if emb1 is None or emb2 is None:
            return 0.0
        v1 = np.asarray(emb1, dtype=np.float32).flatten()
        v2 = np.asarray(emb2, dtype=np.float32).flatten()
        norm1 = np.linalg.norm(v1)
        norm2 = np.linalg.norm(v2)
        if norm1 < 1e-6 or norm2 < 1e-6:
            return 0.0
        return float(np.dot(v1, v2) / (norm1 * norm2))

    def compute_phash(self, img_bgr: np.ndarray) -> str:
        """Compute a 64-bit perceptual hash (pHash) based on DCT frequency analysis."""
        if cv2 is None or img_bgr is None or img_bgr.size == 0:
            return "0" * 16
        gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY) if len(img_bgr.shape) == 3 else img_bgr
        resized = cv2.resize(gray, (32, 32), interpolation=cv2.INTER_AREA)
        dct = cv2.dct(np.float32(resized))
        # Top-left 8x8 low frequency region excluding DC component (0,0)
        dct_low = dct[:8, :8]
        median = float(np.median(dct_low))
        bits = dct_low > median
        hash_val = 0
        for bit in bits.flatten():
            hash_val = (hash_val << 1) | int(bit)
        return f"{hash_val:016x}"

    def compute_visual_continuity(self, img1: np.ndarray, img2: np.ndarray) -> float:
        """Compute visual continuity (similarity) between two consecutive frames.

        Returns a score in [0.0, 1.0], where >= 0.30 indicates continuous video
        and low values suggest discontinuous or spliced frames.
        """
        if cv2 is None or img1 is None or img2 is None:
            return 0.5
        h1, w1 = img1.shape[:2]
        h2, w2 = img2.shape[:2]
        if (h1, w1) != (h2, w2):
            img2 = cv2.resize(img2, (w1, h1))

        hsv1 = cv2.cvtColor(img1, cv2.COLOR_BGR2HSV)
        hsv2 = cv2.cvtColor(img2, cv2.COLOR_BGR2HSV)
        hist1 = cv2.calcHist([hsv1], [0, 1], None, [30, 32], [0, 180, 0, 256])
        hist2 = cv2.calcHist([hsv2], [0, 1], None, [30, 32], [0, 180, 0, 256])
        cv2.normalize(hist1, hist1, alpha=0, beta=1, norm_type=cv2.NORM_MINMAX)
        cv2.normalize(hist2, hist2, alpha=0, beta=1, norm_type=cv2.NORM_MINMAX)
        score = float(cv2.compareHist(hist1, hist2, cv2.HISTCMP_CORREL))
        return max(0.0, min(1.0, (score + 1.0) / 2.0))


class RealFaceEngine(FaceEngine):
    """Production face engine using OpenCV YuNet and ArcFace ONNX."""

    def __init__(self, yunet_model_path: Optional[str] = None, arcface_model_path: Optional[str] = None):
        self.yunet_path = yunet_model_path
        self.arcface_path = arcface_model_path
        self._detector: Any = None
        self._detector_type = "none"
        self._arcface_session: Any = None
        self._init_models()

    def _init_models(self) -> None:
        if cv2 is None:
            return

        # Initialize YuNet if model path exists
        if self.yunet_path and Path(self.yunet_path).exists():
            try:
                self._detector = cv2.FaceDetectorYN.create(
                    model=self.yunet_path,
                    config="",
                    input_size=(320, 320),
                    score_threshold=0.5,
                    nms_threshold=0.3,
                    top_k=5000,
                )
                self._detector_type = "yunet"
            except Exception:
                self._detector = None

        # Fallback to Haar cascade if YuNet not loaded
        if self._detector is None:
            cascade_path = cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
            if Path(cascade_path).exists():
                self._detector = cv2.CascadeClassifier(cascade_path)
                self._detector_type = "haar"

        # Initialize ArcFace ONNX if present
        if ort is not None and self.arcface_path and Path(self.arcface_path).exists():
            try:
                self._arcface_session = ort.InferenceSession(self.arcface_path)
            except Exception:
                self._arcface_session = None

    def detect_faces(self, img_bgr: np.ndarray) -> list[FaceDetection]:
        if cv2 is None or self._detector is None or img_bgr is None or img_bgr.size == 0:
            return []

        h, w = img_bgr.shape[:2]
        faces: list[FaceDetection] = []

        if self._detector_type == "yunet":
            self._detector.setInputSize((w, h))
            _, detections = self._detector.detect(img_bgr)
            if detections is not None:
                for d in detections:
                    box_x = max(0, int(d[0]))
                    box_y = max(0, int(d[1]))
                    box_w = max(1, int(d[2]))
                    box_h = max(1, int(d[3]))
                    conf = float(d[14])
                    # Landmarks: right eye (d[4], d[5]), left eye (d[6], d[7])
                    rx, ry = float(d[4]), float(d[5])
                    lx, ly = float(d[6]), float(d[7])
                    ipd = math.sqrt((rx - lx) ** 2 + (ry - ly) ** 2)
                    landmarks = [(rx, ry), (lx, ly), (float(d[8]), float(d[9])),
                                 (float(d[10]), float(d[11])), (float(d[12]), float(d[13]))]
                    faces.append(FaceDetection(
                        bbox_x=box_x,
                        bbox_y=box_y,
                        bbox_w=box_w,
                        bbox_h=box_h,
                        confidence=round(conf, 3),
                        landmarks=landmarks,
                        ipd_px=round(ipd, 1),
                    ))
        elif self._detector_type == "haar":
            gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY) if len(img_bgr.shape) == 3 else img_bgr
            rects = self._detector.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=4, minSize=(20, 20))
            for (x, y, bw, bh) in rects:
                approx_ipd = round(bw * 0.38, 1)
                # Synthetic eye coordinates for alignment
                rx = x + bw * 0.31
                ry = y + bh * 0.37
                lx = x + bw * 0.69
                ly = y + bh * 0.37
                faces.append(FaceDetection(
                    bbox_x=int(x),
                    bbox_y=int(y),
                    bbox_w=int(bw),
                    bbox_h=int(bh),
                    confidence=0.85,
                    landmarks=[(rx, ry), (lx, ly)],
                    ipd_px=approx_ipd,
                ))

        return faces

    def extract_embedding(self, img_bgr: np.ndarray, detection: FaceDetection) -> np.ndarray:
        h, w = img_bgr.shape[:2]
        x1 = max(0, detection.bbox_x)
        y1 = max(0, detection.bbox_y)
        x2 = min(w, detection.bbox_x + detection.bbox_w)
        y2 = min(h, detection.bbox_y + detection.bbox_h)
        crop = img_bgr[y1:y2, x1:x2]

        if crop.size == 0 or cv2 is None:
            return np.zeros(512, dtype=np.float32)

        # If ArcFace ONNX runtime session is active:
        if self._arcface_session is not None:
            aligned = cv2.resize(crop, (112, 112))
            rgb = cv2.cvtColor(aligned, cv2.COLOR_BGR2RGB)
            input_tensor = np.transpose(rgb, (2, 0, 1)).astype(np.float32)
            input_tensor = (input_tensor - 127.5) / 128.0
            input_tensor = np.expand_dims(input_tensor, axis=0)
            input_name = self._arcface_session.get_inputs()[0].name
            raw_emb = self._arcface_session.run(None, {input_name: input_tensor})[0][0]
            norm = np.linalg.norm(raw_emb)
            return (raw_emb / (norm + 1e-7)).astype(np.float32)

        # Fallback feature extractor when ONNX model file is not provisioned
        # Uses normalized spatial gradient representation (112x112 -> 512 dimensions)
        aligned = cv2.resize(crop, (64, 64))
        gray = cv2.cvtColor(aligned, cv2.COLOR_BGR2GRAY)
        gx = cv2.Sobel(gray, cv2.CV_32F, 1, 0, ksize=3)
        gy = cv2.Sobel(gray, cv2.CV_32F, 0, 1, ksize=3)
        mag = cv2.magnitude(gx, gy)
        sampled = cv2.resize(mag, (16, 32)).flatten()[:512]
        norm = np.linalg.norm(sampled)
        if norm > 1e-6:
            sampled = sampled / norm
        return sampled.astype(np.float32)


class FakeFaceEngine(FaceEngine):
    """Deterministic face engine for unit and integration testing."""

    def __init__(self):
        self.preset_detections: list[FaceDetection] = []
        self.identity_map: dict[str, np.ndarray] = {}
        self.default_similarity = 0.85

    def set_identity_embedding(self, identity_key: str, embedding: np.ndarray) -> None:
        self.identity_map[identity_key] = embedding

    def create_deterministic_embedding(self, seed_text: str) -> np.ndarray:
        """Create a consistent 512-dim unit vector based on a string seed."""
        h = hashlib.sha256(seed_text.encode("utf-8")).digest()
        # Generate 512 floats deterministically
        floats = []
        counter = 0
        while len(floats) < 512:
            chunk = hashlib.sha256(h + counter.to_bytes(4, "big")).digest()
            for i in range(0, len(chunk), 4):
                if len(floats) < 512:
                    val = int.from_bytes(chunk[i:i+4], "big", signed=True) / (2**31)
                    floats.append(val)
            counter += 1
        arr = np.asarray(floats, dtype=np.float32)
        norm = np.linalg.norm(arr)
        return arr / (norm + 1e-7)

    def detect_faces(self, img_bgr: np.ndarray) -> list[FaceDetection]:
        if self.preset_detections:
            return list(self.preset_detections)
        # Default mock detection if an image has pixels
        if img_bgr is not None and img_bgr.size > 0:
            h, w = img_bgr.shape[:2]
            return [
                FaceDetection(
                    bbox_x=int(w * 0.3),
                    bbox_y=int(h * 0.2),
                    bbox_w=int(w * 0.4),
                    bbox_h=int(h * 0.5),
                    confidence=0.98,
                    landmarks=[(w * 0.4, h * 0.35), (w * 0.6, h * 0.35)],
                    ipd_px=float(w * 0.2),
                )
            ]
        return []

    def extract_embedding(self, img_bgr: np.ndarray, detection: FaceDetection) -> np.ndarray:
        # Generate embedding derived from detection position and size
        seed = f"{detection.bbox_x}_{detection.bbox_y}_{detection.bbox_w}_{detection.bbox_h}"
        return self.create_deterministic_embedding(seed)


# Global face engine instance
_ENGINE_INSTANCE: Optional[FaceEngine] = None


def get_face_engine() -> FaceEngine:
    global _ENGINE_INSTANCE
    if _ENGINE_INSTANCE is None:
        _ENGINE_INSTANCE = RealFaceEngine()
    return _ENGINE_INSTANCE


def set_face_engine(engine: FaceEngine) -> None:
    global _ENGINE_INSTANCE
    _ENGINE_INSTANCE = engine
