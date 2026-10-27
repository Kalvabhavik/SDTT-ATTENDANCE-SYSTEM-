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
type CohortDataset = 80 | 120 | 240 | 260;
type DashboardView = "faculty" | "controller";

interface AttendanceRecord {
  id: string;
  name: string;
  email: string;
  seat: number;
  status: "VERIFIED" | "UNCERTAIN" | "PENDING_REVIEW" | "REJECTED" | "NOT_RECORDED";
  similarity: number | null;
  gyroSweepDelta: number;
  sweepPassed: boolean;
  yuNetPresence: "PASSED (PEERS DETECTED)" | "FLAGGED (0 FACES / EMPTY ROOM)";
  time: string;
  note?: string;
}

export default function Section10Dashboard() {
  const [activeView, setActiveView] = useState<DashboardView>("faculty");
  const [cohortSize, setCohortSize] = useState<CohortDataset>(260);
  const [statusFilter, setStatusFilter] = useState<FilterStatus>("ALL");
  const [searchQuery, setSearchQuery] = useState<string>("");
  const [inspectingRecord, setInspectingRecord] = useState<AttendanceRecord | null>(null);

  // Controller state
  const [selectedVenue, setSelectedVenue] = useState<string>("AUD-260");
  const [cameraUploading, setCameraUploading] = useState<boolean>(false);
  const [venueLockStatus, setVenueLockStatus] = useState<"UNLOCKED" | "VERIFYING" | "LOCKED">("LOCKED");

  // Generate synthetic reconciled dataset for 80, 120, 240, or 260 students
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
        let gyroSweepDelta = 138 + (i % 24);
        let sweepPassed = true;
        let yuNetPresence: AttendanceRecord["yuNetPresence"] = "PASSED (PEERS DETECTED)";
        let time = `09:02:${(10 + (i % 45)).toString().padStart(2, "0")}`;
        let note: string | undefined = undefined;

        if (i <= numPending) {
          status = "PENDING_REVIEW";
          similarity = 0.58;
          if (i === 1) {
            yuNetPresence = "FLAGGED (0 FACES / EMPTY ROOM)";
            note = "Anti-Empty-Room Defense: YuNet 0 faces detected in sweep";
          } else {
            note = "Borderline cosine similarity (0.58), marginal lighting";
          }
        } else if (i > total - numUnrecorded) {
          status = "NOT_RECORDED";
          similarity = null;
          sweepPassed = false;
          gyroSweepDelta = 0;
          time = "—";
          note = "No sweep submission received";
        } else if (i === 42) {
          status = "REJECTED";
          sweepPassed = false;
          gyroSweepDelta = 42;
          similarity = 0.88;
          note = "Insufficient gyro arc (Δyaw = 42° < 120° minimum)";
        } else if (i === 67) {
          status = "UNCERTAIN";
          similarity = 0.44;
          note = "Motion blur threshold fail (Laplacian var < 1.5)";
        }

        list.push({
          id: studentId,
          name,
          email,
          seat: i,
          status,
          similarity: similarity ? Number(similarity.toFixed(2)) : null,
          gyroSweepDelta,
          sweepPassed,
          yuNetPresence,
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
      260: generateForCohort(260, 236, 14, 10),
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
    const headers = ["StudentID", "StudentName", "Email", "SeatNumber", "AttendanceStatus", "ArcFaceCosine", "GyroDeltaYaw", "YuNetPresence", "SubmissionTime", "Notes"];
    const rows = currentDataset.map((r) => [
      r.id,
      `"${r.name}"`,
      r.email,
      r.seat,
      r.status,
      r.similarity ?? "N/A",
      `${r.gyroSweepDelta}°`,
      `"${r.yuNetPresence}"`,
      r.time,
      `"${r.note || ""}"`,
    ]);

    const csvContent = "data:text/csv;charset=utf-8," + [headers.join(","), ...rows.map((e) => e.join(","))].join("\n");
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement("a");
    link.setAttribute("href", encodedUri);
    link.setAttribute("download", `attendrix_session8491_cohort${cohortSize}_verified_roster.csv`);
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
          The Attendrix administrative portal provides institutional command.
          Switch between live lecturer WebSocket supervision and Academic Controller venue configuration with real camera panorama reference capture.
        </p>

        {/* View Switcher: Faculty Console vs Academic Controller */}
        <div className="inline-flex items-center p-1.5 bg-slate-100 rounded-2xl border border-slate-300 mt-6 shadow-sm">
          <button
            onClick={() => {
              soundManager.playClick();
              setActiveView("faculty");
            }}
            className={`px-5 py-2 rounded-xl text-xs font-mono font-bold transition-all cursor-pointer flex items-center gap-2 ${
              activeView === "faculty"
                ? "bg-amber-600 text-white shadow-md shadow-amber-600/30"
                : "text-slate-700 hover:text-slate-950"
            }`}
          >
            <Users className="w-3.5 h-3.5" />
            <span>Faculty Live Console &amp; Roster</span>
          </button>
          <button
            onClick={() => {
              soundManager.playClick();
              setActiveView("controller");
            }}
            className={`px-5 py-2 rounded-xl text-xs font-mono font-bold transition-all cursor-pointer flex items-center gap-2 ${
              activeView === "controller"
                ? "bg-amber-600 text-white shadow-md shadow-amber-600/30"
                : "text-slate-700 hover:text-slate-950"
            }`}
          >
            <ShieldCheck className="w-3.5 h-3.5" />
            <span>Academic Controller Portal</span>
          </button>
        </div>
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
                <span>CS-401: Computer Vision &amp; Deep Learning</span>
                <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-emerald-100 text-emerald-900 border border-emerald-300 font-bold">
                  SESSION #8491 • OPEN
                </span>
              </div>
              <div className="text-[11px] font-mono text-slate-600 font-medium">
                Instructor: Prof. Sharma • Venue: AUD-260 (Grand Auditorium) • 180° Sweep Telemetry Active
              </div>
            </div>
          </div>

          {/* Dataset Cohort Switcher */}
          <div className="flex items-center gap-1.5 bg-white p-1 rounded-xl border border-slate-300 font-mono text-xs shadow-sm">
            <span className="text-slate-600 px-2 text-[10px] font-bold">COHORT:</span>
            {[80, 120, 240, 260].map((size) => (
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
            <span className="text-slate-700 text-[10px] uppercase tracking-wider block mb-1 font-bold">
              ENROLLED
            </span>
            <div className="text-2xl font-bold text-slate-900">{summaryStats.total}</div>
            <div className="text-[10px] text-slate-700 font-medium">100% Course Roster</div>
          </div>

          <div className="bg-slate-50 p-4 rounded-xl border border-emerald-300 font-mono">
            <span className="text-emerald-900 text-[10px] uppercase tracking-wider block mb-1 font-bold">
              VERIFIED PRESENT
            </span>
            <div className="text-2xl font-bold text-emerald-800">{summaryStats.verified}</div>
            <div className="text-[10px] text-emerald-800 font-bold">
              {((summaryStats.verified / summaryStats.total) * 100).toFixed(1)}% verified
            </div>
          </div>

          <div className="bg-slate-50 p-4 rounded-xl border border-amber-300 font-mono">
            <span className="text-amber-900 text-[10px] uppercase tracking-wider block mb-1 font-bold">
              PENDING REVIEW
            </span>
            <div className="text-2xl font-bold text-amber-800">{summaryStats.pending}</div>
            <div className="text-[10px] text-amber-800 font-bold">Requires TA check</div>
          </div>

          <div className="bg-slate-50 p-4 rounded-xl border border-rose-300 font-mono">
            <span className="text-rose-900 text-[10px] uppercase tracking-wider block mb-1 font-bold">
              REJECTED RULES
            </span>
            <div className="text-2xl font-bold text-rose-800">{summaryStats.rejected}</div>
            <div className="text-[10px] text-rose-800 font-bold">Replay / Expired token</div>
          </div>

          <div className="bg-slate-50 p-4 rounded-xl border border-slate-200 font-mono col-span-2 lg:col-span-1">
            <span className="text-slate-700 text-[10px] uppercase tracking-wider block mb-1 font-bold">
              NOT RECORDED
            </span>
            <div className="text-2xl font-bold text-slate-800">{summaryStats.unrecorded}</div>
            <div className="text-[10px] text-slate-700 font-medium">Absent students</div>
          </div>
        </div>

        {/* Conditional View: Faculty Live Roster vs Academic Controller Portal */}
        {activeView === "faculty" ? (
          <>
            {/* Action Controls & Filter Ribbon */}
            <div className="p-4 sm:p-6 flex flex-wrap items-center justify-between gap-4 bg-slate-50 border-b border-slate-200">
              {/* Status Filter Pills */}
              <div className="flex flex-wrap items-center gap-1.5 font-mono text-xs">
                <span className="text-slate-700 text-[10px] mr-1 hidden sm:inline font-bold">FILTER:</span>
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
                        ? "bg-amber-100 text-amber-950 border border-amber-300 font-bold shadow-sm"
                        : "text-slate-700 hover:text-slate-950 bg-white border border-slate-300 font-semibold shadow-sm"
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
                <thead className="bg-slate-200 text-slate-800 uppercase text-[11px] font-bold tracking-wider border-b border-slate-300 sticky top-0 z-10">
                  <tr>
                    <th className="py-3 px-4">Seat #</th>
                    <th className="py-3 px-4">Student ID</th>
                    <th className="py-3 px-4">Name</th>
                    <th className="py-3 px-4">Status</th>
                    <th className="py-3 px-4">Active Liveness</th>
                    <th className="py-3 px-4">1:1 ArcFace</th>
                    <th className="py-3 px-4">180° Sweep</th>
                    <th className="py-3 px-4">Anti-Proxy</th>
                    <th className="py-3 px-4 text-right">Audit</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-200">
                  {filteredRecords.length === 0 ? (
                    <tr>
                      <td colSpan={9} className="py-12 text-center text-slate-600 font-mono font-semibold">
                        No student records match the active filter criteria.
                      </td>
                    </tr>
                  ) : (
                    filteredRecords.map((r) => {
                      let statusBadge = "bg-slate-100 text-slate-800 border-slate-300";
                      if (r.status === "VERIFIED")
                        statusBadge = "bg-emerald-100 text-emerald-950 border-emerald-300 font-bold";
                      else if (r.status === "PENDING_REVIEW" || r.status === "UNCERTAIN")
                        statusBadge = "bg-amber-100 text-amber-950 border-amber-300 font-bold";
                      else if (r.status === "REJECTED")
                        statusBadge = "bg-rose-100 text-rose-950 border-rose-300 font-bold";

                      return (
                        <tr
                          key={r.id}
                          className="hover:bg-amber-50/50 transition-colors group cursor-pointer"
                          onClick={() => {
                            soundManager.playClick();
                            setInspectingRecord(r);
                          }}
                        >
                          <td className="py-3 px-4 text-slate-700 font-bold">#{r.seat}</td>
                          <td className="py-3 px-4 text-amber-900 font-bold">{r.id}</td>
                          <td className="py-3 px-4 text-slate-900 font-sans font-medium">{r.name}</td>
                          <td className="py-3 px-4">
                            <span className={`px-2 py-0.5 rounded text-[10px] border ${statusBadge}`}>
                              {r.status}
                            </span>
                          </td>
                          <td className="py-3 px-4">
                            {r.status === "VERIFIED" ? (
                              <span className="text-emerald-800 font-bold text-[10px] bg-emerald-50 px-1.5 py-0.5 rounded border border-emerald-200">
                                Yaw &amp; Blink OK
                              </span>
                            ) : r.status === "PENDING_REVIEW" && r.note?.includes("Liveness") ? (
                              <span className="text-rose-800 font-bold text-[10px] bg-rose-50 px-1.5 py-0.5 rounded border border-rose-200">
                                Static / Incomplete
                              </span>
                            ) : (
                              <span className="text-slate-500 text-[10px]">Challenge OK</span>
                            )}
                          </td>
                          <td className="py-3 px-4 text-slate-800 font-bold">
                            {r.similarity ? `${r.similarity} (${r.similarity >= 0.68 ? "Pass" : "Marginal"})` : "—"}
                          </td>
                          <td className="py-3 px-4 font-mono">
                            {r.sweepPassed ? (
                              <span className="text-emerald-800 font-bold">Δ{r.gyroSweepDelta}° (Pass)</span>
                            ) : (
                              <span className="text-rose-800 font-bold">Δ{r.gyroSweepDelta}° (Fail)</span>
                            )}
                          </td>
                          <td className="py-3 px-4">
                            {r.yuNetPresence.includes("PASSED") ? (
                              <span className="text-emerald-800 font-bold text-[10px]">Peers Confirmed</span>
                            ) : (
                              <span className="text-rose-800 font-bold text-[10px] bg-rose-50 px-1 py-0.5 rounded border border-rose-200">
                                Empty Room Flag
                              </span>
                            )}
                          </td>
                          <td className="py-3 px-4 text-right">
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                soundManager.playClick();
                                setInspectingRecord(r);
                              }}
                              className="px-2.5 py-1 rounded bg-white hover:bg-amber-600 hover:text-white text-slate-800 border border-slate-300 text-[10px] transition-colors shadow-sm font-bold"
                            >
                              Inspect
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
            <div className="p-4 bg-slate-50 border-t border-slate-200 flex flex-wrap items-center justify-between text-xs font-mono text-slate-800 font-medium">
              <div>
                Showing {filteredRecords.length} of {currentDataset.length} students (Cohort {cohortSize})
              </div>
              <div className="text-[10px] text-slate-600 font-semibold">
                *Reconciled telemetry with continuous gyro tracking and anti-empty-room proxy interception.
              </div>
            </div>
          </>
        ) : (
          /* Academic Controller Venue & Panorama Portal View */
          <div className="p-6 sm:p-8 space-y-6">
            <div className="flex flex-wrap items-center justify-between gap-4 pb-6 border-b border-slate-200">
              <div>
                <span className="text-xs font-mono text-purple-900 font-bold uppercase tracking-wider block mb-1">
                  CONTROLLER VENUE GOVERNANCE
                </span>
                <h3 className="text-xl font-bold text-slate-900">Lecture Hall &amp; Reference Panorama Registry</h3>
                <p className="text-xs text-slate-600 font-sans mt-1">
                  Academic Controllers provision physical venues, configure seating topologies (80, 120, 240, 260), and upload reference panorama captures.
                </p>
              </div>

              <div className="flex items-center gap-2">
                <span className="text-xs font-mono text-slate-600 font-bold">STATE:</span>
                <span className="px-3 py-1 rounded-full text-xs font-mono font-bold bg-emerald-100 text-emerald-950 border border-emerald-300">
                  {venueLockStatus}
                </span>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              {/* Venue Selector */}
              <div className="bg-slate-50 p-5 rounded-2xl border border-slate-200 space-y-3 font-mono text-xs">
                <span className="text-slate-700 block font-bold uppercase text-[10px]">1. SELECT ASSIGNED VENUE</span>
                <div className="space-y-2">
                  {[
                    { id: "AUD-260", name: "Grand Auditorium Alpha", capacity: 260, tiers: "13 Rows + Balcony" },
                    { id: "AMP-240", name: "Amphitheater Beta", capacity: 240, tiers: "12 Rows / 3 Banks" },
                    { id: "LEC-120", name: "Lecture Hall Gamma", capacity: 120, tiers: "8 Rows Tiered" },
                    { id: "SEM-80", name: "Seminar Room Delta", capacity: 80, tiers: "4 Flat Rows" },
                  ].map((venue) => (
                    <button
                      key={venue.id}
                      onClick={() => {
                        soundManager.playClick();
                        setSelectedVenue(venue.id);
                        if (venue.capacity === 260) setCohortSize(260);
                        else if (venue.capacity === 240) setCohortSize(240);
                        else if (venue.capacity === 120) setCohortSize(120);
                        else setCohortSize(80);
                      }}
                      className={`w-full p-3 rounded-xl border text-left transition-all cursor-pointer ${
                        selectedVenue === venue.id
                          ? "bg-amber-600 text-white font-bold border-amber-600 shadow-md shadow-amber-600/20"
                          : "bg-white text-slate-800 border-slate-300 hover:border-amber-400"
                      }`}
                    >
                      <div className="flex items-center justify-between">
                        <span className="font-bold">{venue.id}</span>
                        <span className="text-[10px] px-1.5 py-0.5 rounded bg-black/10">{venue.capacity} Seats</span>
                      </div>
                      <div className="text-[11px] opacity-90 mt-0.5 font-sans">{venue.name}</div>
                      <div className="text-[9px] opacity-75">{venue.tiers}</div>
                    </button>
                  ))}
                </div>
              </div>

              {/* Panorama Camera Upload */}
              <div className="bg-slate-50 p-5 rounded-2xl border border-slate-200 space-y-3 font-mono text-xs">
                <span className="text-slate-700 block font-bold uppercase text-[10px]">2. REFERENCE ROOM PANORAMA</span>
                <div className="p-4 bg-white rounded-xl border-2 border-dashed border-slate-300 text-center space-y-3">
                  <div className="w-12 h-12 mx-auto rounded-xl bg-purple-100 border border-purple-300 text-purple-900 flex items-center justify-center font-bold text-lg">
                    📷
                  </div>
                  <div>
                    <div className="font-bold text-slate-900">Reference Wide-Angle Capture</div>
                    <div className="text-[10px] text-slate-600 font-sans mt-0.5">
                      Ground truth panorama used by YuNet anti-proxy defense to detect real classroom background features.
                    </div>
                  </div>
                  <button
                    onClick={() => {
                      soundManager.playClick();
                      setCameraUploading(true);
                      setTimeout(() => {
                        setCameraUploading(false);
                        soundManager.playSuccess();
                      }, 900);
                    }}
                    className="w-full py-2 rounded-xl text-xs font-mono font-bold bg-purple-700 hover:bg-purple-600 text-white transition-all shadow-md cursor-pointer"
                  >
                    {cameraUploading ? "Uploading Live Camera Stream..." : "Upload New Venue Panorama"}
                  </button>
                </div>
                <div className="text-[10px] text-slate-600 bg-purple-50 p-2.5 rounded-xl border border-purple-200">
                  *Panorama signature hash: <span className="font-bold text-purple-950">SHA256:7f9e8a...01cb</span> (Active)
                </div>
              </div>

              {/* Biometric Registry Lock */}
              <div className="bg-slate-50 p-5 rounded-2xl border border-slate-200 space-y-3 font-mono text-xs">
                <span className="text-slate-700 block font-bold uppercase text-[10px]">3. BIOMETRIC REGISTRY &amp; ENROLLMENT</span>
                <div className="space-y-2 bg-white p-4 rounded-xl border border-slate-300">
                  <div className="flex items-center justify-between">
                    <span className="text-slate-600">Registered Students:</span>
                    <span className="font-bold text-slate-900">260 / 260</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-slate-600">512-D Vectors Encrypted:</span>
                    <span className="font-bold text-emerald-800">100% (AES-256)</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-slate-600">Anti-Spoof Baseline:</span>
                    <span className="font-bold text-purple-900">LOCKED</span>
                  </div>
                  <div className="pt-2 border-t border-slate-200">
                    <button
                      onClick={() => {
                        soundManager.playSuccess();
                        setVenueLockStatus(venueLockStatus === "LOCKED" ? "UNLOCKED" : "LOCKED");
                      }}
                      className="w-full py-2 rounded-xl text-xs font-mono font-bold bg-slate-900 hover:bg-slate-800 text-white transition-all cursor-pointer"
                    >
                      {venueLockStatus === "LOCKED" ? "Unlock Venue Configuration" : "Lock & Sign Venue Topology"}
                    </button>
                  </div>
                </div>
                <div className="text-[10px] text-slate-600 bg-slate-100 p-2.5 rounded-xl border border-slate-200">
                  Enforces strict institutional boundary: teachers cannot alter venue seating matrices or reference panoramas.
                </div>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Evidence Inspector Modal / Drawer */}
      {inspectingRecord && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm animate-in fade-in">
          <div className="bg-white w-full max-w-xl p-6 sm:p-8 rounded-3xl border border-slate-300 shadow-2xl relative space-y-6">
            <div className="flex items-center justify-between pb-4 border-b border-slate-200">
              <div>
                <span className="text-xs font-mono text-amber-900 font-bold uppercase tracking-wider block">
                  EVIDENCE AUDIT DOSSIER
                </span>
                <h3 className="text-lg font-bold text-slate-900">{inspectingRecord.name}</h3>
                <span className="text-xs font-mono text-slate-700 font-semibold">
                  {inspectingRecord.id} • Seat #{inspectingRecord.seat}
                </span>
              </div>
              <button
                onClick={() => setInspectingRecord(null)}
                className="w-8 h-8 rounded-lg bg-slate-100 text-slate-700 hover:text-slate-950 flex items-center justify-center text-lg cursor-pointer font-bold"
              >
                ×
              </button>
            </div>

            {/* Evidence Data Grid */}
            <div className="grid grid-cols-2 gap-4 text-xs font-mono">
              <div className="bg-slate-50 p-3.5 rounded-xl border border-slate-200">
                <span className="text-slate-700 text-[10px] block mb-1 font-bold">SUBMISSION TIME</span>
                <span className="text-slate-900 font-bold">{inspectingRecord.time}</span>
              </div>

              <div className="bg-slate-50 p-3.5 rounded-xl border border-slate-200">
                <span className="text-slate-700 text-[10px] block mb-1 font-bold">180° GYRO SWEEP ARC</span>
                <span className={inspectingRecord.sweepPassed ? "text-emerald-800 font-bold" : "text-rose-800 font-bold"}>
                  {inspectingRecord.sweepPassed ? `Δyaw = ${inspectingRecord.gyroSweepDelta}° (PASS)` : `Δyaw = ${inspectingRecord.gyroSweepDelta}° (INSUFFICIENT)`}
                </span>
              </div>

              <div className="bg-slate-50 p-3.5 rounded-xl border border-slate-200">
                <span className="text-slate-700 text-[10px] block mb-1 font-bold">1:1 ARCFACE COSINE</span>
                <span className="text-amber-900 font-extrabold text-sm">
                  {inspectingRecord.similarity ? `${inspectingRecord.similarity} (Threshold: 0.65)` : "No Biometric Crop"}
                </span>
              </div>

              <div className="bg-slate-50 p-3.5 rounded-xl border border-slate-200">
                <span className="text-slate-700 text-[10px] block mb-1 font-bold">ANTI-EMPTY-ROOM DEFENSE</span>
                <span className={inspectingRecord.yuNetPresence.includes("PASSED") ? "text-emerald-800 font-bold" : "text-rose-800 font-bold"}>
                  {inspectingRecord.yuNetPresence}
                </span>
              </div>
            </div>

            {inspectingRecord.note && (
              <div className="bg-amber-50 p-3.5 rounded-xl border border-amber-300 text-xs text-amber-950 font-mono">
                <span className="font-bold text-amber-900 block mb-0.5">DECISION NOTE:</span>
                {inspectingRecord.note}
              </div>
            )}

            {/* Instructor Action Decision Buttons */}
            <div className="pt-4 border-t border-slate-200 flex flex-wrap items-center justify-end gap-3">
              <button
                onClick={() => handleTeacherOverride("NOT_RECORDED")}
                className="px-4 py-2 rounded-xl text-xs font-mono font-bold bg-rose-100 text-rose-950 border border-rose-300 hover:bg-rose-200 transition-colors cursor-pointer"
              >
                Mark Absent
              </button>

              <button
                onClick={() => handleTeacherOverride("VERIFIED")}
                className="px-5 py-2 rounded-xl text-xs font-mono font-bold bg-emerald-600 text-white hover:bg-emerald-700 shadow-md transition-all cursor-pointer"
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
