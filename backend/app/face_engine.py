"""Real YuNet + ArcFace analysis boundary; models are supplied by deployment."""
from __future__ import annotations

import os
from pathlib import Path
from typing import Any

import cv2
import numpy as np
import onnxruntime as ort


class ModelUnavailable(RuntimeError):
    pass


class YuNetArcFaceEngine:
    """Detect with YuNet, align five landmarks, and embed with ArcFace ONNX."""

    model_version = os.getenv("ATTENDANCE_FACE_MODEL_VERSION", "yunet-arcface-unconfigured")

    def __init__(self, detector_path: str | None = None, recognizer_path: str | None = None):
        detector = detector_path or os.getenv("ATTENDANCE_YUNET_MODEL_PATH")
        recognizer = recognizer_path or os.getenv("ATTENDANCE_ARCFACE_MODEL_PATH")
        if not detector or not recognizer or not Path(detector).is_file() or not Path(recognizer).is_file():
            raise ModelUnavailable("Configure licensed YuNet and ArcFace ONNX model files on the backend")
        if not hasattr(cv2, "FaceDetectorYN_create"):
            raise ModelUnavailable("opencv-python-headless build does not provide FaceDetectorYN")
        self.detector_path = detector
        self.detector = None
        self.session = ort.InferenceSession(recognizer, providers=["CPUExecutionProvider"])
        self.input = self.session.get_inputs()[0]
        self.model_version = os.getenv("ATTENDANCE_FACE_MODEL_VERSION", "yunet-arcface-v1")

    def analyze(self, image_bytes: bytes) -> dict[str, Any]:
        array = np.frombuffer(image_bytes, dtype=np.uint8)
        image = cv2.imdecode(array, cv2.IMREAD_COLOR)
        if image is None:
            raise ValueError("invalid_image")
        height, width = image.shape[:2]
        if self.detector is None:
            self.detector = cv2.FaceDetectorYN_create(
                self.detector_path, "", (width, height), 0.6, 0.3, 5000
            )
        self.detector.setInputSize((width, height))
        _, detections = self.detector.detect(image)
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        brightness = float(np.mean(gray))
        blur = float(cv2.Laplacian(gray, cv2.CV_64F).var())
        faces = []
        for row in detections if detections is not None else []:
            x, y, w, h = [float(value) for value in row[:4]]
            points = np.asarray(row[4:14], dtype=np.float32).reshape(5, 2)
            aligned = self._align(image, points)
            blob = cv2.dnn.blobFromImage(aligned, 1.0 / 127.5, (112, 112), (127.5, 127.5), swapRB=True)
            embedding = self.session.run(None, {self.input.name: blob})[0].reshape(-1).astype(np.float32)
            norm = float(np.linalg.norm(embedding))
            if norm:
                embedding /= norm
            faces.append({
                "bbox": [x, y, w, h],
                "embedding": embedding.tolist(),
                "inter_pupil_pixels": float(np.linalg.norm(points[0] - points[1])),
                "quality": float(row[14]),
            })
        return {
            "width": width, "height": height, "brightness": brightness,
            "laplacian_variance": blur, "faces": faces,
            "person_detected": bool(faces),
        }

    @staticmethod
    def _align(image: np.ndarray, landmarks: np.ndarray) -> np.ndarray:
        target = np.asarray([
            [38.2946, 51.6963], [73.5318, 51.5014], [56.0252, 71.7366],
            [41.5493, 92.3655], [70.7299, 92.2041],
        ], dtype=np.float32)
        transform, _ = cv2.estimateAffinePartial2D(landmarks, target, method=cv2.LMEDS)
        if transform is None:
            raise ValueError("face_alignment_failed")
        return cv2.warpAffine(image, transform, (112, 112), borderValue=0)


def cosine_similarity(left: list[float], right: list[float]) -> float:
    a = np.asarray(left, dtype=np.float32)
    b = np.asarray(right, dtype=np.float32)
    denom = float(np.linalg.norm(a) * np.linalg.norm(b))
    return float(np.dot(a, b) / denom) if denom else -1.0
