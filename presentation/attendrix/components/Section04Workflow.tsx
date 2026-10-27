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
  const [activeStep, setActiveStep] = useState<number>(2);
  const [sweepYaw, setSweepYaw] = useState<number>(142);

  // Live 180 continuous sweep trajectory simulation
  useEffect(() => {
    const timer = setInterval(() => {
      setSweepYaw((prev) => {
        if (prev >= 170) return 30;
        return prev + 15;
      });
    }, 600);

    return () => clearInterval(timer);
  }, []);

  const steps = [
    {
      step: 1,
      title: "Controller & Faculty Provisioning",
      shortTitle: "1. Provision & Init",
      icon: MonitorCheck,
      color: "text-amber-700",
      bgBadge: "bg-amber-100 text-amber-900 border-amber-300 font-bold",
      desc: "Academic Controller assigns classroom venue (80, 120, 240, or 260 seats), captures reference panorama with on-device camera, and locks enrollment. Faculty launches timed session with server-authoritative clock.",
      actionDetails: [
        "Academic Controller creates venue profile with exact capacity tier (80–260 seats).",
        "Direct camera capture registers classroom baseline panorama into backend storage.",
        "Faculty spawns active session with configurable deadline (5, 10, or 15 minutes).",
      ],
      caution: "Guarantees venue integrity; unauthorized rooms or unassigned halls cannot be selected.",
    },
    {
      step: 2,
      title: "Interactive Active Liveness Detection",
      shortTitle: "2. Active Liveness",
      icon: Timer,
      color: "text-orange-700",
      bgBadge: "bg-orange-100 text-orange-900 border-orange-300 font-bold",
      desc: "Student camera prompt executes a 4-action biometric challenge: frontal alignment, head turn LEFT, head turn RIGHT, and firm EYE BLINK, actively verified by YuNet 5-point facial landmark geometry.",
      actionDetails: [
        "Head Yaw Excursion: Normalized dx_nose / IPD angle deflection (< -10° left, > +10° right).",
        "Eyelid Blink Closure: Vertical Sobel gradient energy drop across pupil/sclera contours.",
        "Anti-Spoof Defense: Rejects static printed photos, video screen playback, and deepfake masks.",
      ],
      caution:
        "ACTIVE LIVENESS GUARANTEE: Student must perform genuine head rotation and eye blinking on-device during the live session window.",
    },
    {
      step: 3,
      title: "180° Classroom Physical Sweep & Stage Match",
      shortTitle: "3. 180° Room Sweep",
      icon: Layers,
      color: "text-amber-700",
      bgBadge: "bg-amber-100 text-amber-900 border-amber-300 font-bold",
      desc: "Following liveness, student sweeps the classroom across neighbor peers to the lecturer stage (Δyaw ≥ 120°), corroborating the real physical environment with the controller baseline template.",
      actionDetails: [
        `Live Sweep Yaw Progression: ${sweepYaw}° (Monotonic gyroscope angular check ≥ 120°).`,
        "Audience Peer Corroboration: Detects surrounding peers seated in the lecture hall.",
        "Podium & Lecturer Stage Match: Verifies lecturer presence and stage architecture.",
      ],
      caution:
        "ZERO-PROXY DEFENSE: Empty halls, outside photos, or scanned walls are immediately intercepted and flagged.",
    },
    {
      step: 4,
      title: "Zero-Proxy Anti-Empty-Room Defense",
      shortTitle: "4. Anti-Proxy Defense",
      icon: ShieldAlert,
      color: "text-rose-700",
      bgBadge: "bg-rose-100 text-rose-900 border-rose-300 font-bold",
      desc: "YuNet evaluates active hall occupancy. If an empty room is captured (0 peers present, no lecturer on stage), the attempt is blocked as a ghost proxy fraud attempt.",
      actionDetails: [
        "Scans classroom frames for real peers and lecturer presence.",
        "Blocks students who sneak into empty lecture halls before/after hours to claim attendance.",
        "Automatically routes attempts to PENDING REVIEW with security audit alert attendance.empty_room_proxy_detected.",
      ],
      caution:
        "EMPTY-ROOM INTERCEPTION: Both the lecturer on stage and peers in the hall must be present simultaneously.",
    },
    {
      step: 5,
      title: "1:1 Biometric Verification (ArcFace 512-D)",
      shortTitle: "5. Biometric 1:1",
      icon: Camera,
      color: "text-amber-700",
      bgBadge: "bg-amber-100 text-amber-900 border-amber-300 font-bold",
      desc: "Canonical 112×112 frontal crop is extracted, aligned, and matched against enrolled institutional reference vector using 512-dimensional ArcFace deep embeddings (cosine similarity threshold ≥ 0.68).",
      actionDetails: [
        "Laplacian sharpness variance check (≥ 1.5) ensures crisp face focus.",
        "512-dimensional Euclidean-normalized unit embedding extraction.",
        "Cosine threshold cos(θ) ≥ 0.68 authenticates individual enrollment identity.",
      ],
      caution:
        "Ephemeral In-Memory Verification: Raw image bytes are purged immediately after comparison (Zero-Knowledge biometric privacy).",
    },
    {
      step: 6,
      title: "Backend Neural Engine & 1-Attempt Policy",
      shortTitle: "6. Decision Policy",
      icon: ServerCog,
      color: "text-orange-700",
      bgBadge: "bg-orange-100 text-orange-900 border-orange-300 font-bold",
      desc: "FastAPI server executes full multi-layer evaluation: Active liveness verified + ArcFace match + Classroom physical match + 1-attempt constraint per session.",
      actionDetails: [
        "1. Active Liveness (Yaw Turn & Blink) | 2. ArcFace Biometric (≥0.68).",
        "3. 180° Sweep Continuity (≥120°) | 4. Lecturer & Peer Presence (N≥1).",
        "5. Anti-Empty-Room Defense | 6. Server Clock TTL | 7. Deduplication Constraint.",
      ],
      caution: "1-Attempt Policy: Prevents replay brute-forcing; every submission is final and immutably audited.",
    },
    {
      step: 7,
      title: "Lecturer Real-Time Radar & Excel Export",
      shortTitle: "7. Audit & Export",
      icon: FileCheck2,
      color: "text-emerald-700",
      bgBadge: "bg-emerald-100 text-emerald-900 border-emerald-300 font-bold",
      desc: "Faculty dashboard displays real-time live attendance ticker via WebSockets, enables review of flagged cases, and exports certified institutional Excel (.xlsx) spreadsheets.",
      actionDetails: [
        "Real-time WebSocket radar pushes verified student entries within milliseconds.",
        "Flagged review queue displays reason tags and key-frame evidence filmstrips.",
        "One-click institutional Excel export (.xlsx) with colored KPI headers and audit ledger.",
      ],
      caution: "Every manual review action is logged with actor email, timestamp, and rationale in the immutable audit log.",
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

          {/* Interactive Live 180 Sweep Gyro Component if Step 2 */}
          {activeStep === 2 && (
            <div className="bg-white p-4 rounded-xl border border-amber-300 font-mono text-xs space-y-2 shadow-sm">
              <div className="text-amber-800 flex justify-between font-bold">
                <span>CONTINUOUS 180° SWEEP TRAJECTORY:</span>
                <span className="text-emerald-700 animate-pulse">● TRACKING</span>
              </div>
              <div className="text-xl font-black text-slate-900 tracking-wider text-center py-2 bg-amber-50/60 rounded border border-amber-200">
                Δyaw: {sweepYaw}° / 180° (Selfie → Audience → Stage)
              </div>
              <div className="flex justify-between items-center text-[11px] text-slate-700 pt-1 font-bold">
                <span>Monotonic Gyro Check:</span>
                <span className="text-emerald-700 font-bold">PASS (Δ ≥ 120°)</span>
              </div>
              <div className="w-full bg-slate-200 h-2 rounded-full overflow-hidden">
                <div
                  className="bg-amber-500 h-full transition-all duration-500"
                  style={{ width: `${Math.min(100, (sweepYaw / 180) * 100)}%` }}
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
