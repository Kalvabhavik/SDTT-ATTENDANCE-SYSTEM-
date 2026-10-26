# Panorama verification experiment

run_manifest.py analyzes a local, consented-volunteer manifest with the production YuNet/ArcFace engine. Manifest frame paths, photographs and embeddings must remain local and must never be committed. It reports per-rule pass/flag/fail rates by device and the share of lecturer checks ending flagged. There are no bundled images, sample results or accuracy claims.

Run from repo root after installing backend requirements and configuring the models:

    python experiments/panorama_verification/run_manifest.py .\private-manifest.json --yunet .\private-models\face_detection_yunet_2023mar.onnx --arcface .\private-models\arcface.onnx
