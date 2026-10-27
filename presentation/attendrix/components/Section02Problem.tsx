"use client";

import React, { useState, useEffect } from "react";
import { soundManager } from "./SoundManager";
import { Clock, AlertTriangle, UserX, FileSpreadsheet, EyeOff, Check, RefreshCw } from "lucide-react";

export default function Section02Problem() {
  const [simulatedMinutes, setSimulatedMinutes] = useState<number>(0);
  const [simulatedNamesCalled, setSimulatedNamesCalled] = useState<number>(0);
  const [isSimulating, setIsSimulating] = useState<boolean>(true);

  useEffect(() => {
    if (!isSimulating) return;
    const interval = setInterval(() => {
      setSimulatedNamesCalled((prev) => {
        if (prev >= 240) {
          return 240;
        }
        return prev + 4;
      });
      setSimulatedMinutes((prev) => {
        if (prev >= 18.5) return 18.5;
        return Number((prev + 0.35).toFixed(1));
      });
    }, 180);

    return () => clearInterval(interval);
  }, [isSimulating]);

  const restartSimulation = () => {
    soundManager.playClick();
    setSimulatedMinutes(0);
    setSimulatedNamesCalled(0);
    setIsSimulating(true);
  };

  return (
    <section id="problem" className="relative py-24 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto">
      {/* Section Header */}
      <div className="text-center max-w-3xl mx-auto mb-16">
        <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-rose-100 border border-rose-300 text-rose-800 font-mono text-xs font-bold mb-4 shadow-sm">
          <AlertTriangle className="w-3.5 h-3.5" />
          <span>SECTION 02 • THE CONVENTIONAL REALITY</span>
        </div>
        <h2 className="text-3xl sm:text-5xl font-extrabold text-slate-900 tracking-tight mb-4">
          240 Students. One Lecture. <br />
          <span className="text-rose-700">Too Much Time Lost.</span>
        </h2>
        <p className="text-base sm:text-lg text-slate-700">
          Manual roll calls in modern university amphitheaters force a painful tradeoff: sacrifice 35% of instruction time, or surrender attendance integrity to unverified paper sheets.
        </p>
      </div>

      {/* Simulated Time Lost Interactive Visualizer */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center mb-16">
        {/* Left Side: Roll Call Live Telemetry */}
        <div className="lg:col-span-5 glass-panel p-6 rounded-2xl border border-slate-200 relative overflow-hidden shadow-md">
          <div className="flex items-center justify-between mb-4 pb-3 border-b border-slate-200">
            <div className="flex items-center gap-2 text-rose-700 font-mono text-xs font-bold">
              <Clock className="w-4 h-4 animate-spin text-rose-600" />
              <span>TRADITIONAL ROLL CALL SIMULATOR</span>
            </div>
            <button
              onClick={restartSimulation}
              className="text-xs font-mono text-slate-700 hover:text-slate-950 flex items-center gap-1 font-bold cursor-pointer"
            >
              <RefreshCw className="w-3 h-3 text-amber-700" />
              <span>Replay</span>
            </button>
          </div>

          {/* Time & Count Meters */}
          <div className="grid grid-cols-2 gap-4 mb-6">
            <div className="bg-slate-50 p-4 rounded-xl border border-slate-200">
              <div className="text-xs font-mono text-slate-700 mb-1 font-bold">INSTRUCTION TIME LOST</div>
              <div className="text-3xl font-extrabold text-rose-700 font-mono">
                {simulatedMinutes}m
              </div>
              <div className="text-[11px] text-slate-700 font-medium mt-1">out of a 50m lecture (37%)</div>
            </div>

            <div className="bg-slate-50 p-4 rounded-xl border border-slate-200">
              <div className="text-xs font-mono text-slate-700 mb-1 font-bold">NAMES CALLED (240)</div>
              <div className="text-3xl font-extrabold text-amber-800 font-mono">
                {simulatedNamesCalled} / 240
              </div>
              <div className="text-[11px] text-slate-700 font-medium mt-1">Average 4.6 sec per student</div>
            </div>
          </div>

          {/* Simulated Sequential Roll-Call Log (High contrast dark terminal) */}
          <div className="space-y-1.5 font-mono text-xs bg-slate-950 p-4 rounded-xl border border-slate-800 h-44 overflow-hidden relative shadow-inner">
            <div className="text-amber-300 text-[10px] pb-1 uppercase tracking-wider font-bold border-b border-slate-800">
              Lecture Hall Audio Roll Call Sequence
            </div>
            <div className="text-slate-100 font-medium">
              &gt; [00:15] &quot;Student 001 - Present?&quot; ... &quot;Yes sir.&quot;
            </div>
            <div className="text-slate-100 font-medium">
              &gt; [00:21] &quot;Student 002 - Present?&quot; ... &quot;Here.&quot;
            </div>
            <div className="text-rose-300 font-bold">
              &gt; [04:12] &quot;Student 047?&quot; ... (Silence. Repeat name twice). Proxy answer overheard.
            </div>
            <div className="text-slate-100 font-medium">
              &gt; [08:44] &quot;Student 108?&quot; ... &quot;Present.&quot;
            </div>
            <div className="text-amber-300 font-bold">
              &gt; [14:20] Paper sign-in clipboard passed to Row 8. 4 duplicate signatures flagged.
            </div>
            <div className="text-rose-300 font-bold">
              &gt; [{simulatedMinutes >= 18 ? "18:42" : "16:10"}] Class halted. Instructor manually auditing disputes.
            </div>
          </div>

          <div className="mt-4 text-[10px] text-slate-900 font-mono bg-slate-100 p-2.5 rounded-lg border border-slate-300 font-semibold">
            *Demonstration illustrative timing — roll calls in 240-seat halls routinely consume 15–20 minutes of 50-minute lectures based on classroom observational studies.
          </div>
        </div>

        {/* Right Side: Structural Vulnerabilities of Manual Attendance */}
        <div className="lg:col-span-7 grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div className="glass-panel p-5 rounded-xl border border-rose-300/80 bg-white/95 hover:border-rose-500 transition-all shadow-md">
            <div className="w-10 h-10 rounded-lg bg-rose-100 border border-rose-300 flex items-center justify-center text-rose-700 mb-3">
              <UserX className="w-5 h-5" />
            </div>
            <h3 className="text-base font-bold text-slate-900 mb-1.5">Empty Room Proxy Spoofing</h3>
            <p className="text-xs text-slate-700 font-medium leading-relaxed">
              Students photographing an empty room outside session hours or holding up phones in vacant halls. Traditional apps blindly mark attendance despite zero humans present.
            </p>
          </div>

          <div className="glass-panel p-5 rounded-xl border border-slate-300/90 bg-white/95 hover:border-amber-400 transition-all shadow-md">
            <div className="w-10 h-10 rounded-lg bg-amber-100 border border-amber-300 flex items-center justify-center text-amber-700 mb-3">
              <FileSpreadsheet className="w-5 h-5" />
            </div>
            <h3 className="text-base font-bold text-slate-900 mb-1.5">QR Screenshots &amp; Buddy Relay</h3>
            <p className="text-xs text-slate-700 font-medium leading-relaxed">
              Paper circulation and static projector QR codes are instantly screenshotted and shared on messaging channels, allowing students in dorms to claim presence.
            </p>
          </div>

          <div className="glass-panel p-5 rounded-xl border border-slate-300/90 bg-white/95 hover:border-amber-400 transition-all shadow-md">
            <div className="w-10 h-10 rounded-lg bg-amber-100 border border-amber-300 flex items-center justify-center text-amber-700 mb-3">
              <EyeOff className="w-5 h-5" />
            </div>
            <h3 className="text-base font-bold text-slate-900 mb-1.5">20-Meter Depth Blur</h3>
            <p className="text-xs text-slate-700 font-medium leading-relaxed">
              In large 260-seat tiered halls, rear-row students appear as 12×12 pixel blobs to front cameras. Without student-edge 180° sweeps, biometric verification is mathematically impossible.
            </p>
          </div>

          <div className="glass-panel p-5 rounded-xl border border-slate-300/90 bg-white/95 hover:border-emerald-400 transition-all shadow-md">
            <div className="w-10 h-10 rounded-lg bg-emerald-100 border border-emerald-300 flex items-center justify-center text-emerald-700 mb-3">
              <Check className="w-5 h-5" />
            </div>
            <h3 className="text-base font-bold text-slate-900 mb-1.5">Detection vs. Verification</h3>
            <p className="text-xs text-slate-700 font-medium leading-relaxed">
              Lightweight detection (YuNet) counts heads to prove the room is occupied; 1:1 biometric embedding (ArcFace) proves authorized identity. Attendrix unifies both.
            </p>
          </div>
        </div>
      </div>

      {/* Emphatic Closing Statement */}
      <div className="max-w-3xl mx-auto glass-panel p-6 rounded-2xl border border-amber-300 text-center relative shadow-md">
        <p className="text-xl sm:text-2xl font-bold text-slate-900 tracking-wide">
          &ldquo;Attendance should be a verifiable workflow, <br className="hidden sm:block" />
          not just a list of names.&rdquo;
        </p>
        <span className="text-xs font-mono text-amber-800 font-bold mt-2 block uppercase tracking-widest">
          Attendrix Core Philosophy
        </span>
      </div>
    </section>
  );
}
