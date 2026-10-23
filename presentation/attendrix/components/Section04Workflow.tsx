"use client";

import React, { useState, useEffect } from "react";
import { soundManager } from "./SoundManager";
import {
  MonitorCheck,
  Timer,
  Camera,
  Layers,
  ServerCog,
  CheckCircle,
  FileCheck2,
  ChevronRight,
  ShieldAlert,
  AlertCircle,
  Clock,
} from "lucide-react";

export default function Section04Workflow() {
  const [activeStep, setActiveStep] = useState<number>(1);
  const [tokenCountdown, setTokenCountdown] = useState<number>(14);
  const [currentToken, setCurrentToken] = useState<string>("9K4-PX2");

  // Live rotating challenge countdown simulator
  useEffect(() => {
    const timer = setInterval(() => {
      setTokenCountdown((prev) => {
        if (prev <= 1) {
          const tokens = ["9K4-PX2", "7B8-WR4", "3M2-LQ9", "5X9-ZT1", "8H3-VK7"];
          const next = tokens[Math.floor(Math.random() * tokens.length)];
          setCurrentToken(next);
          return 15;
        }
        return prev - 1;
      });
    }, 1000);

    return () => clearInterval(timer);
  }, []);

  const steps = [
    {
      step: 1,
      title: "Faculty Session Init",
      shortTitle: "1. Faculty Init",
      icon: MonitorCheck,
      color: "text-amber-700",
      bgBadge: "bg-amber-100 text-amber-900 border-amber-300 font-bold",
      desc: "Faculty member authenticates via Supabase Auth, selects the course roster (80, 120, or 240 students), and spawns an active cryptographic attendance session with an assigned classroom ID.",
      actionDetails: [
        "Loads enrolled student roster from PostgreSQL database.",
        "Generates session encryption secret and WebSocket room.",
        "Launches projector interface in full-screen lecture display.",
      ],
      caution: "Prevents ghost sessions; only authorized faculty can activate room capture.",
    },
    {
      step: 2,
      title: "Dynamic Projector Challenge",
      shortTitle: "2. Challenge",
      icon: Timer,
      color: "text-orange-700",
      bgBadge: "bg-orange-100 text-orange-900 border-orange-300 font-bold",
      desc: "Projector broadcasts a short-lived, dynamic alphanumeric token changing every 15 seconds. Students submit the currently valid token alongside their submission.",
      actionDetails: [
        `Active Classroom Token: ${currentToken} (TTL: ${tokenCountdown}s)`,
        "Backend rejects expired tokens (t > 15s window + 5s network grace).",
        "Prevents asynchronous attendance submissions hours after lecture.",
      ],
      caution:
        "CRITICAL HONESTY: Visible codes can be shared or photographed. A valid code proves temporal alignment with the session, not physical bodily presence alone.",
    },
    {
      step: 3,
      title: "Student Selfie Capture",
      shortTitle: "3. Student Selfie",
      icon: Camera,
      color: "text-amber-700",
      bgBadge: "bg-amber-100 text-amber-900 border-amber-300 font-bold",
      desc: "Student opens the Flutter mobile client, authenticates, and captures a live front camera selfie with on-screen bounding guide and ambient illumination feedback.",
      actionDetails: [
        "Client verifies camera hardware integrity & geolocation perimeter.",
        "Performs client-side face orientation and blur validation.",
        "Prepares image crop for 1-to-1 ArcFace embedding comparison.",
      ],
      caution:
        "Low-light or motion-blurred photos prompt immediate recapture rather than false rejection.",
    },
    {
      step: 4,
      title: "Contextual Classroom Evidence",
      shortTitle: "4. Room Context",
      icon: Layers,
      color: "text-amber-700",
      bgBadge: "bg-amber-100 text-amber-900 border-amber-300 font-bold",
      desc: "Where hardware allows, a wide-angle room capture establishes physical context, seating density, and detected human heads across amphitheater zones.",
      actionDetails: [
        "YuNet lightweight detector identifies bounding boxes across rows.",
        "Corroborates submission volume against detected person clusters.",
        "Flags anomalous spikes where submissions exceed visible seat occupancy.",
      ],
      caution:
        "TECHNICAL LIMITATION: Wide-angle panorama cannot biometrically resolve small 14x14px distant faces at 20 meters. It establishes environmental context, not individual proof.",
    },
    {
      step: 5,
      title: "Backend Validation Sequence",
      shortTitle: "5. Backend Validation",
      icon: ServerCog,
      color: "text-orange-700",
      bgBadge: "bg-orange-100 text-orange-900 border-orange-300 font-bold",
      desc: "FastAPI server executes an ordered 9-stage verification pipeline before committing any attendance state.",
      actionDetails: [
        "1. Authenticate JWT token & student enrollment in course.",
        "2. Validate session status = OPEN.",
        "3. Match challenge token against rolling window history.",
        "4. Enforce submission timestamp freshness (replay attack block).",
        "5. Evaluate face image quality (sharpness, lux, angle).",
        "6. Compute 1:1 ArcFace cosine similarity vs registered reference photo.",
        "7. Deduplication check: single record per student per session.",
        "8. Cross-reference contextual seat density.",
        "9. Assign provisional classification (Verified / Uncertain / Rejected).",
      ],
      caution: "Guarantees zero database race conditions using PostgreSQL unique constraints.",
    },
    {
      step: 6,
      title: "Attendance Outcome Classification",
      shortTitle: "6. Outcome Result",
      icon: CheckCircle,
      color: "text-amber-700",
      bgBadge: "bg-amber-100 text-amber-900 border-amber-300 font-bold",
      desc: "Every record resolves into one of four mutually exclusive, transparent status states based on evidence thresholds.",
      actionDetails: [
        "VERIFIED: All checks passed (Valid challenge + high similarity > 0.72).",
        "UNCERTAIN: Evidence present but confidence marginal (similarity 0.50–0.71 or low light).",
        "REJECTED: Explicit rule failure (expired token, duplicate submission, non-student).",
        "PENDING REVIEW: Routed to instructor review queue for dispute resolution.",
      ],
      caution: "Uncertain cases are NEVER automatically marked absent. Human discretion is preserved.",
    },
    {
      step: 7,
      title: "Teacher Review & Audit Record",
      shortTitle: "7. Audit & Finalize",
      icon: FileCheck2,
      color: "text-amber-700",
      bgBadge: "bg-amber-100 text-amber-900 border-amber-300 font-bold",
      desc: "Instructor inspects unresolved cases in the review queue, evaluates student photos alongside capture timestamps, overrides if legitimate, and seals the finalized session.",
      actionDetails: [
        "Full audit trail logs instructor ID, timestamp, and rationale note.",
        "Synchronizes with university LMS / ERP export (CSV, JSON, PDF).",
        "Closes session and terminates WebSocket broadcasting channels.",
      ],
      caution: "Immutable audit log ensures accountability for all manual overrides.",
    },
  ];

  const currentStepData = steps.find((s) => s.step === activeStep) || steps[0];
  const StepIcon = currentStepData.icon;

  return (
    <section id="workflow" className="relative py-24 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto">
      {/* Header */}
      <div className="text-center max-w-3xl mx-auto mb-16">
        <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-amber-100 border border-amber-300 text-amber-900 font-mono text-xs font-bold mb-4 shadow-sm">
          <Clock className="w-3.5 h-3.5" />
          <span>SECTION 04 • EVIDENCE PIPELINE</span>
        </div>
        <h2 className="text-3xl sm:text-5xl font-extrabold text-slate-900 tracking-tight mb-4">
          One Session. <br />
          <span className="bg-gradient-to-r from-amber-800 via-amber-700 to-orange-700 bg-clip-text text-transparent">
            Multiple Verification Checks.
          </span>
        </h2>
        <p className="text-base sm:text-lg text-slate-700 font-medium">
          Step through the 7-stage verification workflow. See how instructor authority, dynamic projection, student capture, and server-side validation protect attendance integrity.
        </p>
      </div>

      {/* Horizontal Step Selector */}
      <div className="glass-panel p-2.5 rounded-2xl border border-slate-300/90 bg-white/95 mb-8 overflow-x-auto shadow-md">
        <div className="flex items-center min-w-max gap-1.5">
          {steps.map((s) => {
            const Icon = s.icon;
            const isCurrent = s.step === activeStep;
            return (
              <button
                key={s.step}
                onClick={() => {
                  soundManager.playClick();
                  setActiveStep(s.step);
                }}
                className={`flex items-center gap-2 px-4 py-2.5 rounded-xl text-xs font-mono transition-all cursor-pointer ${
                  isCurrent
                    ? "bg-amber-600 text-white font-bold shadow-md shadow-amber-600/30"
                    : "text-slate-700 font-semibold hover:text-slate-900 hover:bg-slate-100"
                }`}
              >
                <Icon className="w-4 h-4 text-amber-700" />
                <span>{s.shortTitle}</span>
              </button>
            );
          })}
        </div>
      </div>

      {/* Active Step Detailed Showcase Panel */}
      <div className="glass-panel p-6 sm:p-10 rounded-3xl border border-slate-300/90 bg-white/95 grid grid-cols-1 lg:grid-cols-12 gap-8 items-start relative shadow-xl">
        {/* Left Column: Visual Step Simulation */}
        <div className="lg:col-span-5 bg-slate-50/95 p-6 rounded-2xl border border-slate-200 space-y-4 shadow-inner">
          <div className="flex items-center justify-between">
            <span className={`text-xs font-mono px-3 py-1 rounded-full border ${currentStepData.bgBadge}`}>
              STAGE 0{currentStepData.step} / 07
            </span>
            <span className="text-xs font-mono text-slate-700 font-bold">FastAPI Pipeline</span>
          </div>

          <div className="flex items-center gap-4 py-2">
            <div className="w-14 h-14 rounded-2xl bg-amber-100 border border-amber-300 flex items-center justify-center text-amber-800 shadow-sm">
              <StepIcon className="w-7 h-7" />
            </div>
            <div>
              <h3 className="text-lg font-bold text-slate-900">{currentStepData.title}</h3>
              <p className="text-xs text-slate-700 font-semibold">Classroom Session Orchestration</p>
            </div>
          </div>

          {/* Interactive Live Challenge Component if Step 2 */}
          {activeStep === 2 && (
            <div className="bg-white p-4 rounded-xl border border-amber-300 font-mono text-xs space-y-2 shadow-sm">
              <div className="text-amber-800 flex justify-between font-bold">
                <span>SIMULATED PROJECTOR DISPLAY:</span>
                <span className="text-emerald-700 animate-pulse">● BROADCASTING</span>
              </div>
              <div className="text-2xl font-black text-slate-900 tracking-widest text-center py-2 bg-amber-50/60 rounded border border-amber-200">
                {currentToken}
              </div>
              <div className="flex justify-between items-center text-[11px] text-slate-700 pt-1 font-bold">
                <span>Next Token Rotation in:</span>
                <span className="text-orange-700 font-bold">{tokenCountdown}s</span>
              </div>
              <div className="w-full bg-slate-200 h-2 rounded-full overflow-hidden">
                <div
                  className="bg-amber-500 h-full transition-all duration-1000"
                  style={{ width: `${(tokenCountdown / 15) * 100}%` }}
                />
              </div>
            </div>
          )}

          {/* 4 Status Outcomes Preview if Step 6 */}
          {activeStep === 6 && (
            <div className="grid grid-cols-2 gap-2 font-mono text-xs">
              <div className="bg-emerald-50 border border-emerald-300 p-2.5 rounded-lg text-emerald-900">
                <div className="font-bold">VERIFIED</div>
                <div className="text-[10px] text-emerald-700">Checks Passed</div>
              </div>
              <div className="bg-amber-50 border border-amber-300 p-2.5 rounded-lg text-amber-900">
                <div className="font-bold">UNCERTAIN</div>
                <div className="text-[10px] text-amber-700">Low Confidence</div>
              </div>
              <div className="bg-rose-50 border border-rose-300 p-2.5 rounded-lg text-rose-900">
                <div className="font-bold">REJECTED</div>
                <div className="text-[10px] text-rose-700">Policy Failed</div>
              </div>
              <div className="bg-orange-50 border border-orange-300 p-2.5 rounded-lg text-orange-900">
                <div className="font-bold">PENDING REVIEW</div>
                <div className="text-[10px] text-orange-700">Teacher Audit</div>
              </div>
            </div>
          )}

          {/* Step Action Details */}
          <div className="space-y-2 pt-2">
            <span className="text-[11px] font-mono text-slate-600 font-bold uppercase tracking-wider block">
              Automated Operations:
            </span>
            {currentStepData.actionDetails.map((action, i) => (
              <div key={i} className="flex items-start gap-2 text-xs text-slate-700 font-mono">
                <ChevronRight className="w-3.5 h-3.5 text-amber-600 shrink-0 mt-0.5" />
                <span>{action}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Right Column: In-Depth Explanation & Limitations */}
        <div className="lg:col-span-7 space-y-6">
          <div>
            <h4 className="text-xl font-bold text-slate-900 mb-2">{currentStepData.title}</h4>
            <p className="text-sm text-slate-700 leading-relaxed">{currentStepData.desc}</p>
          </div>

          {/* Academic & Engineering Honesty Callout */}
          <div className="bg-amber-50 border border-amber-300 p-4 rounded-xl flex items-start gap-3 text-xs text-slate-700 leading-relaxed shadow-sm">
            <AlertCircle className="w-5 h-5 text-amber-700 shrink-0 mt-0.5" />
            <div>
              <span className="font-bold block text-amber-900 mb-0.5">TECHNICAL CONSIDERATION:</span>
              {currentStepData.caution}
            </div>
          </div>

          {/* Navigation between steps */}
          <div className="pt-4 flex items-center justify-between border-t border-slate-200">
            <button
              disabled={activeStep === 1}
              onClick={() => {
                soundManager.playClick();
                setActiveStep((prev) => Math.max(1, prev - 1));
              }}
              className="px-4 py-2 rounded-xl text-xs font-mono text-slate-800 hover:text-slate-950 disabled:opacity-30 disabled:pointer-events-none cursor-pointer font-bold"
            >
              ← Previous Step
            </button>

            <span className="text-xs font-mono text-slate-700 font-bold">
              {activeStep} of {steps.length}
            </span>

            <button
              disabled={activeStep === steps.length}
              onClick={() => {
                soundManager.playClick();
                setActiveStep((prev) => Math.min(steps.length, prev + 1));
              }}
              className="px-4 py-2 rounded-xl text-xs font-mono bg-amber-600 hover:bg-amber-500 text-white font-bold disabled:opacity-30 disabled:pointer-events-none flex items-center gap-1 cursor-pointer shadow-md shadow-amber-600/30"
            >
              <span>Next Step</span>
              <ChevronRight className="w-3.5 h-3.5" />
            </button>
          </div>
        </div>
      </div>
    </section>
  );
}
