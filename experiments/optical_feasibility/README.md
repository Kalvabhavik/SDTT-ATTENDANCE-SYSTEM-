# Phase 2: Optical Feasibility Experiment Framework

**Project**: SDTT Classroom Attendance System (240-Seat Lecture Hall)  
**Objective**: Quantify the optical resolution and face detection performance of smartphone cameras across distances ($3\text{m}$ to $25\text{m}$), lens types, and lecture hall lighting conditions before deploying biometric attendance.

---

## 1. Face Detection vs. Identity Recognition

Before conducting experiments, researchers and engineers must distinguish between two fundamentally distinct computer vision tasks:

```
+----------------------------------------------------------------------------------------------------+
|                               DETECTION vs. RECOGNITION PIPELINE                                   |
|                                                                                                    |
|  [Input Frame]                                                                                     |
|        |                                                                                           |
|        v                                                                                           |
|  +---------------------------+                                                                     |
|  | STEP 1: FACE DETECTION    |  -> "Is there a human face here, and where is it located?"          |
|  | (YuNet, SCRFD, Haar)      |  -> Output: Bounding Box [x, y, w, h] + 5 landmarks (eyes, nose)   |
|  |                           |  -> Operates on small pixel scales (down to 16x16 - 20x20 px)       |
|  +---------------------------+                                                                     |
|        |                                                                                           |
|        | Face Crop [w, h]                                                                          |
|        v                                                                                           |
|  +---------------------------+                                                                     |
|  | STEP 2: FACE ALIGNMENT &  |  -> Aligns eyes horizontally; normalizes affine transform           |
|  | PREPROCESSING             |  -> Resizes to canonical dimension (e.g., 112x112 px)                |
|  +---------------------------+                                                                     |
|        |                                                                                           |
|        | Standardized 112x112 Crop                                                                 |
|        v                                                                                           |
|  +---------------------------+                                                                     |
|  | STEP 3: IDENTITY          |  -> "WHO does this face belong to?"                                 |
|  | RECOGNITION (ArcFace)     |  -> Extracts 512-dimensional unit embedding vector                  |
|  |                           |  -> Computes cosine similarity: cos(theta) = u . v                  |
|  |                           |  -> REQUIRES high facial detail (inter-pupillary distance >= 30px)  |
|  +---------------------------+                                                                     |
+----------------------------------------------------------------------------------------------------+
```

### Why Detection Success Does Not Imply Recognition Feasibility
A lightweight deep face detector (like YuNet or SCRFD) may successfully detect a head bounding box at $20\text{ meters}$ where the face is only $20 \times 20\text{ pixels}$. 
However, **identity recognition requires fine-grained biometric texture** (iris spacing, nose bridge contour, lip geometry). Upscaling a $20 \times 20$ pixel face to $112 \times 112$ for an ArcFace backbone results in blur and interpolation artifacts. At that scale, feature representations collapse, and cosine similarity becomes uninformative.

---

## 2. Equipment and Setup Requirements

### Equipment
1. **Camera Devices (3 Representative Tiers)**:
   - *Device A (Entry-level)*: Budget Android smartphone with single 12MP/13MP rear sensor ($f/2.2$).
   - *Device B (Mid-range)*: 50MP sensor with pixel-binning to 12.5MP ($f/1.8$).
   - *Device C (Flagship)*: Multi-lens setup with optical zoom (e.g. 0.5x Ultra-wide, 1x Wide, 3x Telephoto).
2. **Classroom Space**:
   - A physical university lecture hall with approximately 200–250 seats, tiered elevation, and at least 20–25 meters depth from front lectern to rear row.
3. **Measurement Tools**:
   - Laser rangefinder or tape measure to record physical distance ($3\text{m}$, $6\text{m}$, $12\text{m}$, $18\text{m}$, $24\text{m}$).
   - Lux meter or calibrated smartphone light meter app to measure ambient illuminance at student desk height.

---

## 3. Photography Protocol with Consented Volunteers

### Rules and Consent
- All subjects in experimental photographs must be adult volunteers who have signed an explicit written participation consent form for this academic research.
- **Privacy Rule**: Raw photographs and biometric crops must **NEVER** be committed to the git repository. All data resides in local `data/raw/` directories excluded by `.gitignore`.

