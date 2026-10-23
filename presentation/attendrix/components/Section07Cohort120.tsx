"use client";

import React, { useState } from "react";
import { soundManager } from "./SoundManager";
import { Layers, CheckCircle2, AlertCircle, HelpCircle, ArrowRight, ShieldCheck, Filter } from "lucide-react";

type ZoneKey = "all" | "zoneA" | "zoneB" | "zoneC";

interface Section07Cohort120Props {
  onZoneChange?: (zone: ZoneKey) => void;
}

export default function Section07Cohort120({ onZoneChange }: Section07Cohort120Props) {
  const [activeZone, setActiveZone] = useState<ZoneKey>("all");

  const zonesData = {
    zoneA: {
      name: "Zone A (Front Rows 1–4)",
      enrolled: 40,
      submissions: 39,
      facesDetected: 39,
      verified: 38,
      pending: 1,
      unrecorded: 1,
      opticalCondition: "High classroom illuminance (>450 lux), near-zero perspective skew",
    },
    zoneB: {
      name: "Zone B (Mid Rows 5–8)",
      enrolled: 40,
      submissions: 38,
      facesDetected: 37,
      verified: 36,
      pending: 2,
      unrecorded: 2,
      opticalCondition: "Standard classroom ambient (300 lux), minor laptop screen glare",
    },
    zoneC: {
      name: "Zone C (Rear Rows 9–12)",
      enrolled: 40,
      submissions: 37,
      facesDetected: 35,
      verified: 34,
      pending: 3,
      unrecorded: 3,
      opticalCondition: "Dimmer lecture hall background (180 lux), moderate head occlusion",
    },
  };

  const totalEnrolled = 120;
  const totalVerified = 108;
  const totalPending = 6;
  const totalUnrecorded = 6;

  const currentZoneData =
    activeZone === "all"
      ? {
          name: "All Zones (Entire 120-Seat Amphitheater)",
          enrolled: totalEnrolled,
          submissions: 114,
          facesDetected: 111,
          verified: totalVerified,
          pending: totalPending,
          unrecorded: totalUnrecorded,
          opticalCondition: "Aggregated 12-row cohort distribution",
        }
      : zonesData[activeZone];

  const handleSelectZone = (zone: ZoneKey) => {
    soundManager.playClick();
    setActiveZone(zone);
    if (onZoneChange) onZoneChange(zone);
  };

  return (
    <section className="relative py-24 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto">
      {/* Header */}
      <div className="text-center max-w-3xl mx-auto mb-16">
        <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-amber-100 border border-amber-300 text-amber-900 font-mono text-xs font-bold mb-4 shadow-sm">
          <Layers className="w-3.5 h-3.5" />
          <span>SECTION 07 • SCALE TIER 2</span>
        </div>
        <h2 className="text-3xl sm:text-5xl font-extrabold text-slate-900 tracking-tight mb-4">
          More Students. <br />
          <span className="bg-gradient-to-r from-amber-800 via-amber-700 to-orange-700 bg-clip-text text-transparent">
            The Same Verification Discipline.
          </span>
        </h2>
        <p className="text-base sm:text-lg text-slate-700 font-medium">
          Scaling to 120 students introduces tiering and zone partitioning.
          Submissions are organized into manageable logical zones (A, B, C) to balance network ingestion and instructor review workflows.
        </p>
      </div>

      {/* Zone Interactive Controls Bar */}
      <div className="flex flex-wrap items-center justify-center gap-3 mb-12">
        <button
          onClick={() => handleSelectZone("all")}
          className={`px-5 py-2.5 rounded-xl text-xs font-mono font-bold transition-all border cursor-pointer ${
            activeZone === "all"
              ? "bg-amber-600 text-white border-amber-600 shadow-md shadow-amber-600/30 ring-2 ring-amber-400/40"
              : "bg-white text-slate-800 font-semibold border-slate-300 hover:border-amber-500 hover:text-slate-900 shadow-sm"
          }`}
        >
          All 3 Zones (120 Seats)
        </button>

        <button
          onClick={() => handleSelectZone("zoneA")}
          className={`px-5 py-2.5 rounded-xl text-xs font-mono font-bold transition-all border cursor-pointer ${
            activeZone === "zoneA"
              ? "bg-amber-600 text-white border-amber-600 shadow-md shadow-amber-600/30 ring-2 ring-amber-400/40"
              : "bg-white text-slate-800 font-semibold border-slate-300 hover:border-amber-500 hover:text-slate-900 shadow-sm"
          }`}
        >
          Zone A (Front • 40 Seats)
        </button>

        <button
          onClick={() => handleSelectZone("zoneB")}
          className={`px-5 py-2.5 rounded-xl text-xs font-mono font-bold transition-all border cursor-pointer ${
            activeZone === "zoneB"
              ? "bg-amber-600 text-white border-amber-600 shadow-md shadow-amber-600/30 ring-2 ring-amber-400/40"
              : "bg-white text-slate-800 font-semibold border-slate-300 hover:border-amber-500 hover:text-slate-900 shadow-sm"
          }`}
        >
          Zone B (Mid • 40 Seats)
        </button>

        <button
          onClick={() => handleSelectZone("zoneC")}
          className={`px-5 py-2.5 rounded-xl text-xs font-mono font-bold transition-all border cursor-pointer ${
            activeZone === "zoneC"
              ? "bg-amber-600 text-white border-amber-600 shadow-md shadow-amber-600/30 ring-2 ring-amber-400/40"
              : "bg-white text-slate-800 font-semibold border-slate-300 hover:border-amber-500 hover:text-slate-900 shadow-sm"
          }`}
        >
          Zone C (Rear • 40 Seats)
        </button>
      </div>

      {/* Reconciled Telemetry Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
        <div className="glass-panel p-5 rounded-2xl border border-slate-200 shadow-sm">
          <span className="text-[10px] font-mono text-amber-850 font-bold uppercase tracking-wider block mb-1">
            ENROLLED CAPACITY
          </span>
          <div className="text-3xl font-extrabold text-slate-900 font-mono">
            {currentZoneData.enrolled}
          </div>
          <div className="text-[11px] text-slate-700 font-medium mt-1">Total assigned seats</div>
        </div>

        <div className="glass-panel p-5 rounded-2xl border border-slate-200 shadow-sm">
          <span className="text-[10px] font-mono text-emerald-800 font-bold uppercase tracking-wider block mb-1">
            VERIFIED PRESENT
          </span>
          <div className="text-3xl font-extrabold text-emerald-800 font-mono">
            {currentZoneData.verified}
          </div>
          <div className="text-[11px] text-emerald-800 font-bold mt-1">
            {((currentZoneData.verified / currentZoneData.enrolled) * 100).toFixed(1)}% verified rate
          </div>
        </div>

        <div className="glass-panel p-5 rounded-2xl border border-slate-200 shadow-sm">
          <span className="text-[10px] font-mono text-orange-850 font-bold uppercase tracking-wider block mb-1">
            PENDING REVIEW
          </span>
          <div className="text-3xl font-extrabold text-orange-800 font-mono">
            {currentZoneData.pending}
          </div>
          <div className="text-[11px] text-orange-800 font-bold mt-1">Uncertain / blurry crops</div>
        </div>

        <div className="glass-panel p-5 rounded-2xl border border-slate-200 shadow-sm">
          <span className="text-[10px] font-mono text-slate-700 font-bold uppercase tracking-wider block mb-1">
            NOT YET RECORDED
          </span>
          <div className="text-3xl font-extrabold text-slate-800 font-mono">
            {currentZoneData.unrecorded}
          </div>
          <div className="text-[11px] text-slate-700 font-medium mt-1">Absent or unsubmitted</div>
        </div>
      </div>

      {/* Visual Representation of 3 Zones */}
      <div className="glass-panel p-6 sm:p-8 rounded-3xl border border-slate-200 mb-12 shadow-lg">
        <div className="flex items-center justify-between mb-6 pb-4 border-b border-slate-200">
          <div>
            <h3 className="text-base font-bold text-slate-900">{currentZoneData.name}</h3>
            <p className="text-xs text-slate-700 font-mono font-medium">
              Optical Condition: {currentZoneData.opticalCondition}
            </p>
          </div>
          <div className="text-xs font-mono text-amber-900 font-bold">
            Reconciliation: {currentZoneData.verified} + {currentZoneData.pending} + {currentZoneData.unrecorded} = {currentZoneData.enrolled} ✓
          </div>
        </div>

        {/* 3 Tier Blocks Container */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {/* Block A */}
          <div
            onClick={() => handleSelectZone("zoneA")}
            className={`p-5 rounded-2xl border transition-all cursor-pointer ${
              activeZone === "zoneA" || activeZone === "all"
                ? "bg-white border-amber-500 ring-2 ring-amber-400/30 shadow-md"
                : "bg-slate-50 border-slate-200 opacity-70 hover:opacity-100"
            }`}
          >
            <div className="flex items-center justify-between mb-3">
              <span className="text-xs font-bold text-amber-900 font-mono">ZONE A (FRONT)</span>
              <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-amber-100 text-amber-950 border border-amber-300 font-bold">
                Rows 1–4
              </span>
            </div>
            <div className="space-y-1.5 text-xs font-mono text-slate-800">
              <div className="flex justify-between">
                <span className="text-slate-700 font-bold">Enrolled:</span>
                <span className="text-slate-900 font-extrabold">40</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-700 font-bold">Verified:</span>
                <span className="text-emerald-800 font-bold">38 (95.0%)</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-700 font-bold">Pending Review:</span>
                <span className="text-orange-800 font-bold">1</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-700 font-bold">Not Recorded:</span>
                <span className="text-slate-800 font-bold">1</span>
              </div>
            </div>
          </div>

          {/* Block B */}
          <div
            onClick={() => handleSelectZone("zoneB")}
            className={`p-5 rounded-2xl border transition-all cursor-pointer ${
              activeZone === "zoneB" || activeZone === "all"
                ? "bg-white border-orange-500 ring-2 ring-orange-400/30 shadow-md"
                : "bg-slate-50 border-slate-200 opacity-70 hover:opacity-100"
            }`}
          >
            <div className="flex items-center justify-between mb-3">
              <span className="text-xs font-bold text-orange-900 font-mono">ZONE B (MID)</span>
              <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-orange-100 text-orange-950 border border-orange-300 font-bold">
                Rows 5–8
              </span>
            </div>
            <div className="space-y-1.5 text-xs font-mono text-slate-800">
              <div className="flex justify-between">
                <span className="text-slate-700 font-bold">Enrolled:</span>
                <span className="text-slate-900 font-extrabold">40</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-700 font-bold">Verified:</span>
                <span className="text-amber-800 font-bold">36 (90.0%)</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-700 font-bold">Pending Review:</span>
                <span className="text-orange-800 font-bold">2</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-700 font-bold">Not Recorded:</span>
                <span className="text-slate-800 font-bold">2</span>
              </div>
            </div>
          </div>

          {/* Block C */}
          <div
            onClick={() => handleSelectZone("zoneC")}
            className={`p-5 rounded-2xl border transition-all cursor-pointer ${
              activeZone === "zoneC" || activeZone === "all"
                ? "bg-white border-amber-600 ring-2 ring-amber-500/30 shadow-md"
                : "bg-slate-50 border-slate-200 opacity-70 hover:opacity-100"
            }`}
          >
            <div className="flex items-center justify-between mb-3">
              <span className="text-xs font-bold text-amber-900 font-mono">ZONE C (REAR)</span>
              <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-amber-100 text-amber-950 border border-amber-300 font-bold">
                Rows 9–12
              </span>
            </div>
            <div className="space-y-1.5 text-xs font-mono text-slate-800">
              <div className="flex justify-between">
                <span className="text-slate-700 font-bold">Enrolled:</span>
                <span className="text-slate-900 font-extrabold">40</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-700 font-bold">Verified:</span>
                <span className="text-amber-800 font-bold">34 (85.0%)</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-700 font-bold">Pending Review:</span>
                <span className="text-orange-800 font-bold">3</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-700 font-bold">Not Recorded:</span>
                <span className="text-slate-800 font-bold">3</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Critical Metric Differentiation */}
      <div className="glass-panel p-6 rounded-2xl border border-slate-200 shadow-sm">
        <h4 className="text-sm font-bold text-slate-900 mb-3 flex items-center gap-2">
          <HelpCircle className="w-4 h-4 text-amber-700" />
          <span>Metric Definitions: Never Treat These As Interchangeable</span>
        </h4>
        <div className="grid grid-cols-1 md:grid-cols-5 gap-3 text-xs font-mono">
          <div className="bg-slate-50 p-3 rounded-lg border border-slate-200">
            <span className="text-amber-900 font-bold block mb-1">1. Enrolled (120)</span>
            <span className="text-slate-700 font-medium">Registered students on the official course roster.</span>
          </div>
          <div className="bg-slate-50 p-3 rounded-lg border border-slate-200">
            <span className="text-orange-900 font-bold block mb-1">2. Submissions (114)</span>
            <span className="text-slate-700 font-medium">Packets received by the FastAPI backend.</span>
          </div>
          <div className="bg-slate-50 p-3 rounded-lg border border-slate-200">
            <span className="text-amber-900 font-bold block mb-1">3. Faces Detected (111)</span>
            <span className="text-slate-700 font-medium">YuNet candidate bounding boxes identified in room.</span>
          </div>
          <div className="bg-slate-50 p-3 rounded-lg border border-slate-200">
            <span className="text-emerald-900 font-bold block mb-1">4. Identities Verified (108)</span>
            <span className="text-slate-700 font-medium">1:1 ArcFace matches passing similarity &gt; 0.72.</span>
          </div>
          <div className="bg-slate-50 p-3 rounded-lg border border-slate-200">
            <span className="text-orange-900 font-bold block mb-1">5. Unresolved (6)</span>
            <span className="text-slate-700 font-medium">Cases preserved for authorized instructor audit.</span>
          </div>
        </div>
      </div>
    </section>
  );
}
