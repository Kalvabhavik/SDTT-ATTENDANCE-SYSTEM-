"use client";

import React, { useState } from "react";
import { soundManager } from "./SoundManager";
import confetti from "canvas-confetti";
import {
  ShieldCheck,
  Camera,
  UserCheck,
  AlertTriangle,
  XCircle,
  Clock,
  Play,
  RotateCcw,
  CheckCircle2,
  Lock,
  ScanFace,
  Fingerprint,
} from "lucide-react";

type ScenarioKey = "valid" | "poor_quality" | "empty_room_proxy" | "duplicate" | "uncertain_match";

interface ScenarioConfig {
  key: ScenarioKey;
  label: string;
  badge: string;
  badgeColor: string;
  qualityScore: number;
  challengeMatch: boolean;
  cosineSimilarity: number;
  isDuplicate: boolean;
  outcomeStatus: "VERIFIED" | "UNCERTAIN" | "REJECTED" | "PENDING REVIEW";
  outcomeMessage: string;
  outcomeExplanation: string;
}

const scenarios: Record<ScenarioKey, ScenarioConfig> = {
  valid: {
    key: "valid",
    label: "1. Valid Active Liveness & Room Match",
    badge: "VERIFIED PRESENT",
    badgeColor: "bg-emerald-100 text-emerald-900 border-emerald-300 font-bold",
    qualityScore: 95,
    challengeMatch: true,
    cosineSimilarity: 0.86,
    isDuplicate: false,
    outcomeStatus: "VERIFIED",
    outcomeMessage: "All Attendrix verification checks passed.",
    outcomeExplanation:
      "Active liveness confirmed (Yaw left -18°, yaw right +22°, eye blink verified), ArcFace cosine similarity (0.86 ≥ 0.68), lecturer detected on stage, and lecture hall matched.",
  },
  poor_quality: {
    key: "poor_quality",
    label: "2. Spoof Replay / Liveness Incomplete",
    badge: "LIVENESS FAILED",
    badgeColor: "bg-rose-100 text-rose-900 border-rose-300 font-bold",
    qualityScore: 32,
    challengeMatch: false,
    cosineSimilarity: 0.48,
    isDuplicate: false,
    outcomeStatus: "PENDING REVIEW",
    outcomeMessage: "Liveness challenge incomplete: Static face image detected.",
    outcomeExplanation:
      "YuNet detected 0° yaw excursion and zero eyelid closure motion across frames. Replay spoof attempt intercepted and logged as attendance.liveness_incomplete.",
  },
  empty_room_proxy: {
    key: "empty_room_proxy",
    label: "3. Empty Room Proxy Spoof Attempt",
    badge: "PROXY INTERCEPTED",
    badgeColor: "bg-rose-100 text-rose-900 border-rose-300 font-bold",
    qualityScore: 91,
    challengeMatch: false,
    cosineSimilarity: 0.88,
    isDuplicate: false,
    outcomeStatus: "PENDING REVIEW",
    outcomeMessage: "Empty hall detected. 0 peers found. Blocked by Anti-Proxy defense.",
    outcomeExplanation:
      "Audience face count = 0 and no lecturer on stage. The student attempted to claim attendance in a vacant room. Intercepted with security audit alert attendance.empty_room_proxy_detected.",
  },
  duplicate: {
    key: "duplicate",
    label: "4. Duplicate Submission (1-Attempt Policy)",
    badge: "DUPLICATE REPLAY",
    badgeColor: "bg-rose-100 text-rose-900 border-rose-300 font-bold",
    qualityScore: 95,
    challengeMatch: true,
    cosineSimilarity: 0.89,
    isDuplicate: true,
    outcomeStatus: "REJECTED",
    outcomeMessage: "A record already exists for this student and session.",
    outcomeExplanation:
      "Student ID STU-2024-0482 already holds a committed attendance record for session #8491. 1-Attempt Policy rejects re-submission.",
  },
  uncertain_match: {
    key: "uncertain_match",
    label: "5. Borderline Biometric Match",
    badge: "HUMAN AUDIT REQUIRED",
    badgeColor: "bg-amber-100 text-amber-900 border-amber-300 font-bold",
    qualityScore: 82,
    challengeMatch: true,
    cosineSimilarity: 0.58,
    isDuplicate: false,
    outcomeStatus: "PENDING REVIEW",
    outcomeMessage: "Cosine below 0.68 threshold. Routed to Lecturer Review Desk.",
    outcomeExplanation:
      "Cosine similarity of 0.58 falls below the autonomous 0.68 threshold. System automatically preserves filmstrip keyframes and routes to Lecturer Review Desk.",
  },
};

