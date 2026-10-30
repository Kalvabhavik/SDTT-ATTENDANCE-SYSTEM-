/**
 * Attendrix Design System Tokens (React / Web Dashboard)
 * Matches the reference design mockup:
 * - Sky-blue to deep royal blue gradients
 * - Soft powder-blue canvas (#EBF3FA)
 * - Pure white floating cards (24px radius, soft diffuse shadow)
 * - 4 Iconic quick-action colors:
 *   Coral Watermelon (#FF6584), Sky Blue (#38BDF8), Mint Green (#2ED573), Lavender Purple (#9B51E0)
 */

export const tokens = {
  colors: {
    // Canvas & Surfaces
    canvas: '#EBF3FA',
    surface: '#FFFFFF',
    surfaceSubtle: '#F8FAFC',
    surfaceMuted: '#F1F5F9',

    // Primary Sky Blue Gradient
    primaryStart: '#38BDF8',
    primaryEnd: '#0284C7',
    primaryDark: '#0369A1',
    primaryLight: '#BAE6FD',

    // Text & Typographic Hierarchy
    textPrimary: '#0F172A',
    textSecondary: '#64748B',
    textTertiary: '#94A3B8',
    textInverse: '#FFFFFF',

    // 4 Reference Action Squircle Colors
    actionLeave: '#FF6584',      // Coral Pink
    actionCalendar: '#38BDF8',   // Sky Blue
    actionCourses: '#2ED573',    // Mint Green
    actionTask: '#9B51E0',       // Lavender Purple

    // Status Semantics
    statusPresent: '#10B981',    // Emerald 500
    statusAbsent: '#EF4444',     // Rose 500
    statusPending: '#F59E0B',    // Amber 500
    statusInfo: '#0284C7',       // Sky 600

    // Borders & Dividers
    border: '#E2E8F0',
    borderSubtle: '#F1F5F9',
    borderFocus: '#38BDF8',
  },

  radii: {
    xs: '6px',
    sm: '10px',
    md: '14px',
    card: '22px',
    squircle: '18px',
    pill: '9999px',
  },

  shadows: {
    card: '0 10px 25px -5px rgba(2, 132, 199, 0.12), 0 8px 10px -6px rgba(0, 0, 0, 0.04)',
    floating: '0 14px 34px -4px rgba(2, 132, 199, 0.22)',
    hover: '0 16px 32px -4px rgba(2, 132, 199, 0.16)',
    glow: '0 0 20px rgba(56, 189, 248, 0.35)',
  },

  typography: {
    fontFamily: '"Plus Jakarta Sans", "Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
    weights: {
      regular: 400,
      medium: 500,
      semibold: 600,
      bold: 700,
      heavy: 800,
    },
  },

  gradients: {
    hero: 'linear-gradient(180deg, #38BDF8 0%, #0284C7 100%)',
    heroHorizontal: 'linear-gradient(135deg, #38BDF8 0%, #0284C7 100%)',
    cardGloss: 'linear-gradient(180deg, rgba(255, 255, 255, 0.8) 0%, rgba(255, 255, 255, 1) 100%)',
    leave: 'linear-gradient(135deg, #FF6584 0%, #F43F5E 100%)',
    calendar: 'linear-gradient(135deg, #38BDF8 0%, #0284C7 100%)',
    courses: 'linear-gradient(135deg, #2ED573 0%, #10B981 100%)',
    task: 'linear-gradient(135deg, #A855F7 0%, #9333EA 100%)',
  },
} as const

export type AppTheme = typeof tokens
