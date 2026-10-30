# Comprehensive SDTT Attendance System Enhancements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix administrator student/class registration errors, seed rich timetable & multi-tier classrooms into live Supabase, enhance the classroom panorama pipeline with accurate controller reference training, crowd detection, venue classification (80/120/240/260/lab), instructor (sir) presence detection, and phone-pointing detection, and replace laggy loaders with the provided smooth .lottie animations.

**Architecture:** 
1. Database: Populate live Supabase tables (`classes`, `timetable`, `enrollments`) with diverse seating tiers (80, 120, 240, 260, lab), recurring weekly schedules, and student enrollments.
2. Admin Backend: Fix `controller_create_student` (create auth user first, then upsert profile and enrollments), `controller_create_class` (safe handling of nullable teacher and is_lab schema fallback), and `controller_capture_class_room` (remove missing `reference_captured_at` column constraint).
3. Vision Intelligence: Upgrade `_analyze_panorama_image` and `_panorama_context_analysis` in `backend/app/main.py` with multi-scale seated head/face detection for crowds, ORB/SSIM feature matching against controller's reference photo, spatial instructor/sir detection, smartphone screen pointing detection, and multi-tier venue classification.
4. Mobile UI: Incorporate `Sandy Loading.lottie`, `chatbot.lottie`, and `Ai-powered marketing tools abstract.lottie` into `AppLottieLoader` and mobile loading views.

**Tech Stack:** FastAPI, Supabase (Auth + PostgreSQL), OpenCV (`cv2`), Flutter/Dart, Lottie.

**Spec:** User request:
- Add dummy data in Supabase with classes across various timings with live updating.
- Fix administrator section (unable to register new student and class).
- Panorama intelligence: Train/match on controller's class photo, detect crowd, classify room (80, 120, 240, 260 seater or lab), detect if sir is present, detect any phone pointing, and capture all results.
- Replace laggy loading with `Sandy Loading.lottie`, `chatbot.lottie`, and `Ai-powered marketing tools abstract.lottie`.

---

## Global Constraints
- Must preserve active Supabase configuration and credentials.
- Must keep database schema backward-compatible without breaking existing tables.
- Flutter mobile app must pass `flutter analyze` and tests without syntax or asset loading regressions.
- Backend must pass test suite and run cleanly on Python 3.12.
- No dummy hallucinated data in error handling; all API errors must be clean, structured, and informative.

---

## Review Focus
1. `controller_create_student` must create an `auth.users` record and profile without throwing null ID or duplicate key errors.
2. `controller_create_class` must succeed even if `teacher_id` is unassigned or `is_lab` is not in the DB schema cache.
3. `controller_capture_class_room` must not fail with `PGRST204` on missing `reference_captured_at`.
4. Panorama analyzer must handle both synthetic/real panoramas, detect seated crowd, classify hall tier (80/120/240/260/lab), detect instructor/sir, and flag phone pointing without throwing exceptions.
5. All three `.lottie` animations must load smoothly without asset path errors or lag.

---

### Task 1: Seed Supabase with Multi-Tier Classrooms & Rich Timetable Schedule

**Files:**
- Create: `backend/scripts/seed_dummy_classes_timetable.py`
- Modify: `backend/app/main.py`

**Interfaces:**
- Produces: Populated `classes`, `timetable`, and `enrollments` in live Supabase.
- Consumes: Live Supabase service role client.

- [ ] **Step 1: Write seeding script for classrooms (80, 120, 240, 260, lab), timetable slots, and enrollments**
- [ ] **Step 2: Run seeding script against live Supabase database and verify rows**
- [ ] **Step 3: Verify `/api/timetable` and `/api/controller/classes` endpoints return the seeded data**
- [ ] **Step 4: Commit changes**

---

### Task 2: Fix Administrator & Controller Registration Issues

**Files:**
- Modify: `backend/app/main.py:3660-3720` (controller_create_class)
- Modify: `backend/app/main.py:3860-3880` (controller_capture_class_room)
- Modify: `backend/app/main.py:3912-3945` (controller_create_student)
- Test: `backend/tests/test_controller_and_reference.py`

