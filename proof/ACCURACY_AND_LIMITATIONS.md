# Attendrix Biometric Accuracy, Anti-Spoofing & Security Limitations
**System:** Attendrix Computer-Vision Assisted Attendance  
**Review Version:** 2.4.0  
**Scope:** Biometric Identity Matching vs. Presentation-Attack Detection (PAD) Disclosures  

---

## 1. Separation of Concerns: Identity vs. Liveness

Biometric security requires treating face identification and liveness detection as distinct controls:
1. **Face Detection (YuNet):** Answers *"Is a human face geometry located in the image frame?"*
2. **Face Identity Verification (SFace):** Answers *"Does this face match the enrolled student reference embedding?"*
3. **Presentation Attack Detection (FFT + Chroma + Active Yaw/Blink):** Answers *"Is this capture originating from a live, physically present human rather than a photograph, video, or digital screen?"*
4. **Institutional Session Authorization:** Answers *"Is this check-in associated with the active room, active lecturer, and correct student roster?"*

A positive face match **never** implies liveness. Active liveness **never** substitutes for identity verification.

---

## 2. Tested Presentation Attack Scenarios & Measured Resistance

| Attack Vector | Attack Medium | Detection Mechanism | Test Outcome | Real-World Limitation |
| :--- | :--- | :--- | :---: | :--- |
| **Replay: Exact Captured Image** | Intercepted raw JPEG/PNG bytes | SHA-256 Digest Deduplication Cache | **BLOCKED** (`TC-SPOOF-002`) | Complete resistance to exact byte replays. |
| **Replay: Re-encoded / Resized** | JPEG re-compression with different quality | DCT 64-bit Perceptual Hash (Hamming distance $\le 3$) | **BLOCKED** (`TC-SPOOF-003`) | Robust against mild cropping, compression, and scaling. |
| **Digital Screen Replay** | Smartphone / tablet LCD/OLED display | 2D FFT High-Frequency Spectral Ratio ($> 0.40$) | **BLOCKED** (`TC-SPOOF-004`) | High-density 4K/Retina displays held further back may exhibit reduced moiré; active challenges required as secondary shield. |
| **Static Printed 2D Photo** | High-resolution color photograph | Multi-frame dynamic yaw deflection + eye blink ratio | **BLOCKED** (`TC-SPOOF-001`) | Completely defeats single static photos because frames cannot perform random yaw or blink. |
| **Passive Video Replay** | Pre-recorded video on phone screen | Dynamic server-signed challenge sequence (90s TTL) | **BLOCKED** (`TC-API-004`) | Attacker cannot predict the randomized sequence (e.g., turn left vs. right) generated server-side. |
| **Impersonation (Non-matching peer)** | Consenting live peer's face | SFace 128D cosine distance ($< 0.65$) | **BLOCKED** (`TC-FUNC-002`) | Live non-matching student is flagged as biometric mismatch (`absent`/`pending`). |
| **Empty Room Proxy Check-in** | Student verifying from hostel or outside room | 180° Classroom Sweep analyzing lecturer presence & crowd density | **BLOCKED** (`TC-FUNC-003`) | Empty hall flagged as proxy attempt (`is_empty_room = True`). |

---

## 3. Outstanding Security Risks & Known Limitations

1. **RGB-Only Sensor Limits:**
   - Standard commodity smartphone cameras provide only 8-bit RGB imagery without active depth (Time-of-Flight / LiDAR) or near-infrared (NIR) structured light.
   - Passive software PAD on RGB cannot match the presentation attack defense of hardware NIR/depth sensors.
2. **High-End 3D Silicone Masks:**
   - Advanced 3D wearable latex/silicone masks with custom eye and mouth apertures can potentially mimic head yaw and eye openness.
3. **Deepfake Real-Time Video Injection:**
   - An attacker routing a real-time virtual camera feed (e.g. OBS Virtual Camera on rooted Android) driven by a generative facial model could attempt to follow live challenge cues. The FFT spectral filter mitigates virtual camera raster artifacts, but rooted device hardware tampering remains an adversarial threat.
4. **Dataset Demographics Disclosure:**
   - In accordance with ethical benchmarking standards: Full demographic fairness curves (FAR/FRR across Fitzpatrick skin types I–VI) have not been statistically evaluated across a multi-thousand subject cohort. The OpenCV SFace model was pre-trained on the public CASIA-WebFace and tested on LFW (~99.4% on LFW). Institutional deployments should maintain the lecturer review queue for flagged low-confidence attempts.
