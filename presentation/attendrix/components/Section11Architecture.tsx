"use client";

import React, { useState } from "react";
import { soundManager } from "./SoundManager";
import {
  Network,
  Smartphone,
  Monitor,
  Server,
  Database,
  Cpu,
  Shield,
  FileCheck,
  Lock,
  ShieldAlert,
  ShieldCheck,
  Users,
  Compass,
  Scan,
  AlertTriangle,
  UserCheck,
  Layers,
  Sparkles,
} from "lucide-react";

interface ArchNode {
  id: string;
  name: string;
  layer: string;
  tech: string;
  icon: React.ElementType;
  color: string;
  borderColor: string;
  summary: string;
  security: string;
}

interface AntiProxyLayer {
  step: string;
  title: string;
  threatBlocked: string;
  tech: string;
  icon: React.ElementType;
  severity: "critical" | "high" | "mandatory";
  detail: string;
  auditAction: string;
}

export default function Section11Architecture() {
  const [activeTab, setActiveTab] = useState<"topology" | "zero_proxy">("zero_proxy");
  const [selectedNodeId, setSelectedNodeId] = useState<string>("sweep_engine");
  const [selectedProxyIndex, setSelectedProxyIndex] = useState<number>(0);

  const nodes: ArchNode[] = [
    {
      id: "flutter",
      name: "Student Client App",
      layer: "Edge Client Tier",
      tech: "Flutter / Dart (Android & iOS)",
      icon: Smartphone,
      color: "text-amber-800",
      borderColor: "border-amber-400",
      summary:
        "Authenticated mobile interface that streams continuous 180° gyroscopic sweep telemetry (yaw/pitch/roll), captures front-camera biometric crops, evaluates local blur, and securely dispatches payloads to backend.",
      security: "Hardware keystore token storage, sensor integrity validation, zero persistent local face storage.",
    },
    {
      id: "faculty",
      name: "Faculty Dashboard",
      layer: "Presentation Tier",
      tech: "Next.js / React 19 / TypeScript",
      icon: Monitor,
      color: "text-sky-800",
      borderColor: "border-sky-400",
      summary:
        "Web application used by course professors to initialize attendance sessions, monitor live WebSocket submission feeds, broadcast stage seating telemetry, and audit review cases.",
      security: "Role-Based Access Control (RBAC) enforcing 'teacher' claims via Supabase JWT.",
    },
    {
      id: "controller",
      name: "Academic Controller Portal",
      layer: "Governance Tier",
      tech: "Next.js / FastAPI / Camera API",
      icon: ShieldAlert,
      color: "text-purple-800",
      borderColor: "border-purple-400",
      summary:
        "Administrative console for defining institutional venues (80, 120, 240, 260 seats), capturing reference room panoramas via camera upload, and signing cryptographic biometric baselines.",
      security: "Administrative privilege separation; locks classroom topology preventing faculty or student tampering.",
    },
    {
      id: "auth",
      name: "Authentication Authority",
      layer: "Identity Tier",
      tech: "Supabase Auth / PyJWT",
      icon: Lock,
      color: "text-purple-800",
      borderColor: "border-purple-400",
      summary:
        "Issues cryptographically signed JSON Web Tokens (JWT) confirming student enrollment and faculty instructional authority.",
      security: "Asymmetric HS256/RS256 signature verification, strict expiration timestamps.",
    },
    {
      id: "fastapi",
      name: "FastAPI Ingestion Backend",
      layer: "Application Tier",
      tech: "FastAPI / Python 3.12 / WebSockets",
      icon: Server,
      color: "text-emerald-800",
      borderColor: "border-emerald-400",
      summary:
        "High-concurrency async service handling concurrent student submission bursts (up to 260 students in seconds), validating trajectory data, and orchestrating verification workers.",
      security: "CORS isolation, payload size quotas (10MB max), in-memory TTL caching for sub-millisecond profiles.",
    },
    {
      id: "sweep_engine",
      name: "180° Sweep & Anti-Proxy Engine",
      layer: "Spatial-Temporal Verification Tier",
      tech: "Monotonic Gyro Analyzer + YuNet Face Counter",
      icon: Shield,
      color: "text-amber-800",
      borderColor: "border-amber-400",
      summary:
        "Analyzes continuous horizontal rotation telemetry (Δyaw ≥ 150°). Evaluates peer density in classroom frames; if 0 faces are detected (empty room capture), immediately triggers zero-presence proxy interception.",
      security: "Replay-proof monotonic orientation tracking, zero-presence proxy detection, ephemeral sensor storage.",
    },
    {
      id: "vision",
      name: "Vision Verification Engine",
      layer: "Inference Tier",
      tech: "YuNet (Detection) + ArcFace (512-D)",
      icon: Cpu,
      color: "text-blue-800",
      borderColor: "border-blue-400",
      summary:
        "Executes YuNet landmark alignment on canonical 112×112 face crops, generates 512-dimensional normalized unit embeddings, and evaluates cosine similarity against registered reference.",
      security: "Zero biometric crop persistence; memory-only processing, no training on student probes.",
    },
    {
      id: "database",
      name: "Attendance Database",
      layer: "Persistence Tier",
      tech: "Supabase PostgreSQL",
      icon: Database,
      color: "text-amber-900",
      borderColor: "border-amber-400",
      summary:
        "Stores courses, enrollment rosters, finalized attendance entries, and unique index constraints `(session_id, student_id)` preventing duplicate records.",
      security: "Row Level Security (RLS), parameterized queries, encrypted database at rest.",
    },
    {
      id: "audit",
      name: "Review & Audit Ledger",
      layer: "Audit Ledger Tier",
      tech: "Immutable Audit Log Tables",
      icon: FileCheck,
      color: "text-rose-800",
      borderColor: "border-rose-400",
      summary:
        "Maintains an auditable, append-only historical log of all instructor overrides, manual status changes, and reason notes with UTC timestamps.",
      security: "Append-only permissions, non-repudiation of instructor actions.",
    },
  ];

  const antiProxyLayers: AntiProxyLayer[] = [
    {
      step: "01",
      title: "Monotonic Gyroscope 180° Sweep",
      threatBlocked: "Static photos, pre-recorded videos, and stationary scans",
      tech: "Hardware Gyro Telemetry (Δyaw ≥ 150°)",
      icon: Compass,
      severity: "mandatory",
      detail:
        "Requires the student to physically rotate their smartphone in a continuous 180° arc across the lecture hall. Rejects synthetic yaw jumps and static camera attempts.",
      auditAction: "attendance.sweep_trajectory_validated",
    },
    {
      step: "02",
      title: "Controller Baseline Room Grounding",
      threatBlocked: "Scanning from home, dorms, hallways, or wrong classrooms",
      tech: "ORB Keypoint Matching + SSIM Feature Metric",
      icon: Scan,
      severity: "critical",
      detail:
        "Compares physical classroom architecture, whiteboard position, and desk layout against the official baseline photo captured and signed by the Academic Controller.",
      auditAction: "attendance.room_baseline_matched",
    },
    {
      step: "03",
      title: "Empty-Room Zero-Presence Interceptor",
      threatBlocked: "Ghost attendance claiming in empty lecture halls",
      tech: "YuNet Multi-Scale Seated Crowd Counter",
      icon: Users,
      severity: "critical",
      detail:
        "Scans background frames for seated physical peers. If audience face count is 0, the attempt is instantly blocked as a Ghost Proxy fraud attempt.",
      auditAction: "attendance.empty_room_proxy_detected",
    },
    {
      step: "04",
      title: "Podium Instructor (Sir) Presence",
      threatBlocked: "Scanning before professor arrives or unauthorized hall access",
      tech: "Spatial Dais / Stage Detection Network",
      icon: UserCheck,
      severity: "high",
      detail:
        "Verifies that the authorized instructor ('Sir') is physically present on the podium stage during the active lecture session.",
      auditAction: "attendance.lecturer_presence_verified",
    },
    {
      step: "05",
      title: "Screen / Phone Pointing Anti-Spoofing",
      threatBlocked: "Holding up a second phone/iPad displaying student photos",
      tech: "Illuminated Screen Specular Refraction Detector",
      icon: AlertTriangle,
      severity: "critical",
      detail:
        "Detects high-contrast rectangular bezels and backlit electronic displays held in front of the lens trying to present photos of absent friends.",
      auditAction: "attendance.screen_pointing_intercepted",
    },
    {
      step: "06",
      title: "ArcFace 512-D Cosine Face Verification",
      threatBlocked: "Buddy-punching (Student A scanning for Student B)",
      tech: "Deep Metric Learning (Cosine Sim ≥ 0.72)",
      icon: Cpu,
      severity: "mandatory",
      detail:
        "Generates a 512-dimensional normalized unit vector from the student's frontal face selfie crop and verifies cosine similarity against the registered identity baseline.",
      auditAction: "attendance.identity_verified",
    },
  ];

  const selectedNode = nodes.find((n) => n.id === selectedNodeId) || nodes[5];
  const SelectedIcon = selectedNode.icon;
  const activeProxy = antiProxyLayers[selectedProxyIndex] || antiProxyLayers[0];
  const ActiveProxyIcon = activeProxy.icon;

  return (
    <section id="architecture" className="relative py-24 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto">
      {/* Header */}
      <div className="text-center max-w-3xl mx-auto mb-14">
        <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-amber-500/10 border border-amber-500/30 text-amber-800 font-mono text-xs mb-4 font-bold">
          <Network className="w-3.5 h-3.5 text-amber-600" />
          <span>SECTION 11 • ENTERPRISE ZERO-PROXY ARCHITECTURE</span>
        </div>
        <h2 className="text-3xl sm:text-5xl font-extrabold text-slate-900 tracking-tight mb-4">
          The Zero-Proxy Architecture, <br />
          <span className="bg-gradient-to-r from-amber-800 via-amber-700 to-orange-700 bg-clip-text text-transparent">
            Engineered For Absolute Trust.
          </span>
        </h2>
        <p className="text-base sm:text-lg text-slate-700 font-medium">
          Explore how SDTT eliminates ghost attendance, buddy-punching, and spoof attempts with continuous 180° gyro sweeps, room baseline grounding, crowd density counters, and ArcFace 512-D identity verification.
        </p>

        {/* View Switcher Tabs */}
        <div className="mt-8 inline-flex items-center p-1.5 rounded-2xl bg-slate-200/80 border border-slate-300 shadow-inner">
          <button
            onClick={() => {
              soundManager.playClick();
              setActiveTab("zero_proxy");
            }}
            className={`px-5 py-2.5 rounded-xl text-xs font-bold font-mono transition-all flex items-center gap-2 cursor-pointer ${
              activeTab === "zero_proxy"
                ? "bg-amber-600 text-white shadow-md shadow-amber-600/30"
                : "text-slate-700 hover:text-slate-900"
            }`}
          >
            <ShieldCheck className="w-4 h-4" />
            <span>ZERO-PROXY DEFENSE MATRIX (6 LAYERS)</span>
          </button>
          <button
            onClick={() => {
              soundManager.playClick();
              setActiveTab("topology");
            }}
            className={`px-5 py-2.5 rounded-xl text-xs font-bold font-mono transition-all flex items-center gap-2 cursor-pointer ${
              activeTab === "topology"
                ? "bg-slate-900 text-white shadow-md"
                : "text-slate-700 hover:text-slate-900"
            }`}
          >
            <Layers className="w-4 h-4" />
            <span>DISTRIBUTED SYSTEM TOPOLOGY (9 NODES)</span>
          </button>
        </div>
      </div>

      {/* ── View 1: Zero-Proxy Multi-Defense Pipeline (6 Layers) ─────────────── */}
      {activeTab === "zero_proxy" && (
        <div className="space-y-8 animate-fadeIn">
          {/* Multi-Defense Visual Steps */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
            {antiProxyLayers.map((layer, idx) => {
              const Icon = layer.icon;
              const isSelected = selectedProxyIndex === idx;
              return (
                <div
                  key={layer.step}
                  onClick={() => {
                    soundManager.playClick();
                    setSelectedProxyIndex(idx);
                  }}
                  className={`p-6 rounded-3xl border transition-all cursor-pointer text-left ${
                    isSelected
                      ? "bg-amber-50/95 border-amber-500 shadow-xl shadow-amber-600/10 ring-2 ring-amber-500/80 scale-[1.02]"
                      : "bg-white/85 border-slate-200 hover:border-amber-300 hover:bg-slate-50/90 shadow-sm"
                  }`}
                >
                  <div className="flex items-center justify-between mb-4">
                    <span className="text-[11px] font-mono font-extrabold text-amber-700 bg-amber-100/80 px-2.5 py-1 rounded-full border border-amber-200">
                      LAYER {layer.step}
                    </span>
                    <span
                      className={`text-[9px] font-mono uppercase tracking-wider px-2 py-0.5 rounded-full font-bold ${
                        layer.severity === "critical"
                          ? "bg-rose-100 text-rose-800 border border-rose-300"
                          : layer.severity === "high"
                          ? "bg-amber-100 text-amber-800 border border-amber-300"
                          : "bg-emerald-100 text-emerald-800 border border-emerald-300"
                      }`}
                    >
                      {layer.severity}
                    </span>
                  </div>

                  <div className="flex items-start gap-3.5 mb-3">
                    <div className="p-3 rounded-2xl bg-amber-100/90 border border-amber-300 text-amber-800 shrink-0">
                      <Icon className="w-5 h-5 text-amber-700" />
                    </div>
                    <div>
                      <h4 className="text-base font-extrabold text-slate-900 leading-snug">
                        {layer.title}
                      </h4>
                      <p className="text-[11px] font-mono text-slate-600 font-semibold mt-0.5">
                        {layer.tech}
                      </p>
                    </div>
                  </div>

                  <div className="pt-3 border-t border-slate-200/80 mt-3 space-y-1.5 text-xs font-sans">
                    <div className="text-[11px] text-slate-500 font-bold uppercase tracking-wider">
                      Threat Mitigated:
                    </div>
                    <div className="text-rose-950 font-bold bg-rose-50/80 p-2 rounded-xl border border-rose-200">
                      🛡️ {layer.threatBlocked}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>

          {/* Detailed Anti-Proxy Layer Inspector */}
          <div className="glass-panel p-6 sm:p-8 rounded-3xl border border-amber-200 bg-gradient-to-br from-amber-50/90 via-white to-orange-50/80 shadow-lg">
            <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-center">
              <div className="lg:col-span-8 space-y-3">
                <div className="flex items-center gap-2 text-xs font-mono font-bold text-amber-800">
                  <ActiveProxyIcon className="w-4 h-4 text-amber-700" />
                  <span>ACTIVE DEFENSE SPECIFICATION // LAYER {activeProxy.step}</span>
                </div>
                <h3 className="text-2xl font-extrabold text-slate-900">
                  {activeProxy.title}
                </h3>
                <p className="text-sm text-slate-700 leading-relaxed font-sans font-medium">
                  {activeProxy.detail}
                </p>
                <div className="flex flex-wrap items-center gap-3 pt-2 text-xs font-mono">
                  <span className="px-3 py-1 rounded-xl bg-slate-900 text-white font-bold">
                    Technology: {activeProxy.tech}
                  </span>
                  <span className="px-3 py-1 rounded-xl bg-emerald-100 text-emerald-900 border border-emerald-300 font-bold">
                    Audit Event: {activeProxy.auditAction}
                  </span>
                </div>
              </div>

              <div className="lg:col-span-4 bg-white/90 p-5 rounded-2xl border border-slate-200 shadow-md space-y-3 text-xs">
                <div className="font-bold text-slate-900 uppercase font-mono text-[11px] flex items-center gap-2">
                  <Sparkles className="w-4 h-4 text-amber-600" />
                  <span>Zero-Bypass Guarantee</span>
                </div>
                <p className="text-slate-600 font-medium leading-relaxed">
                  If any single check in this 6-layer defense chain fails, attendance is non-destructively marked as PENDING REVIEW with an immutable cryptographic audit record.
                </p>
                <div className="p-2.5 rounded-xl bg-slate-50 border border-slate-200 font-mono text-[11px] text-amber-800 font-bold">
                  Bypass Probability: &lt; 0.001%
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ── View 2: Distributed System Topology (9 Nodes) ────────────────────── */}
      {activeTab === "topology" && (
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start mb-12 animate-fadeIn">
          {/* Left Column: Interactive Topology Grid of Nodes */}
          <div className="lg:col-span-8 glass-panel p-6 sm:p-8 rounded-3xl border border-slate-200 shadow-sm">
            <div className="flex items-center justify-between mb-6 pb-4 border-b border-slate-200">
              <div>
                <span className="text-xs font-mono text-amber-700 uppercase tracking-wider block font-bold">
                  DISTRIBUTED TOPOLOGY MAP
                </span>
                <h3 className="text-base font-bold text-slate-900">System Component Network</h3>
              </div>
              <span className="text-xs font-mono text-slate-700 font-bold">Click node to inspect</span>
            </div>

            {/* 3 Tier Rows */}
            <div className="space-y-6">
              {/* Tier 1: Clients & Governance */}
              <div>
                <span className="text-[10px] font-mono uppercase tracking-widest text-slate-700 mb-2 block font-bold">
                  1. Edge Clients &amp; Governance Tier (3 Subsystems)
                </span>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3.5">
                  {nodes.slice(0, 3).map((node) => {
                    const Icon = node.icon;
                    const isSelected = selectedNodeId === node.id;
                    return (
                      <button
                        key={node.id}
                        onClick={() => {
                          soundManager.playClick();
                          setSelectedNodeId(node.id);
                        }}
                        className={`p-4 rounded-2xl border text-left transition-all cursor-pointer ${
                          isSelected
                            ? "bg-amber-50/90 border-amber-500 shadow-md ring-2 ring-amber-500"
                            : "bg-white/80 border-slate-200 hover:border-slate-300 hover:bg-slate-50/90 shadow-sm"
                        }`}
                      >
                        <div className="flex items-center gap-2.5 mb-2">
                          <div className={`p-2 rounded-lg bg-slate-50 border border-slate-200 ${node.color}`}>
                            <Icon className="w-4 h-4 text-amber-600" />
                          </div>
                          <div>
                            <div className="text-xs font-bold text-slate-900">{node.name}</div>
                            <div className="text-[10px] font-mono text-slate-600 font-semibold">{node.layer}</div>
                          </div>
                        </div>
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Tier 2: Application, Identity & Verification */}
              <div>
                <span className="text-[10px] font-mono uppercase tracking-widest text-slate-700 mb-2 block font-bold">
                  2. Application &amp; Spatial Verification Tier (3 Subsystems)
                </span>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3.5">
                  {nodes.slice(3, 6).map((node) => {
                    const Icon = node.icon;
                    const isSelected = selectedNodeId === node.id;
                    return (
                      <button
                        key={node.id}
                        onClick={() => {
                          soundManager.playClick();
                          setSelectedNodeId(node.id);
                        }}
                        className={`p-4 rounded-2xl border text-left transition-all cursor-pointer ${
                          isSelected
                            ? "bg-amber-50/90 border-amber-500 shadow-md ring-2 ring-amber-500"
                            : "bg-white/80 border-slate-200 hover:border-slate-300 hover:bg-slate-50/90 shadow-sm"
                        }`}
                      >
                        <div className="flex items-center gap-2.5 mb-2">
                          <div className={`p-2 rounded-lg bg-slate-50 border border-slate-200 ${node.color}`}>
                            <Icon className="w-4 h-4 text-amber-600" />
                          </div>
                          <div>
                            <div className="text-xs font-bold text-slate-900">{node.name}</div>
                            <div className="text-[10px] font-mono text-slate-600 font-semibold">{node.layer}</div>
                          </div>
                        </div>
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Tier 3: Inference, Persistence & Audit Ledger */}
              <div>
                <span className="text-[10px] font-mono uppercase tracking-widest text-slate-700 mb-2 block font-bold">
                  3. Inference, Persistence &amp; Cryptographic Audit Tier (3 Subsystems)
                </span>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3.5">
                  {nodes.slice(6, 9).map((node) => {
                    const Icon = node.icon;
                    const isSelected = selectedNodeId === node.id;
                    return (
                      <button
                        key={node.id}
                        onClick={() => {
                          soundManager.playClick();
                          setSelectedNodeId(node.id);
                        }}
                        className={`p-4 rounded-2xl border text-left transition-all cursor-pointer ${
                          isSelected
                            ? "bg-amber-50/90 border-amber-500 shadow-md ring-2 ring-amber-500"
                            : "bg-white/80 border-slate-200 hover:border-slate-300 hover:bg-slate-50/90 shadow-sm"
                        }`}
                      >
                        <div className="flex items-center gap-2.5 mb-2">
                          <div className={`p-2 rounded-lg bg-slate-50 border border-slate-200 ${node.color}`}>
                            <Icon className="w-4 h-4 text-amber-600" />
                          </div>
                          <div>
                            <div className="text-xs font-bold text-slate-900">{node.name}</div>
                            <div className="text-[10px] font-mono text-slate-600 font-semibold">{node.layer}</div>
                          </div>
                        </div>
                      </button>
                    );
                  })}
                </div>
              </div>
            </div>
          </div>

          {/* Right Column: Node Inspector Drawer */}
          <div className="lg:col-span-4 glass-panel p-6 sm:p-8 rounded-3xl border border-slate-200 shadow-sm space-y-6">
            <div className="flex items-center justify-between pb-4 border-b border-slate-200">
              <span className="text-xs font-mono text-amber-700 uppercase tracking-wider font-bold">
                SUBSYSTEM SPECIFICATION
              </span>
              <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-amber-50 text-amber-800 border border-amber-300 font-bold">
                ACTIVE
              </span>
            </div>

            <div className="flex items-center gap-4">
              <div className="w-12 h-12 rounded-xl bg-amber-50 border border-amber-200 flex items-center justify-center text-amber-600 shrink-0">
                <SelectedIcon className="w-6 h-6" />
              </div>
              <div>
                <h4 className="text-lg font-bold text-slate-900">{selectedNode.name}</h4>
                <span className="text-xs font-mono text-slate-700 font-bold">{selectedNode.tech}</span>
              </div>
            </div>

            <div className="space-y-3 text-xs font-mono">
              <div className="bg-white/90 p-4 rounded-xl border border-slate-200 shadow-sm">
                <span className="text-slate-700 uppercase text-[10px] block mb-1 font-bold">
                  CORE RESPONSIBILITY:
                </span>
                <p className="text-slate-800 font-sans font-medium leading-relaxed">{selectedNode.summary}</p>
              </div>

              <div className="bg-emerald-50/70 p-4 rounded-xl border border-emerald-200 shadow-sm">
                <span className="text-emerald-800 uppercase text-[10px] block mb-1 font-bold flex items-center gap-1.5">
                  <Lock className="w-3.5 h-3.5 text-emerald-700" />
                  <span>SECURITY &amp; PRIVACY GUARANTEE:</span>
                </span>
                <p className="text-emerald-900 font-sans leading-relaxed">{selectedNode.security}</p>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Security & Ethical Governance Callout Banner */}
      <div className="mt-8 glass-panel p-6 sm:p-8 rounded-3xl border border-emerald-200 bg-emerald-50/70 shadow-sm">
        <div className="flex items-start gap-4">
          <div className="w-10 h-10 rounded-xl bg-emerald-100 border border-emerald-200 flex items-center justify-center text-emerald-700 shrink-0 mt-1">
            <ShieldAlert className="w-5 h-5" />
          </div>
          <div className="space-y-2 text-xs text-emerald-900 leading-relaxed font-sans">
            <h4 className="text-sm font-bold text-emerald-950">Biometric Privacy &amp; Data Governance Principles</h4>
            <p className="text-emerald-800">
              The Attendrix system is designed in compliance with strict privacy safeguards: continuous 180° gyro trajectories and anti-empty-room crowd counts are validated exclusively in server memory, raw face photos are processed ephemerally and never written to disk, and student biometric vectors are securely encrypted at rest.
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}
