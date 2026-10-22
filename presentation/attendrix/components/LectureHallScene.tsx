"use client";

import React, { useEffect, useRef, useState, useCallback } from "react";
import * as THREE from "three";
import { soundManager } from "./SoundManager";

interface LectureHallSceneProps {
  scrollProgress: number; // 0 to 1
  activeSection: string;
  isReducedMotion?: boolean;
  selectedCohort?: 80 | 120 | 240;
  activeZone?: "all" | "zoneA" | "zoneB" | "zoneC";
}

export default function LectureHallScene({
  scrollProgress,
  activeSection,
  isReducedMotion = false,
  selectedCohort = 240,
  activeZone = "all",
}: LectureHallSceneProps) {
  const mountRef = useRef<HTMLDivElement>(null);
  const [webglSupported, setWebglSupported] = useState<boolean>(true);
  const [force2D, setForce2D] = useState<boolean>(isReducedMotion);
  const [hoveredSeat, setHoveredSeat] = useState<{ id: number; row: number; col: number; status: string } | null>(null);

  // References to three.js objects
  const sceneRef = useRef<THREE.Scene | null>(null);
  const cameraRef = useRef<THREE.PerspectiveCamera | null>(null);
  const rendererRef = useRef<THREE.WebGLRenderer | null>(null);
  const instancedSeatsRef = useRef<THREE.InstancedMesh | null>(null);
  const projectorBeamRef = useRef<THREE.Mesh | null>(null);
  const targetCameraPos = useRef(new THREE.Vector3(0, 7.5, 25));
  const targetLookAt = useRef(new THREE.Vector3(0, 2.5, -4));
  const currentLookAt = useRef(new THREE.Vector3(0, 2.5, -4));
  const mousePos = useRef({ x: 0, y: 0 });

  // 240 seat metadata definition
  const seatsData = useRef<
    Array<{
      id: number;
      row: number;
      col: number;
      x: number;
      y: number;
      z: number;
      zone: "zoneA" | "zoneB" | "zoneC";
      status: "verified" | "pending" | "unrecorded";
    }>
  >([]);

  // Initialize seat positions and status
  if (seatsData.current.length === 0) {
    const totalRows = 12;
    const seatsPerRow = 20;
    let idCounter = 1;

    for (let r = 0; r < totalRows; r++) {
      const zone: "zoneA" | "zoneB" | "zoneC" =
        r < 4 ? "zoneA" : r < 8 ? "zoneB" : "zoneC";

      const rowElevation = r * 0.45;
      const rowZ = 14 - r * 1.6;

      for (let c = 0; c < seatsPerRow; c++) {
        // Left aisle between 4 & 5, Right aisle between 14 & 15
        let x = (c - 9.5) * 0.96;
        if (c < 5) x -= 0.65;
        else if (c >= 15) x += 0.65;

        // Subtle realistic tiered curvature
        const curveOffset = Math.pow((c - 9.5) * 0.09, 2) * 0.38;
        const z = rowZ + curveOffset;

        // Reconciled seed status: 218 verified, 12 pending, 10 unrecorded
        let status: "verified" | "pending" | "unrecorded" = "verified";
        if (idCounter % 20 === 7) status = "pending";
        else if (idCounter % 24 === 0) status = "unrecorded";

        seatsData.current.push({
          id: idCounter++,
          row: r + 1,
          col: c + 1,
          x,
          y: rowElevation + 0.3,
          z,
          zone,
          status,
        });
      }
    }
  }

  // Continuous cinematic camera flight trajectory smoothly driven by scrollProgress
  useEffect(() => {
    const waypoints = [
      { p: 0.00, pos: [0, 6.8, 25], look: [0, 2.5, -4] },     // Vantage 1: Front stage looking up at tiered amphitheater
      { p: 0.15, pos: [4.2, 4.4, 16], look: [-1.8, 2.0, -3] },  // Vantage 2: Front desk row angled perspective
      { p: 0.32, pos: [-10.5, 6.5, 12], look: [1.5, 2.2, -2] }, // Vantage 3: Left-flank diagonal dual-stream
      { p: 0.48, pos: [-2.5, 3.2, 9], look: [-1.2, 1.8, 5] },    // Vantage 4: Student verification camera - close zoom
      { p: 0.62, pos: [-13, 9.8, 17], look: [1.0, 3.0, 3.5] },   // Vantage 5: Cohort 80 zone perspective
      { p: 0.76, pos: [14.5, 11.5, 21], look: [-1.2, 3.2, 2.0] },// Vantage 6: Cohort 120 opposite diagonal
      { p: 0.88, pos: [0, 20.5, 35], look: [0, 3.8, 0] },       // Vantage 7: High Balcony panoramic sweep
      { p: 1.00, pos: [2.5, 25.0, 15], look: [0, 0, 3.5] },     // Vantage 8: Architectural plan / bird's eye view
    ];

    const p = Math.min(1, Math.max(0, scrollProgress));

    // Find bounding waypoints
    let idx = 0;
    for (let i = 0; i < waypoints.length - 1; i++) {
      if (p >= waypoints[i].p && p <= waypoints[i + 1].p) {
        idx = i;
        break;
      }
    }

    const w0 = waypoints[idx];
    const w1 = waypoints[idx + 1] || waypoints[waypoints.length - 1];
    const range = (w1.p - w0.p) || 1;
    const rawT = (p - w0.p) / range;
    // Hermite smoothstep for natural camera inertia
    const smoothT = rawT * rawT * (3 - 2 * rawT);

    const lerp = (a: number, b: number, t: number) => a + (b - a) * t;

    targetCameraPos.current.set(
      lerp(w0.pos[0], w1.pos[0], smoothT),
      lerp(w0.pos[1], w1.pos[1], smoothT),
      lerp(w0.pos[2], w1.pos[2], smoothT)
    );

    targetLookAt.current.set(
      lerp(w0.look[0], w1.look[0], smoothT),
      lerp(w0.look[1], w1.look[1], smoothT),
      lerp(w0.look[2], w1.look[2], smoothT)
    );
  }, [scrollProgress]);

  // Light Mode seat colors
  const updateSeatColors = useCallback(() => {
    const mesh = instancedSeatsRef.current;
    if (!mesh) return;

    const dummyColor = new THREE.Color();
    const verifiedAmber = new THREE.Color("#d97706"); // Warm golden amber
    const verifiedBright = new THREE.Color("#f59e0b"); // Bright sunstone amber
    const pendingMarigold = new THREE.Color("#eab308"); // Warm marigold
    const unrecordedSlate = new THREE.Color("#94a3b8"); // Clean architectural slate
    const dimmedSlate = new THREE.Color("#e2e8f0"); // Soft light neutral

    seatsData.current.forEach((seat, idx) => {
      const inCohort =
        selectedCohort === 80
          ? seat.id <= 80
          : selectedCohort === 120
            ? seat.id <= 120
            : true;

      const inZone = activeZone === "all" || seat.zone === activeZone;

      if (!inCohort || !inZone) {
        dummyColor.copy(dimmedSlate);
      } else {
        if (seat.status === "verified") {
          dummyColor.copy(seat.id % 2 === 0 ? verifiedAmber : verifiedBright);
        } else if (seat.status === "pending") {
          dummyColor.copy(pendingMarigold);
        } else {
          dummyColor.copy(unrecordedSlate);
        }
      }

      mesh.setColorAt(idx, dummyColor);
    });

    if (mesh.instanceColor) {
      mesh.instanceColor.needsUpdate = true;
    }
  }, [selectedCohort, activeZone]);

  useEffect(() => {
    updateSeatColors();
  }, [updateSeatColors]);

  // Main Three.js real physical lecture hall in Light Mode
  useEffect(() => {
    if (force2D) return;

    const container = mountRef.current;
    if (!container) return;

    const testCanvas = document.createElement("canvas");
    const gl = testCanvas.getContext("webgl2") || testCanvas.getContext("webgl");
    if (!gl) {
      setWebglSupported(false);
      return;
    }

    const width = container.clientWidth;
    const height = container.clientHeight || 600;

    // Scene
    const scene = new THREE.Scene();
    sceneRef.current = scene;
    scene.background = null;
    scene.fog = new THREE.FogExp2("#f8fafc", 0.012);

    // Camera
    const camera = new THREE.PerspectiveCamera(46, width / height, 0.1, 100);
    camera.position.set(0, 7.5, 25);
    cameraRef.current = camera;

    // Renderer
    const renderer = new THREE.WebGLRenderer({
      antialias: true,
      alpha: true,
      powerPreference: "high-performance",
    });
    renderer.setClearColor(0x000000, 0);
    renderer.setSize(width, height);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.8));
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.05;
    container.replaceChildren(renderer.domElement);
    rendererRef.current = renderer;

    // Light Mode Natural Classroom Lighting: Daylight ambient + golden sun directional
    const ambientLight = new THREE.AmbientLight("#ffffff", 1.8);
    scene.add(ambientLight);

    const hemiLight = new THREE.HemisphereLight("#ffffff", "#f1f5f9", 1.2);
    scene.add(hemiLight);

    const stageSunKey = new THREE.DirectionalLight("#fffbeb", 2.2);
    stageSunKey.position.set(10, 20, 14);
    scene.add(stageSunKey);

    const lecternSpot = new THREE.SpotLight("#f59e0b", 2.0, 32, Math.PI / 4, 0.4);
    lecternSpot.position.set(0, 14, -2);
    lecternSpot.target.position.set(0, 2, -6.5);
    scene.add(lecternSpot);
    scene.add(lecternSpot.target);

    // Front stage platform (Light Warm Beech Wood)
    const stageGeo = new THREE.BoxGeometry(24, 0.6, 6);
    const stageMat = new THREE.MeshStandardMaterial({
      color: "#dfd5c6",
      roughness: 0.35,
      metalness: 0.08,
    });
    const stage = new THREE.Mesh(stageGeo, stageMat);
    stage.position.set(0, 0, -6.5);
    scene.add(stage);

    // Classroom Whiteboard / Wood Acoustic Backing Wall
    const backWallGeo = new THREE.BoxGeometry(26, 8, 0.4);
    const backWallMat = new THREE.MeshStandardMaterial({
      color: "#f4efe6",
      roughness: 0.6,
      metalness: 0.05,
    });
    const backWall = new THREE.Mesh(backWallGeo, backWallMat);
    backWall.position.set(0, 4.0, -9.8);
    scene.add(backWall);

    // Flanking Chalkboards / Whiteboards
    const boardMat = new THREE.MeshStandardMaterial({
      color: "#1e293b", // classic dark slate chalkboard with high contrast
      roughness: 0.85,
    });
    const leftBoard = new THREE.Mesh(new THREE.PlaneGeometry(4.8, 3.8), boardMat);
    leftBoard.position.set(-8.5, 4.0, -9.55);
    scene.add(leftBoard);

    const rightBoard = new THREE.Mesh(new THREE.PlaneGeometry(4.8, 3.8), boardMat);
    rightBoard.position.set(8.5, 4.0, -9.55);
    scene.add(rightBoard);

    // Wood Lectern / Podium
    const lecternGeo = new THREE.BoxGeometry(1.4, 1.25, 0.9);
    const lecternMat = new THREE.MeshStandardMaterial({
      color: "#cbbda8",
      roughness: 0.35,
      metalness: 0.1,
    });
    const lectern = new THREE.Mesh(lecternGeo, lecternMat);
    lectern.position.set(3.5, 0.9, -5.5);
    scene.add(lectern);

    // Brass microphone & reading lamp on lectern
    const micGeo = new THREE.CylinderGeometry(0.03, 0.03, 0.4);
    const brassMat = new THREE.MeshStandardMaterial({
      color: "#d97706",
      metalness: 0.8,
      roughness: 0.2,
    });
    const mic = new THREE.Mesh(micGeo, brassMat);
    mic.position.set(3.5, 1.6, -5.3);
    scene.add(mic);

    // Large Center Projector Display (Light Mode Presentation)
    const screenGeo = new THREE.PlaneGeometry(13.5, 6.0);
    const screenCanvas = document.createElement("canvas");
    screenCanvas.width = 1024;
    screenCanvas.height = 512;
    const ctx = screenCanvas.getContext("2d");
    if (ctx) {
      // Crisp light ivory screen canvas
      ctx.fillStyle = "#ffffff";
      ctx.fillRect(0, 0, 1024, 512);

      // Warm amber architectural grid
      ctx.strokeStyle = "rgba(217, 119, 6, 0.12)";
      ctx.lineWidth = 2;
      for (let i = 0; i < 1024; i += 64) {
        ctx.beginPath();
        ctx.moveTo(i, 0);
        ctx.lineTo(i, 512);
        ctx.stroke();
      }
      for (let j = 0; j < 512; j += 64) {
        ctx.beginPath();
        ctx.moveTo(0, j);
        ctx.lineTo(1024, j);
        ctx.stroke();
      }

      // Title & Course
      ctx.fillStyle = "#0f172a";
      ctx.font = "bold 44px sans-serif";
      ctx.fillText("ATTENDRIX // LECTURE HALL A", 70, 85);

      ctx.fillStyle = "#b45309";
      ctx.font = "24px sans-serif";
      ctx.fillText("CS-401 • Cap. 240 Tiered Lecture Hall • Live Verification", 70, 130);

      // Challenge box (Light Mode Solar Styling)
      ctx.fillStyle = "rgba(245, 158, 11, 0.08)";
      ctx.strokeStyle = "#d97706";
      ctx.lineWidth = 3;
      ctx.roundRect(70, 165, 884, 185, 16);
      ctx.fill();
      ctx.stroke();

      ctx.fillStyle = "#0f172a";
      ctx.font = "bold 64px monospace";
      ctx.fillText("CHALLENGE: 9K4-PX2", 120, 255);

      ctx.fillStyle = "#059669";
      ctx.font = "bold 26px monospace";
      ctx.fillText("● DYNAMIC CLASSROOM TOKEN • TTL: 14s", 120, 310);

      // Reconciled telemetry bar
      ctx.fillStyle = "#b45309";
      ctx.font = "bold 24px monospace";
      ctx.fillText("218 Verified / 12 Review Queue / 10 Unrecorded", 70, 420);
    }
    const screenTexture = new THREE.CanvasTexture(screenCanvas);
    const screenMat = new THREE.MeshBasicMaterial({
      map: screenTexture,
      toneMapped: false,
    });
    const screenMesh = new THREE.Mesh(screenGeo, screenMat);
    screenMesh.position.set(0, 4.2, -9.4);
    scene.add(screenMesh);

    // Frame around Screen
    const screenBorderGeo = new THREE.BoxGeometry(13.8, 6.3, 0.1);
    const screenBorderMat = new THREE.MeshStandardMaterial({
      color: "#d4a373",
      roughness: 0.35,
      metalness: 0.4,
    });
    const screenBorder = new THREE.Mesh(screenBorderGeo, screenBorderMat);
    screenBorder.position.set(0, 4.2, -9.45);
    scene.add(screenBorder);

    // Volumetric Warm Projection Light Cone in Daylight
    const coneGeo = new THREE.CylinderGeometry(0.3, 7.2, 16, 24, 1, true);
    coneGeo.rotateX(Math.PI / 2);
    const coneMat = new THREE.MeshBasicMaterial({
      color: "#f59e0b",
      transparent: true,
      opacity: 0.04,
      side: THREE.DoubleSide,
      blending: THREE.AdditiveBlending,
      depthWrite: false,
    });
    const projectorBeam = new THREE.Mesh(coneGeo, coneMat);
    projectorBeam.position.set(0, 7.5, 0);
    projectorBeam.lookAt(0, 4.2, -9.4);
    scene.add(projectorBeam);
    projectorBeamRef.current = projectorBeam;

    // Real Tiered Floor Risers & Continuous Wooden Desks
    const riserMat = new THREE.MeshStandardMaterial({
      color: "#f1f5f9",
      roughness: 0.65,
      metalness: 0.05,
    });

    const deskMat = new THREE.MeshStandardMaterial({
      color: "#d4a373", // Scandinavian natural warm oak
      roughness: 0.35,
      metalness: 0.08,
    });

    for (let r = 0; r < 12; r++) {
      // Stepped Riser Platform
      const riserGeo = new THREE.BoxGeometry(26, 0.45, 1.6);
      const riser = new THREE.Mesh(riserGeo, riserMat);
      riser.position.set(0, r * 0.45 - 0.22, 14 - r * 1.6);
      scene.add(riser);

      // Continuous wooden desk counter in front of each seat row
      const deskGeo = new THREE.BoxGeometry(25.5, 0.08, 0.45);
      const desk = new THREE.Mesh(deskGeo, deskMat);
      desk.position.set(0, r * 0.45 + 0.55, 14 - r * 1.6 - 0.55);
      scene.add(desk);

      // Warm Step Edge Lights along the aisles
      const stepLightGeo = new THREE.BoxGeometry(26, 0.03, 0.03);
      const stepLightMat = new THREE.MeshBasicMaterial({
        color: "#f59e0b",
        transparent: true,
        opacity: 0.3,
      });
      const stepLight = new THREE.Mesh(stepLightGeo, stepLightMat);
      stepLight.position.set(0, r * 0.45 + 0.02, 14 - r * 1.6 - 0.78);
      scene.add(stepLight);
    }

    // Overhead Classroom Trusses
    const ceilingTrussMat = new THREE.MeshStandardMaterial({
      color: "#e2e8f0",
      roughness: 0.7,
    });
    for (let t = 0; t < 5; t++) {
      const trussGeo = new THREE.BoxGeometry(28, 0.8, 0.4);
      const truss = new THREE.Mesh(trussGeo, ceilingTrussMat);
      truss.position.set(0, 11, -6 + t * 5);
      scene.add(truss);
    }

    // 240 Instanced Auditorium Seats (Folding Cushion + Backrest)
    const seatGroupGeo = new THREE.BoxGeometry(0.68, 0.72, 0.58);
    const seatMat = new THREE.MeshStandardMaterial({
      roughness: 0.35,
      metalness: 0.2,
    });
    const instancedSeats = new THREE.InstancedMesh(
      seatGroupGeo,
      seatMat,
      seatsData.current.length
    );
    instancedSeats.instanceMatrix.setUsage(THREE.DynamicDrawUsage);

    const dummy = new THREE.Object3D();
    seatsData.current.forEach((seat, idx) => {
      dummy.position.set(seat.x, seat.y, seat.z);
      dummy.rotation.y = -seat.x * 0.032;
      dummy.updateMatrix();
      instancedSeats.setMatrixAt(idx, dummy.matrix);
    });

    instancedSeats.instanceMatrix.needsUpdate = true;
    scene.add(instancedSeats);
    instancedSeatsRef.current = instancedSeats;

    updateSeatColors();

    // Mouse parallax
    const handleMouseMove = (e: MouseEvent) => {
      const rect = container.getBoundingClientRect();
      const x = ((e.clientX - rect.left) / rect.width) * 2 - 1;
      const y = -(((e.clientY - rect.top) / rect.height) * 2 - 1);
      mousePos.current = { x, y };
    };
    window.addEventListener("mousemove", handleMouseMove);

    // Resize listener
    const handleResize = () => {
      if (!container || !rendererRef.current || !cameraRef.current) return;
      const w = container.clientWidth;
      const h = container.clientHeight || 600;
      cameraRef.current.aspect = w / h;
      cameraRef.current.updateProjectionMatrix();
      rendererRef.current.setSize(w, h);
    };
    window.addEventListener("resize", handleResize);

    // Animation loop
    let animationFrameId: number;
    let clock = new THREE.Clock();

    const animate = () => {
      animationFrameId = requestAnimationFrame(animate);
      const delta = clock.getDelta();
      const elapsed = clock.getElapsedTime();

      // Projector beam subtle breathing pulse
      if (projectorBeamRef.current) {
        (projectorBeamRef.current.material as THREE.MeshBasicMaterial).opacity =
          0.03 + Math.sin(elapsed * 2.2) * 0.015;
      }

      // Smooth camera position lerp
      if (cameraRef.current) {
        const mouseOffsetX = mousePos.current.x * 0.6;
        const mouseOffsetY = mousePos.current.y * 0.35;

        cameraRef.current.position.x +=
          (targetCameraPos.current.x + mouseOffsetX - cameraRef.current.position.x) * (delta * 2.8);
        cameraRef.current.position.y +=
          (targetCameraPos.current.y + mouseOffsetY - cameraRef.current.position.y) * (delta * 2.8);
        cameraRef.current.position.z +=
          (targetCameraPos.current.z - cameraRef.current.position.z) * (delta * 2.8);

        // Smooth lookAt lerp
        currentLookAt.current.x +=
          (targetLookAt.current.x - currentLookAt.current.x) * (delta * 3.2);
        currentLookAt.current.y +=
          (targetLookAt.current.y - currentLookAt.current.y) * (delta * 3.2);
        currentLookAt.current.z +=
          (targetLookAt.current.z - currentLookAt.current.z) * (delta * 3.2);

        cameraRef.current.lookAt(currentLookAt.current);
      }

      if (rendererRef.current && sceneRef.current && cameraRef.current) {
        rendererRef.current.render(sceneRef.current, cameraRef.current);
      }
    };

    animate();

    return () => {
      window.removeEventListener("mousemove", handleMouseMove);
      window.removeEventListener("resize", handleResize);
      cancelAnimationFrame(animationFrameId);
      renderer.dispose();
    };
  }, [force2D, updateSeatColors]);

  return (
    <div className="relative w-full h-full select-none overflow-hidden">
      {/* 3D WebGL Canvas */}
      {webglSupported && !force2D ? (
        <div ref={mountRef} className="w-full h-full cursor-grab active:cursor-grabbing" />
      ) : (
        /* 2D Accessible Floor Plan View (Light Mode) */
        <div className="w-full h-full absolute inset-0 bg-slate-50 flex flex-col items-center justify-center p-4">
          <div className="text-center mb-3">
            <span className="text-xs uppercase tracking-widest text-amber-700 font-mono font-bold">
              Classroom Floor Plan &amp; Topology View
            </span>
            <p className="text-xs text-slate-600">
              Tiered 240-seat amphitheater seating chart (Light Architectural Mode)
            </p>
          </div>
          <div className="w-full max-w-4xl glass-panel p-4 rounded-xl border border-slate-200 overflow-x-auto shadow-sm">
            {/* Front Stage Indicator */}
            <div className="w-3/4 mx-auto mb-6 py-2 px-4 rounded bg-amber-50 border border-amber-300 text-center text-xs font-mono text-amber-900 font-bold">
              [ FRONT PODIUM &amp; DYNAMIC LECTURE SCREEN • CODE: 9K4-PX2 ]
            </div>
            {/* Grid of 12 rows */}
            <div className="flex flex-col gap-1.5 items-center">
              {Array.from({ length: 12 }).map((_, r) => {
                const rowSeats = seatsData.current.filter((s) => s.row === r + 1);
                return (
                  <div key={r} className="flex items-center gap-1">
                    <span className="w-6 text-[10px] font-mono text-slate-500 text-right pr-1 font-bold">
                      R{12 - r}
                    </span>
                    {rowSeats.map((seat) => {
                      const inCohort =
                        selectedCohort === 80
                          ? seat.id <= 80
                          : selectedCohort === 120
                            ? seat.id <= 120
                            : true;
                      const inZone = activeZone === "all" || seat.zone === activeZone;
                      const isDimmed = !inCohort || !inZone;

                      let bgClass = "bg-slate-300";
                      if (!isDimmed) {
                        if (seat.status === "verified") bgClass = "bg-amber-500 shadow-[0_0_8px_#f59e0b]";
                        else if (seat.status === "pending") bgClass = "bg-orange-500 shadow-[0_0_8px_#ea580c]";
                        else bgClass = "bg-slate-400";
                      } else {
                        bgClass = "bg-slate-200 border border-slate-300 opacity-40";
                      }

                      return (
                        <button
                          key={seat.id}
                          onClick={() => {
                            soundManager.playClick();
                            setHoveredSeat(seat);
                          }}
                          title={`Seat #${seat.id} (Row ${seat.row}, Col ${seat.col}) - ${seat.status}`}
                          className={`w-3.5 h-3.5 rounded-sm transition-transform hover:scale-125 ${bgClass} ${seat.col === 5 || seat.col === 15 ? "mr-2.5" : ""
                            }`}
                        />
                      );
                    })}
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      )}

      {/* Floating HUD Controls */}
      <div className="absolute top-4 right-4 z-20 flex items-center gap-2">
        <button
          onClick={() => {
            soundManager.playClick();
            setForce2D(!force2D);
          }}
          className="px-3.5 py-1.5 rounded-full text-xs font-mono glass-panel text-slate-700 hover:text-slate-900 border border-slate-200 hover:border-amber-400 transition-colors flex items-center gap-1.5 shadow-md"
          title="Toggle between 3D Lecture Hall and 2D Floor Plan"
        >
          <span className={`w-2 h-2 rounded-full ${force2D ? "bg-amber-600" : "bg-amber-500 animate-pulse"}`} />
          {force2D ? "Switch to 3D Hall" : "2D Floor Plan Mode"}
        </button>
      </div>

      {/* Interactive Seat Info Overlay if clicked */}
      {hoveredSeat && (
        <div className="absolute bottom-6 left-6 z-20 glass-panel p-3.5 rounded-xl border border-amber-500/40 text-xs font-mono text-slate-800 flex items-center gap-3 shadow-xl">
          <div>
            <span className="text-amber-700 font-bold">SEAT #{hoveredSeat.id}</span> • Row {hoveredSeat.row}, Col {hoveredSeat.col}
          </div>
          <div className="capitalize px-2 py-0.5 rounded text-[10px] bg-amber-100 text-amber-900 border border-amber-300 font-bold">
            {hoveredSeat.status}
          </div>
          <button
            onClick={() => setHoveredSeat(null)}
            className="text-slate-500 hover:text-slate-900 ml-2 text-sm"
          >
            ×
          </button>
        </div>
      )}

      {/* Live Session Overlay Badge in 3D Mode */}
      <div className="absolute bottom-4 left-4 z-10 pointer-events-none">
        <div className="glass-panel px-4 py-2 rounded-xl border border-slate-200 text-xs font-mono flex items-center gap-2.5 shadow-md">
          <span className="relative flex h-2 w-2">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-amber-500 opacity-75"></span>
            <span className="relative inline-flex rounded-full h-2 w-2 bg-amber-600"></span>
          </span>
          <span className="text-amber-700 font-bold">SESSION #8491:</span>
          <span className="text-slate-800 font-semibold">CS-401</span>
          <span className="text-slate-400">|</span>
          <span className="text-emerald-700 font-bold">218 Verified</span>
          <span className="text-amber-700 font-medium">12 Pending</span>
          <span className="text-slate-500">10 Unrecorded</span>
        </div>
      </div>
    </div>
  );
}