### Test Conditions Matrix
| Variable | Experimental Test Values |
| :--- | :--- |
| **Distance ($D$)** | $3.0\text{m}$ (Front row), $6.0\text{m}$ (Row 3), $12.0\text{m}$ (Row 6), $18.0\text{m}$ (Row 10), $24.0\text{m}$ (Back row) |
| **Lighting ($L$)** | 1. `ambient_full`: All classroom overhead lights on ($400\text{–}500\text{ lux}$).<br>2. `dimmed_projection`: Front lights dimmed for projector slide viewing ($70\text{–}120\text{ lux}$).<br>3. `backlit`: Classroom curtains open with strong daylight behind subjects ($150\text{–}300\text{ lux}$). |
| **Lens Mode** | 1. `normal` ($1.0\times$, standard wide-angle equivalent $\approx 24\text{–}28\text{mm}$).<br>2. `ultrawide` ($0.5\times\text{–}0.6\times$, equivalent $\approx 13\text{–}16\text{mm}$).<br>3. `telephoto` ($2.0\times\text{–}3.0\times$ optical zoom where available). |

---

## 4. Running the Experiment

### Step 1: Install Dependencies
Ensure the backend virtual environment is active and contains OpenCV and NumPy:
```bash
source backend/.venv/bin/activate
pip install numpy opencv-python-headless
```

### Step 2: Populate the Manifest
Copy `manifest.example.csv` to `manifest.csv` and populate it with details for each photograph taken in the lecture hall:
```bash
cp experiments/optical_feasibility/manifest.example.csv experiments/optical_feasibility/manifest.csv
```

### Step 3: Execute Detection and Metrics Extraction
```bash
# Run against physical classroom photos specified in manifest.csv
python experiments/optical_feasibility/run_experiment.py \
    --manifest experiments/optical_feasibility/manifest.csv \
    --output experiments/optical_feasibility/results/raw_results.csv

# OR, run the synthetic baseline validation test (no real photos needed):
python experiments/optical_feasibility/run_experiment.py \
    --synthetic-test \
    --output experiments/optical_feasibility/results/synthetic_results.csv
```

### Step 4: Summarize and Generate Report
```bash
python experiments/optical_feasibility/summarize_results.py \
    --input-csv experiments/optical_feasibility/results/raw_results.csv \
    --output-md experiments/optical_feasibility/results/summary_report.md \
    --output-csv experiments/optical_feasibility/results/summary_distance.csv
```

---

## 5. Quantitative Measurements & Blur Diagnosis

The script extracts:
- `laplacian_var`: Variance of the Laplacian ($\text{Var}(\nabla^2 I)$). Measures edge sharpness. Values $< 35.0$ indicate severe motion or lens blur.
- `mean_luminance`: Average grayscale intensity ($0\text{–}255$). Values $< 30$ indicate severe underexposure; values $> 225$ indicate saturation/washout.
- `bbox_w`, `bbox_h`: Dimensions of the detected face bounding box in pixels.
- `ipd_px`: Inter-pupillary distance in pixels (Euclidean distance between eye landmarks).

### Failure Diagnosis Categories
- `UNDETECTED_SMALL_SCALE`: Distance $\ge 12\text{m}$; face resolution too low for detector anchor grids.
- `MOTION_BLUR`: Laplacian variance $< 35.0$.
- `UNDEREXPOSURE`: Mean luminance $< 30.0$.
- `OVEREXPOSURE`: Mean luminance $> 225.0$.
- `OCCLUSION_OR_OFF_ANGLE`: Subject head turned $> 30^\circ$ or occluded by row seats.

---

## 6. Measurements Still Required in the Physical Classroom

Because this sandbox environment lacks access to a physical 240-seat lecture hall and mobile phone cameras, **physical validation remains pending**.

The physical experiment requires:
1. Photographing consented students in rows 1, 4, 8, 12, and 16 under both full light and dimmed projection mode.
2. Generating empirical detection curves across distance.
3. Measuring empirical IPD drop-off to establish whether the rear camera can serve as a primary biometric capture or must be restricted to a room-challenge / contextual validation role (Method 3).
