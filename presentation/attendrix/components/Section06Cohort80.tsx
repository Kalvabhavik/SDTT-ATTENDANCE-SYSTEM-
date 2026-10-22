"use client";

import React, { useState } from "react";
import { soundManager } from "./SoundManager";
import { Users, CheckCircle, Clock, AlertTriangle, ChevronRight, UserCheck, Shield } from "lucide-react";

interface Section06Cohort80Props {
  onSelectCohort?: (cohort: 80) => void;
}

export default function Section06Cohort80({ onSelectCohort }: Section06Cohort80Props) {
  const [selectedSeat, setSelectedSeat] = useState<number | null>(14);

  // Reconciled sample data: Enrolled: 80, Verified: 72, Pending: 5, Not yet recorded: 3 (72 + 5 + 3 = 80)
  const cohortData = {
    enrolled: 80,
    verified: 72,
    pending: 5,
    unrecorded: 3,
  };

  // Generate 80 sample seats (8 rows x 10 seats)
  const seats = Array.from({ length: 80 }, (_, i) => {
    const id = i + 1;
    let status: "verified" | "pending" | "unrecorded" = "verified";
    if ([7, 19, 38, 55, 71].includes(id)) status = "pending";
    else if ([24, 48, 80].includes(id)) status = "unrecorded";

    const names = [
      "Aarav Sharma", "Ananya Iyer", "Rohan Mehta", "Diya Patel",
      "Kavya Nair", "Aditya Verma", "Ishaan Roy", "Pooja Reddy",
      "Vikram Joshi", "Meera Sen", "Siddharth Das", "Neha Gupta"
    ];
    const name = names[i % names.length] + ` (STU-${1000 + id})`;

    return {
      id,
      row: Math.floor(i / 10) + 1,
      col: (i % 10) + 1,
      status,
      name,
      confidence: status === "verified" ? (0.82 + (id % 15) * 0.01).toFixed(2) : status === "pending" ? "0.56" : "N/A",
      timestamp: status !== "unrecorded" ? `09:02:${(10 + (id % 45)).toString().padStart(2, "0")}` : "—",
    };
  });

  const activeSeatRecord = seats.find((s) => s.id === selectedSeat) || seats[0];

  return (
    <section id="scale" className="relative py-24 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto">
      {/* Header */}
      <div className="text-center max-w-3xl mx-auto mb-16">
        <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-amber-100 border border-amber-300 text-amber-900 font-mono text-xs font-bold mb-4 shadow-sm">
          <Users className="w-3.5 h-3.5" />
          <span>SECTION 06 • SCALE TIER 1</span>
        </div>
        <h2 className="text-3xl sm:text-5xl font-extrabold text-slate-900 tracking-tight mb-4">
          Small Cohort. <br />
          <span className="bg-gradient-to-r from-amber-800 via-amber-700 to-orange-700 bg-clip-text text-transparent">
            Controlled Verification.
          </span>
        </h2>
        <p className="text-base sm:text-lg text-slate-700 font-medium">
          For classes of up to 80 enrolled students, Attendrix delivers immediate operational relief.
          A low review queue (5 cases) allows the instructor to audit discrepancies in under 60 seconds before closing the lecture.
        </p>
      </div>

      {/* Main Grid: 80 Seat Map on Left, Metrics & Inspector on Right */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start mb-12">
        {/* Left Column: 80 Seat Topological Interactive Matrix */}
        <div className="lg:col-span-7 glass-panel p-6 sm:p-8 rounded-3xl border border-slate-300/90 bg-white/95 shadow-xl">
          <div className="flex items-center justify-between mb-6 pb-4 border-b border-slate-200">
            <div>
              <span className="text-xs font-mono text-amber-800 font-bold uppercase tracking-wider block">
                TOPOLOGICAL SEAT MATRIX (8 ROWS × 10 SEATS)
              </span>
              <h3 className="text-base font-bold text-slate-900">CS-101 Seminar Hall (80 Enrolled)</h3>
            </div>
            <div className="text-xs font-mono text-slate-500 font-semibold">
              Click seat to inspect
            </div>
          </div>

          {/* Front Stage Indicator */}
          <div className="w-full py-2.5 mb-6 rounded-xl bg-amber-50 border border-amber-300 text-center text-xs font-mono text-amber-900 font-bold tracking-widest shadow-sm">
            [ FRONT LECTERN &amp; DYNAMIC CHALLENGE SCREEN ]
          </div>

          {/* 8 Rows of Seats */}
          <div className="space-y-2">
            {Array.from({ length: 8 }).map((_, rowIndex) => {
              const rowSeats = seats.filter((s) => s.row === rowIndex + 1);
              return (
                <div key={rowIndex} className="flex items-center justify-center gap-1.5 sm:gap-2">
                  <span className="w-7 text-[11px] font-mono text-amber-800 font-bold text-right pr-1">
                    R{rowIndex + 1}
                  </span>
                  {rowSeats.map((seat) => {
                    const isSelected = selectedSeat === seat.id;
                    let colorClass =
                      seat.status === "verified"
                        ? "bg-amber-500 border-amber-400 text-white shadow-sm"
                        : seat.status === "pending"
                        ? "bg-orange-500 border-orange-400 text-white shadow-sm"
                        : "bg-slate-200 border-slate-300 text-slate-600";

                    return (
                      <button
                        key={seat.id}
                        onClick={() => {
                          soundManager.playClick();
                          setSelectedSeat(seat.id);
                        }}
                        title={`Seat #${seat.id}: ${seat.name} - ${seat.status.toUpperCase()}`}
                        className={`w-7 h-7 sm:w-8 sm:h-8 rounded-lg text-[10px] font-mono font-bold flex items-center justify-center border transition-all cursor-pointer ${colorClass} ${
                          isSelected ? "ring-2 ring-amber-600 scale-110 z-10 shadow-md" : "hover:scale-105"
                        } ${seat.col === 5 ? "mr-4" : ""}`}
                      >
                        {seat.id}
                      </button>
                    );
                  })}
                </div>
              );
            })}
          </div>

          {/* Seat Color Legend */}
          <div className="mt-8 pt-4 border-t border-slate-200 flex flex-wrap items-center justify-center gap-6 text-xs font-mono">
            <div className="flex items-center gap-2">
              <span className="w-3 h-3 rounded bg-amber-500 shadow-sm" />
              <span className="text-slate-700 font-medium">Verified ({cohortData.verified})</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="w-3 h-3 rounded bg-orange-500 shadow-sm" />
              <span className="text-slate-700 font-medium">Pending Review ({cohortData.pending})</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="w-3 h-3 rounded bg-slate-300" />
              <span className="text-slate-700 font-medium">Not Recorded ({cohortData.unrecorded})</span>
            </div>
          </div>
        </div>

        {/* Right Column: Reconciled Telemetry & Selected Seat Record */}
        <div className="lg:col-span-5 space-y-6">
          {/* Reconciled Summary Card */}
          <div className="glass-panel p-6 rounded-2xl border border-slate-200 space-y-4 shadow-sm">
            <div className="flex items-center justify-between pb-3 border-b border-slate-200">
              <span className="text-xs font-mono text-amber-800 font-bold uppercase tracking-wider">
                SESSION RECONCILIATION SUMMARY
              </span>
              <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-amber-100 text-amber-900 border border-amber-300 font-bold">
                TOTAL: 80 / 80
              </span>
            </div>

            <div className="grid grid-cols-2 gap-3 text-xs font-mono">
              <div className="bg-slate-50 p-3.5 rounded-xl border border-slate-200">
                <span className="text-slate-500 text-[10px] block font-semibold">TOTAL ENROLLED</span>
                <span className="text-2xl font-bold text-slate-900 font-mono">
                  {cohortData.enrolled}
                </span>
                <span className="text-[10px] text-slate-500 block">Class Roster</span>
              </div>

              <div className="bg-slate-50 p-3.5 rounded-xl border border-slate-200">
                <span className="text-amber-700 text-[10px] block font-semibold">VERIFIED PRESENT</span>
                <span className="text-2xl font-bold text-amber-700 font-mono">
                  {cohortData.verified}
                </span>
                <span className="text-[10px] text-emerald-700 font-semibold block">90.0% sample pass</span>
              </div>

              <div className="bg-slate-50 p-3.5 rounded-xl border border-slate-200">
                <span className="text-orange-700 text-[10px] block font-semibold">PENDING REVIEW</span>
                <span className="text-2xl font-bold text-orange-700 font-mono">
                  {cohortData.pending}
                </span>
                <span className="text-[10px] text-orange-700 font-semibold block">Requires TA glance</span>
              </div>

              <div className="bg-slate-50 p-3.5 rounded-xl border border-slate-200">
                <span className="text-slate-500 text-[10px] block font-semibold">NOT YET RECORDED</span>
                <span className="text-2xl font-bold text-slate-600 font-mono">
                  {cohortData.unrecorded}
                </span>
                <span className="text-[10px] text-slate-500 block">Absent / No submission</span>
              </div>
            </div>

            <div className="text-[11px] font-mono text-slate-700 bg-amber-50 p-2.5 rounded-lg border border-amber-200 flex justify-between">
              <span>Mathematical Check:</span>
              <span className="text-amber-900 font-bold">72 + 5 + 3 = 80 Enrolled ✓</span>
            </div>
          </div>

          {/* Seat Inspector Drawer */}
          {activeSeatRecord && (
            <div className="glass-panel p-6 rounded-2xl border border-slate-200 relative shadow-md">
              <div className="flex items-center justify-between mb-4">
                <div className="text-xs font-mono text-amber-800 font-bold">
                  SELECTED SEAT #{activeSeatRecord.id} (ROW {activeSeatRecord.row})
                </div>
                <span
                  className={`text-[10px] font-mono px-2.5 py-0.5 rounded font-bold uppercase ${
                    activeSeatRecord.status === "verified"
                      ? "bg-emerald-100 text-emerald-900 border border-emerald-300"
                      : activeSeatRecord.status === "pending"
                      ? "bg-amber-100 text-amber-900 border border-amber-300"
                      : "bg-slate-200 text-slate-700 border border-slate-300"
                  }`}
                >
                  {activeSeatRecord.status}
                </span>
              </div>

              <div className="space-y-2 text-xs font-mono bg-slate-50 p-3.5 rounded-xl border border-slate-200">
                <div className="flex justify-between">
                  <span className="text-slate-500">Student Name:</span>
                  <span className="text-slate-900 font-bold">{activeSeatRecord.name}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-slate-500">Submission Time:</span>
                  <span className="text-slate-700">{activeSeatRecord.timestamp}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-slate-500">Cosine Similarity:</span>
                  <span className="text-amber-800 font-bold">{activeSeatRecord.confidence}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-slate-500">Challenge Code:</span>
                  <span className="text-emerald-700 font-bold">9K4-PX2 (Valid)</span>
                </div>
              </div>
            </div>
          )}

          {/* Technical Honesty Note */}
          <div className="bg-slate-50 p-4 rounded-xl border border-slate-200 text-[11px] text-slate-600 font-mono leading-relaxed">
            *Notice on 80-student scale: Does not claim instantaneous verification. Real-world throughput depends on mobile network latency, client camera quality, and institutional facial matching thresholds.
          </div>
        </div>
      </div>
    </section>
  );
}
