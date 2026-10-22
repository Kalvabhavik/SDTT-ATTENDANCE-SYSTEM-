"use client";

import React, { useState } from "react";
import { soundManager } from "./SoundManager";
import {
  Maximize2,
  ChevronDown,
  ChevronUp,
  Camera,
  Scan,
} from "lucide-react";

export default function Section08Hall240() {
  const [activeBeat, setActiveBeat] = useState<number>(5);
  const [panelOpen, setPanelOpen] = useState<boolean>(true);
  const [comparisonMode, setComparisonMode] = useState<"side_by_side" | "wide_crop" | "selfie_crop">("side_by_side");

  // Reconciled 240 dataset:
  // Enrolled: 240
  // Verified: 218 (90.8%)
  // Pending review: 12 (5.0%)
  // Not yet recorded: 10 (4.2%)
  // Total: 218 + 12 + 10 = 240
  const stats = {
    enrolled: 240,
    verified: 218,
    pending: 12,
    unrecorded: 10,
    rate: "90.8%",
  };

  const beats = [
    {
      num: 1,
      title: "Beat 1: Reveal Scale",
      desc: "Camera elevates above Row 12, revealing the full 240-seat lecture hall architecture.",
    },
    {
      num: 2,
      title: "Beat 2: Organize Blocks",
      desc: "Seating rows segment into 3 physical banks (Left, Center, Right) across 12 ascending tiers.",
    },
    {
      num: 3,
      title: "Beat 3: Collect Submissions",
      desc: "Submissions ingest concurrently from student mobile devices alongside the active projector challenge.",
    },
    {
      num: 4,
      title: "Beat 4: Corroborate & Validate",
      desc: "Backend cross-references 1:1 biometric crops, challenge TTL, replay prevention, and room context.",
    },
    {
      num: 5,
      title: "Beat 5: Resolve States",
      desc: "Classifies each seat into Verified (218), Pending Review (12), or Not Recorded (10).",
    },
  ];

  return (
    <section className="relative py-24 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto">
      {/* Header */}
      <div className="text-center max-w-3xl mx-auto mb-16">
        <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-amber-100 border border-amber-300 text-amber-900 font-mono text-xs font-bold mb-4 shadow-sm">
          <Maximize2 className="w-3.5 h-3.5" />
          <span>SECTION 08 • VISUAL CLIMAX</span>
        </div>
        <h2 className="text-3xl sm:text-5xl font-extrabold text-slate-900 tracking-tight mb-4">
          Designed for the <br />
          <span className="bg-gradient-to-r from-amber-800 via-amber-700 to-orange-700 bg-clip-text text-transparent">
            Entire Lecture Hall.
          </span>
        </h2>
        <p className="text-base sm:text-lg text-slate-700 font-medium">
          The ultimate test of an attendance system is the 240-seat amphitheater.
          Rather than relying on unrealistic long-distance facial recognition, Attendrix orchestrates high-density verification through distributed student evidence and human-in-the-loop audit.
        </p>
      </div>

      {/* 5-Beat Story Progression Bar */}
      <div className="glass-panel p-3 rounded-2xl border border-slate-300/90 bg-white/95 mb-8 overflow-x-auto shadow-md">
        <div className="flex items-center min-w-max gap-2">
          {beats.map((b) => (
            <button
              key={b.num}
              onClick={() => {
                soundManager.playClick();
                setActiveBeat(b.num);
              }}
              className={`px-4 py-2.5 rounded-xl text-xs font-mono transition-all flex items-center gap-2 border cursor-pointer ${
                activeBeat === b.num
                  ? "bg-amber-600 text-white font-bold border-amber-600 shadow-md shadow-amber-600/30 ring-2 ring-amber-400/40"
                  : "bg-white text-slate-800 font-semibold border-slate-300 hover:text-slate-900 hover:border-amber-500 shadow-sm"
              }`}
            >
              <span>{b.title}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Active Beat Explanation Card */}
      <div className="glass-panel p-4 rounded-xl border border-slate-200 mb-8 flex items-center justify-between text-xs font-mono text-slate-700 shadow-sm">
        <div className="flex items-center gap-3">
          <span className="px-2 py-0.5 rounded bg-amber-100 text-amber-900 border border-amber-300 font-bold">
            BEAT 0{activeBeat}
          </span>
          <span className="font-medium text-slate-800">{beats[activeBeat - 1].desc}</span>
        </div>
        <span className="text-slate-500 hidden sm:inline font-semibold">240-Seat Real Classroom Storyboard</span>
      </div>

      {/* 240-Seat Live Dashboard Telemetry Banner */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 mb-12">
        <div className="glass-panel p-5 rounded-2xl border border-slate-200 shadow-sm">
          <span className="text-[10px] font-mono text-amber-800 font-bold uppercase tracking-wider block mb-1">
            TOTAL ENROLLED
          </span>
          <div className="text-3xl font-extrabold text-slate-900 font-mono">{stats.enrolled}</div>
          <div className="text-[11px] text-slate-500 mt-1">Full Amphitheater Roster</div>
        </div>

        <div className="glass-panel p-5 rounded-2xl border border-slate-200 shadow-sm">
          <span className="text-[10px] font-mono text-emerald-800 font-bold uppercase tracking-wider block mb-1">
            VERIFIED PRESENT
          </span>
          <div className="text-3xl font-extrabold text-emerald-700 font-mono">{stats.verified}</div>
          <div className="text-[11px] text-emerald-700 font-semibold mt-1">{stats.rate} Sample Pass</div>
        </div>

        <div className="glass-panel p-5 rounded-2xl border border-slate-200 shadow-sm">
          <span className="text-[10px] font-mono text-orange-800 font-bold uppercase tracking-wider block mb-1">
            PENDING REVIEW
          </span>
          <div className="text-3xl font-extrabold text-orange-700 font-mono">{stats.pending}</div>
          <div className="text-[11px] text-orange-700 font-semibold mt-1">Marginal Cosine / Low Light</div>
        </div>

        <div className="glass-panel p-5 rounded-2xl border border-slate-200 shadow-sm">
          <span className="text-[10px] font-mono text-slate-500 font-bold uppercase tracking-wider block mb-1">
            NOT RECORDED
          </span>
          <div className="text-3xl font-extrabold text-slate-600 font-mono">{stats.unrecorded}</div>
          <div className="text-[11px] text-slate-500 mt-1">Unsubmitted / Absent</div>
        </div>
      </div>

      {/* Expandable Technical Panel: How does the system scale to 240 students? */}
      <div className="glass-panel rounded-3xl border border-slate-200 mb-12 overflow-hidden shadow-lg">
        <button
          onClick={() => {
            soundManager.playClick();
            setPanelOpen(!panelOpen);
          }}
          className="w-full p-6 text-left flex items-center justify-between hover:bg-slate-50/80 transition-colors cursor-pointer"
        >
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-amber-100 border border-amber-300 flex items-center justify-center text-amber-800">
              <Camera className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-base font-bold text-slate-900">
                How does the system scale to 240 students without magical claims?
              </h3>
              <p className="text-xs text-slate-500 font-mono">
                Optical analysis: Wide-angle panorama vs 1:1 student selfie crop
              </p>
            </div>
          </div>
          {panelOpen ? (
            <ChevronUp className="w-5 h-5 text-amber-700" />
          ) : (
            <ChevronDown className="w-5 h-5 text-amber-700" />
          )}
        </button>

        {panelOpen && (
          <div className="p-6 pt-0 border-t border-slate-200 space-y-8 animate-in fade-in">
            {/* 3 Core Engineering Considerations */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6 pt-6">
              <div className="bg-slate-50 p-5 rounded-2xl border border-slate-200">
                <span className="text-xs font-mono font-bold text-amber-800 block mb-2">
                  1. Individual Device Evidence
                </span>
                <p className="text-xs text-slate-700 leading-relaxed">
                  Every student holds a high-resolution camera inches from their face. Capturing a 112×112 canonical crop on the student device bypasses amphitheater distance and occlusions entirely.
                </p>
              </div>

              <div className="bg-slate-50 p-5 rounded-2xl border border-slate-200">
                <span className="text-xs font-mono font-bold text-orange-800 block mb-2">
                  2. Classroom Context Constraints
                </span>
                <p className="text-xs text-slate-700 leading-relaxed">
                  A wide classroom camera establishes room occupancy and detects human presence clusters. At 20 meters, distant faces occupy only 14×14 pixels—insufficient for ArcFace recognition.
                </p>
              </div>

              <div className="bg-slate-50 p-5 rounded-2xl border border-slate-200">
                <span className="text-xs font-mono font-bold text-amber-800 block mb-2">
                  3. Multi-View Feasibility
                </span>
                <p className="text-xs text-slate-700 leading-relaxed">
                  If physical ceiling cameras are deployed, rigorous optical testing (included in Section 12) dictates multi-camera overlapping zones rather than a single fictitious rear sensor.
                </p>
              </div>
            </div>

            {/* Visual Resolution Comparison Tool */}
            <div className="bg-slate-50 p-6 rounded-2xl border border-slate-200 space-y-4">
              <div className="flex flex-wrap items-center justify-between gap-4">
                <div>
                  <h4 className="text-sm font-bold text-slate-900 flex items-center gap-2">
                    <Scan className="w-4 h-4 text-amber-700" />
                    <span>Optical Resolution Comparison: Distance vs Proximity</span>
                  </h4>
                  <p className="text-xs text-slate-500 font-mono">
                    Visual comparison of facial pixel density available for biometric feature extraction
                  </p>
                </div>

                <div className="flex items-center gap-2">
                  <button
                    onClick={() => setComparisonMode("side_by_side")}
                    className={`px-3 py-1.5 rounded-lg text-xs font-mono cursor-pointer font-bold ${
                      comparisonMode === "side_by_side"
                        ? "bg-amber-600 text-white shadow-sm"
                        : "text-slate-600 hover:text-slate-900 bg-white border border-slate-200"
                    }`}
                  >
                    Side-by-Side
                  </button>
                  <button
                    onClick={() => setComparisonMode("wide_crop")}
                    className={`px-3 py-1.5 rounded-lg text-xs font-mono cursor-pointer font-bold ${
                      comparisonMode === "wide_crop"
                        ? "bg-amber-600 text-white shadow-sm"
                        : "text-slate-600 hover:text-slate-900 bg-white border border-slate-200"
                    }`}
                  >
                    Wide-Angle (20m)
                  </button>
                  <button
                    onClick={() => setComparisonMode("selfie_crop")}
                    className={`px-3 py-1.5 rounded-lg text-xs font-mono cursor-pointer font-bold ${
                      comparisonMode === "selfie_crop"
                        ? "bg-amber-600 text-white shadow-sm"
                        : "text-slate-600 hover:text-slate-900 bg-white border border-slate-200"
                    }`}
                  >
                    Student Selfie (0.5m)
                  </button>
                </div>
              </div>

              {/* Visual Crops Container */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6 pt-2">
                {/* Crop A: Distant Wide Classroom Crop */}
                {(comparisonMode === "side_by_side" || comparisonMode === "wide_crop") && (
                  <div className="bg-white p-4 rounded-xl border border-orange-300 flex flex-col items-center shadow-sm">
                    <span className="text-[10px] font-mono text-orange-800 font-bold mb-2 uppercase tracking-wider">
                      CROP A: Wide Camera Panorama (20m Distance, Row 12)
                    </span>
                    <div className="w-36 h-36 bg-slate-950 rounded-xl border-2 border-dashed border-orange-400 flex items-center justify-center relative overflow-hidden mb-3">
                      <div className="grid grid-cols-7 gap-1 w-20 h-20 opacity-70">
                        {Array.from({ length: 49 }).map((_, i) => (
                          <div
                            key={i}
                            className={`w-full h-full rounded-sm ${
                              i === 16 || i === 18 ? "bg-orange-500" : i > 28 ? "bg-slate-600" : "bg-slate-800"
                            }`}
                          />
                        ))}
                      </div>
                      <span className="absolute bottom-1 right-2 text-[9px] font-mono text-orange-400 font-bold">
                        14×14 px
                      </span>
                    </div>
                    <div className="space-y-1 text-center font-mono text-[11px] text-slate-700">
                      <div className="text-orange-700 font-bold">Inter-Pupillary Distance (IPD): ~6px</div>
                      <div className="text-slate-600">YuNet Head Detection: PASS (Candidate Box)</div>
                      <div className="text-orange-700 font-bold">ArcFace Biometric Vector: COLLAPSED (Interpolated Blur)</div>
                    </div>
                  </div>
                )}

                {/* Crop B: Student Selfie Crop */}
                {(comparisonMode === "side_by_side" || comparisonMode === "selfie_crop") && (
                  <div className="bg-white p-4 rounded-xl border border-amber-400 flex flex-col items-center shadow-sm">
                    <span className="text-[10px] font-mono text-amber-800 font-bold mb-2 uppercase tracking-wider">
                      CROP B: Student Authenticated Selfie (0.5m Distance)
                    </span>
                    <div className="w-36 h-36 bg-amber-50 rounded-xl border-2 border-amber-500 flex flex-col items-center justify-center relative shadow-sm mb-3">
                      <div className="w-20 h-24 rounded-full border border-amber-600 flex flex-col items-center justify-center">
                        <div className="flex gap-4 mb-2">
                          <span className="w-2 h-2 rounded-full bg-amber-700" />
                          <span className="w-2 h-2 rounded-full bg-amber-700" />
                        </div>
                        <div className="w-1.5 h-1.5 rounded-full bg-amber-600 mb-1" />
                        <div className="w-5 h-1 rounded-full bg-amber-700" />
                      </div>
                      <span className="absolute bottom-1 right-2 text-[9px] font-mono text-amber-800 font-bold">
                        112×112 px
                      </span>
                    </div>
                    <div className="space-y-1 text-center font-mono text-[11px] text-slate-700">
                      <div className="text-amber-800 font-bold">Inter-Pupillary Distance (IPD): ~48px (&gt; 30px min)</div>
                      <div className="text-slate-600">YuNet 5-Landmark Alignment: OPTIMAL</div>
                      <div className="text-emerald-700 font-bold">ArcFace 512-D Embedding: HIGH CONFIDENCE (0.86)</div>
                    </div>
                  </div>
                )}
              </div>
            </div>

            <div className="text-xs text-slate-700 font-mono bg-slate-100 p-4 rounded-xl border border-slate-200">
              *Conclusion: True attendance verification at 240-seat scale is achieved by combining student client capture for high-resolution biometric grounding with server-side challenge and audit reconciliation.
            </div>
          </div>
        )}
      </div>
    </section>
  );
}
