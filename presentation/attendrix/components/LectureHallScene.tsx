"use client";

import React, { useState, useEffect, useRef, useMemo } from "react";
import Image from "next/image";
import {
  ShieldCheck,
  Activity,
  Layers,
  Compass,
  AlertTriangle,
} from "lucide-react";

interface SceneItem {
  id: string;
  name: string;
  badge: string;
  badgeColor: string;
  image: string;
  headline: string;
  subline: string;
  sections: string[];
  hudTelemetry: {
    status: string;
    peersDetected: string;
    antiProxyLevel: string;
    angleSweep: string;
  };
  highlightBoxes: Array<{
    id: string;
    label: string;
    top: string;
    left: string;
    width: string;
    height: string;
    status: "verified" | "threat" | "sensor";
  }>;
}

const SCENES: SceneItem[] = [
  {
    id: "overview",
    name: "Lecture Theater Main Stage",
    badge: "STAGE 01 • OVERVIEW",
    badgeColor: "bg-amber-100 text-amber-900 border-amber-300",
    image: "/images/stage_hero.jpg",
    headline: "260-Seat Tiered Auditorium",
    subline: "Continuous lecture dais & stadium tiered rows with natural daylight illumination.",
    sections: ["section-01"],
    hudTelemetry: {
      status: "STATIONARY MONITORING",
      peersDetected: "148 / 160 Present",
      antiProxyLevel: "Zero-Proxy Baseline Active",
      angleSweep: "0.0° Reference Point",
    },
    highlightBoxes: [
      {
        id: "podium",
        label: "LECTURER DAIS // SIR PRESENT",
        top: "54%",
        left: "11%",
        width: "16%",
        height: "28%",
        status: "verified",
      },
      {
        id: "tier_front",
        label: "TIER A // 80 SEATER FRONT",
        top: "60%",
        left: "42%",
        width: "36%",
        height: "32%",
        status: "verified",
      },
    ],
  },
  {
    id: "empty_room_proxy",
    name: "Anti-Proxy Scanner Interception",
    badge: "STAGE 02 • ANTI-PROXY THREAT DEFENSE",
    badgeColor: "bg-rose-100 text-rose-900 border-rose-300",
    image: "/images/anti_proxy_hall.jpg",
    headline: "Zero-Presence Ghost Proxy Intercepted",
    subline: "YuNet crowd face evaluator flags empty room captures (0 physical peers present).",
    sections: ["section-02", "section-03"],
    hudTelemetry: {
      status: "INTERCEPTED PROXY THREAT",
      peersDetected: "0 Peers (Vacant Desks)",
      antiProxyLevel: "EMPTY_ROOM_PROXY_DETECTED",
      angleSweep: "Δyaw: 12.4° (ABORTED)",
    },
    highlightBoxes: [
      {
        id: "empty_warning",
        label: "EMPTY SEAT SPOOF // 0 PEERS DETECTED",
        top: "40%",
        left: "32%",
        width: "38%",
        height: "36%",
        status: "threat",
      },
      {
        id: "podium_empty",
        label: "DAIS VACANT // NO INSTRUCTOR DETECTED",
        top: "32%",
        left: "74%",
        width: "18%",
        height: "22%",
        status: "threat",
      },
    ],
  },
  {
    id: "sweep_verification",
    name: "180° Monotonic Gyro Sweep",
    badge: "STAGE 03 • PHYSICAL VERIFICATION",
    badgeColor: "bg-sky-100 text-sky-900 border-sky-300",
    image: "/images/sweep_pov.jpg",
    headline: "Continuous Gyroscope & Peer Triangulation",
    subline: "Students sweep 180° horizontally to ground physical co-presence with peers & lecturer.",
    sections: ["section-04", "section-05"],
    hudTelemetry: {
      status: "CONTINUOUS SWEEP ACTIVE",
      peersDetected: "24 Peer Landmarks Mapped",
      antiProxyLevel: "Screen Pointing Defenses OK",
      angleSweep: "172.6° / 180° Completed",
    },
    highlightBoxes: [
      {
        id: "phone_sensor",
        label: "STUDENT POV // AR GYRO TELEMETRY",
        top: "38%",
        left: "40%",
        width: "34%",
        height: "30%",
        status: "sensor",
      },
      {
        id: "peer_group",
        label: "CO-PRESENT PEER CROWD // CONFIRMED",
        top: "28%",
        left: "8%",
        width: "28%",
        height: "36%",
        status: "verified",
      },
    ],
  },
  {
    id: "cohort_balcony",
    name: "Multi-Tier Venue Scale",
    badge: "STAGE 04 • VENUE CLASSIFICATION",
    badgeColor: "bg-purple-100 text-purple-900 border-purple-300",
    image: "/images/classroom_balcony_daylight.jpg",
    headline: "80 / 120 / 240 / 260 Seater & Labs",
    subline: "Architectural classification verifies that classroom layout matches scheduled timetable tier.",
    sections: ["section-06", "section-07", "section-08"],
    hudTelemetry: {
      status: "TIER MAPPING VERIFIED",
      peersDetected: "Zone A: 76 | Zone B: 62 | Zone C: 102",
      antiProxyLevel: "Venue Reference Grounded",
      angleSweep: "180.0° Panoramic Coverage",
    },
    highlightBoxes: [
      {
        id: "balcony_tier",
        label: "UPPER BALCONY // ZONE C (102 SEATS)",
        top: "22%",
        left: "24%",
        width: "52%",
        height: "30%",
        status: "verified",
      },
    ],
  },
  {
    id: "biometric_decision",
    name: "ArcFace 512-D Grounding",
    badge: "STAGE 05 • INFERENCE PIPELINE",
    badgeColor: "bg-emerald-100 text-emerald-900 border-emerald-300",
    image: "/images/classroom_desk_daylight.jpg",
    headline: "Biometric Feature Decision",
    subline: "Cosine similarity computed against controller-enrolled vector with cryptographic audit.",
    sections: ["section-09"],
    hudTelemetry: {
      status: "DECISION COMMITTED",
      peersDetected: "Self Cosine Match: 0.941",
      antiProxyLevel: "Zero Buddy-Punching Confirmed",
      angleSweep: "Deterministic Timestamp Logged",
    },
    highlightBoxes: [
      {
        id: "desk_decision",
        label: "ARCFACE 512-D EMBEDDING // MATCH: 94.1%",
        top: "42%",
        left: "30%",
        width: "40%",
        height: "38%",
        status: "verified",
      },
    ],
  },
  {
    id: "control_hub",
    name: "Live Academic Control Center",
    badge: "STAGE 06 • GOVERNANCE DASHBOARD",
    badgeColor: "bg-amber-100 text-amber-900 border-amber-300",
    image: "/images/control_hub.jpg",
    headline: "Faculty & Controller Telemetry",
    subline: "Real-time WebSocket event feed, live classroom heatmaps, and immutable audit logs.",
    sections: ["section-10", "section-11", "section-12", "section-13"],
    hudTelemetry: {
      status: "GOVERNANCE CONSOLE ACTIVE",
      peersDetected: "3 Sessions Active Campus-Wide",
      antiProxyLevel: "Zero-Bypass Architecture Validated",
      angleSweep: "100% Cryptographic Ledger Sync",
    },
    highlightBoxes: [
      {
        id: "monitor_heatmap",
        label: "LIVE SEATING HEATMAP // REAL-TIME HUD",
        top: "34%",
        left: "25%",
        width: "24%",
        height: "35%",
        status: "sensor",
      },
      {
        id: "audit_ledger",
        label: "IMMUTABLE AUDIT FEED // ZERO PROXIES",
        top: "36%",
        left: "3%",
        width: "22%",
        height: "38%",
        status: "verified",
      },
    ],
  },
];

