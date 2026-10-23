"use client";

import React, { useState } from "react";
import { soundManager } from "./SoundManager";
import { useSmoothScroll } from "./SmoothScrollProvider";
import { Volume2, VolumeX, Menu, X, ChevronRight } from "lucide-react";

interface NavbarProps {
  activeSection: string;
}

export default function Navbar({ activeSection }: NavbarProps) {
  const [soundOn, setSoundOn] = useState<boolean>(false);
  const [mobileMenuOpen, setMobileMenuOpen] = useState<boolean>(false);
  const { scrollTo } = useSmoothScroll();

  const toggleSound = () => {
    const newState = soundManager.toggle();
    setSoundOn(newState);
  };

  const navLinks = [
    { label: "Experience", href: "#experience" },
    { label: "The Problem", href: "#problem" },
    { label: "Concept", href: "#concept" },
    { label: "Workflow", href: "#workflow" },
    { label: "1:1 Verification", href: "#verification" },
    { label: "Scale (80/120/240)", href: "#scale" },
    { label: "Pipeline", href: "#pipeline" },
    { label: "Dashboard", href: "#dashboard" },
    { label: "Architecture", href: "#architecture" },
    { label: "Experiments", href: "#experiments" },
  ];

  const handleNavClick = (href: string) => {
    soundManager.playClick();
    setMobileMenuOpen(false);
    scrollTo(href, { offset: -70, duration: 1.4 });
  };

  return (
    <header className="fixed top-0 left-0 right-0 z-50 transition-all duration-300">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pt-3">
        <nav className="glass-panel px-4 py-3 rounded-2xl border border-slate-300 shadow-md flex items-center justify-between bg-white/95 backdrop-blur-xl">
          {/* Logo & Academic Badge */}
          <div className="flex items-center gap-3">
            <button
              onClick={() => handleNavClick("#experience")}
              className="flex items-center gap-2.5 text-left group cursor-pointer"
            >
              <div className="w-8 h-8 rounded-lg bg-amber-600 flex items-center justify-center shadow-md shadow-amber-600/30 group-hover:scale-105 transition-transform">
                <span className="font-mono font-black text-white text-sm tracking-tighter">AX</span>
              </div>
              <div className="flex flex-col">
                <span className="font-bold text-base tracking-wider text-slate-900 group-hover:text-amber-700 transition-colors flex items-center gap-1.5 font-sans">
                  ATTENDRIX
                  <span className="text-[10px] px-1.5 py-0.2 rounded font-mono font-bold bg-amber-100 text-amber-900 border border-amber-300">
                    SDTT
                  </span>
                </span>
                <span className="text-[10px] text-slate-600 font-mono tracking-tight hidden sm:block font-medium">
                  Classroom Verification Architecture
                </span>
              </div>
            </button>
          </div>

          {/* Desktop Navigation Links */}
          <div className="hidden xl:flex items-center gap-1">
            {navLinks.map((link) => (
              <button
                key={link.label}
                onClick={() => handleNavClick(link.href)}
                className="px-2.5 py-1 rounded-lg text-xs font-bold text-slate-800 hover:text-amber-800 hover:bg-amber-50 transition-colors cursor-pointer"
              >
                {link.label}
              </button>
            ))}
          </div>

          {/* Controls & Quick CTAs */}
          <div className="flex items-center gap-2">
            {/* Audio Toggle */}
            <button
              onClick={toggleSound}
              className={`p-2 rounded-xl text-xs font-mono transition-colors border cursor-pointer ${
                soundOn
                  ? "bg-amber-100 text-amber-900 border-amber-300 shadow-sm font-bold"
                  : "bg-slate-100 text-slate-700 border-slate-300 hover:text-slate-900"
              }`}
              title={soundOn ? "Mute interactive audio effects" : "Enable synthetic audio effects"}
            >
              {soundOn ? <Volume2 className="w-4 h-4 text-amber-800" /> : <VolumeX className="w-4 h-4" />}
            </button>

            {/* Quick Demo CTA */}
            <button
              onClick={() => handleNavClick("#verification")}
              className="hidden sm:flex items-center gap-1.5 px-3.5 py-1.5 rounded-xl text-xs font-bold bg-amber-600 text-white hover:bg-amber-700 transition-colors shadow-md shadow-amber-600/30 cursor-pointer"
            >
              <span>Simulate Flow</span>
              <ChevronRight className="w-3.5 h-3.5" />
            </button>

            {/* Mobile Menu Button */}
            <button
              onClick={() => {
                soundManager.playClick();
                setMobileMenuOpen(!mobileMenuOpen);
              }}
              className="xl:hidden p-2 rounded-xl bg-slate-100 border border-slate-200 text-slate-700 hover:text-amber-700"
            >
              {mobileMenuOpen ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
            </button>
          </div>
        </nav>

        {/* Mobile Dropdown Menu */}
        {mobileMenuOpen && (
          <div className="xl:hidden mt-2 glass-panel rounded-2xl p-4 border border-slate-200 shadow-xl flex flex-col gap-1 animate-in fade-in slide-in-from-top-2">
            {navLinks.map((link) => (
              <button
                key={link.label}
                onClick={() => handleNavClick(link.href)}
                className="w-full text-left px-3 py-2 rounded-lg text-sm font-medium text-slate-800 hover:text-amber-700 hover:bg-amber-50 transition-colors flex items-center justify-between"
              >
                <span>{link.label}</span>
                <ChevronRight className="w-3.5 h-3.5 text-slate-600" />
              </button>
            ))}
            <div className="pt-2 mt-2 border-t border-slate-200 flex justify-between items-center text-xs text-slate-700 font-mono font-semibold">
              <span>SDTT Academic Demonstration</span>
              <button
                onClick={() => handleNavClick("#dashboard")}
                className="text-amber-800 font-bold underline"
              >
                Open Dashboard →
              </button>
            </div>
          </div>
        )}
      </div>
    </header>
  );
}
