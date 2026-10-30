# Attendrix UI Redesign Plan & Visual Specification
**Reference Source:** Reference Design Image (Uploaded Media `uploaded_media_1793317826139.jpg`)  
**Target Scope:** Attendrix Mobile App (Student, Teacher, Controller) & Attendrix Web Dashboard (Faculty & Controller)  
**Engineering Standard Compliance:** Attendrix Core Guidelines (Zero functionality drop, preserve tests, WCAG AA accessibility, token-driven architecture).

---

## 1. Visual Design Analysis of the Reference Image

The reference mockup depicts a three-screen mobile experience built around a cheerful, modern "claymorphism / soft-depth" visual language with vibrant sky-blue gradients, rounded white floating cards, and pastel accent actions.

### 1.1 Color Palette & Token Definitions
| Semantic Role | Hex Value | Token Name | Reference Usage |
| :--- | :--- | :--- | :--- |
| **Primary Gradient Start** | `#38BDF8` | `sky400` | Top header gradient start, calendar background top |
| **Primary Gradient End** | `#0284C7` | `sky600` | Header gradient bottom, primary button fills, active icons |
| **Canvas Background** | `#EBF3FA` | `appBackground` | Screen canvas, soft powder-blue page backdrop |
| **Card / Surface Background** | `#FFFFFF` | `surfaceWhite` | Main attendance card, schedule sheet, profile body |
| **Primary Text / Heading** | `#0F172A` / `#1E293B` | `textPrimary` | Card titles ("My Attendance", "Today's Task", "Ge Firman") |
| **Secondary Text / Muted** | `#64748B` | `textSecondary` | Subtitles, role descriptions, schedule times |
| **Caption / Tertiary Text** | `#94A3B8` | `textTertiary` | Date indicators ("2022, Mar 27"), timestamps, location pin |
| **Accent 1: Coral Watermelon**| `#FF6584` | `accentCoral` | "Leave" action tile, delete swipe action, alert dots |
| **Accent 2: Sky Blue** | `#38BDF8` | `accentSky` | "Calendar" action tile, check-in swipe, today schedule dot |
| **Accent 3: Mint Green** | `#2ED573` / `#10B981` | `accentMint` | "Salary / Verified" action tile, check-in time pill, reporting dot |
| **Accent 4: Lavender Purple** | `#9B51E0` / `#A855F7` | `accentPurple` | "Task / Notes" action tile |
| **Dock Bar Surface** | `#38BDF8` / `#0284C7` | `dockBackground` | Floating bottom navigation dock |
| **Active Dock Pill** | `#FFFFFF` | `dockPillActive` | Pill-shaped highlight around active navigation item |

---

### 1.2 Typography
* **Font Family:** `Plus Jakarta Sans` or `Inter` / `Nunito` (via `google_fonts` in Flutter, Google Fonts CDN / system fallback in React).
* **Hierarchy:**
  * **Hero Greeting / Title:** `24px` - `26px` (FontWeight `800` / `900`, line height `1.2`, white `#FFFFFF`).
  * **Screen Headers & Months:** `18px` - `20px` (FontWeight `800`, line height `1.25`, white or navy).
  * **Card & Section Titles:** `16px` - `17px` (FontWeight `700`, line height `1.3`, `#0F172A`).
  * **Subheadings & Role Titles:** `13px` - `14px` (FontWeight `600`, line height `1.4`, `#64748B`).
  * **Body Copy & Bio:** `12px` - `13px` (FontWeight `400` / `500`, line height `1.5`, `#475569`).
  * **Chips, Time Pills & Badges:** `11px` - `12px` (FontWeight `700`, line height `1.2`).
  * **Micro-labels (Day of week, location pin):** `10px` - `11px` (FontWeight `500`, line height `1.2`, `#94A3B8`).

---

### 1.3 Spacing, Grid & Layout
* **Screen Edge Margins:** `16px` (mobile standard) to `20px`.
* **Card Interior Padding:** `16px` to `20px`.
* **Header Overlap Stacking:**
  * The top gradient container has a vertical padding of `16px` top to `48px` bottom.
  * The main white card translates upwards by `-32px` to `-36px` (`Transform.translate(offset: Offset(0, -32))`), creating the signature overlapping stacked layer effect.
* **Navigation Style:**
  * Mobile: Floating bottom pill dock (`height: 64px`, `border-radius: 28px`, `margin: 16px 20px 24px 20px`). Active tab displays an animated white rounded pill with an icon and text label.
  * Web Dashboard: Collapsible left navigation bar matching the sky-to-royal blue gradient accent, with rounded pill nav links and soft cards.

---

### 1.4 Shape, Depth & Elevation
* **Corner Radii:**
  * Main Hero Cards: `24px`.
  * Quick-Action Tiles: `18px` - `20px` (squircle).
  * Bottom Dock: `28px` (fully rounded capsule).
  * Time Pills / Status Badges: `16px` - `20px` (pill).
  * List Item Containers: `14px` - `16px`.
* **Shadows:**
  * Floating Cards: `0 10px 25px -5px rgba(2, 132, 199, 0.12), 0 8px 10px -6px rgba(0, 0, 0, 0.04)`.
  * Floating Dock: `0 14px 30px rgba(2, 132, 199, 0.28)`.
  * Hero Avatar Outer Ring: `rgba(255, 255, 255, 0.18)` glow outline.

---

