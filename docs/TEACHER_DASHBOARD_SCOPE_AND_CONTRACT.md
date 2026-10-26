# Teacher dashboard implementation plan and data contract

## Scope decision

The attached Attendrix master brief describes a much broader product than the current API provides. This implementation improves the active React dashboard (`apps/dashboard/`) using the documented FastAPI/Supabase contract and does not replace the backend or introduce fabricated client data.

### Delivered in this pass

1. Make the teacher overview resilient: loading, explicit retry/error feedback, last successful refresh, honest unavailable values, and meaningful loaded-empty states.
2. Improve session history loading/error/retry behavior and avoid treating missing session status as a real status.
3. Improve the selected-session workspace: searchable roster and submissions, filters based on actual attendance/submission/review status, visible session-scoped counts, refresh timestamp, and errors.
4. Replace browser `prompt()` reason collection with labeled accessible forms for audited submission reviews and attendance corrections; keep confirmation before finalization.
5. Clarify that reports are per-session and that print/save-to-PDF is browser print behavior, not a server-generated PDF.
6. Document the current visual tokens and component/accessibility conventions in [`../apps/dashboard/design.md`](../apps/dashboard/design.md).

## Current API contract used by the UI

All routes are under `/api`; authenticated HTTP calls use the Supabase access token. The active backend is `backend/app/main.py`.

| Need | API route / returned information | UI treatment |
|---|---|---|
| Teacher's classes | `GET /classes`; class ID/name/code and available enrollment count | Render returned class data; missing enrollment count is unavailable, not zero. No schedule/section/classroom fields are assumed. |
| Session list/detail | `GET /sessions`, `GET /sessions/{session_id}`; actual server status and teacher roster in detail | Display scheduled/open/closed/finalized; missing state is unavailable. Counts are derived only from successfully returned rows. |
| Create/timing controls | `POST /sessions`; class, title, opening/deadline, optional normalized `stage_region`, minimum people | Validate form input, but server time is authoritative. |
| Session state controls | `POST /sessions/{session_id}/open`, `/close`, `/finalize` | Show current state and available actions; remaining pending rows become absent on finalization per backend policy. |
| Submission review inbox | `GET /sessions/{session_id}/submissions`; student, time, attempt, status, explanation, quality/scene metadata and short-lived private image URL | Search/filter only the loaded selected session. Missing values remain unknown. No global inbox is implied. |
| Review decisions | `POST /sessions/{session_id}/submissions/{submission_id}/review`; approve/reject plus required reason | Capture an explicit reason, submit to the audited backend route, refresh authoritative records. |
| Manual roster correction | `PATCH /sessions/{session_id}/attendance/{student_id}`; status and note | Capture a correction reason and refresh records. |
| Session report | `GET /reports/sessions/{session_id}`; session rows, counts, CSV and print-oriented HTML | Show returned summary/row counts and export/print; no cross-course analytics or server PDF is inferred. |
| Live refresh | `POST /auth/ws-ticket`, `/ws` or `/api/ws`; event signals | Re-fetch REST state after events; refresh timestamps refer to successful REST reads. Events are not a durable job log. |

The current image analysis reports image quality, person counts, optional person-in-configured-region evidence, status, and explanation. A `VERIFIED` submission means configured **scene criteria** passed for an authenticated submitter; it does not identify any person in the image.

## Explicitly unsupported by current backend

Do not implement UI that presents any of the following as current product capability: student face matching or liveness, lecturer identity/presence, classroom identity matching, screen-spoof detection, per-person identity verification, secondary/background AI audits, processing-job stages/retries/latency, queue or worker health, model version/calibrated confidence, fraud/anomaly/security event feeds, admin-only operations, class schedules/room/capacity management, global pending-review queue, or cross-session/date-filtered analytics. These require separately designed backend, authorization, storage, and privacy contracts; a frontend mock is not an acceptable substitute.

The attached brief mentions identity verification and continuous verification stages that conflict with the repository's explicit scene-only privacy boundary. This dashboard retains the existing boundary and does not claim identity recognition or continuous monitoring.

## Validation performed

The dashboard TypeScript check and Vite production build were run after the changes. Backend contracts and the hosted service were not modified by this dashboard-only work. Full browser interaction, Flutter builds, and live authorization tests require their respective toolchain and deployment test accounts.
