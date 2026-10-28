"use client";

import { useEffect, useRef } from "react";
import Image from "next/image";
import { gsap } from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { ArrowDown, Camera, CheckCircle2, ScanFace, ShieldCheck } from "lucide-react";

if (typeof window !== "undefined") {
  gsap.registerPlugin(ScrollTrigger);
}

const beats = [
  { label: "01", title: "Frame the room", detail: "Venue context" },
  { label: "02", title: "Verify the student", detail: "1:1 reference match" },
  { label: "03", title: "Close the loop", detail: "Review + audit" },
];

export default function DepthScrollStory() {
  const sectionRef = useRef<HTMLElement>(null);
  const stageRef = useRef<HTMLDivElement>(null);
  const backRef = useRef<HTMLDivElement>(null);
  const midRef = useRef<HTMLDivElement>(null);
  const frontRef = useRef<HTMLDivElement>(null);
  const copyRef = useRef<HTMLDivElement>(null);
  const progressRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const section = sectionRef.current;
    const stage = stageRef.current;
    if (!section || !stage || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    const ctx = gsap.context(() => {
      const tl = gsap.timeline({
        scrollTrigger: {
          trigger: section,
          start: "top top",
          end: "bottom bottom",
          scrub: 1,
          pin: stage,
          anticipatePin: 1,
          invalidateOnRefresh: true,
        },
      });

      tl.to(backRef.current, { z: -180, y: -28, scale: 1.12, rotationY: -5, ease: "none" }, 0)
        .to(midRef.current, { z: 40, y: -10, scale: 1.02, rotationY: 4, ease: "none" }, 0)
        .to(frontRef.current, { z: 160, y: 22, scale: 1.08, rotationY: -3, ease: "none" }, 0)
        .to(copyRef.current, { y: -24, opacity: 0.28, ease: "none" }, 0.22)
        .to(progressRef.current, { scaleX: 1, ease: "none" }, 0);

      gsap.fromTo(
        ".depth-beat",
        { y: 24, opacity: 0 },
        {
          y: 0,
          opacity: 1,
          duration: 0.7,
          stagger: 0.08,
          ease: "power3.out",
          scrollTrigger: { trigger: section, start: "top 72%", once: true },
        }
      );
    }, section);

    return () => ctx.revert();
  }, []);

  return (
    <section ref={sectionRef} id="depth-story" className="relative min-h-[220vh] px-4 sm:px-6 lg:px-8">
      <div ref={stageRef} className="depth-stage mx-auto flex min-h-screen max-w-7xl items-center py-24">
        <div className="grid w-full items-center gap-12 lg:grid-cols-[0.82fr_1.18fr]">
          <div ref={copyRef} className="relative z-20 max-w-xl">
            <div className="mb-5 inline-flex items-center gap-2 rounded-full border border-amber-300 bg-amber-100/90 px-3.5 py-1.5 font-mono text-xs font-bold text-amber-950 shadow-sm">
              <span className="h-2 w-2 rounded-full bg-amber-600 shadow-[0_0_0_5px_rgba(217,119,6,0.14)]" />
              SCROLL-DRIVEN EVIDENCE STORY
            </div>
            <p className="mb-4 font-mono text-xs font-bold uppercase tracking-[0.24em] text-amber-800">Attendrix / the proof chain</p>
            <h2 className="text-4xl font-extrabold leading-[1.03] tracking-tight text-slate-950 sm:text-6xl">
              A room becomes a
              <span className="block bg-gradient-to-r from-amber-800 via-amber-600 to-orange-700 bg-clip-text text-transparent">trusted record.</span>
            </h2>
            <p className="mt-6 max-w-lg text-base font-medium leading-relaxed text-slate-700 sm:text-lg">
              Scroll through the three layers of Attendrix: classroom context, student evidence, and the lecturer&apos;s accountable decision.
            </p>
            <div className="mt-8 grid max-w-md gap-3 sm:grid-cols-3">
              {beats.map((beat) => (
                <div key={beat.label} className="depth-beat rounded-2xl border border-slate-200 bg-white/85 p-3 shadow-sm backdrop-blur-md">
                  <div className="font-mono text-[10px] font-bold text-amber-700">{beat.label}</div>
                  <div className="mt-1 text-xs font-bold text-slate-900">{beat.title}</div>
                  <div className="mt-1 text-[10px] font-medium text-slate-600">{beat.detail}</div>
                </div>
              ))}
            </div>
            <div className="mt-8 flex items-center gap-2 font-mono text-[10px] font-bold uppercase tracking-wider text-slate-600">
              <ArrowDown className="h-4 w-4 text-amber-700" />
              Native scroll controls the camera — no scroll hijacking
            </div>
          </div>

          <div className="relative mx-auto h-[520px] w-full max-w-[680px] [perspective:1400px] sm:h-[620px]">
            <div className="absolute inset-x-8 top-1/2 h-64 -translate-y-1/2 rounded-full bg-amber-400/20 blur-3xl" />
            <div className="depth-layer depth-layer-back" ref={backRef}>
              <Image fill priority sizes="(max-width: 768px) 92vw, 56vw" src="/images/classroom_stage_daylight.jpg" alt="Lecture hall stage context" className="h-full w-full object-cover" />
              <div className="depth-overlay" />
              <div className="absolute left-5 top-5 flex items-center gap-2 rounded-full border border-white/60 bg-slate-950/75 px-3 py-1.5 font-mono text-[10px] font-bold text-white backdrop-blur-md">
                <Camera className="h-3.5 w-3.5 text-amber-300" /> VENUE CONTEXT
              </div>
            </div>

            <div className="depth-layer depth-layer-mid" ref={midRef}>
              <Image fill sizes="(max-width: 768px) 92vw, 56vw" src="/images/classroom_balcony_daylight.jpg" alt="Lecture hall balcony context" className="h-full w-full object-cover" />
              <div className="depth-overlay depth-overlay-warm" />
              <div className="absolute bottom-5 left-5 right-5 rounded-2xl border border-white/50 bg-white/90 p-4 shadow-xl backdrop-blur-lg">
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <div className="font-mono text-[10px] font-bold uppercase tracking-wider text-amber-800">Student evidence</div>
                    <div className="mt-1 text-sm font-extrabold text-slate-950">180° continuous sweep</div>
                  </div>
                  <ScanFace className="h-7 w-7 text-amber-700" />
                </div>
                <div className="mt-3 h-1.5 overflow-hidden rounded-full bg-slate-200"><div className="h-full w-[76%] rounded-full bg-amber-600" /></div>
                <div className="mt-2 flex justify-between font-mono text-[10px] font-bold text-slate-600"><span>frames aligned</span><span>reviewable</span></div>
              </div>
            </div>

            <div className="depth-layer depth-layer-front" ref={frontRef}>
              <Image fill sizes="(max-width: 768px) 92vw, 56vw" src="/images/classroom_desk_daylight.jpg" alt="Attendance decision at a classroom desk" className="h-full w-full object-cover" />
              <div className="depth-overlay depth-overlay-light" />
              <div className="absolute right-5 top-5 w-[min(250px,72%)] rounded-2xl border border-emerald-300 bg-white/95 p-4 shadow-2xl backdrop-blur-lg">
                <div className="flex items-center gap-2 font-mono text-[10px] font-bold uppercase tracking-wider text-emerald-800"><CheckCircle2 className="h-4 w-4" /> Decision ledger</div>
                <div className="mt-3 space-y-2 text-xs font-bold text-slate-800">
                  <div className="flex items-center justify-between"><span>Self-match</span><span className="text-emerald-700">PASS</span></div>
                  <div className="flex items-center justify-between"><span>Room presence</span><span className="text-emerald-700">PASS</span></div>
                  <div className="flex items-center justify-between"><span>Audit event</span><span className="text-amber-700">LOGGED</span></div>
                </div>
                <div className="mt-3 flex items-center gap-2 border-t border-slate-200 pt-3 font-mono text-[10px] text-slate-600"><ShieldCheck className="h-3.5 w-3.5 text-emerald-700" /> lecturer review stays in control</div>
              </div>
            </div>

            <div className="absolute bottom-5 left-1/2 z-30 w-[76%] -translate-x-1/2 rounded-full border border-slate-300 bg-white/90 p-1 shadow-xl backdrop-blur-md">
              <div ref={progressRef} className="h-1.5 origin-left scale-x-0 rounded-full bg-gradient-to-r from-amber-600 via-orange-500 to-emerald-600" />
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
