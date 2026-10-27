"use client";

import React, { useState } from "react";
import { soundManager } from "./SoundManager";
import {
  GitCommit,
  CheckCircle2,
  AlertOctagon,
  FileCode,
  Cpu,
  Layers,
  ArrowRight,
  Shield,
  Eye,
  Sliders,
  ChevronRight,
  Sparkles,
} from "lucide-react";

interface PipelineStage {
  id: number;
  name: string;
  shortName: string;
  tagline: string;
  purpose: string;
  input: string;
  output: string;
  failureConditions: string;
  status: "Implemented in Prototype" | "Proposed for Production";
  statusColor: string;
  codeSnippet: string;
}

export default function Section09PipelineDeepDive() {
  const [activeStageId, setActiveStageId] = useState<number>(3); // Default on Detection stage

  const stages: PipelineStage[] = [
    {
      id: 1,
      name: "Stage 1: Dual-Stream Payload Ingestion",
      shortName: "1. Ingestion",
      tagline: "180° sweep trajectory and venue reference pairing",
      purpose:
        "Ingests the client-side continuous 180° gyroscopic sweep payload (yaw, pitch, roll telemetry samples) and student biometric probe frames over secure HTTPS / WebSocket, paired with the Academic Controller's venue reference panorama.",
      input: "Base64 camera frames, monotonic gyro sample array, session JWT, student ID.",
      output: "Raw image buffer in memory, trajectory sequence dict, active session lock.",
      failureConditions: "Corrupt image format, payload size > 10MB, network timeout.",
      status: "Implemented in Prototype",
      statusColor: "bg-emerald-100 text-emerald-950 border-emerald-300 font-bold",
      codeSnippet: `async def submit_attendance_sweep(
    session_id: str,
    gyro_trajectory: List[GyroSample],
    file: UploadFile = File(...)
):
    # Enforce MAX_CAPTURE_BYTES (10MB limit)
    contents = await file.read()
    return parse_and_validate_sweep(contents, gyro_trajectory)`,
    },
    {
      id: 2,
      name: "Stage 2: Continuous 180° Gyroscope Trajectory Gate",
      shortName: "2. Gyro Gate",
      tagline: "Dynamic spatial-temporal replay elimination",
      purpose:
        "Verifies that the student swept their device across the physical lecture hall horizontally. Evaluates monotonic yaw angular displacement (Delta yaw >= 120°) to mathematically eliminate static photo relays, screenshots, and pre-recorded videos.",
      input: "Array of GyroSample { timestamp, yaw, pitch, roll }.",
      output: "SweepValidationResult { valid: bool, delta_yaw: float, monotonic: bool }.",
      failureConditions:
        "Delta yaw < 120°, non-monotonic angular velocity (spikes or reversed movement), static phone holding.",
      status: "Implemented in Prototype",
      statusColor: "bg-emerald-100 text-emerald-950 border-emerald-300 font-bold",
      codeSnippet: `def verify_gyro_sweep(samples: List[GyroSample]):
    yaw_values = [s.yaw for s in samples]
    delta_yaw = max(yaw_values) - min(yaw_values)
    is_continuous = check_monotonic_progression(yaw_values)
    
    if delta_yaw < 120.0 or not is_continuous:
        return SweepResult(valid=False, reason="insufficient_arc")
    return SweepResult(valid=True, delta_yaw=delta_yaw)`,
    },
    {
      id: 3,
      name: "Stage 3: Image Quality & Sharpness Assessment",
      shortName: "3. Quality",
      tagline: "Laplacian variance and luminance stabilization",
      purpose:
        "Evaluates whether the student face capture possesses sufficient optical clarity before expending deep learning compute. Computes Laplacian variance for motion blur and luminance histogram for ambient lighting.",
      input: "RGB image tensor [H, W, 3].",
      output: "Sharpness index Var(nabla^2 I), mean luminance lux estimate.",
      failureConditions:
        "Laplacian variance < 1.5 (severe motion blur), mean luminance <= 3.0 lux (extreme underexposure).",
      status: "Implemented in Prototype",
      statusColor: "bg-emerald-100 text-emerald-950 border-emerald-300 font-bold",
      codeSnippet: `def check_image_quality(img_rgb):
    gray = cv2.cvtColor(img_rgb, cv2.COLOR_RGB2GRAY)
    laplacian_var = cv2.Laplacian(gray, cv2.CV_64F).var()
    mean_lux = float(np.mean(gray))
    
    if laplacian_var < 1.5:
        return QualityResult(usable=False, reason="motion_blur")
    if mean_lux <= 3.0:
        return QualityResult(usable=False, reason="low_lighting")
    return QualityResult(usable=True, score=laplacian_var, lux=mean_lux)`,
    },
    {
      id: 4,
      name: "Stage 4: Face Detection & Anti-Empty-Room Defense",
      shortName: "4. Anti-Proxy",
      tagline: "Candidate localization & zero-presence proxy interception",
      purpose:
        "Executes YuNet / SCRFD face candidate localization and 5 facial landmarks. Simultaneously evaluates peer crowd density in classroom context frames. IF ZERO FACES ARE DETECTED (empty room capture), immediately triggers Anti-Empty-Room Proxy Interception.",
      input: "Preprocessed RGB image and classroom context frame.",
      output: "Bounding box [x, y, w, h], 5 landmark pairs, peer count N.",
      failureConditions:
        "Zero human faces detected in room (empty room proxy attempt), severe off-camera face orientation.",
      status: "Implemented in Prototype",
      statusColor: "bg-emerald-100 text-emerald-950 border-emerald-300 font-bold",
      codeSnippet: `# DETECTOR ONLY: Answers "Is a human face present here?"
detector = cv2.FaceDetectorYN.create(
    model="yunet.onnx", config="",
    input_size=(320, 320), score_threshold=0.6
)
_, faces = detector.detect(img)
if faces is None or len(faces) == 0:
    # Anti-Empty-Room Zero-Presence Proxy Interception
    return ProxyAlert(status=AttendanceStatus.PENDING_REVIEW,
                      flag="EMPTY_ROOM_SPOOF_ATTEMPT")`,
    },
    {
      id: 5,
      name: "Stage 5: 1:1 Identity Verification (ArcFace 512-D)",
      shortName: "5. Identity",
      tagline: "MobileFaceNet 512-dimensional vector embedding comparison",
      purpose:
        "Applies similarity affine transform aligning eye landmarks horizontally, crops canonical 112x112 face tensor, extracts 512-D unit embedding, and computes scalar cosine similarity against the student's authorized registration reference vector.",
      input: "Aligned 112x112 canonical crop + registered 512-D reference vector.",
      output: "Scalar cosine similarity score cos(theta) in [-1.0, 1.0].",
      failureConditions:
        "Cosine similarity below threshold (tau < 0.68), unregistered student reference vector.",
      status: "Implemented in Prototype",
      statusColor: "bg-emerald-100 text-emerald-950 border-emerald-300 font-bold",
      codeSnippet: `# Extracts 512-D unit embedding vector
emb_probe = arcface_model.forward(aligned_112x112)
# Cosine similarity: cos(theta) = u . v (normalized)
cosine_sim = np.dot(emb_probe, emb_reference)
verified = (cosine_sim >= 0.68)`,
    },
    {
      id: 6,
      name: "Stage 6: Multi-Factor 9-Rule Decision Policy",
      shortName: "6. Decision",
      tagline: "Deterministic rule matrix evaluation into 4 operational states",
      purpose:
        "Synthesizes active liveness challenge, gyro sweep trajectory, image quality gates, YuNet anti-empty-room crowd detection, and ArcFace cosine similarity into four transparent states: VERIFIED, PENDING_REVIEW, UNCERTAIN, or REJECTED.",
      input: "Active liveness (left/right/blink), Gyro delta yaw, Laplacian variance, peer face count, cosine similarity.",
      output: "AttendanceStatus: {VERIFIED, PENDING_REVIEW, UNCERTAIN, REJECTED}.",
      failureConditions: "Ambiguous sensor reading or missing controller venue anchor.",
      status: "Implemented in Prototype",
      statusColor: "bg-emerald-100 text-emerald-950 border-emerald-300 font-bold",
      codeSnippet: `if not liveness_verified or empty_room_flag or delta_yaw < 120.0:
    return AttendanceStatus.PENDING_REVIEW  # Flagged for supervisor
elif is_duplicate or student_unregistered:
    return AttendanceStatus.REJECTED
elif quality_ok and cosine_sim >= 0.68:
    return AttendanceStatus.VERIFIED
elif cosine_sim >= 0.50:
    return AttendanceStatus.PENDING_REVIEW
else:
    return AttendanceStatus.UNCERTAIN`,
    },
    {
      id: 7,
      name: "Stage 7: Teacher Review & Controller Audit Trail",
      shortName: "7. Audit",
      tagline: "Human-in-the-loop dispute resolution, Excel export, and governance",
      purpose:
        "Allows authorized faculty to inspect flagged empty room proxy alerts and borderline cosine scores on the live WebSocket dashboard, apply justified overrides, and export cryptographically sealed Excel XLSX rosters.",
      input: "Faculty override decision (Approve / Reject), faculty ID, justification note.",
      output: "Finalized attendance status, updated PostgreSQL row, Excel XLSX export.",
      failureConditions: "Unauthorized user attempting override without teacher or controller role.",
      status: "Implemented in Prototype",
      statusColor: "bg-emerald-100 text-emerald-950 border-emerald-300 font-bold",
      codeSnippet: `def record_faculty_override(session_id, student_id, decision, reason):
    db.audit_logs.insert({
        "session_id": session_id,
        "student_id": student_id,
        "action": f"manual_override_{decision}",
        "actor": current_user.email,
        "timestamp": utc_now()
    })
    broadcast_ws_event(session_id, "ATTENDANCE_OVERRIDE_FINALIZED")`,
    },
  ];

  const currentStage = stages.find((s) => s.id === activeStageId) || stages[0];

  return (
    <section id="pipeline" className="relative py-24 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto">
      {/* Header */}
      <div className="text-center max-w-3xl mx-auto mb-16">
        <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-amber-100 border border-amber-300 text-amber-900 font-mono text-xs font-bold mb-4 shadow-sm">
          <GitCommit className="w-3.5 h-3.5" />
          <span>SECTION 09 • DEEP DIVE</span>
        </div>
        <h2 className="text-3xl sm:text-5xl font-extrabold text-slate-900 tracking-tight mb-4">
          Detection Is Not <br />
          <span className="bg-gradient-to-r from-amber-800 via-amber-700 to-orange-700 bg-clip-text text-transparent">
            Identification.
          </span>
        </h2>
        <p className="text-base sm:text-lg text-slate-700 font-medium">
          The central computer-vision distinction behind Attendrix: detecting that a face exists is trivial; verifying an identity requires high biometric texture, 1-to-1 alignment, and policy-driven corroboration.
        </p>
      </div>

      {/* Horizontal Stage Navigator */}
      <div className="glass-panel p-2.5 rounded-2xl border border-slate-300/90 bg-white/95 mb-8 overflow-x-auto shadow-md">
        <div className="flex items-center min-w-max gap-1.5">
          {stages.map((stage) => {
            const isSelected = stage.id === activeStageId;
            return (
              <button
                key={stage.id}
                onClick={() => {
                  soundManager.playClick();
                  setActiveStageId(stage.id);
                }}
                className={`px-4 py-2.5 rounded-xl text-xs font-mono transition-all flex items-center gap-2 cursor-pointer ${
                  isSelected
                    ? "bg-amber-600 text-white font-bold shadow-md shadow-amber-600/30"
                    : "text-slate-800 font-semibold hover:text-slate-900 hover:bg-slate-100"
                }`}
              >
                <span>{stage.shortName}</span>
              </button>
            );
          })}
        </div>
      </div>

      {/* Detailed Stage Exploration Canvas */}
      <div className="glass-panel p-6 sm:p-10 rounded-3xl border border-slate-300/90 bg-white/95 grid grid-cols-1 lg:grid-cols-12 gap-8 items-start relative shadow-xl">
        {/* Left Column: Stage Specifications */}
        <div className="lg:col-span-6 space-y-6">
          <div className="flex items-center justify-between">
            <span className="text-xs font-mono text-amber-800 font-bold uppercase tracking-wider">
              STAGE 0{currentStage.id} SPECIFICATION
            </span>
            <span className={`text-[10px] font-mono px-2.5 py-0.5 rounded border ${currentStage.statusColor}`}>
              {currentStage.status}
            </span>
          </div>

          <div>
            <h3 className="text-2xl font-bold text-slate-900 mb-1">{currentStage.name}</h3>
            <p className="text-xs font-mono text-amber-800 font-bold">{currentStage.tagline}</p>
          </div>

          <div className="space-y-4 text-xs font-mono">
            <div className="bg-slate-50 p-4 rounded-xl border border-slate-300">
              <span className="text-slate-700 block uppercase text-[10px] mb-1 font-bold">
                ENGINEERING PURPOSE:
              </span>
              <p className="text-slate-900 font-sans font-medium leading-relaxed">{currentStage.purpose}</p>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div className="bg-slate-50 p-3.5 rounded-xl border border-slate-300">
                <span className="text-slate-700 block uppercase text-[10px] mb-1 font-bold">
                  REQUIRED INPUT:
                </span>
                <span className="text-slate-950 font-semibold">{currentStage.input}</span>
              </div>

              <div className="bg-emerald-50 p-3.5 rounded-xl border border-emerald-300">
                <span className="text-emerald-900 block uppercase text-[10px] mb-1 font-bold">
                  PRODUCED OUTPUT:
                </span>
                <span className="text-emerald-950 font-bold">{currentStage.output}</span>
              </div>
            </div>

            <div className="bg-rose-50 border border-rose-300 p-3.5 rounded-xl">
              <span className="text-rose-900 block uppercase text-[10px] mb-1 font-bold">
                FAILURE CONDITIONS &amp; MITIGATION:
              </span>
              <span className="text-rose-950 font-medium">{currentStage.failureConditions}</span>
            </div>
          </div>
        </div>

        {/* Right Column: Code Implementation Reference */}
        <div className="lg:col-span-6 space-y-4">
          <div className="flex items-center justify-between text-xs font-mono text-slate-600 pb-2 border-b border-slate-200">
            <div className="flex items-center gap-2 text-slate-900 font-bold">
              <FileCode className="w-4 h-4 text-amber-700" />
              <span>FastAPI Backend Implementation Reference</span>
            </div>
            <span className="text-[10px] text-slate-700 font-bold">Python 3.11 • OpenCV • PyTorch</span>
          </div>

          <div className="bg-slate-950 rounded-2xl p-4 border border-slate-800 font-mono text-xs overflow-x-auto text-slate-300 leading-relaxed shadow-inner">
            <pre className="text-amber-300">{currentStage.codeSnippet}</pre>
          </div>

          {/* Theoretical Rule Callout */}
          <div className="bg-amber-50 p-4 rounded-xl border border-amber-300 text-xs font-mono text-slate-700 space-y-2 shadow-sm">
            <div className="text-amber-900 font-bold flex items-center gap-2">
              <Sparkles className="w-4 h-4 text-amber-700" />
              <span>ACADEMIC INTEGRITY NOTICE</span>
            </div>
            <p className="text-[11px] text-slate-800 font-medium leading-relaxed font-sans">
              No fictional biometric confidence percentages or fabricated latency times are generated. The Attendrix pipeline isolates face candidate detection (YuNet) from feature vector comparison (ArcFace) to ensure scientific validity.
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}
