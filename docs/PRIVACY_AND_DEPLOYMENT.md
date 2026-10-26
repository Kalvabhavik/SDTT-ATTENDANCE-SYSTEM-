# Privacy and deployment

## Biometric data lifecycle

Enrollment requires explicit consent. YuNet detects faces; ArcFace ONNX embeddings are encrypted server-side with ATTENDANCE_TEMPLATE_ENCRYPTION_KEY and stored in face_templates. Enrollment API responses expose only a boolean, model version and consent timestamp. Service-role access is required for biometric records; RLS has no client-readable policy for templates/evidence. Do not place the service key, encryption key, model files, images, embeddings, credentials or tokens in client bundles, logs or source control.

Sweep uploads are analyzed frame by frame. Verified and rejected attempts store metrics/reason codes, not raw image bytes. Flagged attempts retain selected key frames in the private Supabase Storage bucket for ATTENDANCE_FLAGGED_RETENTION_DAYS (default 7); a background retention worker deletes expired storage objects and evidence rows. Review links are signed and short-lived. Multipart upload spooling may use temporary storage during request processing; secure and clean server temporary storage as part of deployment operations.

JWT identity is checked through Supabase Auth and profile role, and selected login role must match. Attendance decisions and time windows are backend-authoritative. Heading metadata is client-supplied and spoofable; it is supporting evidence, not proof of a physical sweep or liveness. No liveness detection is implemented or claimed. Lecturer review or manual roll-call override handles uncertain evidence.

## Model licensing and evidence

YuNet model files in OpenCV Zoo are marked MIT in the [official model README](https://github.com/opencv/opencv_zoo/blob/main/models/face_detection_yunet/README.md?plain=1). InsightFace source code is MIT, but its [official model README](https://github.com/deepinsight/insightface/blob/master/README.md?plain=1) states pretrained models are for non-commercial research purposes; obtain a separate commercial license before commercial deployment. Confirm the precise downloaded ONNX model provenance and terms. Model files are not included.

There is no accuracy claim. The late-stage lecturer test is likely to be uncertain with small front-camera faces; the current detector has no independent person detector. Run experiments/panorama_verification/run_manifest.py only with a locally held, consented-volunteer manifest and real models. It reports rule outcomes per device and flagged lecturer checks; never commit photos or embeddings.

## Deployment prerequisites

- Apply SQL migrations using the approved Supabase migration process. Test RLS, service-role boundaries, storage bucket privacy and RPC atomicity in a dedicated project.
- Configure HTTPS/WSS, Supabase keys, JWT secret, Fernet encryption key, private model files, CORS, upload limits, retention, monitoring and backups in secret management. .env is local only.
- Verify rate limiting across multiple workers (current login limiting is in-process), request size limits at proxy and application layers, concurrent writes, lifecycle jobs, and retention deletion.
- Establish notice, consent, age/jurisdiction review, accessible manual opt-out, deletion requests and incident response before real classroom use. No email/SMS provider is configured; notifications are in-app.

Implementation source alone does not prove migration execution, storage privacy, model suitability, accuracy, fairness or real-device behavior.
