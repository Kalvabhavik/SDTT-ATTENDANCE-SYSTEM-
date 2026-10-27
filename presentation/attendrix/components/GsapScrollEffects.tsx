"use client";

import { useEffect } from "react";
import { gsap } from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";

if (typeof window !== "undefined") {
  gsap.registerPlugin(ScrollTrigger);
}

export default function GsapScrollEffects() {
  useEffect(() => {
    const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (prefersReducedMotion) return;

    // Small delay ensuring DOM and Lenis ticker are synchronized
    const timer = setTimeout(() => {
      // 1. Section Headers - Clean, subtle upward drift on entrance
      const sectionHeaders = document.querySelectorAll("h2, .section-header");
      sectionHeaders.forEach((el) => {
        gsap.fromTo(
          el,
          { y: 22, opacity: 0 },
          {
            y: 0,
            opacity: 1,
            duration: 0.7,
            ease: "power2.out",
            scrollTrigger: {
              trigger: el,
              start: "top 88%",
              once: true,
            },
          }
        );
      });

      // 2. Glass Panel Content Cards - Smooth staggered entrance
      const cards = document.querySelectorAll(".glass-panel");
      cards.forEach((card) => {
        gsap.fromTo(
          card,
          { y: 18, opacity: 0.3 },
          {
            y: 0,
            opacity: 1,
            duration: 0.65,
            ease: "power2.out",
            scrollTrigger: {
              trigger: card,
              start: "top 92%",
              once: true,
            },
          }
        );
      });

      // 3. Hero Pillar Stat Badges
      const statPillars = document.querySelectorAll("#experience .glass-panel");
      if (statPillars.length > 0) {
        gsap.fromTo(
          statPillars,
          { y: 24, opacity: 0 },
          {
            y: 0,
            opacity: 1,
            duration: 0.6,
            stagger: 0.08,
            ease: "power2.out",
            delay: 0.2,
          }
        );
      }
    }, 120);

    return () => {
      clearTimeout(timer);
      ScrollTrigger.getAll().forEach((st) => st.kill());
    };
  }, []);

  return null;
}
