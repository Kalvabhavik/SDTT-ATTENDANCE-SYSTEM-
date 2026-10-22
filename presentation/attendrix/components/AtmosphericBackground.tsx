"use client";

import React, { useEffect, useRef, useState } from "react";
import Image from "next/image";

export default function AtmosphericBackground() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const spotlightRef = useRef<HTMLDivElement>(null);
  const [scrollRatio, setScrollRatio] = useState<number>(0);

  // Monitor scroll progress for real-time background view shifting
  useEffect(() => {
    const handleScroll = () => {
      const maxScroll = document.documentElement.scrollHeight - window.innerHeight;
      if (maxScroll > 0) {
        const ratio = Math.min(1, Math.max(0, window.scrollY / maxScroll));
        setScrollRatio(ratio);
      }
    };

    window.addEventListener("scroll", handleScroll, { passive: true });
    handleScroll();
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  // Interactive warm solar spotlight following mouse cursor
  useEffect(() => {
    const handleMouseMove = (e: MouseEvent) => {
      if (!spotlightRef.current) return;
      spotlightRef.current.style.transform = `translate(${e.clientX - 320}px, ${e.clientY - 320}px)`;
    };
    window.addEventListener("mousemove", handleMouseMove, { passive: true });
    return () => window.removeEventListener("mousemove", handleMouseMove);
  }, []);

  // Ambient classroom sun dust motes drifting through daylight rays
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    let animationFrameId: number;
    let width = (canvas.width = window.innerWidth);
    let height = (canvas.height = window.innerHeight);

    const handleResize = () => {
      if (!canvas) return;
      width = canvas.width = window.innerWidth;
      height = canvas.height = window.innerHeight;
    };
    window.addEventListener("resize", handleResize);

    const particleCount = 45;
    const particles = Array.from({ length: particleCount }).map(() => ({
      x: Math.random() * width,
      y: Math.random() * height,
      size: Math.random() * 2.2 + 0.6,
      speedX: (Math.random() - 0.5) * 0.35,
      speedY: -Math.random() * 0.4 - 0.1,
      opacity: Math.random() * 0.5 + 0.2,
      color: Math.random() > 0.4 ? "#d97706" : "#f59e0b",
    }));

    const render = () => {
      ctx.clearRect(0, 0, width, height);

      particles.forEach((p) => {
        p.x += p.speedX;
        p.y += p.speedY;

        if (p.y < -10) {
          p.y = height + 10;
          p.x = Math.random() * width;
        }
        if (p.x < -10) p.x = width + 10;
        else if (p.x > width + 10) p.x = -10;

        ctx.fillStyle = p.color;
        ctx.globalAlpha = p.opacity;
        ctx.shadowBlur = 6;
        ctx.shadowColor = p.color;
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
        ctx.fill();
      });

      animationFrameId = requestAnimationFrame(render);
    };

    render();

    return () => {
      window.removeEventListener("resize", handleResize);
      cancelAnimationFrame(animationFrameId);
    };
  }, []);

  // Calculate smooth crossfade opacities for the 3 real classroom photo views
  // View 1 (Stage looking up): 0.0 -> 0.35
  // View 2 (Desk rows looking forward): 0.30 -> 0.70
  // View 3 (Balcony high amphitheater): 0.65 -> 1.00
  let opacityStage = 0;
  let opacityDesk = 0;
  let opacityBalcony = 0;
  let currentCamLabel = "CAM 01 // FRONT STAGE PODIUM";

  if (scrollRatio <= 0.35) {
    opacityStage = 1;
    opacityDesk = 0;
    opacityBalcony = 0;
    currentCamLabel = "CAM 01 // FRONT STAGE PODIUM";
  } else if (scrollRatio <= 0.50) {
    const factor = (scrollRatio - 0.35) / 0.15;
    opacityStage = 1 - factor;
    opacityDesk = factor;
    opacityBalcony = 0;
    currentCamLabel = factor > 0.5 ? "CAM 02 // MID-TIER STUDENT DESKS" : "CAM 01 // FRONT STAGE PODIUM";
  } else if (scrollRatio <= 0.68) {
    opacityStage = 0;
    opacityDesk = 1;
    opacityBalcony = 0;
    currentCamLabel = "CAM 02 // MID-TIER STUDENT DESKS";
  } else if (scrollRatio <= 0.82) {
    const factor = (scrollRatio - 0.68) / 0.14;
    opacityStage = 0;
    opacityDesk = 1 - factor;
    opacityBalcony = factor;
    currentCamLabel = factor > 0.5 ? "CAM 03 // HIGH BALCONY AMPHITHEATER" : "CAM 02 // MID-TIER STUDENT DESKS";
  } else {
    opacityStage = 0;
    opacityDesk = 0;
    opacityBalcony = 1;
    currentCamLabel = "CAM 03 // HIGH BALCONY AMPHITHEATER";
  }

  const parallaxTransform = `scale(${1.04 + scrollRatio * 0.05}) translateY(${-scrollRatio * 35}px)`;

  return (
    <div className="fixed inset-0 pointer-events-none z-0 overflow-hidden select-none">
      {/* Real Classroom Photo Layers with View Shifting & Parallax */}
      <div
        className="absolute inset-0 transition-transform duration-700 ease-out"
        style={{ transform: parallaxTransform }}
      >
        {/* View 1: Real Photo Stage Looking Up */}
        <div
          className="absolute inset-0 transition-opacity duration-500 ease-out"
          style={{ opacity: opacityStage }}
        >
          <Image
            src="/images/classroom_stage_daylight.jpg"
            alt="Real University Lecture Hall - Stage View"
            fill
            priority
            sizes="100vw"
            className="object-cover object-center filter contrast-[1.04] brightness-[1.01]"
          />
        </div>

        {/* View 2: Real Photo Student Desk Rows */}
        <div
          className="absolute inset-0 transition-opacity duration-500 ease-out"
          style={{ opacity: opacityDesk }}
        >
          <Image
            src="/images/classroom_desk_daylight.jpg"
            alt="Real University Lecture Hall - Student Desks"
            fill
            sizes="100vw"
            className="object-cover object-center filter contrast-[1.04] brightness-[1.01]"
          />
        </div>

        {/* View 3: Real Photo High Balcony Amphitheater */}
        <div
          className="absolute inset-0 transition-opacity duration-500 ease-out"
          style={{ opacity: opacityBalcony }}
        >
          <Image
            src="/images/classroom_balcony_daylight.jpg"
            alt="Real University Lecture Hall - Balcony View"
            fill
            sizes="100vw"
            className="object-cover object-center filter contrast-[1.04] brightness-[1.01]"
          />
        </div>
      </div>

      {/* Light Mode Soft Luminous Veil - lets real classroom photo show through with natural daylight */}
      <div className="absolute inset-0 bg-white/40 backdrop-blur-[0.5px]" />

      {/* Subtle Warm Daylight Sunbeam Tint */}
      <div className="absolute inset-0 bg-gradient-to-tr from-white/25 via-amber-50/15 to-white/20 pointer-events-none" />

      {/* Interactive Daylight Solar Spotlight */}
      <div
        ref={spotlightRef}
        className="hidden md:block absolute top-0 left-0 w-[640px] h-[640px] rounded-full pointer-events-none transition-transform duration-75 ease-out opacity-25 blur-3xl"
        style={{
          background: "radial-gradient(circle, rgba(217, 119, 6, 0.2) 0%, rgba(180, 83, 9, 0.06) 50%, transparent 70%)",
        }}
      />

      {/* Architectural Blueprint Grid Overlay (Light Mode) */}
      <div className="absolute inset-0 bg-classroom-blueprint opacity-15 pointer-events-none" />

      {/* Floating Sun Dust Motes in Classroom Daylight */}
      <canvas ref={canvasRef} className="absolute inset-0 w-full h-full opacity-60 pointer-events-none" />

      {/* Live Vantage Shift Telemetry HUD */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-2 absolute top-20 inset-x-4 sm:inset-x-8 text-[9px] font-mono uppercase tracking-widest z-20">
        <div className="flex items-center gap-2 px-3.5 py-2 rounded-full bg-white/95 backdrop-blur-md border border-slate-300 shadow-md text-slate-800 pointer-events-auto">
          <span className="w-2.5 h-2.5 bg-amber-600 rounded-full animate-ping shrink-0" />
          <span className="font-bold text-amber-800 hidden sm:inline">VIEW:</span>
          <span className="font-bold text-slate-900 text-[10px]">{currentCamLabel}</span>
          <div className="ml-1 flex items-center gap-1 border-l border-slate-300 pl-2">
            <button
              onClick={() => window.scrollTo({ top: 0, behavior: "smooth" })}
              className={`px-2.5 py-1 rounded text-[9px] font-bold transition-all cursor-pointer ${
                scrollRatio <= 0.35 ? "bg-amber-600 text-white shadow-sm" : "bg-slate-100 text-slate-700 hover:bg-slate-200 border border-slate-200"
              }`}
            >
              STAGE
            </button>
            <button
              onClick={() => {
                const el = document.getElementById("workflow");
                if (el) el.scrollIntoView({ behavior: "smooth" });
              }}
              className={`px-2.5 py-1 rounded text-[9px] font-bold transition-all cursor-pointer ${
                scrollRatio > 0.35 && scrollRatio <= 0.75 ? "bg-amber-600 text-white shadow-sm" : "bg-slate-100 text-slate-700 hover:bg-slate-200 border border-slate-200"
              }`}
            >
              DESKS
            </button>
            <button
              onClick={() => {
                const el = document.getElementById("scale");
                if (el) el.scrollIntoView({ behavior: "smooth" });
              }}
              className={`px-2.5 py-1 rounded text-[9px] font-bold transition-all cursor-pointer ${
                scrollRatio > 0.75 ? "bg-amber-600 text-white shadow-sm" : "bg-slate-100 text-slate-700 hover:bg-slate-200 border border-slate-200"
              }`}
            >
              BALCONY
            </button>
          </div>
        </div>

        <div className="hidden lg:flex items-center gap-4 px-4 py-2 rounded-full bg-white/95 backdrop-blur-md border border-slate-300 shadow-md text-slate-700 font-semibold">
          <span>OPTICAL DEPTH: 24.0M</span>
          <span>SCROLL PROGRESS: {Math.round(scrollRatio * 100)}%</span>
          <span className="text-amber-800 font-bold">LIGHT ARCHITECTURAL MODE</span>
        </div>
      </div>

      <div className="hidden lg:flex justify-between items-end absolute bottom-8 inset-x-8 text-[9px] font-mono text-slate-500 uppercase tracking-widest pointer-events-none z-10">
        <div className="px-3 py-1 rounded bg-white/85 backdrop-blur-sm border border-slate-200 shadow-sm">
          SDTT CLASSROOM VERIFICATION SYSTEM // REAL ARCHITECTURAL PHOTO ENVIRONMENT
        </div>
        <div className="px-3 py-1 rounded bg-white/85 backdrop-blur-sm border border-slate-200 shadow-sm">
          TIERED AMPHITHEATER // NATURAL DAYLIGHT ILLUMINANCE: 850 LUX
        </div>
      </div>
    </div>
  );
}