### 1.5 Component Mapping

#### Screen 1: Student Home (`StudentHome`)
1. **Header**: White hamburger menu icon (left), user avatar badge (right), "Hello, [Student Name]!" greeting.
2. **"My Attendance" Card**:
   - Header with title and current formatted date (`yyyy, MMM d`).
   - 3 Time Pills:
     - Check-In / First Class: `#94A3B8` (clock icon).
     - Next Class / Active Slot: `#10B981` (green filled clock icon).
     - Check-Out / Last Class: `#F97316` (orange logout icon).
   - Location row with map pin icon and classroom / building address.
3. **4 Quick Action Tiles**:
   - **Leave** (Coral `#FF6584`): Opens absence/leave request modal.
   - **Calendar** (Sky `#38BDF8`): Transitions to Calendar tab.
   - **Courses** (Mint `#2ED573`): Opens enrolled lecture hall roster.
   - **Tasks / Clock In** (Purple `#9B51E0`): Jumps to live clock-in / camera verification.
4. **"Today's Task" Schedule**:
   - List of enrolled lectures and attendance sessions with status dots (Blue, Green, Orange) and swipe/action buttons.
5. **Floating Navigation Dock**:
   - Tabs: `Home`, `Profile`, `Schedule`, `Clock In`.

#### Screen 2: Student Profile (`_StudentProfileView`)
1. **Hero Character Presentation**:
   - Stylized 3D character avatar with glossy lighting, hair highlights, and double halo glow ring.
2. **Profile Card**:
   - White card overlapping bottom half with small circle avatar badge.
   - Student Full Name, Designation/Role, Enrolled Date | Email.
   - Bio/Academic statement.
   - Attendance reliability metrics and verified status badge.

#### Screen 3: Interactive Schedule Calendar (`_StudentCalendarView`)
1. **Calendar Header**:
   - Year dropdown (`2026 ▼`) and Month title (`OCTOBER ▼`).
   - Weekday labels (`Sun Mon Tue Wed Thu Fri Sat`).
   - Interactive numerical day grid (1-31) with attendance activity indicator dots below scheduled lecture days.
2. **Schedule Sheet**:
   - White container with "Today [Date]" and "Next schedule [Date]" sections showing course codes, lecture times, room numbers, and faculty with color-coded dot badges.

---

### 1.6 Iconography & Imagery Style
* Clean, geometric, outlined icons with rounded stroke terminals (Lucide Icons in React, Material Rounded / Cupertino in Flutter).
* Soft, vibrant colored dots for timeline status indicators.
* High-fidelity 3D avatar representation with layered gradient shading.

---

## 2. Hard Constraint Management & Handling Differences

| Element in Reference | Existing Attendrix App Feature | Resolution / Accommodation Strategy |
| :--- | :--- | :--- |
| Mockup shows generic text ("Ge Firman", "Illustrator") | Real authenticated student data (Name, Roll Number, Student ID, Email) | Display real authenticated profile data while maintaining the exact visual layout and typography. |
| 3D Rendered Head in Screen 2 | Static mobile/web application | Render high-fidelity layered 3D-styled vector illustration with realistic gradient highlights, soft radial depth shadows, and ambient glow rings. |
| "Today's Task" static meeting rows | Live university roll call sessions, timetable, and attendance records | Map live course slots to the "Today's Task" card list with interactive attendance status badges and one-tap clock-in action. |
| No camera verification in reference | Attendrix facial recognition camera with liveness and anti-spoofing overlays | Clock-In action launches the full facial verification screen with styled blue-accented camera viewfinder, HUD overlays, and score badges. |
| Web Dashboard (not explicitly depicted) | Faculty & Exam Controller React dashboards | Apply the identical design language: sky-to-royal blue gradient headers, floating white cards, 24px radii, colorful status pills, and clean typography. |

---

## 3. Assumptions

1. **Target Platforms**: The primary target depicted in the reference image is the **mobile app** (`apps/mobile`), but the visual tokens (palette, typography, card shapes, and status accents) will also be unified across the **React web dashboard** (`apps/dashboard`) to ensure brand cohesion.
2. **Data Integrity**: No mock data will replace live backend data. Real timetable, session status, user profiles, and enrollment records will feed all newly styled components.
3. **Accessibility**: All text combinations meet WCAG AA minimum 4.5:1 contrast ratio. White text on primary sky blue is restricted to large bold headings; body copy uses dark navy (`#0F172A`) on white backgrounds.
4. **Theme Token Centralization**:
   - Flutter: `apps/mobile/lib/widgets/app_widgets.dart` & dedicated `app_theme.dart`.
   - React: `apps/dashboard/src/theme.ts` & CSS variable definitions in `apps/dashboard/src/styles.css`.

---

## 4. Execution Steps

1. **Step 1 (Current)**: Analyze reference image and document plan in `docs/UI_REDESIGN_PLAN.md` (Complete).
2. **Step 2**: Create design token sources (`app_theme.dart` for Flutter, `theme.ts` for React).
3. **Step 3**: Restyle base shared components (Cards, Pills, Badges, Buttons, Docks).
4. **Step 4**: Apply to screens (Student Home, Student Profile, Student Calendar, Live Sessions, Dashboard).
5. **Step 5**: Run tests and build verifications (`npm run build`, `flutter test`).
6. **Step 6**: Produce side-by-side comparison report in `docs/UI_COMPARISON.md`.