**Interfaces:**
- Consumes: `CreateStudentRequest`, `CreateClassRequest`, multipart photo upload.
- Produces: Clean HTTP 200/201 responses with created student, class, and room reference.

- [ ] **Step 1: Write failing test in `backend/tests/test_controller_and_reference.py` for student creation, class creation with unassigned teacher, and room reference capture**
- [ ] **Step 2: Run test to observe failure**
- [ ] **Step 3: Implement fixes in `backend/app/main.py`**:
  - `controller_create_student`: Call `db.auth.admin.create_user`, retrieve `new_id`, upsert into `profiles`, and insert enrollments.
  - `controller_create_class`: Default unassigned teacher to valid profile or handle schema gracefully; remove unsupported columns before insertion.
  - `controller_capture_class_room`: Safely update without non-existent columns.
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Verify via live Supabase call**
- [ ] **Step 6: Commit changes**

---

### Task 3: Panorama Intelligence Engine (Reference Training, Crowd, Venue Tier, Sir & Phone Pointing Detection)

**Files:**
- Modify: `backend/app/main.py:1668-1845`
- Test: `backend/tests/test_classroom_panorama_api.py`

**Interfaces:**
- Consumes: Panorama stitched image `np.ndarray`, `session_row` with class reference photo and metadata.
- Produces: `context_analysis` and `detection_results` with:
  - `reference_matched`: bool, `similarity`: float, `match_confidence`: float
  - `crowd_count`: int, `crowd_boxes`: list
  - `venue_classification`: `{"capacity": int, "hall_type": str, "is_lab": bool, "confidence": float}`
  - `sir_presence`: `{"present": bool, "confidence": float, "box": list, "zone": str}`
  - `phone_pointing`: `{"detected": bool, "count": int, "boxes": list, "threat_level": str}`
  - Annotated image with visual overlays.

- [ ] **Step 1: Write tests in `backend/tests/test_classroom_panorama_api.py` for venue classification, crowd detection, sir presence, and phone pointing**
- [ ] **Step 2: Run test to observe test status**
- [ ] **Step 3: Implement intelligence engine in `backend/app/main.py`**:
  - Reference training & verification via ORB feature matching & SSIM against controller's room photo.
  - Multi-scale crowd detector combining head/face detection for seated students.
  - Architectural venue tier classifier for 80, 120, 240, 260, and Lab.
  - Front-of-hall / podium spatial instructor ("Sir") detector.
  - Anti-spoofing screen / phone pointing detector.
  - Annotated visual overlays with color-coded bounding boxes and top diagnostic HUD banner.
- [ ] **Step 4: Run test to verify all tests pass**
- [ ] **Step 5: Commit changes**

---

### Task 4: Integrate Smooth .lottie Animations into Mobile App

**Files:**
- Copy: `/home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/*.lottie` -> `apps/mobile/assets/animations/`
- Modify: `apps/mobile/lib/widgets/app_widgets.dart`
- Modify: `apps/mobile/lib/screens/classroom_panorama_screen.dart`
- Test: `apps/mobile/test/classroom_panorama_widget_test.dart`

**Interfaces:**
- Produces: Smooth, non-laggy animations for general loading, AI scanning, and panorama capture.

- [x] **Step 1: Copy `.lottie` files into `apps/mobile/assets/animations/`**
- [x] **Step 2: Update `AppLottieLoader` in `apps/mobile/lib/widgets/app_widgets.dart` to support animation types (`loading`, `ai`, `bot`) using the new `.lottie` assets**
- [x] **Step 3: Update `LoadingStateView` and `ClassroomPanoramaScreen` to display the smooth animations**
- [x] **Step 4: Run `flutter analyze` and mobile widget tests**
- [x] **Step 5: Commit changes**

---

### Task 5: End-to-End Verification and Server Restart

**Files:**
- Sync: Ensure backend running on port 8000 uses the updated code and restart it.
- Verify: Test mobile and backend flows with automated verification scripts.

- [x] **Step 1: Run complete backend pytest suite**
- [x] **Step 2: Restart backend server with new code and verify port 8000 responds with new endpoints**
- [x] **Step 3: Verify controller registration and panorama APIs live via curl test**
- [x] **Step 4: Document verification evidence**
