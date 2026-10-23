"use client";

import React, { useState, useEffect } from "react";
import dynamic from "next/dynamic";
import SmoothScrollProvider, { useSmoothScroll } from "@/components/SmoothScrollProvider";
import AtmosphericBackground from "@/components/AtmosphericBackground";
import GsapScrollEffects from "@/components/GsapScrollEffects";
import Navbar from "@/components/Navbar";
import Section01Opening from "@/components/Section01Opening";
import Section02Problem from "@/components/Section02Problem";
import Section03Concept from "@/components/Section03Concept";
import Section04Workflow from "@/components/Section04Workflow";
import Section05StudentVerification from "@/components/Section05StudentVerification";
import Section06Cohort80 from "@/components/Section06Cohort80";
import Section07Cohort120 from "@/components/Section07Cohort120";
import Section08Hall240 from "@/components/Section08Hall240";
import Section09PipelineDeepDive from "@/components/Section09PipelineDeepDive";
import Section10Dashboard from "@/components/Section10Dashboard";
import Section11Architecture from "@/components/Section11Architecture";
import Section12ExperimentalValidation from "@/components/Section12ExperimentalValidation";
import Section13Closing from "@/components/Section13Closing";

// Dynamically import 3D lecture hall canvas to avoid SSR issues
const LectureHallScene = dynamic(() => import("@/components/LectureHallScene"), {
  ssr: false,
  loading: () => (
    <div className="w-full h-full flex items-center justify-center bg-slate-50 text-xs font-mono text-amber-700">
      <span className="animate-pulse">INITIALIZING 3D LECTURE HALL SCENE...</span>
    </div>
  ),
});

function HomeContent() {
  const { lenis, scrollTo } = useSmoothScroll();
  const [scrollProgress, setScrollProgress] = useState<number>(0);
  const [activeSection, setActiveSection] = useState<string>("section-01");
  const [selectedCohort, setSelectedCohort] = useState<80 | 120 | 240>(240);
  const [activeZone, setActiveZone] = useState<"all" | "zoneA" | "zoneB" | "zoneC">("all");
  const [isReducedMotion, setIsReducedMotion] = useState<boolean>(false);

  // Detect user preference for reduced motion
  useEffect(() => {
    if (typeof window !== "undefined") {
      const mediaQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
      setIsReducedMotion(mediaQuery.matches);
      const listener = (e: MediaQueryListEvent) => setIsReducedMotion(e.matches);
      mediaQuery.addEventListener("change", listener);
      return () => mediaQuery.removeEventListener("change", listener);
    }
  }, []);

  // Compute scroll progress and active section with direct Lenis RAF integration
  useEffect(() => {
    const handleScrollUpdate = (progressValue?: number) => {
      let progress: number;
      if (typeof progressValue === "number") {
        progress = Math.min(1, Math.max(0, progressValue));
      } else {
        const totalHeight = document.documentElement.scrollHeight - window.innerHeight;
        progress = totalHeight > 0 ? Math.min(1, Math.max(0, window.scrollY / totalHeight)) : 0;
      }
      setScrollProgress(progress);

      // Map scroll positions to active sections
      const sections = [
        { id: "section-01", anchor: "experience" },
        { id: "section-02", anchor: "problem" },
        { id: "section-03", anchor: "concept" },
        { id: "section-04", anchor: "workflow" },
        { id: "section-05", anchor: "verification" },
        { id: "section-06", anchor: "scale" },
        { id: "section-09", anchor: "pipeline" },
        { id: "section-10", anchor: "dashboard" },
        { id: "section-11", anchor: "architecture" },
        { id: "section-12", anchor: "experiments" },
      ];

      for (let i = sections.length - 1; i >= 0; i--) {
        const el = document.getElementById(sections[i].anchor);
        if (el) {
          const rect = el.getBoundingClientRect();
          if (rect.top <= window.innerHeight * 0.45) {
            setActiveSection(sections[i].id);
            break;
          }
        }
      }
    };

    if (lenis) {
      const onLenisScroll = (e: any) => {
        handleScrollUpdate(e.progress);
      };
      lenis.on("scroll", onLenisScroll);
      handleScrollUpdate();
      return () => {
        lenis.off("scroll", onLenisScroll);
      };
    } else {
      const onWindowScroll = () => handleScrollUpdate();
      window.addEventListener("scroll", onWindowScroll, { passive: true });
      handleScrollUpdate();
      return () => window.removeEventListener("scroll", onWindowScroll);
    }
  }, [lenis]);

  const scrollToAnchor = (anchor: string) => {
    scrollTo(`#${anchor}`, { offset: -70, duration: 1.4 });
  };

  return (
    <div className="relative min-h-screen bg-slate-50 text-slate-900 overflow-x-hidden">
      {/* GSAP ScrollTrigger Animations Engine */}
      <GsapScrollEffects />

      {/* Atmospheric Cinematic Background (Aurora Mesh, Spotlight, Cyber Matrix & Particles) */}
      <AtmosphericBackground />

      {/* Global Navigation */}
      <Navbar activeSection={activeSection} />

      {/* Persistent 3D Lecture Hall Canvas in Background */}
      <div className="fixed inset-0 z-0 pointer-events-auto h-screen w-screen opacity-100">
        <LectureHallScene
          scrollProgress={scrollProgress}
          activeSection={activeSection}
          isReducedMotion={isReducedMotion}
          selectedCohort={selectedCohort}
          activeZone={activeZone}
        />
        {/* Subtle Daylight Vignette */}
        <div className="absolute inset-0 pointer-events-none bg-gradient-to-t from-slate-50/20 via-transparent to-slate-50/15" />
      </div>

      {/* Foreground Scroll-Driven Story Content */}
      <main className="relative z-10 space-y-16 sm:space-y-32">
        {/* Section 01: Opening */}
        <Section01Opening
          onExploreClick={() => scrollToAnchor("concept")}
          onWorkflowClick={() => scrollToAnchor("workflow")}
        />

        {/* Section 02: Problem */}
        <Section02Problem />

        {/* Section 03: Concept */}
        <Section03Concept />

        {/* Section 04: Workflow */}
        <Section04Workflow />

        {/* Section 05: Individual Verification */}
        <Section05StudentVerification />

        {/* Section 06: Cohort 80 */}
        <Section06Cohort80
          onSelectCohort={() => {
            setSelectedCohort(80);
            setActiveZone("all");
          }}
        />

        {/* Section 07: Cohort 120 */}
        <Section07Cohort120
          onZoneChange={(zone) => {
            setSelectedCohort(120);
            setActiveZone(zone);
          }}
        />

        {/* Section 08: Full 240 Hall */}
        <Section08Hall240 />

        {/* Section 09: Pipeline Deep Dive */}
        <Section09PipelineDeepDive />

        {/* Section 10: Control Center Dashboard */}
        <Section10Dashboard />

        {/* Section 11: Architecture */}
        <Section11Architecture />

        {/* Section 12: Experimental Validation */}
        <Section12ExperimentalValidation />

        {/* Section 13: Closing Moment */}
        <Section13Closing
          onWorkflowClick={() => scrollToAnchor("workflow")}
          onArchitectureClick={() => scrollToAnchor("architecture")}
          onDashboardClick={() => scrollToAnchor("dashboard")}
        />
      </main>
    </div>
  );
}

export default function Home() {
  return (
    <SmoothScrollProvider>
      <HomeContent />
    </SmoothScrollProvider>
  );
}