export default function Section05StudentVerification() {
  const [selectedScenario, setSelectedScenario] = useState<ScenarioKey>("valid");
  const [isRunning, setIsRunning] = useState<boolean>(false);
  const [currentStepIndex, setCurrentStepIndex] = useState<number>(4);

  const scenario = scenarios[selectedScenario];

  const runSimulation = () => {
    soundManager.playClick();
    setIsRunning(true);
    setCurrentStepIndex(0);

    const steps = [1, 2, 3, 4];
    steps.forEach((step, i) => {
      setTimeout(() => {
        setCurrentStepIndex(step);
        soundManager.playScan();
        if (step === 4) {
          setIsRunning(false);
          if (scenario.outcomeStatus === "VERIFIED") {
            soundManager.playSuccess();
            confetti({
              particleCount: 55,
              spread: 60,
              origin: { y: 0.7 },
              colors: ["#d97706", "#f59e0b", "#fbbf24", "#059669"],
            });
          } else {
            soundManager.playWarning();
          }
        }
      }, (i + 1) * 750);
    });
  };

  const selectScenario = (key: ScenarioKey) => {
    soundManager.playClick();
    setSelectedScenario(key);
    setCurrentStepIndex(4);
    setIsRunning(false);
  };

  return (
    <section id="verification" className="relative py-24 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto">
      {/* Header */}
      <div className="text-center max-w-3xl mx-auto mb-16">
        <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-amber-100 border border-amber-300 text-amber-900 font-mono text-xs font-bold mb-4 shadow-sm">
          <ScanFace className="w-3.5 h-3.5" />
          <span>SECTION 05 • INDIVIDUAL EVALUATION</span>
        </div>
        <h2 className="text-3xl sm:text-5xl font-extrabold text-slate-900 tracking-tight mb-4">
          Every Record Has a <br />
          <span className="bg-gradient-to-r from-amber-800 via-amber-700 to-orange-700 bg-clip-text text-transparent">
            Verifiable Reason.
          </span>
        </h2>
        <p className="text-base sm:text-lg text-slate-700 font-medium">
          Explore how an individual student’s attendance evidence is evaluated.
          Switch between 5 edge-case scenarios to observe how the decision engine handles lighting, tokens, replays, and borderline matches.
        </p>
      </div>

      {/* Scenario Selector Pills */}
      <div className="flex flex-wrap items-center justify-center gap-2.5 mb-10">
        {(Object.keys(scenarios) as ScenarioKey[]).map((key) => {
          const s = scenarios[key];
          const isSelected = selectedScenario === key;
          return (
            <button
              key={key}
              onClick={() => selectScenario(key)}
              className={`px-4 py-2.5 rounded-xl text-xs font-mono transition-all border cursor-pointer ${
                isSelected
                  ? "bg-amber-600 text-white font-bold border-amber-600 shadow-md shadow-amber-600/30 ring-2 ring-amber-400/40"
                  : "bg-white text-slate-800 font-semibold border-slate-300 hover:border-amber-500 hover:text-slate-900 shadow-sm"
              }`}
            >
              {s.label}
            </button>
          );
        })}
      </div>

      {/* Main Interactive Student Verification Workbench */}
      <div className="glass-panel p-6 sm:p-10 rounded-3xl border border-slate-300/90 bg-white/95 grid grid-cols-1 lg:grid-cols-12 gap-8 items-start relative shadow-xl">
        {/* Left Column: Stylized Camera View & Student Identity */}
        <div className="lg:col-span-5 space-y-4">
          {/* Simulated Mobile Camera Viewport */}
          <div className="relative aspect-[4/3] rounded-2xl bg-slate-950 border-2 border-slate-800 overflow-hidden flex flex-col items-center justify-center p-4 shadow-inner">
            {/* Camera Overlay Elements */}
            <div className="absolute top-3 left-3 flex items-center gap-2 text-[10px] font-mono text-amber-400 bg-slate-900/90 px-2.5 py-1 rounded border border-amber-500/30">
              <Camera className="w-3 h-3 text-amber-400" />
              <span>FRONT CAM • 112×112 ROI</span>
            </div>

            <div className="absolute top-3 right-3 text-[10px] font-mono text-amber-300 bg-slate-900/90 px-2 py-1 rounded border border-amber-500/30">
              ISO 200 • 60 FPS
            </div>

            {/* Stylized Face Silhouette / Landmark Box */}
            <div
              className={`relative w-36 h-44 rounded-3xl border-2 transition-all flex flex-col items-center justify-center ${
                selectedScenario === "poor_quality"
                  ? "border-orange-500/60 blur-[1.5px] bg-orange-950/20"
                  : selectedScenario === "valid"
                  ? "border-amber-400/80 bg-amber-950/20 shadow-[0_0_20px_rgba(245,158,11,0.25)]"
                  : "border-stone-700 bg-stone-900/30"
              }`}
            >
              {/* Scanline Animation if running */}
              {isRunning && (
                <div className="absolute inset-x-0 h-1 bg-amber-400 shadow-[0_0_12px_#fbbf24] animate-scanline" />
              )}

              {/* Face Landmark Markers */}
              <div className="w-20 h-28 rounded-full border border-dashed border-amber-400/40 flex flex-col items-center justify-center">
                <div className="flex gap-6 mb-3">
                  <span className="w-2 h-2 rounded-full bg-amber-400 shadow-[0_0_6px_#fbbf24]" />
                  <span className="w-2 h-2 rounded-full bg-amber-400 shadow-[0_0_6px_#fbbf24]" />
                </div>
                <div className="w-1.5 h-1.5 rounded-full bg-amber-400/60 mb-2" />
                <div className="w-6 h-1 rounded-full bg-amber-400/80" />
              </div>

              <div className="absolute bottom-2 text-[9px] font-mono text-amber-300 uppercase tracking-widest font-bold">
                {selectedScenario === "poor_quality" ? "BLUR DETECTED" : "FACE ALIGNED"}
              </div>
            </div>

            {/* Bottom 180° Gyro Sweep Telemetry Banner */}
            <div className="absolute bottom-3 inset-x-3 bg-slate-900/95 border border-slate-800 rounded-lg p-2 flex items-center justify-between text-xs font-mono">
              <span className="text-slate-300 font-bold">180° Sweep Arc:</span>
              <span
                className={`font-bold ${
                  scenario.challengeMatch ? "text-amber-300" : "text-rose-400 line-through"
                }`}
              >
                {scenario.challengeMatch ? "Δyaw = 142° (CONTINUOUS PASS)" : "Δyaw = 18° / YuNet: 0 FACES (FLAGGED)"}
              </span>
            </div>
          </div>

          {/* Student Reference Identity Card */}
          <div className="bg-slate-50 p-4 rounded-xl border border-slate-200 flex items-center justify-between shadow-sm">
            <div className="flex items-center gap-3">
              <div className="w-11 h-11 rounded-xl bg-amber-100 border border-amber-300 flex items-center justify-center text-amber-900 font-bold text-sm">
                AS
              </div>
              <div>
                <div className="text-xs font-bold text-slate-900">Aarav Sharma</div>
                <div className="text-[11px] font-mono text-slate-700 font-semibold">ID: STU-2024-0482 • B.Tech CS</div>
              </div>
            </div>
            <div className="text-right">
              <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-amber-100 text-amber-900 border border-amber-300 block mb-0.5 font-bold">
                512-D ARCFACE
              </span>
              <span className="text-[10px] text-slate-700 font-mono font-semibold">Registered Ref</span>
            </div>
          </div>
        </div>

        {/* Right Column: Verification Stages & Decision */}
        <div className="lg:col-span-7 space-y-5">
          {/* Action Header with Run Demo Button */}
          <div className="flex flex-wrap items-center justify-between gap-4 pb-4 border-b border-slate-200">
            <div>
              <div className="text-xs font-mono text-amber-800 font-bold uppercase tracking-wider mb-1">
                EVALUATION PIPELINE
              </div>
              <h3 className="text-lg font-bold text-slate-900">{scenario.label}</h3>
            </div>

            <button
              disabled={isRunning}
              onClick={runSimulation}
              className="px-4 py-2.5 rounded-xl text-xs font-mono font-bold bg-amber-600 hover:bg-amber-500 text-white flex items-center gap-2 transition-all shadow-md shadow-amber-600/30 disabled:opacity-50 cursor-pointer"
            >
              {isRunning ? (
                <>
                  <RotateCcw className="w-3.5 h-3.5 animate-spin" />
                  <span>Evaluating Checks...</span>
                </>
              ) : (
                <>
                  <Play className="w-3.5 h-3.5" />
                  <span>Run Verification Demo</span>
                </>
              )}
            </button>
          </div>

          {/* 4 Sequential Verification Step Cards */}
          <div className="space-y-2.5">
            {/* Step 1: Active Liveness Challenge */}
            <div
              className={`p-3 rounded-xl border text-xs font-mono flex items-center justify-between transition-colors ${
                currentStepIndex >= 1
                  ? scenario.challengeMatch
                    ? "bg-emerald-50 border-emerald-300 text-emerald-900"
                    : "bg-rose-50 border-rose-300 text-rose-900"
                  : "bg-slate-100 border-slate-300 text-slate-700 font-semibold"
              }`}
            >
              <div className="flex items-center gap-2.5">
                <Clock className="w-4 h-4" />
                <span>1. Active Liveness (Turn Left, Right &amp; Blink)</span>
              </div>
              <span className="font-bold">
                {currentStepIndex >= 1
                  ? scenario.challengeMatch
                    ? "PASS (Yaw Rotation & Blink OK)"
                    : "FLAGGED (Liveness Incomplete / Static)"
                  : "WAITING"}
              </span>
            </div>

            {/* Step 2: 180° Classroom Physical Sweep & Anti-Proxy Check */}
            <div
              className={`p-3 rounded-xl border text-xs font-mono flex items-center justify-between transition-colors ${
                currentStepIndex >= 2
                  ? scenario.qualityScore >= 70
                    ? "bg-emerald-50 border-emerald-300 text-emerald-900"
                    : "bg-amber-50 border-amber-300 text-amber-900"
                  : "bg-slate-100 border-slate-300 text-slate-700 font-semibold"
              }`}
            >
              <div className="flex items-center gap-2.5">
                <Camera className="w-4 h-4" />
                <span>2. 180° Classroom Physical Sweep &amp; Anti-Proxy</span>
              </div>
              <span className="font-bold">
                {currentStepIndex >= 2
                  ? scenario.challengeMatch
                    ? "PASS (Δyaw ≥ 120° & Peers Present)"
                    : "FLAGGED (Empty Room / 0 Faces)"
                  : "WAITING"}
              </span>
            </div>

            {/* Step 3: Biometric 1:1 Cosine Similarity */}
            <div
              className={`p-3 rounded-xl border text-xs font-mono flex items-center justify-between transition-colors ${
                currentStepIndex >= 3
                  ? scenario.cosineSimilarity >= 0.68
                    ? "bg-emerald-50 border-emerald-300 text-emerald-900"
                    : scenario.cosineSimilarity >= 0.5
                    ? "bg-amber-50 border-amber-300 text-amber-900"
                    : "bg-rose-50 border-rose-300 text-rose-900"
                  : "bg-slate-100 border-slate-300 text-slate-700 font-semibold"
              }`}
            >
              <div className="flex items-center gap-2.5">
                <Fingerprint className="w-4 h-4" />
                <span>3. ArcFace 1:1 Cosine Similarity</span>
              </div>
              <span className="font-bold">
                {currentStepIndex >= 3
                  ? `${scenario.cosineSimilarity.toFixed(2)} (Threshold: ≥ 0.68)`
                  : "WAITING"}
              </span>
            </div>

            {/* Step 4: Duplicate Record Constraint */}
            <div
              className={`p-3 rounded-xl border text-xs font-mono flex items-center justify-between transition-colors ${
                currentStepIndex >= 4
                  ? !scenario.isDuplicate
                    ? "bg-emerald-50 border-emerald-300 text-emerald-900"
                    : "bg-rose-50 border-rose-300 text-rose-900"
                  : "bg-slate-100 border-slate-300 text-slate-700 font-semibold"
              }`}
            >
              <div className="flex items-center gap-2.5">
                <ShieldCheck className="w-4 h-4" />
                <span>4. 1-Attempt Policy &amp; Deduplication</span>
              </div>
              <span className="font-bold">
                {currentStepIndex >= 4
                  ? !scenario.isDuplicate
                    ? "PASS (First & Only Submission)"
                    : "REJECTED (Duplicate Attempt)"
                  : "WAITING"}
              </span>
            </div>
          </div>

          {/* Final Outcome Box */}
          <div
            className={`p-5 rounded-2xl border transition-all ${
              scenario.outcomeStatus === "VERIFIED"
                ? "bg-emerald-50 border-emerald-300 text-emerald-900"
                : scenario.outcomeStatus === "PENDING REVIEW"
                ? "bg-amber-50 border-amber-300 text-amber-900"
                : scenario.outcomeStatus === "UNCERTAIN"
                ? "bg-amber-50 border-amber-300 text-amber-900"
                : "bg-rose-50 border-rose-300 text-rose-900"
            }`}
          >
            <div className="flex items-center justify-between mb-2">
              <span className="text-xs font-mono uppercase tracking-wider font-bold">
                FINAL CLASSIFICATION: {scenario.outcomeStatus}
              </span>
              <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-white/70 border border-current font-semibold">
                SIMULATED DEMO RESULT
              </span>
            </div>
            <p className="text-sm font-bold mb-1">{scenario.outcomeMessage}</p>
            <p className="text-xs opacity-90 leading-relaxed font-sans">{scenario.outcomeExplanation}</p>
          </div>

          {/* Academic Integrity Callout */}
          <div className="text-[11px] text-slate-600 font-mono bg-slate-50 p-3 rounded-xl border border-slate-200">
            *Technical honesty notice: Simulated demonstration scores. 1-to-1 biometric verification tests whether this specific student matches their own registered record, which is mathematically distinct from scanning 240 faces in an amphitheater panorama.
          </div>
        </div>
      </div>
    </section>
  );
}