interface LectureHallSceneProps {
  scrollProgress: number;
  activeSection: string;
  isReducedMotion?: boolean;
  selectedCohort?: 80 | 120 | 240 | 260;
  activeZone?: "all" | "zoneA" | "zoneB" | "zoneC";
}

export default function LectureHallScene({
  scrollProgress,
  activeSection,
  isReducedMotion = false,
  selectedCohort = 260,
  activeZone = "all",
}: LectureHallSceneProps) {
  const containerRef = useRef<HTMLDivElement>(null);

  // Mouse parallax interaction coordinates
  const [mousePos, setMousePos] = useState<{ x: number; y: number }>({ x: 0, y: 0 });
  const [fps, setFps] = useState<number>(60);
  const [showHud, setShowHud] = useState<boolean>(true);

  // Smooth frame calculation for 2.5D visual feel
  useEffect(() => {
    let frameCount = 0;
    let lastTime = performance.now();
    let animId: number;

    const measureFps = () => {
      frameCount++;
      const now = performance.now();
      if (now - lastTime >= 1000) {
        setFps(Math.min(120, Math.round((frameCount * 1000) / (now - lastTime))));
        frameCount = 0;
        lastTime = now;
      }
      animId = requestAnimationFrame(measureFps);
    };

    animId = requestAnimationFrame(measureFps);
    return () => cancelAnimationFrame(animId);
  }, []);

  // Track mouse position for subtle 2.5D perspective tilt
  useEffect(() => {
    if (isReducedMotion) return;

    const handleMouseMove = (e: MouseEvent) => {
      const { innerWidth, innerHeight } = window;
      const x = (e.clientX / innerWidth - 0.5) * 2; // -1 to 1
      const y = (e.clientY / innerHeight - 0.5) * 2; // -1 to 1
      setMousePos({ x, y });
    };

    window.addEventListener("mousemove", handleMouseMove, { passive: true });
    return () => window.removeEventListener("mousemove", handleMouseMove);
  }, [isReducedMotion]);

  // Determine active scene based on activeSection or scrollProgress fallback
  const activeSceneIndex = useMemo(() => {
    const idx = SCENES.findIndex((s) => s.sections.includes(activeSection));
    if (idx !== -1) return idx;

    // Fallback via scrollProgress
    if (scrollProgress < 0.15) return 0; // Overview
    if (scrollProgress < 0.35) return 1; // Empty Room Proxy
    if (scrollProgress < 0.55) return 2; // 180 Sweep POV
    if (scrollProgress < 0.72) return 3; // Cohort Balcony
    if (scrollProgress < 0.85) return 4; // Biometric Decision
    return 5; // Control Hub
  }, [activeSection, scrollProgress]);

  const activeScene = SCENES[activeSceneIndex] || SCENES[0];

  // Dynamic 2.5D perspective transformation parameters
  const perspectiveTransform = useMemo(() => {
    if (isReducedMotion) {
      return {
        transform: "scale(1.02)",
        transition: "transform 0.6s cubic-bezier(0.16, 1, 0.3, 1)",
      };
    }

    // Scroll-driven subtle camera trajectory
    const scrollTilt = (scrollProgress - 0.5) * 6; // -3deg to +3deg
    const mouseRotY = mousePos.x * 3.5; // -3.5deg to +3.5deg
    const mouseRotX = -mousePos.y * 3.0; // -3deg to +3deg
    const scale = 1.04 + Math.sin(scrollProgress * Math.PI) * 0.04; // subtle pulse
    const translateZ = Math.round(mousePos.y * -15); // -15px to +15px depth push

    return {
      transform: `perspective(1200px) rotateX(${mouseRotX + scrollTilt}deg) rotateY(${mouseRotY}deg) scale(${scale}) translateZ(${translateZ}px)`,
      transition: "transform 0.18s cubic-bezier(0.2, 0, 0.3, 1)",
    };
  }, [scrollProgress, mousePos, isReducedMotion]);

  // Compute dynamic sweep angle for HUD radar
  const sweepDegree = useMemo(() => {
    if (activeSceneIndex === 0) return 0;
    if (activeSceneIndex === 1) return 12;
    if (activeSceneIndex === 2) return Math.min(180, Math.round(scrollProgress * 220));
    return 180;
  }, [activeSceneIndex, scrollProgress]);

  return (
    <div
      ref={containerRef}
      className="relative w-full h-full overflow-hidden bg-slate-950 select-none pointer-events-none"
      style={{ perspective: "1400px" }}
    >
      {/* ── 1. Layer: Dynamic 2.5D Image Changing Scenes ─────────────────────── */}
      <div
        className="absolute inset-0 w-full h-full origin-center"
        style={perspectiveTransform}
      >
        {SCENES.map((scene, idx) => {
          const isActive = idx === activeSceneIndex;
          const isAdjacent = Math.abs(idx - activeSceneIndex) === 1;

          // Optimization: Only render active and adjacent scenes
          if (!isActive && !isAdjacent) return null;

          return (
            <div
              key={scene.id}
              className={`absolute inset-0 w-full h-full transition-all duration-1000 ease-out ${
                isActive
                  ? "opacity-100 scale-100 z-10"
                  : "opacity-0 scale-105 pointer-events-none z-0"
              }`}
            >
              <Image
                src={scene.image}
                alt={scene.name}
                fill
                priority={idx === 0 || idx === 1}
                sizes="100vw"
                className="object-cover object-center filter saturate-[1.08] contrast-[1.04]"
              />

              {/* Atmospheric lighting gradient overlay for high cinematic depth */}
              <div className="absolute inset-0 bg-gradient-to-t from-slate-950/85 via-slate-950/30 to-slate-950/40" />
              <div className="absolute inset-0 bg-radial-vignette opacity-60" />

              {/* 2.5D Scanning Laser Crosshairs for Active Scene */}
              {isActive && (
                <div className="absolute inset-0 pointer-events-none">
                  {/* Subtle Scanning Horizontal Ray */}
                  <div
                    className="absolute left-0 right-0 h-0.5 bg-gradient-to-r from-transparent via-amber-400/70 to-transparent shadow-[0_0_12px_rgba(245,158,11,0.8)]"
                    style={{
                      top: `${Math.round(30 + Math.sin(scrollProgress * 8) * 35)}%`,
                      transition: "top 0.3s ease-out",
                    }}
                  />

                  {/* Highlight AR Diagnostic Bounding Boxes */}
                  {scene.highlightBoxes.map((box) => (
                    <div
                      key={box.id}
                      className={`absolute rounded-xl border-2 transition-all duration-700 animate-pulse ${
                        box.status === "verified"
                          ? "border-emerald-400 bg-emerald-500/10 shadow-[0_0_18px_rgba(16,185,129,0.25)]"
                          : box.status === "threat"
                          ? "border-rose-500 bg-rose-500/15 shadow-[0_0_24px_rgba(244,63,94,0.35)]"
                          : "border-cyan-400 bg-cyan-500/10 shadow-[0_0_18px_rgba(6,182,212,0.25)]"
                      }`}
                      style={{
                        top: box.top,
                        left: box.left,
                        width: box.width,
                        height: box.height,
                      }}
                    >
                      {/* Box corner brackets */}
                      <span className="absolute -top-1 -left-1 w-2.5 h-2.5 border-t-2 border-l-2 border-white" />
                      <span className="absolute -top-1 -right-1 w-2.5 h-2.5 border-t-2 border-r-2 border-white" />
                      <span className="absolute -bottom-1 -left-1 w-2.5 h-2.5 border-b-2 border-l-2 border-white" />
                      <span className="absolute -bottom-1 -right-1 w-2.5 h-2.5 border-b-2 border-r-2 border-white" />

                      {/* Diagnostic HUD label */}
                      <div
                        className={`absolute -top-7 left-2 px-2 py-0.5 rounded text-[10px] font-mono font-bold tracking-wider backdrop-blur-md shadow-sm border ${
                          box.status === "verified"
                            ? "bg-emerald-950/90 text-emerald-300 border-emerald-500/50"
                            : box.status === "threat"
                            ? "bg-rose-950/90 text-rose-300 border-rose-500/50 animate-bounce"
                            : "bg-cyan-950/90 text-cyan-300 border-cyan-500/50"
                        }`}
                      >
                        {box.label}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          );
        })}
      </div>

      {/* ── 2. Layer: Futuristic Perspective Floor Grid & Lighting ──────────── */}
      <div
        className="absolute inset-0 pointer-events-none opacity-20"
        style={{
          backgroundImage:
            "linear-gradient(to right, rgba(217,119,6,0.18) 1px, transparent 1px), linear-gradient(to bottom, rgba(217,119,6,0.18) 1px, transparent 1px)",
          backgroundSize: "64px 64px",
          transform: "perspective(800px) rotateX(65deg) translateY(240px)",
          transformOrigin: "bottom center",
        }}
      />

      {/* ── 3. Layer: High-End Diagnostic HUD Header Bar ─────────────────────── */}
      {showHud && (
        <div className="absolute top-20 left-4 right-4 sm:left-8 sm:right-8 flex flex-wrap items-center justify-between gap-3 pointer-events-auto z-20">
          {/* Active 2.5D Stage Badge */}
          <div className="flex items-center gap-2.5 bg-slate-900/85 backdrop-blur-xl border border-slate-700/80 rounded-2xl px-4 py-2 shadow-2xl text-xs font-mono">
            <span className="relative flex h-2.5 w-2.5">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-amber-400 opacity-75" />
              <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-amber-500" />
            </span>
            <span className="font-bold text-white tracking-wide">
              2.5D SCENE: {activeScene.name.toUpperCase()}
            </span>
            <span className="hidden sm:inline text-slate-500 font-light">•</span>
            <span className="hidden sm:inline text-amber-300 font-semibold">
              {activeScene.badge}
            </span>
          </div>

          {/* Radar Telemetry & Anti-Proxy Security HUD */}
          <div className="flex items-center gap-3 bg-slate-900/85 backdrop-blur-xl border border-slate-700/80 rounded-2xl px-4 py-2 shadow-2xl text-xs font-mono">
            {/* 180° Sweep Arc Gauge */}
            <div className="flex items-center gap-1.5 text-sky-400">
              <Compass className="w-3.5 h-3.5 animate-spin" style={{ animationDuration: "12s" }} />
              <span className="font-bold">{sweepDegree}° / 180° SWEEP</span>
            </div>

            <span className="text-slate-600">|</span>

            {/* Anti-Proxy Status Pill */}
            <div
              className={`flex items-center gap-1.5 font-bold ${
                activeSceneIndex === 1 ? "text-rose-400" : "text-emerald-400"
              }`}
            >
              {activeSceneIndex === 1 ? (
                <>
                  <AlertTriangle className="w-3.5 h-3.5 text-rose-400 animate-bounce" />
                  <span>ANTI-PROXY FLAG</span>
                </>
              ) : (
                <>
                  <ShieldCheck className="w-3.5 h-3.5 text-emerald-400" />
                  <span>ZERO-PROXY ACTIVE</span>
                </>
              )}
            </div>

            <span className="hidden md:inline text-slate-600">|</span>

            {/* Frame Rate Indicator */}
            <div className="hidden md:flex items-center gap-1 text-slate-400 font-bold">
              <Activity className="w-3.5 h-3.5 text-amber-500" />
              <span>{fps} FPS</span>
            </div>
          </div>
        </div>
      )}

      {/* ── 4. Layer: Bottom Right Stage Info & Cohort Telemetry ─────────────── */}
      <div className="absolute bottom-6 right-6 hidden lg:flex flex-col items-end gap-2 pointer-events-auto z-20">
        <div className="bg-slate-900/90 backdrop-blur-xl border border-slate-800 rounded-2xl p-4 shadow-2xl max-w-sm text-right space-y-1.5">
          <div className="text-[10px] font-mono text-amber-400 font-bold uppercase tracking-wider">
            {activeScene.headline}
          </div>
          <div className="text-xs text-slate-300 font-sans leading-relaxed">
            {activeScene.subline}
          </div>
          <div className="pt-2 border-t border-slate-800/80 flex items-center justify-between text-[11px] font-mono text-slate-400">
            <span className="text-amber-500 font-bold">COHORT {selectedCohort} SEATS</span>
            <span>ZONE: {activeZone.toUpperCase()}</span>
          </div>
        </div>

        {/* HUD Toggle Pill */}
        <button
          onClick={() => setShowHud(!showHud)}
          className="px-3 py-1 rounded-xl bg-slate-900/70 hover:bg-slate-800/80 border border-slate-700/60 text-slate-400 hover:text-white text-[10px] font-mono flex items-center gap-1.5 transition-all shadow-md cursor-pointer"
        >
          <Layers className="w-3 h-3 text-amber-400" />
          <span>{showHud ? "Hide HUD Overlays" : "Show HUD Overlays"}</span>
        </button>
      </div>
    </div>
  );
}
