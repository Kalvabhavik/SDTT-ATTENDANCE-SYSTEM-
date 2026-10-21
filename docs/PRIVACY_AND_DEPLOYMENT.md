# Privacy and deployment notes

## Prototype limits

This codebase uses fictional roster entries and a deterministic/simulated review response. It does not identify people from faces. Uploaded images are used for the current request and are not persisted by the application; multipart parsing may spool large files to temporary storage during processing. The mobile client should remove its temporary camera file after upload. Avoid real student names, photos, biometrics, or attendance records in this demo.

Attendance is provisional until the teacher explicitly accepts or corrects suggestions and finalizes the session. The audit log records who changed what and when. Students can view only their own attendance and in-app notifications. No email or SMS notification provider is included; app notification feed is the only channel in this prototype. Browser/native WebSocket events are update signals, not a substitute for re-fetching authoritative records.

## Before any pilot or production use

Determine applicable education, privacy, and biometric rules for the actual jurisdiction and age group; give notice and obtain appropriate consent; offer a reliable opt-out/manual attendance route; define deletion and retention periods; complete a threat model and access-control review; secure TLS/WSS, database encryption, backups, and secrets; replace demo credentials; and assess false accepts/rejects under actual classroom conditions and across demographics. Do not rely on literature benchmark scores as classroom accuracy guarantees. Obtain any required human, legal, security, and institutional approvals before real biometric use.

If app push (rather than in-app notifications) is later required, configure Firebase Cloud Messaging with server-only credentials and user-approved device tokens. The request specified app-only delivery, so email/SMS integrations are intentionally absent.
