"use client";

import React, { useState, useMemo } from "react";
import { soundManager } from "./SoundManager";
import {
  BarChart3,
  Search,
  Filter,
  Download,
  CheckCircle2,
  AlertTriangle,
  XCircle,
  Clock,
  UserCheck,
  Eye,
  FileSpreadsheet,
  ChevronRight,
  Sparkles,
  LayoutDashboard,
  Users,
  Settings,
  ShieldCheck,
  RotateCcw,
} from "lucide-react";

type FilterStatus = "ALL" | "VERIFIED" | "UNCERTAIN" | "PENDING_REVIEW" | "REJECTED" | "NOT_RECORDED";
type CohortDataset = 80 | 120 | 240;

interface AttendanceRecord {
  id: string;
  name: string;
  email: string;
  seat: number;
  status: "VERIFIED" | "UNCERTAIN" | "PENDING_REVIEW" | "REJECTED" | "NOT_RECORDED";
  similarity: number | null;
  challengeMatch: boolean;
  time: string;
  note?: string;
}

export default function Section10Dashboard() {
  const [activeTab, setActiveTab] = useState<string>("records");
  const [cohortSize, setCohortSize] = useState<CohortDataset>(240);
  const [statusFilter, setStatusFilter] = useState<FilterStatus>("ALL");
  const [searchQuery, setSearchQuery] = useState<string>("");
  const [inspectingRecord, setInspectingRecord] = useState<AttendanceRecord | null>(null);

  // Generate synthetic reconciled dataset for 80, 120, or 240 students
  const [records, setRecords] = useState<Record<CohortDataset, AttendanceRecord[]>>(() => {
    const studentNames = [
      "Aarav Sharma", "Ananya Iyer", "Rohan Mehta", "Diya Patel", "Kavya Nair",
      "Aditya Verma", "Ishaan Roy", "Pooja Reddy", "Vikram Joshi", "Meera Sen",
      "Siddharth Das", "Neha Gupta", "Aryan Kapoor", "Tara Deshmukh", "Nikhil Rao",
      "Sanya Malhotra", "Devansh Bhatia", "Riya Sen", "Kabir Khanna", "Anika Chawla"
    ];

    const generateForCohort = (total: number, numVerified: number, numPending: number, numUnrecorded: number) => {
      const list: AttendanceRecord[] = [];
      for (let i = 1; i <= total; i++) {
        const name = `${studentNames[(i - 1) % studentNames.length]} ${Math.floor((i - 1) / studentNames.length) + 1}`;
        const studentId = `STU-2024-${(1000 + i).toString()}`;
        const email = `stu${1000 + i}@univ.demo.edu`;

        let status: AttendanceRecord["status"] = "VERIFIED";
        let similarity: number | null = 0.78 + (i % 18) * 0.01;
        let challengeMatch = true;
        let time = `09:02:${(10 + (i % 45)).toString().padStart(2, "0")}`;
        let note: string | undefined = undefined;

        if (i <= numPending) {
          status = "PENDING_REVIEW";
          similarity = 0.58;
          note = "Borderline cosine similarity (0.58), lighting low";
        } else if (i > total - numUnrecorded) {
          status = "NOT_RECORDED";
          similarity = null;
          challengeMatch = false;
          time = "—";
          note = "No submission received";
        } else if (i === 42 && total === 240) {
          status = "REJECTED";
          challengeMatch = false;
          similarity = 0.88;
          note = "Challenge expired";
        } else if (i === 67 && total === 240) {
          status = "UNCERTAIN";
          similarity = 0.44;
          note = "Motion blur threshold fail";
        }

        list.push({
          id: studentId,
          name,
          email,
          seat: i,
          status,
          similarity: similarity ? Number(similarity.toFixed(2)) : null,
          challengeMatch,
          time,
          note,
        });
      }
      return list;
    };

    return {
      80: generateForCohort(80, 72, 5, 3),
      120: generateForCohort(120, 108, 6, 6),
      240: generateForCohort(240, 218, 12, 10),
    };
  });

  const currentDataset = records[cohortSize];

  // Calculated Reconciled Stats
  const summaryStats = useMemo(() => {
    const total = currentDataset.length;
    const verified = currentDataset.filter((r) => r.status === "VERIFIED").length;
    const pending = currentDataset.filter((r) => r.status === "PENDING_REVIEW" || r.status === "UNCERTAIN").length;
    const rejected = currentDataset.filter((r) => r.status === "REJECTED").length;
    const unrecorded = currentDataset.filter((r) => r.status === "NOT_RECORDED").length;
    return { total, verified, pending, rejected, unrecorded };
  }, [currentDataset]);

  // Filtered rows
  const filteredRecords = useMemo(() => {
    return currentDataset.filter((r) => {
      const matchesSearch =
        r.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        r.id.toLowerCase().includes(searchQuery.toLowerCase()) ||
        r.seat.toString() === searchQuery;

      if (!matchesSearch) return false;
      if (statusFilter === "ALL") return true;
      return r.status === statusFilter;
    });
  }, [currentDataset, searchQuery, statusFilter]);

  // Teacher override action
  const handleTeacherOverride = (newStatus: "VERIFIED" | "NOT_RECORDED") => {
    if (!inspectingRecord) return;
    soundManager.playSuccess();

    setRecords((prev) => {
      const updated = prev[cohortSize].map((item) => {
        if (item.id === inspectingRecord.id) {
          return {
            ...item,
            status: newStatus,
            note: `Instructor override: Marked ${newStatus} with audit stamp`,
          };
        }
        return item;
      });
      return {
        ...prev,
        [cohortSize]: updated,
      };
    });

    setInspectingRecord((prev) =>
      prev ? { ...prev, status: newStatus, note: `Instructor override: Marked ${newStatus}` } : null
    );
  };

  // Real CSV Export
  const handleExportCSV = () => {
    soundManager.playClick();
    const headers = ["StudentID", "StudentName", "Email", "SeatNumber", "AttendanceStatus", "CosineSimilarity", "SubmissionTime", "Notes"];
    const rows = currentDataset.map((r) => [
      r.id,
      `"${r.name}"`,
      r.email,
      r.seat,
      r.status,
      r.similarity ?? "N/A",
      r.time,
      `"${r.note || ""}"`,
    ]);

    const csvContent = "data:text/csv;charset=utf-8," + [headers.join(","), ...rows.map((e) => e.join(","))].join("\n");
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement("a");
    link.setAttribute("href", encodedUri);
    link.setAttribute("download", `attendrix_session8491_cohort${cohortSize}_report.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <section id="dashboard" className="relative py-24 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto">
      {/* Header */}
      <div className="text-center max-w-3xl mx-auto mb-16">
        <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-amber-100 border border-amber-300 text-amber-900 font-mono text-xs font-bold mb-4 shadow-sm">
          <LayoutDashboard className="w-3.5 h-3.5" />
          <span>SECTION 10 • THE CONTROL CENTER</span>
        </div>
        <h2 className="text-3xl sm:text-5xl font-extrabold text-slate-900 tracking-tight mb-4">
          A Clear View of <br />
          <span className="bg-gradient-to-r from-amber-800 via-amber-700 to-orange-700 bg-clip-text text-transparent">
            Every Attendance Session.
          </span>
        </h2>
        <p className="text-base sm:text-lg text-slate-700 font-medium">
          The Attendrix faculty console provides high-density operational command.
          Audit discrepancies, filter by risk, inspect biometric evidence, and export auditable university reports.
        </p>
      </div>

      {/* Main Enterprise Dashboard Box */}
      <div className="glass-panel rounded-3xl border border-slate-300/90 overflow-hidden shadow-2xl bg-white">
        {/* Top Console Navigation Bar */}
        <div className="p-4 sm:p-6 bg-slate-50 border-b border-slate-300 flex flex-wrap items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-amber-600 text-white font-black flex items-center justify-center font-mono text-sm shadow-md shadow-amber-600/30">
              AX
            </div>
            <div>
              <div className="text-sm font-bold text-slate-900 flex items-center gap-2">
                <span>CS-401: Advanced Vision Lecture Hall A</span>
                <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-emerald-100 text-emerald-900 border border-emerald-300 font-bold">
                  SESSION #8491 • OPEN
                </span>
              </div>
              <div className="text-[11px] font-mono text-slate-600 font-medium">
                Instructor: Prof. Sharma • Challenge Token: 9K4-PX2 (15s TTL)
              </div>
            </div>
          </div>

          {/* Dataset Cohort Switcher */}
          <div className="flex items-center gap-1.5 bg-white p-1 rounded-xl border border-slate-300 font-mono text-xs shadow-sm">
            <span className="text-slate-600 px-2 text-[10px] font-bold">COHORT:</span>
            {[80, 120, 240].map((size) => (
              <button
                key={size}
                onClick={() => {
                  soundManager.playClick();
                  setCohortSize(size as CohortDataset);
                }}
                className={`px-3 py-1.5 rounded-lg transition-all cursor-pointer ${
                  cohortSize === size
                    ? "bg-amber-600 text-white font-bold shadow-sm"
                    : "text-slate-800 font-semibold hover:text-slate-900 hover:bg-slate-100"
                }`}
              >
                {size} Seats
              </button>
            ))}
          </div>
        </div>

        {/* Telemetry Summary Metric Cards */}
        <div className="p-6 grid grid-cols-2 lg:grid-cols-5 gap-4 bg-white border-b border-slate-200">
          <div className="bg-slate-50 p-4 rounded-xl border border-slate-200 font-mono">
            <span className="text-slate-500 text-[10px] uppercase tracking-wider block mb-1 font-semibold">
              ENROLLED
            </span>
            <div className="text-2xl font-bold text-slate-900">{summaryStats.total}</div>
            <div className="text-[10px] text-slate-500">100% Course Roster</div>
          </div>

          <div className="bg-slate-50 p-4 rounded-xl border border-emerald-300 font-mono">
            <span className="text-emerald-800 text-[10px] uppercase tracking-wider block mb-1 font-semibold">
              VERIFIED PRESENT
            </span>
            <div className="text-2xl font-bold text-emerald-700">{summaryStats.verified}</div>
            <div className="text-[10px] text-emerald-700 font-semibold">
              {((summaryStats.verified / summaryStats.total) * 100).toFixed(1)}% verified
            </div>
          </div>

          <div className="bg-slate-50 p-4 rounded-xl border border-amber-300 font-mono">
            <span className="text-amber-800 text-[10px] uppercase tracking-wider block mb-1 font-semibold">
              PENDING REVIEW
            </span>
            <div className="text-2xl font-bold text-amber-700">{summaryStats.pending}</div>
            <div className="text-[10px] text-amber-700 font-semibold">Requires TA check</div>
          </div>

          <div className="bg-slate-50 p-4 rounded-xl border border-rose-300 font-mono">
            <span className="text-rose-800 text-[10px] uppercase tracking-wider block mb-1 font-semibold">
              REJECTED RULES
            </span>
            <div className="text-2xl font-bold text-rose-700">{summaryStats.rejected}</div>
            <div className="text-[10px] text-rose-700 font-semibold">Replay / Expired token</div>
          </div>

          <div className="bg-slate-50 p-4 rounded-xl border border-slate-200 font-mono col-span-2 lg:col-span-1">
            <span className="text-slate-500 text-[10px] uppercase tracking-wider block mb-1 font-semibold">
              NOT RECORDED
            </span>
            <div className="text-2xl font-bold text-slate-600">{summaryStats.unrecorded}</div>
            <div className="text-[10px] text-slate-500">Absent students</div>
          </div>
        </div>

        {/* Action Controls & Filter Ribbon */}
        <div className="p-4 sm:p-6 flex flex-wrap items-center justify-between gap-4 bg-slate-50 border-b border-slate-200">
          {/* Status Filter Pills */}
          <div className="flex flex-wrap items-center gap-1.5 font-mono text-xs">
            <span className="text-slate-500 text-[10px] mr-1 hidden sm:inline font-semibold">FILTER:</span>
            {(
              [
                ["ALL", "All"],
                ["VERIFIED", "Verified"],
                ["PENDING_REVIEW", "Review Queue"],
                ["REJECTED", "Rejected"],
                ["NOT_RECORDED", "Not Recorded"],
              ] as [FilterStatus, string][]
            ).map(([val, label]) => (
              <button
                key={val}
                onClick={() => {
                  soundManager.playClick();
                  setStatusFilter(val);
                }}
                className={`px-3 py-1.5 rounded-lg transition-all ${
                  statusFilter === val
                    ? "bg-amber-100 text-amber-900 border border-amber-300 font-bold shadow-sm"
                    : "text-slate-600 hover:text-slate-900 bg-white border border-slate-200 shadow-sm"
                }`}
              >
                {label}
              </button>
            ))}
          </div>

          {/* Search Input & CSV Export Button */}
          <div className="flex items-center gap-3 w-full sm:w-auto">
            <div className="relative flex-1 sm:w-64">
              <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search student or ID..."
                className="w-full bg-white border border-slate-200 rounded-xl pl-9 pr-3 py-1.5 text-xs text-slate-900 placeholder-slate-400 focus:outline-none focus:border-amber-500 font-mono shadow-sm"
              />
            </div>

            <button
              onClick={handleExportCSV}
              className="px-4 py-2 rounded-xl text-xs font-mono font-bold bg-amber-600 hover:bg-amber-500 text-white flex items-center gap-2 transition-colors cursor-pointer shrink-0 shadow-md shadow-amber-600/30"
              title="Download official attendance report in CSV format"
            >
              <Download className="w-3.5 h-3.5" />
              <span>Export CSV</span>
            </button>
          </div>
        </div>

        {/* Interactive Attendance Table */}
        <div className="overflow-x-auto max-h-[460px] overflow-y-auto">
          <table className="w-full text-left text-xs font-mono">
            <thead className="bg-slate-100 text-slate-600 uppercase text-[10px] tracking-wider border-b border-slate-200 sticky top-0 z-10">
              <tr>
                <th className="py-3 px-4">Seat #</th>
                <th className="py-3 px-4">Student ID</th>
                <th className="py-3 px-4">Name</th>
                <th className="py-3 px-4">Status</th>
                <th className="py-3 px-4">1:1 Similarity</th>
                <th className="py-3 px-4">Time</th>
                <th className="py-3 px-4 text-right">Audit Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-200">
              {filteredRecords.length === 0 ? (
                <tr>
                  <td colSpan={7} className="py-12 text-center text-slate-500 font-mono">
                    No student records match the active filter criteria.
                  </td>
                </tr>
              ) : (
                filteredRecords.map((r) => {
                  let statusBadge = "bg-slate-100 text-slate-700 border-slate-300";
                  if (r.status === "VERIFIED")
                    statusBadge = "bg-emerald-100 text-emerald-900 border-emerald-300 font-bold";
                  else if (r.status === "PENDING_REVIEW" || r.status === "UNCERTAIN")
                    statusBadge = "bg-amber-100 text-amber-900 border-amber-300 font-bold";
                  else if (r.status === "REJECTED")
                    statusBadge = "bg-rose-100 text-rose-900 border-rose-300 font-bold";

                  return (
                    <tr
                      key={r.id}
                      className="hover:bg-amber-50/50 transition-colors group cursor-pointer"
                      onClick={() => {
                        soundManager.playClick();
                        setInspectingRecord(r);
                      }}
                    >
                      <td className="py-3 px-4 text-slate-500 font-bold">#{r.seat}</td>
                      <td className="py-3 px-4 text-amber-800 font-bold">{r.id}</td>
                      <td className="py-3 px-4 text-slate-900 font-sans font-medium">{r.name}</td>
                      <td className="py-3 px-4">
                        <span className={`px-2 py-0.5 rounded text-[10px] border ${statusBadge}`}>
                          {r.status}
                        </span>
                      </td>
                      <td className="py-3 px-4 text-slate-700 font-semibold">
                        {r.similarity ? `${r.similarity} (${r.similarity >= 0.72 ? "High" : "Low"})` : "—"}
                      </td>
                      <td className="py-3 px-4 text-slate-500">{r.time}</td>
                      <td className="py-3 px-4 text-right">
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            soundManager.playClick();
                            setInspectingRecord(r);
                          }}
                          className="px-2.5 py-1 rounded bg-white hover:bg-amber-600 hover:text-white text-slate-700 border border-slate-200 text-[10px] transition-colors shadow-sm font-semibold"
                        >
                          Inspect Evidence
                        </button>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>

        {/* Footer info bar */}
        <div className="p-4 bg-slate-50 border-t border-slate-200 flex flex-wrap items-center justify-between text-xs font-mono text-slate-600">
          <div>
            Showing {filteredRecords.length} of {currentDataset.length} students (Cohort {cohortSize})
          </div>
          <div className="text-[10px] text-slate-500">
            *All data synthetic demonstration records matching Section 06/07/08 counts.
          </div>
        </div>
      </div>

      {/* Evidence Inspector Modal / Drawer */}
      {inspectingRecord && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm animate-in fade-in">
          <div className="glass-panel w-full max-w-xl p-6 sm:p-8 rounded-3xl border border-slate-200 shadow-2xl relative space-y-6">
            <div className="flex items-center justify-between pb-4 border-b border-slate-200">
              <div>
                <span className="text-xs font-mono text-amber-800 font-bold uppercase tracking-wider block">
                  EVIDENCE AUDIT DOSSIER
                </span>
                <h3 className="text-lg font-bold text-slate-900">{inspectingRecord.name}</h3>
                <span className="text-xs font-mono text-slate-500">
                  {inspectingRecord.id} • Seat #{inspectingRecord.seat}
                </span>
              </div>
              <button
                onClick={() => setInspectingRecord(null)}
                className="w-8 h-8 rounded-lg bg-slate-100 text-slate-600 hover:text-slate-900 flex items-center justify-center text-lg cursor-pointer"
              >
                ×
              </button>
            </div>

            {/* Evidence Data Grid */}
            <div className="grid grid-cols-2 gap-4 text-xs font-mono">
              <div className="bg-slate-50 p-3.5 rounded-xl border border-slate-200">
                <span className="text-slate-500 text-[10px] block mb-1 font-semibold">PROBE CAPTURE TIME</span>
                <span className="text-slate-900 font-bold">{inspectingRecord.time}</span>
              </div>

              <div className="bg-slate-50 p-3.5 rounded-xl border border-slate-200">
                <span className="text-slate-500 text-[10px] block mb-1 font-semibold">CHALLENGE CODE MATCH</span>
                <span className={inspectingRecord.challengeMatch ? "text-emerald-700 font-bold" : "text-rose-700 font-bold"}>
                  {inspectingRecord.challengeMatch ? "9K4-PX2 (VALID)" : "MISMATCH / EXPIRED"}
                </span>
              </div>

              <div className="bg-slate-50 p-3.5 rounded-xl border border-slate-200">
                <span className="text-slate-500 text-[10px] block mb-1 font-semibold">1:1 ARCFACE SIMILARITY</span>
                <span className="text-amber-800 font-bold text-sm">
                  {inspectingRecord.similarity ?? "No Image Submitted"}
                </span>
              </div>

              <div className="bg-slate-950 p-3.5 rounded-xl border border-slate-800">
                <span className="text-slate-500 text-[10px] block mb-1">RECORD STATUS</span>
                <span className="text-amber-300 font-bold">{inspectingRecord.status}</span>
              </div>
            </div>

            {inspectingRecord.note && (
              <div className="bg-amber-950/30 p-3.5 rounded-xl border border-amber-500/30 text-xs text-amber-200/90 font-mono">
                <span className="font-bold text-amber-400 block mb-0.5">EVIDENCE NOTE:</span>
                {inspectingRecord.note}
              </div>
            )}

            {/* Instructor Action Decision Buttons */}
            <div className="pt-4 border-t border-slate-800 flex flex-wrap items-center justify-end gap-3">
              <button
                onClick={() => handleTeacherOverride("NOT_RECORDED")}
                className="px-4 py-2 rounded-xl text-xs font-mono font-bold bg-rose-500/20 text-rose-300 border border-rose-500/40 hover:bg-rose-500 hover:text-black transition-colors"
              >
                Mark Absent
              </button>

              <button
                onClick={() => handleTeacherOverride("VERIFIED")}
                className="px-5 py-2 rounded-xl text-xs font-mono font-bold bg-emerald-500 text-slate-950 hover:bg-emerald-400 shadow-[0_0_15px_rgba(16,185,129,0.4)] transition-all"
              >
                Approve &amp; Mark Present
              </button>
            </div>
          </div>
        </div>
      )}
    </section>
  );
}
