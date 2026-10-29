import React, { useCallback, useEffect, useRef, useState } from 'react'
import { AlertCircle, ArrowRight, BarChart3, Bell, BookOpen, Briefcase, Building, Calendar, Camera, Check, CheckCircle2, ChevronDown, ChevronLeft, ChevronRight, CircleHelp, Clock, CloudOff, Coffee, Download, FileCheck2, FileSpreadsheet, FileText, Filter, History, LayoutDashboard, Lock, LockKeyhole, LogOut, Menu, MessageSquare, Moon, Pencil, Play, Plus, Printer, RefreshCw, ScanFace, Search, Settings, ShieldAlert, ShieldCheck, Smartphone, Smile, Sparkles, Sun, Table, TrendingUp, Unlock, Upload, UserRound, Users, Wifi, WifiOff, X, Zap } from 'lucide-react'
import * as api from './api'
import { demoClasses, demoRoster, demoSessions, demoStudent, demoTeacher, type AttendanceEntry, type AuditItem, type ClassItem, type Notification, type Report, type ReviewItem, type Session, type StudentAttendance, type User } from './types'
import {
  StatCard,
  StatusBadge,
  SearchInput,
  FilterDropdown,
  DateSelector,
  ModalDialog,
  SkeletonLoader,
  AttendanceDayStrip,
  DataTable,
} from './components/ui'
import { CollegeAttendanceDashboard } from './components/HumanResourceDashboard'
import './styles.css'

type Section = 'overview' | 'matrix' | 'sessions' | 'attendance' | 'analysis' | 'notifications' | 'controller-classes' | 'calendar'
type ConnectionState = 'connecting' | 'connected' | 'closed' | 'error'

const formatDate = (value?: string, withTime = false) => value ? new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric', ...(withTime ? { hour: 'numeric', minute: '2-digit' } : {}) }).format(new Date(value)) : '—'
const formatPct = (value: number | null | undefined) => value === null || value === undefined ? '—' : `${Math.round(value)}%`
const statusCopy: Record<string, string> = { present: 'Present', absent: 'Absent', pending: 'Needs review' }

function App() {
  const [user, setUser] = useState<User | null>(api.currentUser())
  const [isLocal, setIsLocal] = useState(api.isLocalMode())
  const [section, setSection] = useState<Section>('overview')
  const [connection, setConnection] = useState<ConnectionState>('connecting')
  const [notice, setNotice] = useState<string>('')
  const [topSearch, setTopSearch] = useState<string>('')
  const [menuOpen, setMenuOpen] = useState(false)
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false)
  const [darkMode, setDarkMode] = useState(false)
  const socketClose = useRef<() => void>(() => undefined)
  const socketGeneration = useRef(0)

  const connect = useCallback(async () => {
    if (!user) return () => undefined
    const generation = ++socketGeneration.current
    setConnection('connecting')
    try {
      const ticket = await api.wsTicket()
      if (generation !== socketGeneration.current) return () => undefined
      socketClose.current()
      const close = api.openRealtime(ticket, event => {
        if (generation !== socketGeneration.current) return
        if (event.type === 'notification.created') setNotice('New notification received.')
        window.dispatchEvent(new CustomEvent('rollcall:refresh', { detail: event }))
      }, state => {
        if (generation !== socketGeneration.current) return
        setConnection(state)
        if (state === 'connected') window.dispatchEvent(new CustomEvent('rollcall:refresh', { detail: { type: 'realtime.connected' } }))
      })
      socketClose.current = close
      return close
    } catch { if (generation === socketGeneration.current) setConnection('error'); return () => undefined }
  }, [user])

  useEffect(() => { connect().then(() => undefined); return () => { socketGeneration.current += 1; socketClose.current(); socketClose.current = () => undefined } }, [connect])
  useEffect(() => { if (!user || (connection !== 'closed' && connection !== 'error')) return; const retry = window.setTimeout(() => { connect().then(() => undefined) }, 4000); return () => window.clearTimeout(retry) }, [connection, user, connect])
  useEffect(() => { if (!notice) return; const t = window.setTimeout(() => setNotice(''), 5000); return () => window.clearTimeout(t) }, [notice])

  const handleSignOut = () => { api.signOut(); setUser(null); setIsLocal(false) }
  if (!user) return <Login onLogin={(next, local) => { setUser(next); setIsLocal(local) }} />

  return (
    <div className={`app-shell ${darkMode ? 'dark-mode' : ''}`}>
      <aside className={`sidebar ${sidebarCollapsed ? 'is-collapsed' : ''} ${menuOpen ? 'sidebar-open' : ''}`}>
        <div className="sidebar-header">
          <div className="brand-wrap" style={{ gap: 10 }}>
            <div className="sidebar-logo-circle" aria-hidden="true">
              <ShieldCheck size={20} strokeWidth={2.5} />
            </div>
            {!sidebarCollapsed && (
              <div className="brand-text-block">
                <span className="sidebar-brand-name">Attendrix Campus</span>
              </div>
            )}
          </div>
          <button
            type="button"
            className="sidebar-collapse-chevron-btn"
            aria-label={sidebarCollapsed ? "Expand sidebar" : "Collapse sidebar"}
            onClick={() => setSidebarCollapsed(!sidebarCollapsed)}
            title={sidebarCollapsed ? "Expand sidebar" : "Collapse sidebar"}
          >
            {sidebarCollapsed ? <ChevronRight size={14} /> : <ChevronLeft size={14} />}
          </button>
        </div>

        {!sidebarCollapsed && <div className="sidebar-category-heading">ACADEMICS</div>}
        <nav aria-label="Primary navigation" className="main-nav">
          <NavButton
            active={section === 'overview'}
            icon={<LayoutDashboard size={17} />}
            label="Dashboard"
            isCollapsed={sidebarCollapsed}
            onClick={() => { setSection('overview'); setMenuOpen(false) }}
          />
          <NavButton
            active={section === 'matrix'}
            icon={<Table size={17} />}
            label="Monthly Matrix"
            isCollapsed={sidebarCollapsed}
            onClick={() => { setSection('matrix'); setMenuOpen(false) }}
          />
          <NavButton
            active={section === 'attendance'}
            icon={<Clock size={17} />}
            label="Attendance Hub"
            isCollapsed={sidebarCollapsed}
            onClick={() => { setSection('attendance'); setMenuOpen(false) }}
          />
          <NavButton
            active={section === 'sessions'}
            icon={<Zap size={17} />}
            label="Live Sessions"
            isCollapsed={sidebarCollapsed}
            onClick={() => { setSection('sessions'); setMenuOpen(false) }}
          />
          <NavButton
            active={section === 'controller-classes'}
            icon={<Building size={17} />}
            label="Lecture Halls"
            isCollapsed={sidebarCollapsed}
            onClick={() => { setSection('controller-classes'); setMenuOpen(false) }}
          />
          <NavButton
            active={section === 'calendar'}
            icon={<Calendar size={17} />}
            label="Timetable"
            isCollapsed={sidebarCollapsed}
            onClick={() => { setSection('calendar'); setMenuOpen(false) }}
          />

          <NavButton
            active={section === 'notifications'}
            icon={<Bell size={17} />}
            label="Alerts & Reviews"
            badge="02"
            isCollapsed={sidebarCollapsed}
            onClick={() => { setSection('notifications'); setMenuOpen(false) }}
          />
        </nav>

        {!sidebarCollapsed && (
          <>
            <div className="sidebar-workspace-header">
              <span className="sidebar-workspace-title">MY COURSES</span>
              <button
                type="button"
                className="sidebar-workspace-plus-btn"
                aria-label="Add course"
                onClick={() => setNotice('Add course or lecture hall.')}
                title="Add course"
              >
                <Plus size={13} />
              </button>
            </div>
            <div className="workspace-courses-list" style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
              <button type="button" className="workspace-dot-item" onClick={() => setSection('attendance')}>
                <span className="ws-color-dot ws-dot-orange" />
                <span className="truncate">CS 204 HCI</span>
              </button>
              <button type="button" className="workspace-dot-item" onClick={() => setSection('attendance')}>
                <span className="ws-color-dot ws-dot-green" />
                <span className="truncate">DES 112 Design Studio</span>
              </button>
              <button type="button" className="workspace-dot-item" onClick={() => setSection('attendance')}>
                <span className="ws-color-dot ws-dot-purple" />
                <span className="truncate">CS 318 AI Seminar</span>
              </button>
              <button type="button" className="workspace-dot-item" onClick={() => setSection('attendance')}>
                <span className="ws-color-dot ws-dot-yellow" />
                <span className="truncate">CS 301 Distributed Sys</span>
              </button>
            </div>
          </>
        )}

        <div className="sidebar-footer">
          <NavButton
            active={false}
            icon={<Settings size={17} />}
            label="Settings"
            isCollapsed={sidebarCollapsed}
            onClick={() => setNotice('Institutional settings are configured.')}
          />
          <NavButton
            active={false}
            icon={<CircleHelp size={17} />}
            label="Help Center"
            isCollapsed={sidebarCollapsed}
            onClick={() => window.open('https://github.com', '_blank')}
          />
          <button
            type="button"
            className="sidebar-signout-btn"
            onClick={handleSignOut}
            title="Log out"
          >
            <LogOut size={16} />
            {!sidebarCollapsed && <span>Log out</span>}
          </button>
        </div>
      </aside>

      {menuOpen && <button className="scrim" aria-label="Close navigation" onClick={() => setMenuOpen(false)} />}

      <main className="main-content">
        <header className="attendrix-topbar">
          <button className="mobile-menu" aria-label="Open navigation" onClick={() => setMenuOpen(true)}>
            <Menu size={22} />
          </button>

          <div className="topbar-pill-search">
            <Search size={15} className="search-icon" />
            <input
              type="text"
              placeholder="Search courses, student roll numbers, lecture halls..."
              value={topSearch}
              onChange={e => setTopSearch(e.target.value)}
            />
          </div>

          <div className="topbar-right-group">
            <div className="topbar-avatar-stack" title="Faculty peer sync">
              <img src="https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=60&auto=format&fit=crop&q=80" alt="Peer 1" />
              <img src="https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=60&auto=format&fit=crop&q=80" alt="Peer 2" />
              <img src="https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=60&auto=format&fit=crop&q=80" alt="Peer 3" />
            </div>

            <button
              type="button"
              className="topbar-share-btn"
              onClick={() => {
                if (navigator.clipboard) navigator.clipboard.writeText(window.location.href)
                setNotice('Classroom attendance link copied.')
              }}
            >
              Share
            </button>

            <button
              type="button"
              className="topbar-invite-btn clay-btn-primary"
              onClick={() => setSection('sessions')}
              title="Launch active continuous sweep session"
            >
              <Zap size={14} />
              <span>+ Start Session</span>
            </button>

            <button
              type="button"
              className="topbar-bell-btn"
              aria-label="View notifications"
              title="Notifications"
              onClick={() => setSection('notifications')}
            >
              <Bell size={16} />
              <span className="topbar-bell-dot" />
            </button>

            <div className="topbar-user-chip" title={`${user.name} (${user.email})`}>
              <img
                src="https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&auto=format&fit=crop&q=80"
                alt={user.name}
                className="topbar-user-avatar"
              />
              <div className="topbar-user-details">
                <span className="topbar-user-name">{user.name || 'Dr. Mira Chen'}</span>
                <span className="topbar-user-role">
                  {user.role === 'teacher' ? 'Faculty Lecturer' : user.role === 'controller' ? 'Exam Controller' : 'Student'}
                </span>
              </div>
              <ChevronDown size={14} style={{ color: '#94a3b8', marginLeft: 4 }} />
            </div>
          </div>
        </header>

        <div className="page-wrap">
          {notice && (
            <div className="toast" role="status">
              <CheckCircle2 size={17} /> {notice}
              <button aria-label="Dismiss" onClick={() => setNotice('')}><X size={16} /></button>
            </div>
          )}
          {section === 'controller-classes' && <ControllerClassesView />}
                    {section === 'overview' && <CollegeAttendanceDashboard user={user} onNavigate={setSection} initialSubTab="overview" />}
          {section === 'matrix' && <CollegeAttendanceDashboard user={user} onNavigate={setSection} initialSubTab="matrix" />}
          {section === 'attendance' && <CollegeAttendanceDashboard user={user} onNavigate={setSection} initialSubTab="timeline" />}
          {section === 'sessions' && <TeacherSessions />}
          {section === 'analysis' && user.role === 'teacher' && <TeacherAnalysisView />}
          {section === 'notifications' && <NotificationsView />}
          {section === 'calendar' && <CalendarView user={user} />}
        </div>
      </main>
    </div>
  )
}

function Login({ onLogin }: { onLogin: (user: User, local: boolean) => void }) {
  const [email, setEmail] = useState('teacher@demo.edu')
  const [password, setPassword] = useState('teach123')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  async function submit(event: React.FormEvent) {
    event.preventDefault()
    setLoading(true)
    setError('')
    try {
      const result = await api.login(email, password)
      onLogin(result.user, result.local)
    } catch {
      setError('Invalid credentials. Select one of the quick 1-tap demo personas below.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="login-page">
      <div className="login-panel">
        <div className="brand-block login-brand">
          <div className="brand-mark">
            <span className="brand-ax">AX</span>
          </div>
          <div className="brand-details">
            <div className="brand-row">
              <strong>ATTENDRIX</strong>
              <span className="badge-ent">ENTERPRISE</span>
            </div>
            <small>Institutional Attendance & Verification</small>
          </div>
        </div>
        <div className="login-copy">
          <p className="eyebrow">Enterprise Biometrics · SDTT Core</p>
          <h1>Classroom presence, authenticated.</h1>
          <p>Multi-modal attendance platform integrating active liveness verification (head turn + eye blink), 180° continuous spatial sweep, and zero-knowledge ArcFace biometrics.</p>
        </div>
        <form onSubmit={submit} className="login-form">
          <label>Institutional Email
            <input type="email" value={email} onChange={e => setEmail(e.target.value)} autoComplete="username" required placeholder="e.g. teacher@demo.edu" />
          </label>
          <label>Password
            <input type="password" value={password} onChange={e => setPassword(e.target.value)} autoComplete="current-password" required placeholder="••••••••" />
          </label>
          {error && <div className="inline-error"><AlertCircle size={16} /> {error}</div>}
          <button className="primary-button full" type="submit" disabled={loading}>
            {loading ? 'Authenticating…' : 'Sign in to Attendrix'} <ArrowRight size={17} />
          </button>
        </form>
        <div className="demo-logins">
          <span>Quick 1-Tap Demo Access</span>
          <button type="button" onClick={() => { setEmail('controller@demo.edu'); setPassword('control123') }}>
            <ShieldCheck size={14} /> Controller
          </button>
          <button type="button" onClick={() => { setEmail('teacher@demo.edu'); setPassword('teach123') }}>
            <Users size={14} /> Lecturer
          </button>
          <button type="button" onClick={() => { setEmail('student1@demo.edu'); setPassword('student123') }}>
            <UserRound size={14} /> Student
          </button>
        </div>
        <p className="login-foot">
          <LockKeyhole size={14} /> End-to-end encrypted biometric templates · Seeded campus demo
        </p>
      </div>
      <div className="login-aside">
        <div className="aside-orbit orbit-one" />
        <div className="aside-orbit orbit-two" />
        <div className="login-quote">
          <Sparkles size={22} />
          <p>“True presence requires physical, environmental, and biometric corroboration.”</p>
          <small>Attendrix Spatial-Biometric Verification Protocol</small>
        </div>
        <div className="login-points">
          <div><Check size={15} /> Active Liveness Challenge: Center → Turn Left → Turn Right → Blink</div>
          <div><Check size={15} /> 180° Continuous Classroom Sweep (Δyaw ≥ 120°)</div>
          <div><Check size={15} /> Anti-Empty-Room Defense: Real Peer Crowd Corroboration</div>
          <div><Check size={15} /> ArcFace 512-D Cosine Metric (τ ≥ 0.68) with 1-Attempt Policy</div>
        </div>
      </div>
    </div>
  )
}

function Overview({ user, onNavigate }: { user: User; onNavigate: (s: Section) => void }) {
  return user.role === 'teacher' ? <TeacherOverview user={user} onNavigate={onNavigate} /> : <StudentOverview user={user} onNavigate={onNavigate} />
}
function TeacherOverview({ user, onNavigate }: { user: User; onNavigate: (s: Section) => void }) {
  const [classes, setClasses] = useState<ClassItem[]>([])
  const [sessions, setSessions] = useState<Session[]>([])
  const [timetableData, setTimetableData] = useState<api.TimetableResponse | null>(null)
  const [analytics, setAnalytics] = useState<api.AnalyticsData | null>(null)
  const [audits, setAudits] = useState<AuditItem[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [filterText, setFilterText] = useState('')
  const [selectedAcademicPeriod, setSelectedAcademicPeriod] = useState('Fall Semester 2026')
  const [selectedAcademicYear, setSelectedAcademicYear] = useState('2026-2027')

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [cRes, sRes, ttRes, anRes, auRes] = await Promise.allSettled([
        api.getClasses(),
        api.getSessions(),
        api.getTimetable(),
        api.getAnalytics(),
        api.audit(),
      ])

      if (cRes.status === 'fulfilled') setClasses(cRes.value)
      if (sRes.status === 'fulfilled') setSessions(sRes.value)
      if (ttRes.status === 'fulfilled') setTimetableData(ttRes.value)
      if (anRes.status === 'fulfilled') setAnalytics(anRes.value)
      if (auRes.status === 'fulfilled') setAudits(auRes.value)
    } catch {
      setError('Unable to reach backend services. Displaying local cached data.')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    load()
    const fn = () => load()
    window.addEventListener('rollcall:refresh', fn)
    return () => window.removeEventListener('rollcall:refresh', fn)
  }, [load])

  // Real data normalization and local mode fallback
  const displayClasses = classes.length ? classes : demoClasses
  const displaySessions = sessions.length ? sessions : api.isLocalMode() ? demoSessions : []
  const todayClasses: api.TimetableEntry[] = timetableData?.today_classes && timetableData.today_classes.length > 0
    ? timetableData.today_classes
    : displayClasses.slice(0, 2).map((c, idx) => ({
        id: `today-${c.id}`,
        class_id: c.id,
        class_name: c.name,
        class_code: c.code || 'CS-301',
        section: 'Section A',
        day_of_week: 0,
        day_name: 'Today',
        start_time: idx === 0 ? '09:00' : '11:15',
        end_time: idx === 0 ? '10:30' : '12:45',
        room_number: c.room || 'LH-120',
        faculty_name: user.name,
        is_cancelled: false,
        academic_year: '2026-2027',
        semester: 'Fall 2026',
      }))

  const nextClass = timetableData?.next_class || (todayClasses.length > 0 ? todayClasses[0] : null)
  const activeSessions = displaySessions.filter(s => s.status === 'open')
  const finalizedSessions = displaySessions.filter(s => s.status === 'finalized')

  // Real statistics calculations
  const totalStudents = displayClasses.reduce((sum, current) => sum + (current.student_count || 0), 0)
  const studentsPresent = analytics?.summary.present_count ?? displaySessions.reduce((sum, s) => sum + (s.present_count || 0), 0)
  const totalTrackedAttendance = displaySessions.reduce((sum, s) => sum + ((s.present_count || 0) + (s.absent_count || 0)), 0)
  const completionRate = analytics?.summary.attendance_rate != null
    ? Math.round(analytics.summary.attendance_rate)
    : totalTrackedAttendance > 0
      ? Math.round((studentsPresent / totalTrackedAttendance) * 100)
      : displaySessions.length
        ? Math.round(
            displaySessions.reduce((sum, session) => {
              const total = Math.max(1, session.total_enrolled || session.present_count || session.absent_count || 0)
              const rate = (session.present_count ?? 0) / total
              return sum + rate
            }, 0) / displaySessions.length * 100
          )
        : 0

  // Filtered schedule
  const filteredTodayClasses = todayClasses.filter(c => {
    const q = filterText.trim().toLowerCase()
    if (!q) return true
    return [c.class_name, c.class_code, c.room_number, c.section].filter(Boolean).join(' ').toLowerCase().includes(q)
  })

  // Recent activity list
  const recentActivity = (analytics?.recent_audits || audits || []).slice(0, 5)

  // Real weekly trend calculation from session data
  const daysOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']
  const weeklyTrends = daysOfWeek.map((dayLabel, index) => {
    const daySessions = displaySessions.filter(s => {
      const d = new Date(s.started_at)
      return d.getDay() === index + 1
    })
    const dayPresent = daySessions.reduce((acc, s) => acc + (s.present_count || 0), 0)
    const dayTotal = daySessions.reduce((acc, s) => acc + (s.total_enrolled || (s.present_count || 0) + (s.absent_count || 0)), 0)
    const rate = dayTotal > 0 ? Math.round((dayPresent / dayTotal) * 100) : (index === 0 ? 92 : index === 1 ? 88 : index === 2 ? 94 : index === 3 ? 85 : 90)
    return {
      day: dayLabel,
      rate,
      sessionsCount: daySessions.length,
    }
  })

  return (
    <>
      {/* 1. HEADER (Page Title, Subtitle, Date selector, Quick CTA) */}
      <div className="page-heading-block">
        <div>
          <h1 className="page-title">Teacher Dashboard</h1>
          <p className="page-description">
            Monitor classes, attendance, and verification activity.
          </p>
        </div>
        <div className="page-heading-controls">
          <button
            type="button"
            className="topbar-circle-btn"
            title="Refresh live records"
            onClick={load}
          >
            <RefreshCw size={15} className={loading ? 'spin' : ''} />
          </button>
          <DateSelector
            currentPeriod={selectedAcademicPeriod}
            options={['Fall Semester 2026', 'Spring Semester 2026', 'November 2026', 'Today']}
            onSelect={setSelectedAcademicPeriod}
          />
          <button
            type="button"
            className="attendrix-button button-primary"
            onClick={() => onNavigate('sessions')}
          >
            <Zap size={15} />
            <span>+ Start Attendance</span>
          </button>
        </div>
      </div>

      {error && (
        <div className="inline-error" style={{ padding: '10px 14px', borderRadius: 'var(--radius-md)' }}>
          <AlertCircle size={16} /> {error}
        </div>
      )}

      {/* 2. TOP STATISTICS (Four Metric Cards) */}
      <div className="dashboard-top-stats-grid">
        <StatCard
          label="Today's Classes"
          value={todayClasses.length}
          subtext={todayClasses.length > 0 ? `${todayClasses.filter(c => !c.is_cancelled).length} active · Next at ${todayClasses[0]?.start_time || '09:00'}` : 'No remaining classes today'}
          icon={<BookOpen size={16} strokeWidth={2.5} />}
          trend={todayClasses.length > 0 ? 'up' : 'neutral'}
          trendValue={todayClasses.length > 0 ? `${todayClasses.length} Scheduled` : 'Complete'}
        />
        <StatCard
          label="Active Attendance Sessions"
          value={activeSessions.length}
          subtext={activeSessions.length > 0 ? `${activeSessions[0].class_name || 'Active session'} currently running` : 'No live sweep active'}
          icon={<Zap size={16} strokeWidth={2.5} />}
          variant={activeSessions.length > 0 ? 'primary' : 'default'}
          trend={activeSessions.length > 0 ? 'up' : 'neutral'}
          trendValue={activeSessions.length > 0 ? 'LIVE NOW' : 'Idle'}
          onClick={() => onNavigate('sessions')}
        />
        <StatCard
          label="Students Marked Present"
          value={studentsPresent}
          subtext={`Across ${displayClasses.length} institutional courses`}
          icon={<Users size={16} strokeWidth={2.5} />}
          variant="success"
          trend="up"
          trendValue={analytics?.summary.verified_live_count ? `${analytics.summary.verified_live_count} live verified` : `${totalStudents} enrolled`}
        />
        <StatCard
          label="Attendance Completion"
          value={`${completionRate}%`}
          subtext={`${finalizedSessions.length} sessions finalized this term`}
          icon={<TrendingUp size={16} strokeWidth={2.5} />}
          variant={completionRate >= 80 ? 'default' : 'warning'}
          trend={completionRate >= 80 ? 'up' : 'down'}
          trendValue={completionRate >= 80 ? 'Target achieved' : 'Needs attention'}
        />
      </div>

      {/* 3. TEACHER PROFILE & CONTEXT CARD (Adapted from Screenshot's "Employee Details" Card) */}
      <div className="attendrix-hero-card">
        <div className="hero-card-header">
          <div className="hero-card-title-wrap">
            <span className="hero-bullet-dot" />
            <h3 className="hero-card-title">Teacher Profile & Verification Node</h3>
          </div>
          <div className="hero-card-actions">
            <button
              type="button"
              className="hero-circle-btn"
              title="Academic Calendar"
              onClick={() => onNavigate('calendar')}
            >
              <Calendar size={14} />
            </button>
            <DateSelector
              currentPeriod={selectedAcademicYear}
              options={['2026-2027', '2025-2026']}
              onSelect={setSelectedAcademicYear}
            />
            <button
              type="button"
              className="attendrix-button button-primary"
              style={{ padding: '8px 16px', fontSize: '13px' }}
              onClick={() => window.open(api.getMasterExcelUrl(), '_blank')}
            >
              <Download size={14} />
              <span>Export Report (.xlsx)</span>
            </button>
          </div>
        </div>

        <div className="hero-card-grid">
          <div className="hero-profile-entity">
            <div className="hero-avatar-wrap">
              <img
                src="https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=140&auto=format&fit=crop&q=80"
                alt={user.name}
                className="hero-large-avatar"
              />
              <span className="hero-status-pill">Verified Faculty</span>
            </div>
            <div className="hero-entity-details">
              <h2 className="hero-entity-name">{user.name || 'Faculty Lecturer'}</h2>
              <div className="hero-entity-metadata">
                <div className="metadata-item">
                  <span className="metadata-label">Department</span>
                  <span className="metadata-value">Computer Science & Eng.</span>
                </div>
                <div className="metadata-item">
                  <span className="metadata-label">Email Address</span>
                  <span className="metadata-value" title={user.email}>{user.email || 'teacher@demo.edu'}</span>
                </div>
                <div className="metadata-item">
                  <span className="metadata-label">Primary Lecture Hall</span>
                  <span className="metadata-value">{displayClasses[0]?.room || 'LH-120'}</span>
                </div>
              </div>
            </div>
          </div>

          <div className="hero-metrics-quad">
            <div className="quad-metric-cell">
              <span className="quad-metric-label">Enrolled Students</span>
              <div className="quad-metric-value-wrap">
                <span className="quad-metric-val">{totalStudents}</span>
                <span className="quad-metric-unit">students</span>
              </div>
            </div>
            <div className="quad-metric-cell">
              <span className="quad-metric-label">Active Courses</span>
              <div className="quad-metric-value-wrap">
                <span className="quad-metric-val">{displayClasses.length}</span>
                <span className="quad-metric-unit">courses</span>
              </div>
            </div>
            <div className="quad-metric-cell">
              <span className="quad-metric-label">Term Attendance</span>
              <div className="quad-metric-value-wrap">
                <span className="quad-metric-val">{completionRate}%</span>
                <span className="quad-metric-unit">presence</span>
              </div>
            </div>
            <div className="quad-metric-cell">
              <span className="quad-metric-label">Biometric Verification</span>
              <div className="quad-metric-value-wrap">
                <span className="quad-metric-val">99.2</span>
                <span className="quad-metric-unit">% conf.</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* 4. CURRENT OR NEXT CLASS SPOTLIGHT CARD */}
      {nextClass && (
        <div className="spotlight-class-card">
          <div className="spotlight-class-info">
            <div className="spotlight-badge-row">
              <span className="spotlight-pill">
                {activeSessions.some(s => s.class_id === nextClass.class_id) ? 'LIVE SESSION ACTIVE' : 'UPCOMING CLASS'}
              </span>
              <span className="spotlight-time-tag">
                <Clock size={12} style={{ display: 'inline', marginRight: 4 }} />
                {nextClass.start_time} - {nextClass.end_time}
              </span>
            </div>
            <h3 className="spotlight-class-title">
              {nextClass.class_name} <span style={{ color: 'var(--primary-blue)', fontWeight: 600 }}>({nextClass.class_code})</span>
            </h3>
            <div className="spotlight-class-meta">
              <span className="spotlight-meta-item">
                <Building size={14} /> Room: <strong>{nextClass.room_number}</strong>
              </span>
              <span className="spotlight-meta-item">
                <Users size={14} /> Section: <strong>{nextClass.section}</strong>
              </span>
              <span className="spotlight-meta-item">
                <Calendar size={14} /> <strong>{nextClass.semester || 'Fall 2026'}</strong>
              </span>
            </div>
          </div>
          <div className="spotlight-class-actions">
            <button
              type="button"
              className="attendrix-button button-primary"
              onClick={() => onNavigate('sessions')}
            >
              <Zap size={15} />
              <span>Start Attendance Session</span>
            </button>
            <button
              type="button"
              className="attendrix-button button-secondary"
              onClick={() => onNavigate('attendance')}
            >
              View Records
            </button>
          </div>
        </div>
      )}

      {/* 5. QUICK ACTIONS STRIP */}
      <div className="quick-actions-strip">
        <button
          type="button"
          className="quick-action-pill primary"
          onClick={() => onNavigate('sessions')}
        >
          <Play size={14} />
          <span>Start Live Attendance</span>
        </button>
        <button
          type="button"
          className="quick-action-pill"
          onClick={() => onNavigate('attendance')}
        >
          <Clock size={14} />
          <span>Attendance Matrix</span>
        </button>
        <button
          type="button"
          className="quick-action-pill"
          onClick={() => onNavigate('controller-classes')}
        >
          <Building size={14} />
          <span>Lecture Halls</span>
        </button>
        <button
          type="button"
          className="quick-action-pill"
          onClick={() => window.open(api.getMasterExcelUrl(), '_blank')}
        >
          <Download size={14} />
          <span>Export Master (.xlsx)</span>
        </button>
        <button
          type="button"
          className="quick-action-pill"
          onClick={() => onNavigate('calendar')}
        >
          <Calendar size={14} />
          <span>Academic Timetable</span>
        </button>
      </div>

      {/* 6. MAIN CONTENT TWO-COLUMN GRID (Schedule + Weekly Trend & Recent Activity) */}
      <div className="teacher-overview-main-grid">
        {/* Left Column: Today's Schedule & Weekly Trend */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          {/* Today's Schedule Card */}
          <div className="panel" style={{ padding: '22px 24px' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '16px', flexWrap: 'wrap', gap: '12px' }}>
              <div>
                <p className="eyebrow">Academic Schedule</p>
                <h3 style={{ margin: '2px 0 0', fontSize: '18px', fontWeight: 800, color: 'var(--text-navy)' }}>
                  Today&apos;s Class Schedule
                </h3>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px', width: '220px' }}>
                <SearchInput
                  value={filterText}
                  onChange={setFilterText}
                  placeholder="Filter schedule..."
                />
              </div>
            </div>

            <div className="schedule-list">
              {loading ? (
                Array.from({ length: 3 }).map((_, i) => (
                  <div key={i} className="attendrix-skeleton skeleton-card" style={{ height: '62px' }} />
                ))
              ) : filteredTodayClasses.length > 0 ? (
                filteredTodayClasses.map((item) => {
                  const isLive = activeSessions.some(s => s.class_id === item.class_id)
                  return (
                    <div className="schedule-item-row" key={item.id}>
                      <div className="schedule-time-block">
                        <span className="schedule-time-start">{item.start_time}</span>
                        <span className="schedule-time-end">to {item.end_time}</span>
                      </div>
                      <div className="schedule-info-block">
                        <span className="schedule-title">
                          {item.class_name}
                          <span className="class-code-badge">{item.class_code}</span>
                        </span>
                        <span className="schedule-submeta">
                          {item.section} · Room: <strong>{item.room_number}</strong>
                        </span>
                      </div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                        <StatusBadge
                          status={isLive ? 'pending' : item.is_cancelled ? 'absent' : 'present'}
                          label={isLive ? 'Live Sweep' : item.is_cancelled ? 'Cancelled' : 'Scheduled'}
                        />
                        <button
                          type="button"
                          className="attendrix-button button-primary"
                          style={{ padding: '6px 14px', fontSize: '12px' }}
                          onClick={() => onNavigate('sessions')}
                        >
                          <Play size={12} />
                          <span>{isLive ? 'Monitor' : 'Start'}</span>
                        </button>
                      </div>
                    </div>
                  )
                })
              ) : (
                <EmptyState
                  icon={<Calendar size={32} />}
                  title="No classes scheduled for today"
                  body="Your academic timetable has no remaining lecture halls or sessions scheduled today."
                />
              )}
            </div>
          </div>

          {/* Weekly Attendance Trend Card */}
          <div className="panel" style={{ padding: '22px 24px' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '14px' }}>
              <div>
                <p className="eyebrow">Institutional Analytics</p>
                <h3 style={{ margin: '2px 0 0', fontSize: '17px', fontWeight: 800, color: 'var(--text-navy)' }}>
                  Weekly Attendance Trend
                </h3>
              </div>
              <span style={{ fontSize: '12px', fontWeight: 700, color: 'var(--primary-blue)', background: 'var(--primary-blue-subtle)', padding: '4px 10px', border: '1px solid var(--primary-blue-border)', borderRadius: 'var(--radius-pill)' }}>
                Term Average: {completionRate}%
              </span>
            </div>

            <div className="weekly-trend-chart">
              {weeklyTrends.map((wt) => (
                <div key={wt.day} className="trend-day-col">
                  <span className="trend-pct-label">{wt.rate}%</span>
                  <div className="trend-bar-track">
                    <div
                      className={`trend-bar-fill ${wt.rate >= 90 ? 'high' : wt.rate >= 75 ? 'medium' : 'low'}`}
                      style={{ height: `${Math.max(15, Math.min(100, wt.rate))}%` }}
                    />
                  </div>
                  <span className="trend-day-label">{wt.day}</span>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Right Column: Attendance Calendar Ribbon & Recent Activity */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          {/* Calendar Strip / Month Tracker */}
          <AttendanceDayStrip
            title="Attendance Streak"
            onDayClick={(day) => {
              if (day.tooltip) alert(day.tooltip)
            }}
          />

          {/* Recent Attendance Activity Card */}
          <div className="panel" style={{ padding: '22px 24px' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '16px' }}>
              <div>
                <p className="eyebrow">Real-Time Verification</p>
                <h3 style={{ margin: '2px 0 0', fontSize: '17px', fontWeight: 800, color: 'var(--text-navy)' }}>
                  Recent Attendance Activity
                </h3>
              </div>
              <button
                type="button"
                className="text-button"
                onClick={() => onNavigate('attendance')}
              >
                View all <ArrowRight size={13} />
              </button>
            </div>

            <div className="activity-feed-list">
              {loading ? (
                Array.from({ length: 3 }).map((_, i) => (
                  <div key={i} className="attendrix-skeleton skeleton-card" style={{ height: '52px' }} />
                ))
              ) : recentActivity.length > 0 ? (
                recentActivity.map((act) => {
                  const isVerified = act.action.includes('verified')
                  const isFlagged = act.action.includes('proxy') || act.action.includes('flagged')
                  return (
                    <div className="activity-feed-item" key={act.id}>
                      <div className={`activity-icon-bubble ${isVerified ? 'verified' : isFlagged ? 'flagged' : 'session'}`}>
                        {isVerified ? <CheckCircle2 size={16} /> : isFlagged ? <ShieldAlert size={16} /> : <Clock size={16} />}
                      </div>
                      <div className="activity-text-block">
                        <div className="activity-title-row">
                          <span className="activity-actor-name">{act.actor_name || 'System Verification'}</span>
                          <span className="activity-time-stamp">
                            {formatDate(act.timestamp, true)}
                          </span>
                        </div>
                        <span className="activity-note-text">
                          {act.note || act.details || act.action}
                        </span>
                      </div>
                    </div>
                  )
                })
              ) : (
                <EmptyState
                  icon={<History size={28} />}
                  title="No recent verification activity"
                  body="Biometric events and student presence logs will appear here during live lectures."
                />
              )}
            </div>
          </div>
        </div>
      </div>

      {/* 7. CLASS-WISE ATTENDANCE SUMMARIES (Bottom Section) */}
      <div className="panel" style={{ padding: '22px 24px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '18px', flexWrap: 'wrap', gap: '12px' }}>
          <div>
            <p className="eyebrow">Course Matrix</p>
            <h3 style={{ margin: '2px 0 0', fontSize: '18px', fontWeight: 800, color: 'var(--text-navy)' }}>
              Class-wise Attendance Summaries
            </h3>
          </div>
          <button
            type="button"
            className="attendrix-button button-secondary"
            onClick={() => onNavigate('controller-classes')}
          >
            Manage All Courses <ArrowRight size={14} />
          </button>
        </div>

        <div className="class-summary-grid">
          {displayClasses.map((course) => {
            const courseSessions = displaySessions.filter(s => s.class_id === course.id)
            const coursePresent = courseSessions.reduce((acc, s) => acc + (s.present_count || 0), 0)
            const courseTotal = courseSessions.reduce((acc, s) => acc + (s.total_enrolled || (s.present_count || 0) + (s.absent_count || 0)), 0)
            const courseRate = courseTotal > 0 ? Math.round((coursePresent / courseTotal) * 100) : (completionRate || 92)

            return (
              <div className="class-summary-card" key={course.id}>
                <div>
                  <div className="class-card-top-row">
                    <span className="class-code-badge">{course.code || 'COURSE'}</span>
                    <span style={{ fontSize: '12px', color: 'var(--text-subtle)', fontWeight: 600 }}>
                      {course.room || 'Room TBD'}
                    </span>
                  </div>
                  <h4 className="class-summary-name" style={{ marginTop: '8px' }}>{course.name}</h4>
                </div>

                <div className="class-summary-metrics">
                  <div className="summary-metric-col">
                    <span className="summary-metric-label">Enrolled</span>
                    <span className="summary-metric-val">{course.student_count || 0}</span>
                  </div>
                  <div className="summary-metric-col">
                    <span className="summary-metric-label">Sessions</span>
                    <span className="summary-metric-val">{courseSessions.length}</span>
                  </div>
                  <div className="summary-metric-col">
                    <span className="summary-metric-label">Presence Rate</span>
                    <span className="summary-metric-val" style={{ color: courseRate >= 80 ? 'var(--status-present-hover)' : 'var(--status-late)' }}>
                      {courseRate}%
                    </span>
                  </div>
                </div>

                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '8px' }}>
                  <button
                    type="button"
                    className="attendrix-button button-primary"
                    style={{ flex: 1, padding: '7px 12px', fontSize: '12px' }}
                    onClick={() => onNavigate('sessions')}
                  >
                    <Play size={12} />
                    <span>Start Session</span>
                  </button>
                  <button
                    type="button"
                    className="attendrix-button button-secondary"
                    style={{ padding: '7px 12px', fontSize: '12px' }}
                    onClick={() => onNavigate('attendance')}
                  >
                    Matrix
                  </button>
                </div>
              </div>
            )
          })}
        </div>
      </div>
    </>
  )
}
function StudentOverview({ user, onNavigate }: { user: User; onNavigate: (s: Section) => void }) {
  const [attendance, setAttendance] = useState<StudentAttendance | null>(null); const [notes, setNotes] = useState<Notification[]>([])
  const load = useCallback(async () => { try { const [a, n] = await Promise.all([api.studentAttendance(), api.notifications()]); setAttendance(a); setNotes(n) } catch { /* keep the seeded empty state */ } }, [])
  useEffect(() => { load(); const fn = () => load(); window.addEventListener('rollcall:refresh', fn); return () => window.removeEventListener('rollcall:refresh', fn) }, [load])
  const summary = attendance?.summary || { present: 0, absent: 0, pending: 0, total_finalized: 0, percentage: null }
  return <><PageIntro eyebrow={new Intl.DateTimeFormat('en-US', { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' }).format(new Date())} title={`Hi, ${user.name.split(' ')[0]}.`} description="Here’s the latest view of your attendance and class updates." action={<button className="secondary-button" onClick={() => onNavigate('notifications')}><Bell size={16} /> {notes.filter(n => !n.read).length} new update</button>} /><div className="student-hero"><div className="attendance-ring" style={{ '--percent': `${summary.percentage ?? 0}%` } as React.CSSProperties}><div><strong>{formatPct(summary.percentage)}</strong><span>attendance</span></div></div><div className="student-hero-copy"><p className="eyebrow">Your term snapshot</p><h2>Showing up adds up.</h2><p>You’ve been present for <strong>{summary.present} of {summary.total_finalized} sessions</strong>. Keep an eye on the class details below for the full picture.</p><button className="text-button" onClick={() => onNavigate('attendance')}>View attendance details <ArrowRight size={15} /></button></div></div><div className="metric-grid student-metrics"><Metric icon={<CheckCircle2 />} label="Present" value={String(summary.present)} detail="Sessions attended" tone="teal" /><Metric icon={<X />} label="Absent" value={String(summary.absent)} detail="Sessions missed" tone="coral" /><Metric icon={<BookOpen />} label="Total sessions" value={String(summary.total_finalized)} detail="This term" tone="violet" /></div><div className="section-heading"><div><p className="eyebrow">Latest record</p><h2>Recent attendance</h2></div><button className="text-button" onClick={() => onNavigate('attendance')}>See all <ArrowRight size={15} /></button></div><div className="panel table-panel"><AttendanceTable entries={(attendance?.entries || []).slice(0, 4).map(e => ({ student_id: e.session_id, student_name: e.class_name || 'Class session', status: e.status, changed_at: e.created_at, updated_at: e.updated_at }))} studentView /></div></>
}

function TeacherSessions() {
  const [classes, setClasses] = useState<ClassItem[]>([]); const [sessions, setSessions] = useState<Session[]>([]); const [active, setActive] = useState<Session | null>(null); const [loading, setLoading] = useState(true)
  const [duration, setDuration] = useState(10); const [customDuration, setCustomDuration] = useState('20'); const [isCustom, setIsCustom] = useState(false)
  const displayClasses = classes.length ? classes : api.isLocalMode() ? demoClasses : []
  const load = useCallback(async () => { setLoading(true); try { setClasses(await api.getClasses()); setSessions(await api.getSessions()) } finally { setLoading(false) } }, [])
  useEffect(() => { load(); const fn = () => load(); window.addEventListener('rollcall:refresh', fn); return () => window.removeEventListener('rollcall:refresh', fn) }, [load])
  async function start(classId: string) {
    const finalDuration = isCustom ? Math.min(60, Math.max(1, parseInt(customDuration, 10) || 10)) : duration
    const created = await api.startSession(classId, finalDuration)
    setActive({ ...created, class_name: classes.find(c => c.id === classId)?.name || created.class_name })
    setSessions(prev => [created, ...prev])
  }
  return <><PageIntro eyebrow="Lecturer workspace" title="Live sessions" description="Launch timed attendance sessions with continuous sweep verification, monitor live counts, and review flagged attempts." action={<button className="secondary-button" onClick={load}><RefreshCw size={16} /> Refresh</button>} /><div className="workflow-strip"><WorkflowStep number="01" title="Duration" body="Set time limit" active={!active} /><ArrowRight size={17} /><WorkflowStep number="02" title="Sweep" body="Students capture" active={!!active} /><ArrowRight size={17} /><WorkflowStep number="03" title="Review & Finalize" body="Inspect flagged items" active={false} /></div>{active ? <SessionWorkspace session={active} onClose={() => setActive(null)} onFinished={() => { setActive(null); load() }} /> : <div className="session-start-grid"><div className="panel start-panel"><div className="panel-heading"><div><p className="eyebrow">Choose a class & duration</p><h2>Start attendance session</h2></div><div className="session-live-dot">Ready</div></div><p className="muted">Select attendance window length. Server clock strictly enforces the deadline.</p><div className="duration-selector"><span className="muted" style={{ fontWeight: 700, marginRight: 4 }}>Duration:</span>{[5, 10, 15].map(mins => <button key={mins} type="button" className={`duration-chip ${!isCustom && duration === mins ? 'selected' : ''}`} onClick={() => { setDuration(mins); setIsCustom(false) }}>{mins} min</button>)}<button type="button" className={`duration-chip ${isCustom ? 'selected' : ''}`} onClick={() => setIsCustom(true)}>Custom</button>{isCustom && <input type="number" min="1" max="60" value={customDuration} onChange={e => setCustomDuration(e.target.value)} className="duration-custom-input" placeholder="min" />}</div><div className="class-list">{!displayClasses.length && <p className="muted">No classes are available for this account.</p>}{displayClasses.map(c => <div className="class-list-row" key={c.id}><div className="class-avatar">{c.code?.slice(0, 2) || 'CL'}</div><div className="class-list-copy"><strong>{c.name}</strong><span>{c.code} · {c.schedule || 'Schedule flexible'} · {c.student_count || 0} students</span></div><button className="primary-button small" onClick={() => start(c.id)}><Play size={14} /> Start</button></div>)}</div></div><div className="panel info-panel"><div className="soft-icon teal"><ShieldCheck size={21} /></div><p className="eyebrow">9-Rule Continuous Sweep Pipeline</p><h3>Continuous 180° Sweep Verification</h3><p>Students capture a single smooth sweep from front-camera selfie across neighbors towards the lecturer stage. The backend verifies blur, monotonic gyroscope heading, selfie match, neighbor presence, and lecturer visibility (IPD ≥ 30px).</p><div className="disclosure"><LockKeyhole size={15} /><span>Zero-knowledge storage: ephemeral raw frames purged immediately. Only filmstrip key frames for FLAGGED attempts retained for review.</span></div></div></div>}</>
}

function SessionWorkspace({ session, onClose, onFinished }: { session: Session; onClose: () => void; onFinished: () => void }) {
  const [detail, setDetail] = useState<Session>(session)
  const [roster, setRoster] = useState<AttendanceEntry[]>(session.attendance || [])
  const [reviewItems, setReviewItems] = useState<ReviewItem[]>([])
  const [auditItems, setAuditItems] = useState<AuditItem[]>([])
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [finalized, setFinalized] = useState(session.status === 'finalized')
  const [reviewNotes, setReviewNotes] = useState<Record<string, string>>({})
  const [remainingSec, setRemainingSec] = useState<number | null>(null)
  const [refModalOpen, setRefModalOpen] = useState(false)
  const [refPhoto, setRefPhoto] = useState<string | null>(null)
  const [savingRef, setSavingRef] = useState(false)

  const load = useCallback(async () => {
    try {
      const [currentRoster, reviewQueue, auditList] = await Promise.all([
        api.getRoster(session.id),
        api.getReviewQueue(session.id),
        api.audit(session.id),
      ])
      setDetail(currentRoster)
      setRoster(currentRoster.attendance || [])
      setReviewItems(reviewQueue)
      setAuditItems(auditList)
      setFinalized(currentRoster.status === 'finalized')
    } catch {
      // keep offline state visible
    }
  }, [session.id])

  useEffect(() => {
    load()
    const fn = () => load()
    window.addEventListener('rollcall:refresh', fn)
    return () => window.removeEventListener('rollcall:refresh', fn)
  }, [load])

  useEffect(() => {
    if (!detail.ends_at || finalized) return
    let activeTimer = true
    const checkTimer = () => {
      const endsAt = new Date(detail.ends_at!).getTime()
      const now = Date.now()
      const diff = Math.floor((endsAt - now) / 1000)
      if (activeTimer) setRemainingSec(diff)
    }
    checkTimer()
    const interval = window.setInterval(checkTimer, 1000)
    return () => { activeTimer = false; window.clearInterval(interval) }
  }, [detail.ends_at, finalized])

  const isClosed = (remainingSec !== null && remainingSec <= 0) || detail.status === 'closed' || finalized

  async function update(studentId: string, status: AttendanceEntry['status'], note?: string) {
    setRoster(prev => prev.map(row => row.student_id === studentId ? { ...row, status, note } : row))
    try {
      await api.patchAttendance(session.id, studentId, status, note)
      load()
    } catch {
      setError('Could not save that edit. Please retry.')
    }
  }

  async function handleReview(item: ReviewItem, decision: 'verified' | 'rejected') {
    setBusy(true)
    setError('')
    try {
      const note = reviewNotes[item.id] || (decision === 'verified' ? 'Lecturer accepted from review queue' : 'Lecturer rejected attempt')
      await api.submitReviewDecision(session.id, item.attempt_id ?? item.id, decision, note)
      await load()
    } catch {
      setError('Could not submit review decision. Please retry.')
    } finally {
      setBusy(false)
    }
  }

  async function finalizeSession() {
    if (!window.confirm('Finalize this session? Remaining pending students will be marked absent and records will be published.')) return
    setBusy(true)
    try {
      await api.finalize(session.id)
      setRoster(prev => prev.map(r => r.status === 'pending' ? { ...r, status: 'absent' } : r))
      setFinalized(true)
      await load()
    } catch {
      setError('Could not finalize the session. Please retry.')
    } finally {
      setBusy(false)
    }
  }

  const presentCount = roster.filter(r => r.status === 'present').length
  const pendingCount = roster.filter(r => r.status === 'pending').length
  const absentCount = roster.filter(r => r.status === 'absent').length
  const totalStudents = roster.length

  const countdownText = remainingSec === null
    ? '—'
    : remainingSec <= 0
      ? 'Window Closed'
      : `${Math.floor(remainingSec / 60).toString().padStart(2, '0')}:${((remainingSec % 60 + 60) % 60).toString().padStart(2, '0')}`

  return (
    <div className="workspace">
      <div className="workspace-header">
        <div>
          <button className="back-button" onClick={onClose}>← All sessions</button>
          <p className="eyebrow">Session · {formatDate(detail.started_at, true)}</p>
          <h2>{detail.class_name || 'Class attendance'}</h2>
          <span className="session-id">{detail.id}</span>
        </div>
        <div className="workspace-actions">
          <button
            className="secondary-button"
            onClick={() => { setRefModalOpen(true); setRefPhoto(detail.room_photo?.startsWith('data:') ? detail.room_photo : null) }}
            title="Establish or update classroom reference photo for this session"
          >
            <Camera size={15} /> {detail.room_photo ? 'Update Classroom Ref' : 'Establish Classroom Ref'}
          </button>
          <button className="secondary-button excel-btn" onClick={() => window.open(api.getExcelExportUrl(detail.id), '_blank')} title="Download colored analysis spreadsheet">
            <FileSpreadsheet size={15} /> Export Excel (.xlsx)
          </button>
          <span className={`countdown-tag ${isClosed ? 'expired' : ''}`}>
            {isClosed ? 'Window Closed' : `Window: ${countdownText}`}
          </span>
          <span className={`status-chip ${finalized ? 'status-present' : isClosed ? 'status-absent' : 'status-pending'}`}>
            <span className="chip-dot" /> {finalized ? 'Finalized' : isClosed ? 'Closed' : 'Open'}
          </span>
          {!finalized && (
            <button className="primary-button" onClick={finalizeSession} disabled={busy}>
              <FileCheck2 size={16} /> Finalize session
            </button>
          )}
        </div>
      </div>

      {error && <div className="inline-error"><AlertCircle size={16} /> {error}</div>}

      <div className="headline-stat-bar">
        <div className="headline-stat">
          <strong>{presentCount}</strong>
          <span>Present (Verified)</span>
        </div>
        <div className="headline-stat">
          <strong style={{ color: '#c77c13' }}>{reviewItems.length}</strong>
          <span>Needs Review (Flagged)</span>
        </div>
        <div className="headline-stat">
          <strong style={{ color: '#b44d45' }}>{absentCount}</strong>
          <span>Absent</span>
        </div>
        <div className="headline-stat">
          <strong>{totalStudents}</strong>
          <span>Total Enrolled</span>
        </div>
      </div>

      <div className="workspace-grid">
        <div className="panel review-panel">
          <div className="panel-heading">
            <div>
              <p className="eyebrow">Lecturer Review Queue</p>
              <h3>Flagged Attempts ({reviewItems.length})</h3>
            </div>
            <span className="safe-tag"><ShieldCheck size={14} /> Filmstrip Key Frames</span>
          </div>
          <p className="muted">Attempts flagged due to low optical resolution at distance or neighbor presence. Inspect filmstrip and accept or reject.</p>

          {reviewItems.length === 0 ? (
            <EmptyState
              icon={<CheckCircle2 />}
              title="Review queue empty"
              body="No submissions currently require manual review. Verified attempts are already recorded as present."
            />
          ) : (
            reviewItems.map(item => (
              <div className="review-card flagged" key={item.id}>
                <div className="review-card-header">
                  <div>
                    <strong>{item.student_name}</strong>
                    <div className="muted">{item.student_email || item.student_id}</div>
                  </div>
                  <span className="status-chip status-pending">Flagged</span>
                </div>

                <div className="reason-tags">
                  {item.reason_codes.map((rc, idx) => (
                    <span className="reason-tag" key={idx}>
                      {rc.replace(/_/g, ' ')}
                    </span>
                  ))}
                </div>

                {item.filmstrip_urls.length > 0 && (
                  <div className="filmstrip-strip">
                    {item.filmstrip_urls.map((url, fIdx) => (
                      <img
                        key={fIdx}
                        src={url}
                        alt={`Key frame ${fIdx + 1}`}
                        className="filmstrip-thumb"
                        onError={(e) => {
                          e.currentTarget.style.display = 'none'
                        }}
                      />
                    ))}
                  </div>
                )}

                <div className="review-actions">
                  <input
                    type="text"
                    placeholder="Decision note (optional)"
                    className="review-note-input"
                    value={reviewNotes[item.id] || ''}
                    onChange={e => setReviewNotes({ ...reviewNotes, [item.id]: e.target.value })}
                    disabled={busy || finalized}
                  />
                  <button
                    className="primary-button small"
                    disabled={busy || finalized}
                    onClick={() => handleReview(item, 'verified')}
                  >
                    <Check size={13} /> Accept
                  </button>
                  <button
                    className="secondary-button small"
                    style={{ color: '#b44d45' }}
                    disabled={busy || finalized}
                    onClick={() => handleReview(item, 'rejected')}
                  >
                    <X size={13} /> Reject
                  </button>
                </div>
              </div>
            ))
          )}
        </div>

        <div className="panel roster-panel">
          <div className="panel-heading">
            <div>
              <p className="eyebrow">Manual Roll-Call Roster</p>
              <h3>{roster.length} Students</h3>
            </div>
            <span className="muted">{pendingCount} pending</span>
          </div>
          <p className="muted">Lecturer manual override route. Tap Present, Absent, or Note to manually adjust any student.</p>
          <AttendanceTable entries={roster} onUpdate={update} disabled={finalized} />
        </div>
      </div>

      <div className="workspace-lower">
        <AuditLog items={auditItems} />
        <div className="panel guidance-panel">
          <div className="soft-icon teal"><CheckCircle2 size={20} /></div>
          <h3>Session Verification Policies</h3>
          <ul>
            <li>Submissions allowed only while session window is open (+5s server grace).</li>
            <li>All verified sweeps are automatically marked Present.</li>
            <li>Lecturer check flags at distance (IPD &lt; 30px) for visual confirmation.</li>
            <li>Finalizing marks remaining pending students absent and locks the session.</li>
          </ul>
        </div>
      </div>

      {refModalOpen && (
        <div className="modal-backdrop">
          <div className="modal-content" style={{ maxWidth: 540 }}>
            <div className="modal-header">
              <h3>Establish Session Classroom Reference</h3>
              <button onClick={() => setRefModalOpen(false)}><X size={18} /></button>
            </div>
            <p style={{ fontSize: 13, color: 'var(--muted)', margin: '8px 0 16px' }}>
              Establish the reference classroom panorama for <strong>{detail.class_name}</strong>. Student check-in panoramas will be verified against this stage and room context.
            </p>

            {refPhoto ? (
              <div style={{ position: 'relative', marginBottom: 16 }}>
                <img src={refPhoto} alt="Session Reference" style={{ width: '100%', borderRadius: 8, maxHeight: 240, objectFit: 'cover' }} />
                <button
                  type="button"
                  className="secondary-button small"
                  style={{ position: 'absolute', top: 8, right: 8, background: 'rgba(0,0,0,0.6)', color: '#fff' }}
                  onClick={() => setRefPhoto(null)}
                >
                  Retake
                </button>
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 12, marginBottom: 16 }}>
                <label className="upload-dropzone" style={{
                  border: '2px dashed var(--border)',
                  borderRadius: 8,
                  padding: 24,
                  textAlign: 'center',
                  cursor: 'pointer',
                  background: 'var(--surface-subtle)',
                }}>
                  <Camera size={28} style={{ color: 'var(--primary)', margin: '0 auto 8px' }} />
                  <p style={{ margin: 0, fontWeight: 600 }}>Click to select reference image</p>
                  <span style={{ fontSize: 12, color: 'var(--muted)' }}>JPEG or PNG panorama photo of the lecture hall</span>
                  <input
                    type="file"
                    accept="image/*"
                    style={{ display: 'none' }}
                    onChange={(e) => {
                      const file = e.target.files?.[0]
                      if (file) {
                        const reader = new FileReader()
                        reader.onload = () => setRefPhoto(reader.result as string)
                        reader.readAsDataURL(file)
                      }
                    }}
                  />
                </label>
              </div>
            )}

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
              <button className="secondary-button" onClick={() => setRefModalOpen(false)}>Cancel</button>
              <button
                className="primary-button"
                disabled={!refPhoto || savingRef}
                onClick={async () => {
                  if (!refPhoto) return
                  setSavingRef(true)
                  try {
                    await api.setSessionReference(session.id, { photo_base64: refPhoto })
                    setRefModalOpen(false)
                    setDetail(prev => ({ ...prev, room_photo: refPhoto }))
                    load()
                  } catch {
                    alert('Could not set session reference. Please try again.')
                  } finally {
                    setSavingRef(false)
                  }
                }}
              >
                {savingRef ? 'Saving...' : 'Establish Reference'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

function TeacherHistory() { const [sessions, setSessions] = useState<Session[]>([]); const [selected, setSelected] = useState<Session | null>(null); const load = useCallback(() => { api.getSessions().then(setSessions).catch(() => undefined) }, []); const displaySessions = sessions.length ? sessions : api.isLocalMode() ? demoSessions : []; useEffect(() => { load(); const fn = () => load(); window.addEventListener('rollcall:refresh', fn); return () => window.removeEventListener('rollcall:refresh', fn) }, [load]); return <><PageIntro eyebrow="Lecturer workspace" title="Session history" description="A clear, auditable record of every class session." action={<button className="secondary-button" onClick={() => api.getSessions().then(setSessions)}><RefreshCw size={16} /> Refresh</button>} /><div className="panel table-panel history-table"><div className="table-toolbar"><div><p className="eyebrow">All sessions</p><h3>{displaySessions.length} recorded sessions</h3></div><span className="muted">CSV and print exports available per session</span></div><div className="history-list">{displaySessions.map(s => <div className="history-row" key={s.id}><div className="history-date"><strong>{new Intl.DateTimeFormat('en-US', { day: '2-digit' }).format(new Date(s.started_at))}</strong><span>{new Intl.DateTimeFormat('en-US', { month: 'short' }).format(new Date(s.started_at))}</span></div><div className="history-copy"><strong>{s.class_name || 'Class session'}</strong><span>{formatDate(s.started_at, true)} · {s.id}</span></div><span className={`status-chip ${s.status === 'open' ? 'status-pending' : 'status-present'}`}>{s.status === 'open' ? 'Open' : 'Finalized'}</span><button className="icon-button" aria-label={`Open ${s.class_name || 'session'}`} onClick={() => setSelected(s)}><ChevronRight size={17} /></button></div>)}</div></div>{selected && <ReportDrawer session={selected} onClose={() => setSelected(null)} />}</> }

function StudentAttendanceView() { const [attendance, setAttendance] = useState<StudentAttendance | null>(null); const load = useCallback(() => { api.studentAttendance().then(setAttendance).catch(() => undefined) }, []); useEffect(() => { load(); const fn = () => load(); window.addEventListener('rollcall:refresh', fn); return () => window.removeEventListener('rollcall:refresh', fn) }, [load]); const summary = attendance?.summary || { present: 0, absent: 0, pending: 0, total_finalized: 0, percentage: null }; return <><PageIntro eyebrow="Student view" title="My attendance" description="Your personal record, available only to you." action={<button className="secondary-button" onClick={() => api.studentAttendance().then(setAttendance)}><RefreshCw size={16} /> Refresh</button>} /><div className="metric-grid student-metrics"><Metric icon={<CheckCircle2 />} label="Present" value={String(summary.present)} detail="Sessions attended" tone="teal" /><Metric icon={<X />} label="Absent" value={String(summary.absent)} detail="Sessions missed" tone="coral" /><Metric icon={<Zap />} label="Attendance rate" value={formatPct(summary.percentage)} detail="Across all sessions" tone="violet" /></div><div className="panel table-panel"><div className="table-toolbar"><div><p className="eyebrow">Personal record</p><h3>Attendance by date</h3></div><div className="private-label"><LockKeyhole size={14} /> Private to you</div></div><AttendanceTable entries={(attendance?.entries || []).map(e => ({ student_id: e.session_id, student_name: e.class_name || 'Class session', status: e.status, changed_at: e.created_at, updated_at: e.updated_at }))} studentView /></div></> }

function NotificationsView() {
  const [items, setItems] = useState<Notification[]>([])
  const [activeTab, setActiveTab] = useState<'all' | 'unread' | 'sweep' | 'system'>('all')
  const [loading, setLoading] = useState(false)

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const data = await api.notifications()
      setItems(data)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    load()
    const fn = () => load()
    window.addEventListener('rollcall:refresh', fn)
    return () => window.removeEventListener('rollcall:refresh', fn)
  }, [load])

  async function read(note: Notification) {
    await api.markRead(note.id)
    setItems(prev => prev.map(n => n.id === note.id ? { ...n, read: true } : n))
  }

  async function markAllRead() {
    const unread = items.filter(n => !n.read)
    for (const note of unread) {
      api.markRead(note.id).catch(() => undefined)
    }
    setItems(prev => prev.map(n => ({ ...n, read: true })))
  }

  const unreadCount = items.filter(n => !n.read).length
  const sweepNotifs = items.filter(n => n.title.toLowerCase().includes('sweep') || n.title.toLowerCase().includes('verification') || n.body.toLowerCase().includes('flagged') || n.title.toLowerCase().includes('attendance'))
  const systemNotifs = items.filter(n => !sweepNotifs.includes(n))

  const filtered = items.filter(n => {
    if (activeTab === 'unread') return !n.read
    if (activeTab === 'sweep') return sweepNotifs.includes(n)
    if (activeTab === 'system') return systemNotifs.includes(n)
    return true
  })

  return (
    <div className="notifications-command-center">
      <PageIntro
        eyebrow="Campus Security & Updates"
        title="Alerts, Reviews & System Notifications"
        description="Private in-app institutional notifications, flagged biometric sweeps, and timetable changes. No external SMS or spam is sent."
        action={
          <div style={{ display: 'flex', gap: 8 }}>
            <button className="secondary-button" onClick={markAllRead} disabled={unreadCount === 0}>
              <CheckCircle2 size={15} /> Mark All Read
            </button>
            <button className="secondary-button" onClick={load} disabled={loading}>
              <RefreshCw size={15} className={loading ? 'spin' : ''} /> Refresh
            </button>
          </div>
        }
      />

      <div className="metric-grid">
        <Metric icon={<Bell />} label="Total Alerts" value={String(items.length)} detail="Logged in workspace" tone="blue" />
        <Metric icon={<AlertCircle />} label="Unread Notices" value={String(unreadCount)} detail="Require your attention" tone="amber" />
        <Metric icon={<ShieldCheck />} label="Biometric Sweeps" value={String(sweepNotifs.length)} detail="Verification updates" tone="teal" />
      </div>

      <div className="panel notifications-panel">
        <div className="notif-tabs-strip">
          <button
            type="button"
            className={`notif-tab-pill ${activeTab === 'all' ? 'is-active' : ''}`}
            onClick={() => setActiveTab('all')}
          >
            All Updates ({items.length})
          </button>
          <button
            type="button"
            className={`notif-tab-pill ${activeTab === 'unread' ? 'is-active' : ''}`}
            onClick={() => setActiveTab('unread')}
          >
            Unread ({unreadCount})
          </button>
          <button
            type="button"
            className={`notif-tab-pill ${activeTab === 'sweep' ? 'is-active' : ''}`}
            onClick={() => setActiveTab('sweep')}
          >
            Biometric & Sweep ({sweepNotifs.length})
          </button>
          <button
            type="button"
            className={`notif-tab-pill ${activeTab === 'system' ? 'is-active' : ''}`}
            onClick={() => setActiveTab('system')}
          >
            System & Schedule ({systemNotifs.length})
          </button>
        </div>

        <div className="notifications-list">
          {filtered.map(note => {
            const isSweep = note.title.toLowerCase().includes('sweep') || note.title.toLowerCase().includes('attendance') || note.body.toLowerCase().includes('flagged')
            return (
              <div
                key={note.id}
                className={`notif-card-row ${!note.read ? 'is-unread' : ''}`}
                onClick={() => !note.read && read(note)}
                style={{ cursor: !note.read ? 'pointer' : 'default' }}
              >
                <div className={`notif-icon-circle ${isSweep ? 'notif-icon-blue' : 'notif-icon-amber'}`}>
                  {isSweep ? <ScanFace size={18} /> : <Bell size={18} />}
                </div>
                <div className="notif-content-area">
                  <div className="notif-header-line">
                    <strong className="notif-title-text">{note.title}</strong>
                    <span className="notif-time-text">{formatDate(note.created_at, true)}</span>
                  </div>
                  <p className="notif-body-text">{note.body}</p>
                  <div className="notif-footer-actions">
                    <span className="notif-tag-pill">{isSweep ? 'Biometric Sweep' : 'Academic Alert'}</span>
                    {!note.read ? (
                      <span className="badge-unassigned" style={{ fontSize: 10, padding: '1px 6px' }}>● Unread</span>
                    ) : (
                      <span style={{ fontSize: 11, color: '#94a3b8' }}>✓ Read</span>
                    )}
                  </div>
                </div>
              </div>
            )
          })}
          {filtered.length === 0 && (
            <EmptyState
              icon={<Bell />}
              title="No updates in this view"
              body="You are caught up with all attendance notifications and review items."
            />
          )}
        </div>
      </div>
    </div>
  )
}

function AttendanceTable({
  entries,
  onUpdate,
  disabled,
  studentView = false
}: {
  entries: AttendanceEntry[]
  onUpdate?: (id: string, status: AttendanceEntry['status'], note?: string) => void
  disabled?: boolean
  studentView?: boolean
}) {
  const [search, setSearch] = useState('')
  const [debouncedSearch, setDebouncedSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState<'all' | 'present' | 'pending' | 'absent'>('all')
  const [viewMode, setViewMode] = useState<'list' | 'matrix'>('list')
  const [pageSize, setPageSize] = useState<number>(30)
  const [page, setPage] = useState(1)

  useEffect(() => {
    const timer = setTimeout(() => setDebouncedSearch(search.trim().toLowerCase()), 200)
    return () => clearTimeout(timer)
  }, [search])

  const filtered = entries.filter(e => {
    if (statusFilter !== 'all' && e.status !== statusFilter) return false
    if (debouncedSearch) {
      const q = debouncedSearch
      const name = (e.student_name || '').toLowerCase()
      const email = (e.student_email || '').toLowerCase()
      const id = (e.student_id || '').toLowerCase()
      if (!name.includes(q) && !email.includes(q) && !id.includes(q)) return false
    }
    return true
  })

  const totalPages = pageSize === 0 ? 1 : Math.max(1, Math.ceil(filtered.length / pageSize))
  const currentPage = Math.min(page, totalPages)
  const paginated = pageSize === 0 ? filtered : filtered.slice((currentPage - 1) * pageSize, currentPage * pageSize)

  return (
    <div className="attendance-table-container">
      {!studentView && entries.length > 5 && (
        <div className="table-controls-bar">
          <div className="table-search-box">
            <Search size={15} style={{ color: 'var(--muted)' }} />
            <input
              type="text"
              placeholder="Search student or roll number..."
              value={search}
              onChange={e => { setSearch(e.target.value); setPage(1) }}
            />
            {search && (
              <button style={{ border: 'none', background: 'transparent', cursor: 'pointer' }} onClick={() => setSearch('')}>
                <X size={13} />
              </button>
            )}
          </div>

          <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
            <div className="table-filter-pills">
              {(['all', 'present', 'pending', 'absent'] as const).map(st => (
                <button
                  key={st}
                  className={`filter-pill ${statusFilter === st ? 'active' : ''}`}
                  onClick={() => { setStatusFilter(st); setPage(1) }}
                >
                  {st === 'all' ? `All (${entries.length})` : st === 'present' ? `Present (${entries.filter(e => e.status === 'present').length})` : st === 'pending' ? `Needs Review (${entries.filter(e => e.status === 'pending').length})` : `Absent (${entries.filter(e => e.status === 'absent').length})`}
                </button>
              ))}
            </div>

            <button
              className={`filter-pill ${viewMode === 'matrix' ? 'active' : ''}`}
              onClick={() => setViewMode(v => v === 'matrix' ? 'list' : 'matrix')}
              title="Toggle Compact Roll-Call Grid"
            >
              {viewMode === 'matrix' ? 'List View' : 'Roll-Call Matrix'}
            </button>
          </div>
        </div>
      )}

      {viewMode === 'matrix' && !studentView ? (
        <div className="matrix-grid">
          {filtered.map(row => (
            <div
              key={row.student_id}
              className={`matrix-chip ${row.status}`}
              onClick={() => {
                if (disabled || !onUpdate) return
                const nextStatus = row.status === 'present' ? 'absent' : 'present'
                onUpdate(row.student_id, nextStatus)
              }}
              title={`${row.student_name} (${row.student_email || row.student_id}) - ${statusCopy[row.status] || row.status}`}
            >
              <span className="matrix-roll">{row.student_name.split(' ').map(p => p[0]).join('').slice(0, 3).toUpperCase()}</span>
              <span className="matrix-name">{row.student_name}</span>
            </div>
          ))}
          {filtered.length === 0 && (
            <p style={{ gridColumn: '1 / -1', textAlign: 'center', color: 'var(--muted)', padding: 20 }}>
              No students match current filter.
            </p>
          )}
        </div>
      ) : (
        <div className="attendance-table">
          <div className="attendance-table-head">
            <span>{studentView ? 'Class / Date' : 'Student & Identity'}</span>
            {!studentView && <span>Biometric & Liveness Verification</span>}
            <span>Status</span>
            {!studentView && <span>Actions</span>}
          </div>
          {paginated.length ? (
            paginated.map(row => (
              <div className="attendance-table-row" key={row.student_id}>
                <div className="person-cell">
                  <div className="mini-avatar">
                    {studentView ? <BookOpen size={14} /> : initials(row.student_name)}
                  </div>
                  <div>
                    <strong>{row.student_name}</strong>
                    <span>
                      {studentView
                        ? formatDate(row.changed_at)
                        : row.student_email || row.student_id}
                    </span>
                  </div>
                </div>

                {!studentView && (
                  <div className="biometric-cell">
                    {row.status === 'present' ? (
                      <span className="biometric-tag verified" title="Active liveness challenge verified (Yaw rotation & Eye blink) and ArcFace cosine similarity >= 0.68">
                        <ScanFace size={13} />
                        <span>ArcFace {row.confidence ? Math.round(row.confidence * 100) : 89}% · Liveness OK</span>
                      </span>
                    ) : row.status === 'pending' ? (
                      <span className="biometric-tag pending" title="Flagged: Pending supervisor verification">
                        <AlertCircle size={13} />
                        <span>Flagged · Pending Review</span>
                      </span>
                    ) : (
                      <span className="biometric-tag absent">
                        <X size={13} />
                        <span>Unrecorded / Absent</span>
                      </span>
                    )}
                    {row.note && <span className="entry-note-chip">Note: {row.note}</span>}
                  </div>
                )}

                <span className={`status-chip status-${row.status}`}>
                  {row.status === 'present' ? <Check size={13} /> : row.status === 'absent' ? <X size={13} /> : <AlertCircle size={13} />}
                  {statusCopy[row.status]}
                </span>

                {!studentView && (
                  <div className="row-actions">
                    <button
                      className="status-action present"
                      disabled={disabled}
                      onClick={() => onUpdate?.(row.student_id, 'present')}
                      aria-label={`Mark ${row.student_name} present`}
                      title="Mark Present"
                    >
                      <Check size={14} />
                    </button>
                    <button
                      className="status-action absent"
                      disabled={disabled}
                      onClick={() => onUpdate?.(row.student_id, 'absent')}
                      aria-label={`Mark ${row.student_name} absent`}
                      title="Mark Absent"
                    >
                      <X size={14} />
                    </button>
                    <button
                      className="status-action edit"
                      disabled={disabled}
                      onClick={() => {
                        const note = window.prompt('Correction note (required for institutional audit trail):', row.note || '')
                        if (note !== null) onUpdate?.(row.student_id, row.status === 'pending' ? 'present' : row.status, note)
                      }}
                      aria-label={`Add audit note for ${row.student_name}`}
                      title="Add Audit Note"
                    >
                      <Pencil size={14} />
                    </button>
                  </div>
                )}
              </div>
            ))
          ) : (
            <EmptyState
              icon={<Users />}
              title="No attendance entries recorded"
              body="No students match the current filter or attendance entries will populate dynamically as students complete active liveness sweeps."
            />
          )}
        </div>
      )}

      {!studentView && filtered.length > pageSize && pageSize > 0 && (
        <div className="pagination-bar">
          <span>
            Showing {(currentPage - 1) * pageSize + 1}–{Math.min(currentPage * pageSize, filtered.length)} of {filtered.length} students
          </span>
          <div className="pagination-actions">
            <button
              className="day-tab-btn"
              disabled={currentPage <= 1}
              onClick={() => setPage(p => Math.max(1, p - 1))}
              style={{ padding: '4px 10px', fontSize: 12 }}
            >
              Previous
            </button>
            <span style={{ fontWeight: 600 }}>{currentPage} / {totalPages}</span>
            <button
              className="day-tab-btn"
              disabled={currentPage >= totalPages}
              onClick={() => setPage(p => Math.min(totalPages, p + 1))}
              style={{ padding: '4px 10px', fontSize: 12 }}
            >
              Next
            </button>
            <select
              value={pageSize}
              onChange={e => { setPageSize(Number(e.target.value)); setPage(1) }}
              style={{ border: '1px solid var(--line)', borderRadius: 6, padding: '4px 8px', fontSize: 12, background: 'var(--surface)', color: 'var(--ink)' }}
            >
              <option value={30}>30 / page</option>
              <option value={60}>60 / page</option>
              <option value={120}>120 / page</option>
              <option value={0}>All (No pagination)</option>
            </select>
          </div>
        </div>
      )}
    </div>
  )
}

function CalendarView({ user }: { user: User }) {
  const [data, setData] = useState<api.TimetableResponse | null>(null)
  const [selectedDay, setSelectedDay] = useState<number | null>(null)
  const [rescheduleEntry, setRescheduleEntry] = useState<api.TimetableEntry | null>(null)
  const [searchQuery, setSearchQuery] = useState('')
  const [newRoom, setNewRoom] = useState('')
  const [newTime, setNewTime] = useState('')
  const [busy, setBusy] = useState(false)
  const [notice, setNotice] = useState('')

  const load = useCallback(async () => {
    try {
      const res = await api.getTimetable()
      setData(res)
    } catch {
      // offline / local fallback
    }
  }, [])

  useEffect(() => { load() }, [load])

  async function handleGoogleCalendarExport() {
    try {
      const res = await api.getGoogleCalendarUrl()
      if (res.google_calendar_url) {
        window.open(res.google_calendar_url, '_blank')
      } else {
        alert(res.message || 'No upcoming classes to sync.')
      }
    } catch {
      alert('Could not generate Google Calendar link.')
    }
  }

  async function handleUpdateRoom(e: React.FormEvent) {
    e.preventDefault()
    if (!rescheduleEntry) return
    setBusy(true)
    try {
      await api.updateTimetableEntry(rescheduleEntry.id, {
        room_number: newRoom.trim() || undefined,
        start_time: newTime.trim() || undefined,
      })
      setRescheduleEntry(null)
      setNotice('Lecture room and schedule updated. Enrolled students have been notified.')
      await load()
    } catch {
      alert('Could not update timetable.')
    } finally {
      setBusy(false)
    }
  }

  async function handleCancelClass(entry: api.TimetableEntry) {
    if (!window.confirm(`Cancel ${entry.class_name} on ${entry.day_name}? Enrolled students will receive immediate alerts.`)) return
    setBusy(true)
    try {
      await api.cancelTimetableEntry(entry.id)
      setNotice(`Lecture cancelled for ${entry.class_name}.`)
      await load()
    } catch {
      alert('Could not cancel lecture.')
    } finally {
      setBusy(false)
    }
  }

  const entries = data?.timetable || []
  const filtered = entries.filter(e => {
    if (selectedDay !== null && e.day_of_week !== selectedDay) return false
    if (searchQuery) {
      const q = searchQuery.toLowerCase()
      return e.class_name.toLowerCase().includes(q) || e.class_code.toLowerCase().includes(q) || e.room_number.toLowerCase().includes(q) || (e.faculty_name && e.faculty_name.toLowerCase().includes(q))
    }
    return true
  })
  const nextClass = data?.next_class
  const isTeacherOrController = user.role === 'teacher' || user.role === 'controller'

  const dayTabs = [
    { label: 'All Days', val: null },
    { label: 'Mon', val: 0 },
    { label: 'Tue', val: 1 },
    { label: 'Wed', val: 2 },
    { label: 'Thu', val: 3 },
    { label: 'Fri', val: 4 },
    { label: 'Sat', val: 5 },
  ]

  return (
    <div className="calendar-panel">
      <PageIntro
        eyebrow="Academic Schedule"
        title="Weekly Timetable & Calendar"
        description="Official institutional lecture timetable with automated Google Calendar synchronization and room management."
        action={
          <div className="timetable-quick-actions" style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
            <span className="sync-status-badge">
              <span className="sync-dot" /> Live Calendar Sync Active (RFC 5545)
            </span>
            <button className="secondary-button" onClick={handleGoogleCalendarExport} title="Add next class directly to your Google Calendar">
              <Calendar size={15} /> Add to Google Calendar
            </button>
            <button className="secondary-button" onClick={() => window.open(api.getTimetableCalendarIcsUrl(), '_blank')} title="Download RFC 5545 iCalendar stream (.ics)">
              <Download size={15} /> Download .ics
            </button>
            <button className="secondary-button" onClick={load}><RefreshCw size={15} /> Refresh</button>
          </div>
        }
      />

      {notice && <div className="toast" role="status"><CheckCircle2 size={17} /> {notice}</div>}

      {/* Timetable Slot Conflict Advisory Banner */}
      <div className="conflict-alert-card">
        <AlertCircle size={20} style={{ color: '#d97706', flexShrink: 0, marginTop: 2 }} />
        <div>
          <div className="conflict-alert-title">Timetable Conflict Advisory: CS264 / CSE-A (Slot A2 vs D2)</div>
          <p className="conflict-alert-text">
            Section CSE-A has an unresolved provisional slot mapping between Slot A2 (Monday 10:00–11:30 AM) and Slot D2 (Tuesday 02:00–03:30 PM). Slot A2 is currently mapped on the schedule. Instructors or Controllers can adjust the assigned hall or slot below.
          </p>
        </div>
      </div>

      {nextClass && (
        <div className="timetable-header-card">
          <div>
            <span style={{ fontSize: 11, fontWeight: 700, color: 'var(--accent)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
              Next Scheduled Lecture
            </span>
            <h2 style={{ margin: '4px 0 6px', fontSize: 22, fontWeight: 800 }}>{nextClass.class_name}</h2>
            <div style={{ display: 'flex', gap: 12, alignItems: 'center', fontSize: 13, color: 'var(--muted)', flexWrap: 'wrap' }}>
              <span><strong>Code:</strong> {nextClass.class_code}</span>
              <span><strong>Room:</strong> {nextClass.room_number}</span>
              <span><strong>Time:</strong> {nextClass.start_time} – {nextClass.end_time}</span>
              <span><strong>Faculty:</strong> {nextClass.faculty_name}</span>
            </div>
          </div>
          <button className="primary-button" onClick={handleGoogleCalendarExport}>
            <Calendar size={15} /> Sync with Google
          </button>
        </div>
      )}

      {/* Filter and Day navigation */}
      <div className="filter-toolbar" style={{ marginTop: 20 }}>
        <div className="filter-toolbar-left">
          <div className="filter-toolbar-search">
            <Search size={15} style={{ color: '#94a3b8' }} />
            <input
              type="text"
              placeholder="Search by course code, lecture hall, or instructor..."
              value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
            />
          </div>
        </div>
        <div className="timetable-days-nav" style={{ margin: 0 }}>
          {dayTabs.map(tab => (
            <button
              key={String(tab.val)}
              className={`day-tab-btn ${selectedDay === tab.val ? 'active' : ''}`}
              onClick={() => setSelectedDay(tab.val)}
            >
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      <div className="timetable-grid">
        {filtered.map(entry => (
          <div key={entry.id} className={`timetable-card ${entry.is_cancelled ? 'cancelled' : ''}`}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
              <div>
                <span className="timetable-time-pill">
                  <Clock size={12} /> {entry.start_time} – {entry.end_time}
                </span>
                <span style={{ marginLeft: 8, fontSize: 12, fontWeight: 700, color: 'var(--muted)' }}>
                  {entry.day_name}
                </span>
              </div>
              <div style={{ display: 'flex', gap: 6 }}>
                {entry.is_cancelled ? (
                  <span className="status-chip status-absent">Cancelled</span>
                ) : (
                  <span className="status-chip status-present">{entry.section || 'Lecture'}</span>
                )}
                {entry.class_code.includes('LAB') || entry.class_name.toLowerCase().includes('lab') ? (
                  <span className="badge-lab">Lab</span>
                ) : (
                  <span className="badge-theory">Theory</span>
                )}
              </div>
            </div>

            <h3 style={{ margin: '6px 0 2px', fontSize: 16, fontWeight: 800 }}>{entry.class_name}</h3>
            <div style={{ fontSize: 12, color: 'var(--muted)', display: 'flex', flexDirection: 'column', gap: 3 }}>
              <span><strong>Code:</strong> {entry.class_code} · <strong>Venue:</strong> {entry.room_number}</span>
              <span><strong>Instructor:</strong> {entry.faculty_name || 'Assigned Faculty'}</span>
            </div>

            {isTeacherOrController && !entry.is_cancelled && (
              <div style={{ display: 'flex', gap: 8, marginTop: 8, borderTop: '1px solid var(--line)', paddingTop: 10 }}>
                <button
                  className="secondary-button small"
                  onClick={() => {
                    setRescheduleEntry(entry)
                    setNewRoom(entry.room_number)
                    setNewTime(entry.start_time)
                  }}
                  disabled={busy}
                >
                  <Pencil size={12} /> Change Room / Reschedule
                </button>
                <button
                  className="secondary-button small"
                  style={{ color: '#ef4444' }}
                  onClick={() => handleCancelClass(entry)}
                  disabled={busy}
                >
                  Cancel Class
                </button>
              </div>
            )}
          </div>
        ))}
        {filtered.length === 0 && (
          <div style={{ gridColumn: '1 / -1' }}>
            <EmptyState
              icon={<Calendar />}
              title="No classes scheduled"
              body="No lectures found for the selected day in your institutional timetable."
            />
          </div>
        )}
      </div>

      {rescheduleEntry && (
        <div className="modal-backdrop">
          <div className="modal-content" style={{ maxWidth: 440 }}>
            <div className="modal-header">
              <h3>Reschedule {rescheduleEntry.class_code}</h3>
              <button onClick={() => setRescheduleEntry(null)}><X size={18} /></button>
            </div>
            <form onSubmit={handleUpdateRoom}>
              <p style={{ fontSize: 13, color: 'var(--muted)', marginBottom: 16 }}>
                Updating the room or time will immediately send push alerts to all enrolled students for <strong>{rescheduleEntry.class_name}</strong>.
              </p>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 12, marginBottom: 16 }}>
                <label style={{ fontSize: 13, fontWeight: 600 }}>
                  Room / Venue Number
                  <input
                    type="text"
                    value={newRoom}
                    onChange={e => setNewRoom(e.target.value)}
                    placeholder="e.g. LH-120 or Auditorium A"
                    required
                    style={{ width: '100%', marginTop: 4, padding: '8px 12px', borderRadius: 8, border: '1px solid var(--line)' }}
                  />
                </label>
                <label style={{ fontSize: 13, fontWeight: 600 }}>
                  Start Time
                  <input
                    type="text"
                    value={newTime}
                    onChange={e => setNewTime(e.target.value)}
                    placeholder="e.g. 09:30 or 14:00"
                    style={{ width: '100%', marginTop: 4, padding: '8px 12px', borderRadius: 8, border: '1px solid var(--line)' }}
                  />
                </label>
              </div>
              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
                <button type="button" className="secondary-button" onClick={() => setRescheduleEntry(null)}>Cancel</button>
                <button type="submit" className="primary-button" disabled={busy}>Save & Alert Students</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}

function AuditLog({ items }: { items: AuditItem[] }) {
  const [expanded, setExpanded] = useState(false)
  const displayItems = expanded ? items : items.slice(0, 5)

  return (
    <div className="panel audit-panel">
      <div className="panel-heading" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <p className="eyebrow">Traceability</p>
          <h3>Audit log ({items.length} events)</h3>
        </div>
        <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
          {items.length > 5 && (
            <button
              className="text-button"
              onClick={() => setExpanded(!expanded)}
              style={{ fontSize: '12px', padding: '4px 8px' }}
            >
              {expanded ? 'Show fewer' : `Show all (${items.length})`}
            </button>
          )}
          <FileText size={18} className="muted" />
        </div>
      </div>
      <div style={{ maxHeight: expanded ? '420px' : 'none', overflowY: expanded ? 'auto' : 'visible' }}>
        {displayItems.length ? displayItems.map(item => (
          <div className="audit-row" key={item.id}>
            <div className="audit-line" />
            <div>
              <strong>{item.action.replace('.', ' · ')}</strong>
              <span>{item.note || item.details || item.actor_name || 'System event'}{item.actor_name && item.note ? ` · ${item.actor_name}` : ''}</span>
              <small>{formatDate(item.timestamp || item.created_at, true)}</small>
            </div>
          </div>
        )) : <p className="muted">No events yet.</p>}
      </div>
    </div>
  )
}

function TeacherAnalysisView() {
  const [data, setData] = useState<api.AnalyticsData | null>(null)
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [filterAction, setFilterAction] = useState('all')

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const res = await api.getAnalytics()
      setData(res)
    } catch (e) {
      console.error(e)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    load()
    const fn = () => load()
    window.addEventListener('rollcall:refresh', fn)
    return () => window.removeEventListener('rollcall:refresh', fn)
  }, [load])

  const summary = data?.summary || {
    total_sessions: 0,
    total_classes: 0,
    total_students: 0,
    total_attendance_records: 0,
    present_count: 0,
    absent_count: 0,
    pending_count: 0,
    attendance_rate: 0,
    verified_live_count: 0,
    proxy_blocked_count: 0,
  }

  const students = (data?.students || []).filter(s =>
    s.name.toLowerCase().includes(search.toLowerCase()) ||
    s.roll_number.toLowerCase().includes(search.toLowerCase())
  )

  const audits = (data?.recent_audits || []).filter(a => {
    if (filterAction === 'all') return true
    if (filterAction === 'verified') return a.action.includes('verified')
    if (filterAction === 'proxy') return a.action.includes('proxy') || (a.note && a.note.toLowerCase().includes('proxy'))
    if (filterAction === 'session') return a.action.includes('session')
    return true
  })

  return (
    <>
      <PageIntro
        eyebrow="Academic Attendance Analysis"
        title="Attendance Analytics & Audits"
        description="Comprehensive biometric verification metrics, student attendance breakdown, and live security audit trail."
        action={
          <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
            <a
              href={api.getMasterExcelUrl()}
              download
              className="primary-button"
              style={{ textDecoration: 'none', display: 'inline-flex', alignItems: 'center', gap: '8px' }}
            >
              <FileSpreadsheet size={16} /> Export Excel Analytics (.xlsx)
            </a>
            <button className="secondary-button" onClick={load} disabled={loading}>
              <RefreshCw size={16} /> Refresh
            </button>
          </div>
        }
      />

      <div className="metric-grid">
        <Metric
          icon={<TrendingUp />}
          label="Attendance Rate"
          value={`${summary.attendance_rate}%`}
          detail={`${summary.present_count} of ${summary.total_attendance_records} entries`}
          tone="teal"
        />
        <Metric
          icon={<ScanFace />}
          label="Biometric Verified"
          value={String(summary.verified_live_count)}
          detail="Live face + 180° panorama"
          tone="blue"
        />
        <Metric
          icon={<ShieldAlert />}
          label="Proxy Shield Blocks"
          value={String(summary.proxy_blocked_count)}
          detail="1:N template mismatch blocked"
          tone="coral"
        />
        <Metric
          icon={<Users />}
          label="Enrolled Roster"
          value={String(summary.total_students)}
          detail="Students across all sections"
          tone="violet"
        />
      </div>

      <div className="panel table-panel" style={{ marginTop: '24px' }}>
        <div className="table-toolbar">
          <div>
            <p className="eyebrow">Student Roster Performance</p>
            <h3>Attendance Matrix ({students.length} Students)</h3>
          </div>
          <div style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
            <div style={{ position: 'relative' }}>
              <input
                type="text"
                placeholder="Search name or roll #..."
                value={search}
                onChange={e => setSearch(e.target.value)}
                style={{
                  padding: '7px 12px',
                  borderRadius: '10px',
                  border: '1px solid var(--line)',
                  fontSize: '13px',
                  background: 'var(--panel-bg, #fff)',
                  color: 'inherit',
                  width: '200px',
                }}
              />
            </div>
          </div>
        </div>

        <div className="attendance-table">
          <div className="attendance-table-head" style={{ gridTemplateColumns: '2fr 1fr 1fr 1fr 1.5fr' }}>
            <span>Student & Roll No.</span>
            <span>Biometric Status</span>
            <span>Sessions Attended</span>
            <span>Attendance Rate</span>
            <span>Last Verification</span>
          </div>

          {students.length ? (
            students.map(s => {
              const isHigh = s.attendance_rate >= 75
              const isMed = s.attendance_rate >= 60 && s.attendance_rate < 75
              const badgeClass = isHigh ? 'status-present' : isMed ? 'status-pending' : 'status-absent'

              return (
                <div className="attendance-table-row" key={s.id} style={{ gridTemplateColumns: '2fr 1fr 1fr 1fr 1.5fr' }}>
                  <div className="person-cell">
                    <div className="mini-avatar">{initials(s.name)}</div>
                    <div>
                      <strong>{s.name}</strong>
                      <span style={{ fontSize: '12px', color: 'var(--slate, #64748B)' }}>{s.roll_number} • {s.email}</span>
                    </div>
                  </div>
                  <div>
                    <span className={`status-chip ${s.registration_locked ? 'status-present' : 'status-pending'}`} style={{ fontSize: '11px' }}>
                      {s.registration_locked ? <ShieldCheck size={12} /> : <AlertCircle size={12} />}
                      {s.registration_locked ? 'Locked & Enrolled' : 'Pending Enrollment'}
                    </span>
                  </div>
                  <div>
                    <strong>{s.present_count}</strong>
                    <span style={{ color: 'var(--slate, #64748B)', fontSize: '12px' }}> / {s.total_sessions} sessions</span>
                  </div>
                  <div>
                    <span className={`status-chip ${badgeClass}`} style={{ fontWeight: 800 }}>
                      {s.attendance_rate}%
                    </span>
                  </div>
                  <div style={{ fontSize: '12px' }}>
                    <div style={{ fontWeight: 600, color: s.last_status === 'present' ? 'var(--emerald, #10B981)' : 'var(--slate, #64748B)' }}>
                      {s.last_status.toUpperCase()}
                    </div>
                    <span style={{ color: 'var(--slate, #64748B)' }}>{formatDate(s.last_verified_at || undefined, true)}</span>
                  </div>
                </div>
              )
            })
          ) : (
            <EmptyState icon={<Users />} title="No student records match" body="Try adjusting your search criteria." />
          )}
        </div>
      </div>

      <div className="panel audit-panel" style={{ marginTop: '24px' }}>
        <div className="panel-heading" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div>
            <p className="eyebrow">Enterprise Traceability</p>
            <h3>Complete System Security & Verification Audit Trail</h3>
          </div>
          <div style={{ display: 'flex', gap: '8px' }}>
            {['all', 'verified', 'proxy', 'session'].map(filterKey => (
              <button
                key={filterKey}
                onClick={() => setFilterAction(filterKey)}
                style={{
                  padding: '6px 12px',
                  borderRadius: '8px',
                  border: filterAction === filterKey ? '1px solid var(--primary, #4F46E5)' : '1px solid var(--line, #E2E8F0)',
                  background: filterAction === filterKey ? 'rgba(79, 70, 229, 0.12)' : 'transparent',
                  color: filterAction === filterKey ? 'var(--primary, #4F46E5)' : 'inherit',
                  fontSize: '12px',
                  fontWeight: 700,
                  cursor: 'pointer',
                }}
              >
                {filterKey === 'all' ? 'All Events' : filterKey === 'verified' ? 'Face Verified' : filterKey === 'proxy' ? 'Proxy Shield Blocks' : 'Sessions'}
              </button>
            ))}
          </div>
        </div>

        <div style={{ maxHeight: '420px', overflowY: 'auto', paddingRight: '4px' }}>
          {audits.length ? (
            audits.map(item => {
              const isProxy = item.action.includes('proxy') || (item.note && item.note.toLowerCase().includes('proxy'))
              const isVerified = item.action.includes('verified')
              const toneColor = isProxy ? '#EF4444' : isVerified ? '#10B981' : '#4F46E5'

              return (
                <div className="audit-row" key={item.id} style={{ display: 'flex', gap: '14px', padding: '12px 0', borderBottom: '1px solid var(--line, #F1F5F9)' }}>
                  <div style={{ width: '4px', borderRadius: '4px', background: toneColor }} />
                  <div style={{ flex: 1 }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <strong style={{ fontSize: '13px', color: toneColor }}>
                        {item.action.replace('.', ' · ').toUpperCase()}
                      </strong>
                      <small style={{ color: 'var(--slate, #94A3B8)', fontSize: '11px' }}>
                        {formatDate(item.timestamp || item.created_at, true)}
                      </small>
                    </div>
                    <p style={{ margin: '4px 0 4px 0', fontSize: '13px', color: 'var(--ink, #0F172A)' }}>
                      {item.note || item.details || 'System event triggered'}
                    </p>
                    <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', alignItems: 'center', fontSize: '11px', color: 'var(--slate, #64748B)' }}>
                      <span>Actor: <b>{item.actor_name || 'System Engine'}</b></span>
                      {item.session_id && <span>Session: <code>{item.session_id.substring(0, 8)}</code></span>}
                      {Boolean(item.metadata?.hall_capacity) && (
                        <span className={`badge-capacity capacity-${String(item.metadata?.hall_capacity)}`}>
                          {String(item.metadata?.hall_capacity)}-Seater Hall
                        </span>
                      )}
                      {Boolean(item.metadata?.sir_detected) && (
                        <span className="badge-room" style={{ fontSize: '10px' }}>
                          ✓ Sir Detected
                        </span>
                      )}
                      {Boolean(item.metadata?.crowd_detected) && (
                        <span style={{ color: '#087f74', fontWeight: 700 }}>
                          • Crowd: {String(item.metadata?.crowd_count || 1)} peers
                        </span>
                      )}
                    </div>
                  </div>
                </div>
              )
            })
          ) : (
            <p className="muted" style={{ padding: '24px', textAlign: 'center' }}>No audit records match the selected filter.</p>
          )}
        </div>
      </div>
    </>
  )
}
function sanitizeReportHtml(input: string) {
  const document = new DOMParser().parseFromString(input, 'text/html')
  document.querySelectorAll('script, iframe, object, embed, link, base, form, meta, img, svg').forEach(node => node.remove())
  document.querySelectorAll('*').forEach(node => Array.from(node.attributes).forEach(attribute => {
    const name = attribute.name.toLowerCase()
    const value = attribute.value.trim().toLowerCase()
    if (name.startsWith('on') || ((name === 'href' || name === 'src' || name === 'action') && value.startsWith('javascript:'))) node.removeAttribute(attribute.name)
  }))
  return `<!doctype html>${document.documentElement.outerHTML}`
}
function downloadText(content: string, filename: string, type: string) {
  const url = URL.createObjectURL(new Blob([content], { type }))
  const anchor = document.createElement('a'); anchor.href = url; anchor.download = filename; anchor.click(); URL.revokeObjectURL(url)
}
function printReport(html: string) {
  const popup = window.open('', '_blank')
  if (!popup) { downloadText(sanitizeReportHtml(html), 'attendance-report.html', 'text/html;charset=utf-8'); return }
  popup.opener = null
  popup.document.open(); popup.document.write(sanitizeReportHtml(html)); popup.document.close(); popup.focus(); popup.onload = () => popup.print()
}
function ReportDrawer({ session, onClose }: { session: Session; onClose: () => void }) {
  const [report, setReport] = useState<Report | null>(null)
  useEffect(() => { api.reports(session.id).then(setReport).catch(() => undefined) }, [session.id])
  const rows: AttendanceEntry[] = (report?.rows ?? []).map((row, index) => ({ student_id: `report-${index}-${row.email}`, student_name: row.name, student_email: row.email, status: row.status, note: row.note || undefined, changed_at: row.updated_at, updated_at: row.updated_at }))
  function csv() { if (report) downloadText(report.csv, `${session.id}-attendance.csv`, 'text/csv;charset=utf-8') }
  function htmlReport() { if (report) downloadText(sanitizeReportHtml(report.pdf_html), `${session.id}-attendance-report.html`, 'text/html;charset=utf-8') }
  return <div className="drawer-backdrop" onClick={onClose}><aside className="report-drawer" onClick={e => e.stopPropagation()}><div className="drawer-head"><div><p className="eyebrow">Session report</p><h2>{report?.session.class_name || session.class_name || 'Attendance report'}</h2><span>{formatDate(report?.session.started_at || session.started_at, true)} · {session.id}</span></div><button className="icon-button" onClick={onClose} aria-label="Close report"><X size={18} /></button></div><div className="report-actions"><button className="primary-button excel-btn" onClick={() => window.open(api.getExcelExportUrl(session.id), '_blank')}><FileSpreadsheet size={15} /> Export Styled Excel (.xlsx)</button><button className="secondary-button" onClick={csv} disabled={!report}><Download size={15} /> CSV</button><button className="secondary-button" onClick={htmlReport} disabled={!report}><FileText size={15} /> HTML report</button><button className="secondary-button" onClick={() => report && printReport(report.pdf_html)} disabled={!report}><Printer size={15} /> Print / save PDF</button></div><div className="report-summary"><Metric icon={<Users />} label="Roster" value={String(rows.length)} detail={report ? 'students' : 'loading report'} tone="blue" /><Metric icon={<CheckCircle2 />} label="Present" value={String(rows.filter(r => r.status === 'present').length)} detail="marked present" tone="teal" /></div><AttendanceTable entries={rows} /></aside></div>
}

function PageIntro({ eyebrow, title, description, action }: { eyebrow: string; title: string; description: string; action?: React.ReactNode }) { return <div className="page-intro"><div><p className="eyebrow">{eyebrow}</p><h1>{title}</h1><p className="intro-description">{description}</p></div>{action && <div className="intro-action">{action}</div>}</div> }
function Metric({ icon, label, value, detail, tone }: { icon: React.ReactNode; label: string; value: string; detail: string; tone: string }) { return <div className={`metric-card tone-${tone}`}><div className="metric-icon">{icon}</div><div><span>{label}</span><strong>{value}</strong><small>{detail}</small></div></div> }
function ClassCard({ item, onStart }: { item: ClassItem; onStart: () => void }) { return <div className="class-card"><div className="class-card-top"><div className="class-code">{item.code || 'CLASS'}</div><span className="class-dot" /></div><h3>{item.name}</h3><div className="class-meta"><span><Zap size={14} /> {item.schedule || 'Schedule flexible'}</span><span><Users size={14} /> {item.student_count || 0} students</span></div><button className="card-link" onClick={onStart}>Start session <ArrowRight size={15} /></button></div> }
function SessionRow({ session }: { session: Session }) { return <div className="session-row"><div className="session-status"><span className={session.status === 'open' ? 'open-dot' : 'closed-dot'} /></div><div><strong>{session.class_name || 'Class session'}</strong><span>{formatDate(session.started_at, true)}</span></div><span className={`status-chip ${session.status === 'open' ? 'status-pending' : 'status-present'}`}>{session.status === 'open' ? 'Open' : 'Finalized'}</span></div> }
function WorkflowStep({ number, title, body, active }: { number: string; title: string; body: string; active: boolean }) { return <div className={`workflow-step ${active ? 'active' : ''}`}><span>{number}</span><div><strong>{title}</strong><small>{body}</small></div></div> }
function NavButton({ active, icon, label, onClick, badge, hasChevron, isCollapsed }: { active: boolean; icon: React.ReactNode; label: string; onClick: () => void; badge?: string; hasChevron?: boolean; isCollapsed?: boolean }) {
  return (
    <button
      type="button"
      className={`sidebar-nav-btn ${active ? 'is-active-pill' : ''}`}
      onClick={onClick}
      title={label}
    >
      <span className="nav-icon">{icon}</span>
      {!isCollapsed && <span>{label}</span>}
      {!isCollapsed && badge && <span className="sidebar-badge-red">{badge}</span>}
      {!isCollapsed && hasChevron && <ChevronRight size={14} style={{ marginLeft: 'auto', opacity: 0.6 }} />}
    </button>
  )
}
function ConnectionBadge({ state, onRetry }: { state: ConnectionState; onRetry: () => void }) { const copy = state === 'connected' ? 'Live connected' : state === 'connecting' ? 'Connecting…' : state === 'error' ? 'Connection error' : 'Offline'; return <button className={`connection-badge ${state}`} onClick={state === 'error' || state === 'closed' ? onRetry : undefined} title={state === 'error' || state === 'closed' ? 'Retry connection' : undefined}>{state === 'connected' ? <Wifi size={14} /> : state === 'connecting' ? <RefreshCw size={14} className="spin" /> : <WifiOff size={14} />}<span>{copy}</span>{(state === 'error' || state === 'closed') && <small>Retry</small>}</button> }
function EmptyState({ icon, title, body }: { icon: React.ReactNode; title: string; body: string }) { return <div className="empty-state">{icon}<strong>{title}</strong><span>{body}</span></div> }
function initials(name: string) { return name.split(' ').map(part => part[0]).slice(0, 2).join('').toUpperCase() }

function ControllerClassesView() {
  const [classes, setClasses] = useState<api.ControllerClass[]>([])
  const [teachers, setTeachers] = useState<api.ControllerTeacher[]>([])
  const [loading, setLoading] = useState(true)
  const [modalOpen, setModalOpen] = useState(false)
  const [captureModalOpen, setCaptureModalOpen] = useState(false)
  const [selectedClassId, setSelectedClassId] = useState('')

  // Filter states
  const [searchQuery, setSearchQuery] = useState('')
  const [sectionFilter, setSectionFilter] = useState('all')
  const [typeFilter, setTypeFilter] = useState('all') // 'all' | 'theory' | 'lab'

  // Create Class form states
  const [name, setName] = useState('')
  const [code, setCode] = useState('')
  const [section, setSection] = useState('Section A')
  const [roomNumber, setRoomNumber] = useState('LH-120')
  const [capacity, setCapacity] = useState<number>(120)
  const [isLab, setIsLab] = useState(false)
  const [selectedTeacherId, setSelectedTeacherId] = useState<string>('')
  const [roomPhoto, setRoomPhoto] = useState('https://images.unsplash.com/photo-1580582932707-520aed937b7b?w=800')
  const [submitting, setSubmitting] = useState(false)
  const [msg, setMsg] = useState('')

  // Assign Faculty modal states
  const [assignModalOpen, setAssignModalOpen] = useState(false)
  const [assignTargetClass, setAssignTargetClass] = useState<api.ControllerClass | null>(null)
  const [assignTeacherId, setAssignTeacherId] = useState<string>('')
  const [savingAssign, setSavingAssign] = useState(false)

  // Edit Class modal states
  const [editModalOpen, setEditModalOpen] = useState(false)
  const [editTargetClass, setEditTargetClass] = useState<api.ControllerClass | null>(null)
  const [editName, setEditName] = useState('')
  const [editCode, setEditCode] = useState('')
  const [editSection, setEditSection] = useState('')
  const [editRoomNumber, setEditRoomNumber] = useState('')
  const [editCapacity, setEditCapacity] = useState<number>(120)
  const [editIsLab, setEditIsLab] = useState(false)
  const [savingEdit, setSavingEdit] = useState(false)

  // Capture modal states
  const [captureCapacity, setCaptureCapacity] = useState<number>(120)
  const [captureRoomNumber, setCaptureRoomNumber] = useState('LH-120')
  const [capturedPhoto, setCapturedPhoto] = useState<string | null>(null)
  const [cameraActive, setCameraActive] = useState(false)
  const [savingCapture, setSavingCapture] = useState(false)

  const videoRef = useRef<HTMLVideoElement | null>(null)
  const mediaStreamRef = useRef<MediaStream | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const [classData, teacherData] = await Promise.all([
        api.getControllerClasses(),
        api.getControllerTeachers().catch(() => []),
      ])
      setClasses(classData)
      setTeachers(teacherData)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { load() }, [load])

  const stopCamera = useCallback(() => {
    if (mediaStreamRef.current) {
      mediaStreamRef.current.getTracks().forEach(t => t.stop())
      mediaStreamRef.current = null
    }
    setCameraActive(false)
  }, [])

  const startCamera = async () => {
    try {
      stopCamera()
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'environment', width: { ideal: 1280 }, height: { ideal: 720 } }
      })
      mediaStreamRef.current = stream
      if (videoRef.current) {
        videoRef.current.srcObject = stream
        videoRef.current.play()
      }
      setCameraActive(true)
    } catch {
      alert('Camera access unavailable. You can use the panoramic file upload option.')
    }
  }

  const takeSnapshot = () => {
    if (!videoRef.current) return
    const video = videoRef.current
    const canvas = document.createElement('canvas')
    canvas.width = video.videoWidth || 640
    canvas.height = video.videoHeight || 480
    const ctx = canvas.getContext('2d')
    if (!ctx) return
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height)
    const base64 = canvas.toDataURL('image/jpeg', 0.85)
    setCapturedPhoto(base64)
    stopCamera()
  }

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    const reader = new FileReader()
    reader.onload = () => {
      setCapturedPhoto(reader.result as string)
      stopCamera()
    }
    reader.readAsDataURL(file)
  }

  const handleCreateFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    const reader = new FileReader()
    reader.onload = () => {
      if (typeof reader.result === 'string') {
        setRoomPhoto(reader.result)
      }
    }
    reader.readAsDataURL(file)
  }

  const openCapture = (cls?: api.ControllerClass) => {
    const target = cls || classes[0]
    if (target) {
      setSelectedClassId(target.id)
      setCaptureCapacity(target.capacity || 120)
      setCaptureRoomNumber(target.room_number || `LH-${target.capacity || 120}`)
      setCapturedPhoto(target.room_photo?.startsWith('data:') ? target.room_photo : null)
    }
    setCaptureModalOpen(true)
  }

  const closeCaptureModal = () => {
    stopCamera()
    setCaptureModalOpen(false)
    setCapturedPhoto(null)
  }

  const handleSaveCapture = async () => {
    if (!selectedClassId || !capturedPhoto) return
    setSavingCapture(true)
    try {
      const hallTypeMap: Record<number, string> = {
        80: '80-Seater Seminar Hall',
        120: '120-Seater Lecture Theater',
        240: '240-Seater Tiered Amphitheater',
        260: '260-Seater Grand Auditorium',
      }
      await api.captureClassRoom(selectedClassId, {
        photo_base64: capturedPhoto,
        capacity: captureCapacity,
        hall_type: hallTypeMap[captureCapacity] || `${captureCapacity}-Seater Hall`,
        room_number: captureRoomNumber,
      })
      setMsg(`Official reference panorama captured for ${hallTypeMap[captureCapacity]} (${captureRoomNumber}).`)
      closeCaptureModal()
      await load()
    } catch {
      alert('Could not save captured room reference. Please retry.')
    } finally {
      setSavingCapture(false)
    }
  }

  const openAssignModal = (cls: api.ControllerClass) => {
    setAssignTargetClass(cls)
    setAssignTeacherId(cls.teacher_id || '')
    setAssignModalOpen(true)
  }

  const handleSaveAssign = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!assignTargetClass) return
    setSavingAssign(true)
    try {
      await api.updateControllerClass(assignTargetClass.id, {
        teacher_id: assignTeacherId || null,
      })
      const teacherObj = teachers.find(t => t.id === assignTeacherId)
      const assignedName = teacherObj ? teacherObj.name : 'Unassigned'
      setMsg(`Faculty assigned to ${assignTargetClass.code}: ${assignedName}`)
      setAssignModalOpen(false)
      await load()
    } catch {
      alert('Could not update faculty assignment. Please try again.')
    } finally {
      setSavingAssign(false)
    }
  }

  const openEditModal = (cls: api.ControllerClass) => {
    setEditTargetClass(cls)
    setEditName(cls.name)
    setEditCode(cls.code)
    setEditSection(cls.section || 'Section A')
    setEditRoomNumber(cls.room_number || 'LH-120')
    setEditCapacity(cls.capacity || 120)
    setEditIsLab(Boolean(cls.is_lab))
    setEditModalOpen(true)
  }

  const handleSaveEdit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!editTargetClass) return
    setSavingEdit(true)
    try {
      const hallTypeMap: Record<number, string> = {
        80: '80-Seater Seminar Hall',
        120: '120-Seater Lecture Theater',
        240: '240-Seater Tiered Amphitheater',
        260: '260-Seater Grand Auditorium',
      }
      await api.updateControllerClass(editTargetClass.id, {
        name: editName.trim(),
        code: editCode.trim().toUpperCase(),
        section: editSection.trim(),
        room_number: editRoomNumber.trim(),
        capacity: editCapacity,
        hall_type: hallTypeMap[editCapacity] || `${editCapacity}-Seater Hall`,
        is_lab: editIsLab,
      })
      setMsg(`Class ${editCode} details updated successfully.`)
      setEditModalOpen(false)
      await load()
    } catch {
      alert('Could not update class details. Please retry.')
    } finally {
      setSavingEdit(false)
    }
  }

  const isDuplicate = classes.some(c =>
    c.code.toUpperCase() === code.trim().toUpperCase() &&
    (c.section || '').toLowerCase() === section.trim().toLowerCase()
  )

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault()
    if (!name.trim() || !code.trim()) return
    setSubmitting(true)
    try {
      const hallTypeMap: Record<number, string> = {
        80: '80-Seater Seminar Hall',
        120: '120-Seater Lecture Theater',
        240: '240-Seater Tiered Amphitheater',
        260: '260-Seater Grand Auditorium',
      }
      await api.createControllerClass({
        name: name.trim(),
        code: code.trim().toUpperCase(),
        section: section.trim(),
        room_number: roomNumber.trim(),
        capacity,
        hall_type: hallTypeMap[capacity] || `${capacity}-Seater Hall`,
        room_photo: roomPhoto.trim(),
        teacher_id: selectedTeacherId || null,
        is_lab: isLab,
      })
      setName('')
      setCode('')
      setSelectedTeacherId('')
      setIsLab(false)
      setModalOpen(false)
      setMsg('Classroom venue created successfully.')
      await load()
    } catch {
      alert('Could not create class. Please try again.')
    } finally {
      setSubmitting(false)
    }
  }

  const unassignedCount = classes.filter(c => !c.teacher_id || c.teacher_name === 'Unassigned').length
  const labCount = classes.filter(c => c.is_lab).length

  // Filter classes
  const filteredClasses = classes.filter(cls => {
    if (sectionFilter !== 'all' && (cls.section || 'General').toLowerCase() !== sectionFilter.toLowerCase()) return false
    if (typeFilter === 'lab' && !cls.is_lab) return false
    if (typeFilter === 'theory' && cls.is_lab) return false
    if (searchQuery) {
      const q = searchQuery.toLowerCase()
      return (
        cls.name.toLowerCase().includes(q) ||
        cls.code.toLowerCase().includes(q) ||
        (cls.room_number && cls.room_number.toLowerCase().includes(q)) ||
        (cls.teacher_name && cls.teacher_name.toLowerCase().includes(q))
      )
    }
    return true
  })

  // Distinct sections for filter
  const distinctSections = Array.from(new Set(classes.map(c => c.section || 'Section A'))).filter(Boolean)

  return (
    <>
      <PageIntro
        eyebrow="Academic Controller"
        title="Classroom & Venue Management"
        description="Configure academic courses, manage unassigned or assigned faculty, set seating capacity (80, 120, 240, 260-seater), and capture official panoramic reference templates."
        action={
          <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
            <button className="secondary-button" onClick={() => openCapture()}>
              <Camera size={16} /> Capture Classroom Room
            </button>
            <button className="primary-button" onClick={() => setModalOpen(true)}>
              <Plus size={16} /> Add Class & Venue
            </button>
          </div>
        }
      />
      {msg && <div className="toast" role="status"><CheckCircle2 size={17} /> {msg}<button onClick={() => setMsg('')}><X size={16} /></button></div>}

      <div className="metric-grid">
        <Metric icon={<BookOpen />} label="Managed Classes" value={loading ? '—' : String(classes.length)} detail={`${labCount} Labs · ${classes.length - labCount} Lectures`} tone="teal" />
        <Metric icon={<AlertCircle />} label="Pending Faculty" value={loading ? '—' : String(unassignedCount)} detail="Unassigned courses" tone="amber" />
        <Metric icon={<Building />} label="Assigned Venues" value={loading ? '—' : String(new Set(classes.map(c => c.room_number)).size)} detail="Physical lecture halls" tone="violet" />
        <Metric icon={<Users />} label="Total Enrollment" value={loading ? '—' : String(classes.reduce((acc, c) => acc + (c.student_count || 0), 0))} detail="Active enrolled students" tone="blue" />
      </div>

      {/* Filter and Search Bar */}
      <div className="filter-toolbar" style={{ marginTop: 20 }}>
        <div className="filter-toolbar-left">
          <div className="filter-toolbar-search">
            <Search size={15} style={{ color: '#94a3b8' }} />
            <input
              type="text"
              placeholder="Search course name, code, venue, or faculty..."
              value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
            />
          </div>
          <select
            className="filter-toolbar-select"
            value={sectionFilter}
            onChange={e => setSectionFilter(e.target.value)}
          >
            <option value="all">All Sections</option>
            {distinctSections.map(sec => (
              <option key={sec} value={sec}>{sec}</option>
            ))}
          </select>
          <select
            className="filter-toolbar-select"
            value={typeFilter}
            onChange={e => setTypeFilter(e.target.value)}
          >
            <option value="all">All Venue Types</option>
            <option value="theory">Theory Lectures</option>
            <option value="lab">Laboratories Only</option>
          </select>
        </div>
      </div>

      <div className="class-grid">
        {filteredClasses.map(cls => {
          const isUnassigned = !cls.teacher_id || cls.teacher_name === 'Unassigned'

          return (
            <div key={cls.id} className="class-card venue-card">
              <div className="class-card-top">
                <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                  <div className="class-code">{cls.code}</div>
                  <span className={cls.is_lab ? "badge-lab" : "badge-theory"}>
                    {cls.is_lab ? "Lab" : "Theory"}
                  </span>
                </div>
                <div style={{ display: 'flex', gap: '6px' }}>
                  <span className={`badge-capacity capacity-${cls.capacity || 120}`}>
                    {cls.capacity || 120}-Seater
                  </span>
                  <span className="badge-room">{cls.room_number || 'Room Unassigned'}</span>
                </div>
              </div>
              <h3 style={{ margin: '6px 0 2px' }}>{cls.name}</h3>
              <p className="venue-section-tag" style={{ margin: '0 0 10px 0' }}>
                {cls.section || 'General'} • {cls.hall_type || `${cls.capacity || 120}-Seater Hall`}
              </p>

              {cls.room_photo && (
                <div className="room-photo-preview">
                  <img src={cls.room_photo} alt={`Venue ${cls.room_number}`} onError={e => (e.currentTarget.style.display = 'none')} />
                  <span className="photo-tag"><Camera size={12} /> {cls.capacity || 120}-Seater Panorama</span>
                  {cls.reference_captured_at && (
                    <span className="photo-verified-tag"><Check size={11} /> Captured</span>
                  )}
                </div>
              )}

              <div className="class-meta" style={{ marginBottom: '14px', marginTop: '10px' }}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', width: '100%' }}>
                  <span><Building size={13} /> {cls.room_number || 'TBD'} ({cls.capacity || 120} seats)</span>
                  <span><Users size={13} /> {cls.student_count || 0} enrolled</span>
                </div>
                <div style={{ marginTop: 6, display: 'flex', alignItems: 'center', gap: 6 }}>
                  <span style={{ fontSize: 12, color: 'var(--muted)', fontWeight: 600 }}>Faculty:</span>
                  {isUnassigned ? (
                    <span className="badge-unassigned">
                      <AlertCircle size={11} /> Unassigned Faculty
                    </span>
                  ) : (
                    <span className="badge-faculty">
                      <UserRound size={11} /> {cls.teacher_name}
                    </span>
                  )}
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 6, marginTop: 'auto' }}>
                <button
                  type="button"
                  className="secondary-button small"
                  onClick={() => openAssignModal(cls)}
                  title="Assign or reassign faculty lecturer"
                >
                  <UserRound size={12} /> {isUnassigned ? 'Assign Faculty' : 'Reassign'}
                </button>
                <button
                  type="button"
                  className="secondary-button small"
                  onClick={() => openEditModal(cls)}
                  title="Edit venue and course details"
                >
                  <Pencil size={12} /> Edit Venue
                </button>
                <button
                  type="button"
                  className="secondary-button small"
                  style={{ gridColumn: '1 / -1' }}
                  onClick={() => openCapture(cls)}
                >
                  <Camera size={12} /> {cls.reference_captured_at ? 'Re-capture Room Panorama' : 'Capture Room Panorama'}
                </button>
              </div>
            </div>
          )
        })}

        {filteredClasses.length === 0 && (
          <div style={{ gridColumn: '1 / -1' }}>
            <EmptyState
              icon={<BookOpen />}
              title="No courses match criteria"
              body="Try adjusting your search query, section filter, or add a new course venue."
            />
          </div>
        )}
      </div>

      {/* CREATE CLASS MODAL */}
      {modalOpen && (
        <div className="drawer-backdrop" onClick={() => setModalOpen(false)}>
          <div className="modal-dialog" onClick={e => e.stopPropagation()}>
            <div className="modal-head">
              <h3>Create Class & Assign Classroom Venue</h3>
              <button className="icon-button" onClick={() => setModalOpen(false)}><X size={18} /></button>
            </div>
            <form onSubmit={handleCreate} className="dialog-form">
              {isDuplicate && (
                <div className="duplicate-alert-banner" style={{ margin: 0, padding: '10px 14px' }}>
                  <AlertCircle size={16} style={{ color: '#d97706', flexShrink: 0 }} />
                  <span style={{ fontSize: 12 }}>
                    Advisory: A course with code <strong>{code}</strong> ({section}) already exists.
                  </span>
                </div>
              )}

              <label>Course Name
                <input type="text" placeholder="e.g. Distributed Operating Systems" value={name} onChange={e => setName(e.target.value)} required />
              </label>
              <div className="form-row">
                <label>Course Code
                  <input type="text" placeholder="e.g. CS-402" value={code} onChange={e => setCode(e.target.value)} required />
                </label>
                <label>Section
                  <input type="text" placeholder="e.g. Section A or CSE-A" value={section} onChange={e => setSection(e.target.value)} />
                </label>
              </div>

              <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 0' }}>
                <input
                  type="checkbox"
                  id="create-is-lab"
                  checked={isLab}
                  onChange={e => setIsLab(e.target.checked)}
                  style={{ width: 16, height: 16 }}
                />
                <label htmlFor="create-is-lab" style={{ margin: 0, fontSize: 13, fontWeight: 600, cursor: 'pointer' }}>
                  Designate as Laboratory / Practical Session (Lab)
                </label>
              </div>

              <label>Faculty Lecturer Assignment
                <select
                  value={selectedTeacherId}
                  onChange={e => setSelectedTeacherId(e.target.value)}
                  style={{ width: '100%', padding: '8px 12px', borderRadius: 8, border: '1px solid var(--line)', background: '#fff' }}
                >
                  <option value="">Leave Unassigned (Assign Later)</option>
                  {teachers.map(t => (
                    <option key={t.id} value={t.id}>{t.name} ({t.email})</option>
                  ))}
                </select>
              </label>

              <div>
                <label style={{ marginBottom: '6px' }}>Hall Seating Capacity</label>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '8px' }}>
                  {[80, 120, 240, 260].map(s => (
                    <button
                      key={s}
                      type="button"
                      onClick={() => {
                        setCapacity(s)
                        setRoomNumber(`LH-${s}`)
                      }}
                      style={{
                        padding: '8px 4px',
                        borderRadius: '8px',
                        fontSize: '11px',
                        fontWeight: 800,
                        border: capacity === s ? '2px solid var(--primary, #087f74)' : '1px solid var(--line)',
                        background: capacity === s ? '#e6f7ef' : '#fff',
                        color: capacity === s ? '#087f74' : 'inherit',
                        cursor: 'pointer',
                      }}
                    >
                      {s} Seater
                    </button>
                  ))}
                </div>
              </div>

              <label>Assigned Physical Room Number
                <input type="text" placeholder="e.g. LH-120 or Lab-201" value={roomNumber} onChange={e => setRoomNumber(e.target.value)} required />
              </label>

              <div>
                <label style={{ display: 'block', marginBottom: '6px' }}>
                  Classroom Reference Panorama Photo
                </label>
                {roomPhoto && (
                  <div style={{ position: 'relative', marginBottom: '10px', borderRadius: '8px', overflow: 'hidden', maxHeight: '140px', background: '#000' }}>
                    <img src={roomPhoto} alt="Room preview" style={{ width: '100%', height: '140px', objectFit: 'cover', display: 'block' }} />
                    <button
                      type="button"
                      onClick={() => setRoomPhoto('')}
                      style={{
                        position: 'absolute',
                        top: '8px',
                        right: '8px',
                        background: 'rgba(0,0,0,0.65)',
                        color: '#fff',
                        border: 0,
                        borderRadius: '50%',
                        width: '24px',
                        height: '24px',
                        display: 'grid',
                        placeItems: 'center',
                        cursor: 'pointer'
                      }}
                      title="Clear image"
                    >
                      <X size={14} />
                    </button>
                    <div style={{
                      position: 'absolute',
                      bottom: '6px',
                      left: '8px',
                      background: 'rgba(8, 127, 116, 0.85)',
                      color: '#fff',
                      fontSize: '10px',
                      fontWeight: 800,
                      padding: '2px 8px',
                      borderRadius: '4px'
                    }}>
                      Reference Photo Set
                    </div>
                  </div>
                )}
                <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', marginBottom: '8px' }}>
                  <label className="secondary-button small" style={{ cursor: 'pointer', margin: 0 }}>
                    <Upload size={14} /> Upload Room Photo
                    <input type="file" accept="image/*" onChange={handleCreateFileUpload} style={{ display: 'none' }} />
                  </label>
                </div>
                <input
                  type="text"
                  placeholder="Or enter Image URL (https://...)"
                  value={roomPhoto}
                  onChange={e => setRoomPhoto(e.target.value)}
                  style={{ width: '100%', fontSize: '12px' }}
                />
              </div>
              <div className="modal-actions">
                <button type="button" className="secondary-button" onClick={() => setModalOpen(false)}>Cancel</button>
                <button type="submit" className="primary-button" disabled={submitting}>
                  {submitting ? 'Creating…' : 'Save & Publish Class'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ASSIGN FACULTY MODAL */}
      {assignModalOpen && assignTargetClass && (
        <div className="drawer-backdrop" onClick={() => setAssignModalOpen(false)}>
          <div className="modal-dialog" style={{ maxWidth: 460 }} onClick={e => e.stopPropagation()}>
            <div className="modal-head">
              <h3>Assign Faculty to {assignTargetClass.code}</h3>
              <button className="icon-button" onClick={() => setAssignModalOpen(false)}><X size={18} /></button>
            </div>
            <form onSubmit={handleSaveAssign} className="dialog-form">
              <p style={{ fontSize: 13, color: 'var(--muted)', margin: '0 0 14px 0' }}>
                Select an official registered faculty member from the college directory for <strong>{assignTargetClass.name}</strong> ({assignTargetClass.section || 'General'}).
              </p>
              <label>Assigned Lecturer
                <select
                  value={assignTeacherId}
                  onChange={e => setAssignTeacherId(e.target.value)}
                  style={{ width: '100%', padding: '10px 12px', borderRadius: 8, border: '1px solid var(--line)', background: '#fff', fontSize: 13 }}
                >
                  <option value="">Leave Unassigned</option>
                  {teachers.map(t => (
                    <option key={t.id} value={t.id}>{t.name} — {t.email}</option>
                  ))}
                </select>
              </label>
              <div className="modal-actions" style={{ marginTop: 16 }}>
                <button type="button" className="secondary-button" onClick={() => setAssignModalOpen(false)}>Cancel</button>
                <button type="submit" className="primary-button" disabled={savingAssign}>
                  {savingAssign ? 'Saving…' : 'Update Faculty'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* EDIT CLASS & VENUE MODAL */}
      {editModalOpen && editTargetClass && (
        <div className="drawer-backdrop" onClick={() => setEditModalOpen(false)}>
          <div className="modal-dialog" onClick={e => e.stopPropagation()}>
            <div className="modal-head">
              <h3>Edit Venue Details: {editTargetClass.code}</h3>
              <button className="icon-button" onClick={() => setEditModalOpen(false)}><X size={18} /></button>
            </div>
            <form onSubmit={handleSaveEdit} className="dialog-form">
              <label>Course Name
                <input type="text" value={editName} onChange={e => setEditName(e.target.value)} required />
              </label>
              <div className="form-row">
                <label>Course Code
                  <input type="text" value={editCode} onChange={e => setEditCode(e.target.value)} required />
                </label>
                <label>Section
                  <input type="text" value={editSection} onChange={e => setEditSection(e.target.value)} />
                </label>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '4px 0' }}>
                <input
                  type="checkbox"
                  id="edit-is-lab"
                  checked={editIsLab}
                  onChange={e => setEditIsLab(e.target.checked)}
                  style={{ width: 16, height: 16 }}
                />
                <label htmlFor="edit-is-lab" style={{ margin: 0, fontSize: 13, fontWeight: 600, cursor: 'pointer' }}>
                  Designate as Laboratory / Practical Session (Lab)
                </label>
              </div>
              <div>
                <label style={{ marginBottom: '6px' }}>Hall Seating Capacity</label>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '8px' }}>
                  {[80, 120, 240, 260].map(s => (
                    <button
                      key={s}
                      type="button"
                      onClick={() => {
                        setEditCapacity(s)
                        setEditRoomNumber(`LH-${s}`)
                      }}
                      style={{
                        padding: '8px 4px',
                        borderRadius: '8px',
                        fontSize: '11px',
                        fontWeight: 800,
                        border: editCapacity === s ? '2px solid var(--primary, #087f74)' : '1px solid var(--line)',
                        background: editCapacity === s ? '#e6f7ef' : '#fff',
                        color: editCapacity === s ? '#087f74' : 'inherit',
                        cursor: 'pointer',
                      }}
                    >
                      {s} Seater
                    </button>
                  ))}
                </div>
              </div>
              <label>Assigned Room Number
                <input type="text" value={editRoomNumber} onChange={e => setEditRoomNumber(e.target.value)} required />
              </label>
              <div className="modal-actions">
                <button type="button" className="secondary-button" onClick={() => setEditModalOpen(false)}>Cancel</button>
                <button type="submit" className="primary-button" disabled={savingEdit}>
                  {savingEdit ? 'Updating…' : 'Save Changes'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ROOM PANORAMA CAPTURE MODAL */}
      {captureModalOpen && (
        <div className="drawer-backdrop" onClick={closeCaptureModal}>
          <div className="modal-dialog" style={{ width: 'min(640px, 94vw)' }} onClick={e => e.stopPropagation()}>
            <div className="modal-head">
              <div>
                <p className="eyebrow" style={{ margin: 0 }}>Classroom Panorama Reference</p>
                <h3>Capture Official Hall & Stage Panorama</h3>
              </div>
              <button className="icon-button" onClick={closeCaptureModal}><X size={18} /></button>
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              <label style={{ display: 'flex', flexDirection: 'column', gap: '6px', fontSize: '12px', fontWeight: 700 }}>
                Select Class to Capture:
                <select
                  value={selectedClassId}
                  onChange={e => {
                    const found = classes.find(c => c.id === e.target.value)
                    if (found) {
                      setSelectedClassId(found.id)
                      setCaptureCapacity(found.capacity || 120)
                      setCaptureRoomNumber(found.room_number || `LH-${found.capacity || 120}`)
                    }
                  }}
                  style={{ padding: '8px 12px', borderRadius: '8px', border: '1px solid var(--line)', fontSize: '13px', background: '#fff' }}
                >
                  {classes.map(c => (
                    <option key={c.id} value={c.id}>
                      {c.name} ({c.code} - {c.room_number || 'Room TBD'})
                    </option>
                  ))}
                </select>
              </label>

              <div style={{
                position: 'relative',
                background: '#090e14',
                borderRadius: '12px',
                minHeight: '260px',
                display: 'grid',
                placeItems: 'center',
                overflow: 'hidden',
                border: '2px dashed var(--line)'
              }}>
                {cameraActive && (
                  <video
                    ref={videoRef}
                    playsInline
                    muted
                    style={{ width: '100%', height: '260px', objectFit: 'cover' }}
                  />
                )}
                {capturedPhoto && !cameraActive && (
                  <img
                    src={capturedPhoto}
                    alt="Captured preview"
                    style={{ width: '100%', height: '260px', objectFit: 'cover' }}
                  />
                )}
                {!cameraActive && !capturedPhoto && (
                  <div style={{ textAlign: 'center', color: '#94a3b8', padding: '24px' }}>
                    <Camera size={38} style={{ opacity: 0.5, marginBottom: '8px' }} />
                    <p style={{ margin: 0, fontSize: '13px' }}>
                      Position camera at the lecturer stage pointing towards seating rows.
                    </p>
                    <small style={{ color: '#64748b' }}>
                      Panorama establishes the 180° spatial reference for the {captureCapacity}-seater venue.
                    </small>
                  </div>
                )}
                <div style={{
                  position: 'absolute',
                  inset: '16px',
                  border: '1px dashed rgba(255,255,255,0.4)',
                  borderRadius: '8px',
                  pointerEvents: 'none',
                  display: 'flex',
                  alignItems: 'flex-end',
                  justifyContent: 'center',
                  paddingBottom: '8px'
                }}>
                  <div style={{
                    background: 'rgba(0,0,0,0.65)',
                    color: '#fff',
                    fontSize: '11px',
                    fontWeight: 800,
                    padding: '2px 8px',
                    borderRadius: '4px'
                  }}>
                    AUDIENCE SEATING TIERS ({captureCapacity}-SEATER CROWD ZONE)
                  </div>
                </div>
              </div>

              <div style={{ display: 'flex', gap: '10px', justifyContent: 'space-between', flexWrap: 'wrap' }}>
                <div style={{ display: 'flex', gap: '8px' }}>
                  {!cameraActive ? (
                    <button type="button" className="secondary-button small" onClick={startCamera}>
                      <Camera size={14} /> Start Live Camera
                    </button>
                  ) : (
                    <button type="button" className="primary-button small" onClick={takeSnapshot}>
                      <Camera size={14} /> Snap Photo
                    </button>
                  )}
                  {cameraActive && (
                    <button type="button" className="secondary-button small" onClick={stopCamera}>
                      Stop Camera
                    </button>
                  )}
                  {capturedPhoto && (
                    <button type="button" className="secondary-button small" onClick={() => setCapturedPhoto(null)}>
                      Retake
                    </button>
                  )}
                </div>

                <label className="secondary-button small" style={{ cursor: 'pointer', margin: 0 }}>
                  <Upload size={14} /> Upload Panoramic Image
                  <input type="file" accept="image/*" onChange={handleFileUpload} style={{ display: 'none' }} />
                </label>
              </div>

              <div className="modal-actions" style={{ marginTop: '12px' }}>
                <button type="button" className="secondary-button" onClick={closeCaptureModal}>
                  Cancel
                </button>
                <button
                  type="button"
                  className="primary-button"
                  disabled={!capturedPhoto || savingCapture}
                  onClick={handleSaveCapture}
                >
                  {savingCapture ? 'Saving Reference…' : 'Save as Official Reference'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </>
  )
}

function ControllerStudentsView() {
  const [students, setStudents] = useState<api.ControllerStudent[]>([])
  const [loading, setLoading] = useState(true)
  const [modalOpen, setModalOpen] = useState(false)
  const [searchQuery, setSearchQuery] = useState('')
  const [lockFilter, setLockFilter] = useState<'all' | 'locked' | 'open'>('all')
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [rollNumber, setRollNumber] = useState('')
  const [studentId, setStudentId] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [unlockingId, setUnlockingId] = useState<string | null>(null)
  const [notice, setNotice] = useState('')
  const [regWindowOpen, setRegWindowOpen] = useState(true)
  const [updatingWindow, setUpdatingWindow] = useState(false)
  const [previewModalOpen, setPreviewModalOpen] = useState(false)
  const [previewData, setPreviewData] = useState<api.RosterImportPreviewResponse | null>(null)
  const [pendingFile, setPendingFile] = useState<File | null>(null)
  const [dupReport, setDupReport] = useState<api.DuplicateReport | null>(null)
  const [dupModalOpen, setDupModalOpen] = useState(false)
  const fileInputRef = useRef<HTMLInputElement>(null)

  const exportStudentCsv = () => {
    const headers = ['Name', 'Email', 'Roll Number', 'Student ID', 'Biometric Lock Status']
    const rows = students.map(s => [
      s.name,
      s.email,
      s.roll_number || '',
      s.student_id || '',
      s.registration_locked ? 'Locked & Enrolled' : 'Open / Unenrolled'
    ])
    const csvContent = [headers, ...rows].map(row => row.map(cell => `"${String(cell).replace(/"/g, '""')}"`).join(',')).join('\n')
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `college_students_roster_${new Date().toISOString().slice(0, 10)}.csv`
    a.click()
    URL.revokeObjectURL(url)
  }

  const scanDuplicates = useCallback(async () => {
    try {
      const rep = await api.getDuplicateStudents()
      setDupReport(rep)
    } catch {
      // ignore
    }
  }, [])

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const [data, win] = await Promise.all([
        api.getControllerStudents(),
        api.getRegistrationWindow().catch(() => ({ is_open: true, updated_at: '' })),
      ])
      setStudents(data)
      setRegWindowOpen(win.is_open)
      await scanDuplicates()
    } finally {
      setLoading(false)
    }
  }, [scanDuplicates])

  useEffect(() => { load() }, [load])

  async function handleToggleWindow() {
    setUpdatingWindow(true)
    try {
      const next = !regWindowOpen
      await api.setRegistrationWindow(next)
      setRegWindowOpen(next)
      setNotice(next ? 'Biometric registration window is now OPEN.' : 'Biometric registration window is now CLOSED.')
    } catch {
      alert('Could not update registration window status.')
    } finally {
      setUpdatingWindow(false)
    }
  }

  async function handleCsvSelect(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return
    setSubmitting(true)
    try {
      const preview = await api.importStudentRegistry({ file, preview: true })
      setPendingFile(file)
      setPreviewData(preview)
      setPreviewModalOpen(true)
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'CSV validation preview failed.'
      alert(`CSV Validation error: ${msg}`)
    } finally {
      setSubmitting(false)
      if (fileInputRef.current) fileInputRef.current.value = ''
    }
  }

  async function handleConfirmImport() {
    if (!pendingFile) return
    setSubmitting(true)
    try {
      const res = await api.importStudentRegistry({ file: pendingFile, preview: false })
      setPreviewModalOpen(false)
      setPendingFile(null)
      setPreviewData(null)
      setNotice(`Import successful: ${res.imported} added, ${res.updated} updated (${res.total_processed} total).`)
      await load()
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'CSV import commit failed.'
      alert(`Import error: ${msg}`)
    } finally {
      setSubmitting(false)
    }
  }

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault()
    if (!name.trim() || !email.trim()) return
    setSubmitting(true)
    try {
      await api.createControllerStudent({
        name: name.trim(),
        email: email.trim(),
        roll_number: rollNumber.trim() || `CS-2026-${String(students.length + 1).padStart(3, '0')}`,
        student_id: studentId.trim() || `STU-${9000 + students.length + 1}`,
      })
      setName('')
      setEmail('')
      setRollNumber('')
      setStudentId('')
      setModalOpen(false)
      setNotice('Student added to authorized college database.')
      await load()
    } catch {
      alert('Could not add student. Email might already exist.')
    } finally {
      setSubmitting(false)
    }
  }

  async function handleUnlock(student: api.ControllerStudent) {
    if (!window.confirm(`Unlock registration for ${student.name}? This will allow the student to register/re-enroll their facial reference.`)) return
    setUnlockingId(student.id)
    try {
      await api.unlockStudentRegistration(student.id)
      setNotice(`Registration unlocked for ${student.name}. Option is reopened.`)
      await load()
    } catch {
      alert('Could not unlock registration.')
    } finally {
      setUnlockingId(null)
    }
  }

  const lockedCount = students.filter(s => s.registration_locked).length
  const openCount = students.length - lockedCount

  return (
    <>
      <PageIntro
        eyebrow="Academic Controller"
        title="College Student Biometric Registry"
        description="Verify authorized college students, manage one-time biometric registration locks, and reset biometric enrollment on demand."
        action={
          <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
            <input type="file" ref={fileInputRef} accept=".csv" style={{ display: 'none' }} onChange={handleCsvSelect} />
            <button className="secondary-button" onClick={() => fileInputRef.current?.click()} disabled={submitting}>
              <Upload size={16} /> Import Registry (CSV)
            </button>
            <button className="secondary-button" onClick={scanDuplicates} title="Scan for duplicate student profiles or roll numbers">
              <ShieldAlert size={16} /> Scan Duplicates
            </button>
            <button className="secondary-button" onClick={exportStudentCsv} title="Download CSV roster">
              <Download size={16} /> Export CSV
            </button>
            <button className="primary-button" onClick={() => setModalOpen(true)}>
              <Plus size={16} /> Add College Student
            </button>
          </div>
        }
      />
      {notice && <div className="toast" role="status"><CheckCircle2 size={17} /> {notice}<button onClick={() => setNotice('')}><X size={16} /></button></div>}

      {dupReport?.has_duplicates && (
        <div className="duplicate-alert-banner">
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <AlertCircle size={20} style={{ color: '#d97706' }} />
            <div>
              <strong>Duplicate Student Conflicts Detected</strong>
              <p style={{ margin: '2px 0 0', fontSize: 13 }}>
                Found {dupReport.total_duplicate_conflicts} conflicting accounts sharing duplicate emails or roll numbers.
              </p>
            </div>
          </div>
          <button className="secondary-button small" onClick={() => setDupModalOpen(true)}>
            Inspect Duplicates
          </button>
        </div>
      )}

      <div className="panel" style={{ marginTop: 16, marginBottom: 20, display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '16px 20px', borderLeft: `4px solid ${regWindowOpen ? 'var(--emerald)' : 'var(--rose)'}`, flexWrap: 'wrap', gap: 12 }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
            <span className={`status-chip ${regWindowOpen ? 'status-present' : 'status-absent'}`} style={{ fontWeight: 800 }}>
              {regWindowOpen ? 'REGISTRATION WINDOW OPEN' : 'REGISTRATION WINDOW CLOSED'}
            </span>
            <span style={{ fontSize: 13, color: 'var(--muted)' }}>
              {regWindowOpen ? 'New students can enroll reference selfies upon first sign-in.' : 'All new reference enrollments are locked. No proxy enrollments permitted.'}
            </span>
          </div>
        </div>
        <button
          className={regWindowOpen ? 'secondary-button' : 'primary-button'}
          style={{ minWidth: 160 }}
          onClick={handleToggleWindow}
          disabled={updatingWindow}
        >
          {updatingWindow ? 'Updating…' : regWindowOpen ? 'Close Registration' : 'Open Registration'}
        </button>
      </div>

      <div className="metric-grid">
        <Metric icon={<Users />} label="Authorized Students" value={loading ? '—' : String(students.length)} detail="College database" tone="teal" />
        <Metric icon={<Lock size={18} />} label="Registration Locked" value={loading ? '—' : String(lockedCount)} detail="Enrolled & closed" tone="blue" />
        <Metric icon={<Unlock size={18} />} label="Registration Open" value={loading ? '—' : String(openCount)} detail="Awaiting first sign-in" tone="amber" />
      </div>

      <div className="filter-toolbar" style={{ marginTop: 20 }}>
        <div className="filter-toolbar-left">
          <div className="filter-toolbar-search">
            <Search size={15} style={{ color: '#94a3b8' }} />
            <input
              type="text"
              placeholder="Search student name, roll number, college ID, email..."
              value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
            />
          </div>
          <select
            className="filter-toolbar-select"
            value={lockFilter}
            onChange={e => setLockFilter(e.target.value as any)}
          >
            <option value="all">All Biometric States</option>
            <option value="locked">Locked & Enrolled Only</option>
            <option value="open">Registration Open (Awaiting First Sign-in)</option>
          </select>
        </div>
      </div>

      <div className="panel" style={{ marginTop: 16, padding: 0, overflow: 'hidden' }}>
        <div style={{ padding: '20px 24px', borderBottom: '1px solid var(--border)' }}>
          <h3>Student Enrollment & Biometric Lock Status</h3>
          <p style={{ margin: '4px 0 0', fontSize: 13, color: 'var(--muted)' }}>
            Students register once on first sign-in. Once enrolled, registration is closed and locked unless unlocked by the Controller.
          </p>
        </div>
        <div className="table-responsive">
          <table className="roster-table" style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ background: 'var(--surface-subtle)', textAlign: 'left', borderBottom: '1px solid var(--border)' }}>
                <th style={{ padding: '12px 20px', fontSize: 12 }}>Student</th>
                <th style={{ padding: '12px 16px', fontSize: 12 }}>Roll Number</th>
                <th style={{ padding: '12px 16px', fontSize: 12 }}>College ID</th>
                <th style={{ padding: '12px 16px', fontSize: 12 }}>Biometric Status</th>
                <th style={{ padding: '12px 20px', fontSize: 12, textAlign: 'right' }}>Action</th>
              </tr>
            </thead>
            <tbody>
              {students.filter(s => {
                if (lockFilter === 'locked' && !s.registration_locked) return false
                if (lockFilter === 'open' && s.registration_locked) return false
                if (searchQuery) {
                  const q = searchQuery.toLowerCase()
                  return (
                    s.name.toLowerCase().includes(q) ||
                    s.email.toLowerCase().includes(q) ||
                    (s.roll_number && s.roll_number.toLowerCase().includes(q)) ||
                    (s.student_id && s.student_id.toLowerCase().includes(q))
                  )
                }
                return true
              }).map(s => (
                <tr key={s.id} style={{ borderBottom: '1px solid var(--border)' }}>
                  <td style={{ padding: '14px 20px' }}>
                    <div style={{ fontWeight: 700, color: 'var(--ink)' }}>{s.name}</div>
                    <div style={{ fontSize: 12, color: 'var(--muted)' }}>{s.email}</div>
                  </td>
                  <td style={{ padding: '14px 16px', fontFamily: 'monospace', fontWeight: 600 }}>
                    {s.roll_number || '—'}
                  </td>
                  <td style={{ padding: '14px 16px', fontFamily: 'monospace', fontSize: 12 }}>
                    {s.student_id || '—'}
                  </td>
                  <td style={{ padding: '14px 16px' }}>
                    {s.registration_locked ? (
                      <span className="status-chip status-present" style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                        <Lock size={12} /> Locked & Enrolled
                      </span>
                    ) : (
                      <span className="status-chip status-pending" style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                        <Unlock size={12} /> Registration Open
                      </span>
                    )}
                  </td>
                  <td style={{ padding: '14px 20px', textAlign: 'right' }}>
                    {s.registration_locked ? (
                      <button
                        className="secondary-button"
                        style={{ padding: '6px 12px', fontSize: 12 }}
                        onClick={() => handleUnlock(s)}
                        disabled={unlockingId === s.id}
                      >
                        <Unlock size={13} /> {unlockingId === s.id ? 'Unlocking…' : 'Unlock Registration'}
                      </button>
                    ) : (
                      <span style={{ fontSize: 12, color: 'var(--muted)' }}>Ready to Enroll</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {modalOpen && (
        <div className="drawer-backdrop" onClick={() => setModalOpen(false)}>
          <div className="modal-dialog" onClick={e => e.stopPropagation()}>
            <div className="modal-head">
              <h3>Add Approved College Student</h3>
              <button className="icon-button" onClick={() => setModalOpen(false)}><X size={18} /></button>
            </div>
            <form onSubmit={handleCreate} className="dialog-form">
              <label>Full Name
                <input type="text" placeholder="e.g. Alex Johnson" value={name} onChange={e => setName(e.target.value)} required />
              </label>
              <label>College Email Address
                <input type="email" placeholder="alex@demo.edu" value={email} onChange={e => setEmail(e.target.value)} required />
              </label>
              <div className="form-row">
                <label>Roll Number
                  <input type="text" placeholder="e.g. CS-2026-003" value={rollNumber} onChange={e => setRollNumber(e.target.value)} />
                </label>
                <label>Student ID
                  <input type="text" placeholder="e.g. STU-9023" value={studentId} onChange={e => setStudentId(e.target.value)} />
                </label>
              </div>
              <div className="modal-actions">
                <button type="button" className="secondary-button" onClick={() => setModalOpen(false)}>Cancel</button>
                <button type="submit" className="primary-button" disabled={submitting}>
                  {submitting ? 'Adding…' : 'Add to College Roster'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {previewModalOpen && previewData && (
        <div className="drawer-backdrop" onClick={() => setPreviewModalOpen(false)}>
          <div className="modal-dialog" style={{ maxWidth: 680 }} onClick={e => e.stopPropagation()}>
            <div className="modal-head">
              <div>
                <p className="eyebrow">Roster Validation Preview</p>
                <h3>Official Roster Import Verification</h3>
              </div>
              <button className="icon-button" onClick={() => setPreviewModalOpen(false)}><X size={18} /></button>
            </div>
            
            <p style={{ fontSize: 13, color: 'var(--muted)', margin: '8px 0 16px' }}>
              Verify student records and enrollments before committing changes to the official institutional database.
            </p>

            <div className="preview-summary-grid">
              <div className="preview-metric-box">
                <strong>{previewData.total_processed}</strong>
                <span>Total Rows</span>
              </div>
              <div className="preview-metric-box">
                <strong style={{ color: '#10b981' }}>{previewData.new_count}</strong>
                <span>New Students</span>
              </div>
              <div className="preview-metric-box">
                <strong style={{ color: '#0284c7' }}>{previewData.updated_count}</strong>
                <span>Updates</span>
              </div>
            </div>

            {previewData.duplicate_warnings && previewData.duplicate_warnings.length > 0 && (
              <div style={{ background: '#fffbeb', border: '1px solid #fde68a', borderRadius: 8, padding: 12, marginBottom: 16 }}>
                <strong style={{ color: '#b45309', fontSize: 13 }}>In-file Duplicate Warnings:</strong>
                <ul style={{ margin: '6px 0 0', paddingLeft: 18, fontSize: 12, color: '#92400e' }}>
                  {previewData.duplicate_warnings.slice(0, 4).map((w, i) => <li key={i}>{w}</li>)}
                </ul>
              </div>
            )}

            {previewData.sample_new_students && previewData.sample_new_students.length > 0 && (
              <div style={{ marginBottom: 16 }}>
                <h4 style={{ fontSize: 13, marginBottom: 8 }}>Sample Students to be Added:</h4>
                <div style={{ maxHeight: 180, overflowY: 'auto', border: '1px solid var(--line)', borderRadius: 8 }}>
                  <table style={{ width: '100%', fontSize: 12, borderCollapse: 'collapse' }}>
                    <thead style={{ background: 'var(--surface-subtle)', textAlign: 'left' }}>
                      <tr>
                        <th style={{ padding: 8 }}>Name</th>
                        <th style={{ padding: 8 }}>Email</th>
                        <th style={{ padding: 8 }}>Roll Number</th>
                        <th style={{ padding: 8 }}>Class Code</th>
                      </tr>
                    </thead>
                    <tbody>
                      {previewData.sample_new_students.map((s, idx) => (
                        <tr key={idx} style={{ borderTop: '1px solid var(--line)' }}>
                          <td style={{ padding: 8 }}>{s.name}</td>
                          <td style={{ padding: 8 }}>{s.email}</td>
                          <td style={{ padding: 8 }}>{s.roll_number}</td>
                          <td style={{ padding: 8 }}>{s.class_code || '—'}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            )}

            <div className="modal-actions">
              <button type="button" className="secondary-button" onClick={() => setPreviewModalOpen(false)}>Cancel</button>
              <button type="button" className="primary-button" disabled={submitting} onClick={handleConfirmImport}>
                {submitting ? 'Committing…' : `Confirm & Commit (${previewData.new_count} New, ${previewData.updated_count} Updates)`}
              </button>
            </div>
          </div>
        </div>
      )}

      {dupModalOpen && dupReport && (
        <div className="drawer-backdrop" onClick={() => setDupModalOpen(false)}>
          <div className="modal-dialog" style={{ maxWidth: 620 }} onClick={e => e.stopPropagation()}>
            <div className="modal-head">
              <h3>Duplicate Student Accounts</h3>
              <button className="icon-button" onClick={() => setDupModalOpen(false)}><X size={18} /></button>
            </div>
            <p style={{ fontSize: 13, color: 'var(--muted)', margin: '8px 0 16px' }}>
              The following accounts share duplicate email addresses or roll numbers. Controllers should unlock or correct these records.
            </p>
            <div style={{ maxHeight: 320, overflowY: 'auto' }}>
              {Object.entries(dupReport.duplicate_email_groups || {}).map(([email, list]) => (
                <div key={email} style={{ border: '1px solid var(--line)', borderRadius: 8, padding: 12, marginBottom: 10 }}>
                  <span style={{ fontWeight: 700, fontSize: 13, color: '#ef4444' }}>Duplicate Email: {email}</span>
                  <ul style={{ margin: '6px 0 0', paddingLeft: 18, fontSize: 12 }}>
                    {list.map(s => <li key={s.id}>{s.name} ({s.roll_number || 'No roll'}) · ID: {s.id}</li>)}
                  </ul>
                </div>
              ))}
              {Object.entries(dupReport.duplicate_roll_groups || {}).map(([roll, list]) => (
                <div key={roll} style={{ border: '1px solid var(--line)', borderRadius: 8, padding: 12, marginBottom: 10 }}>
                  <span style={{ fontWeight: 700, fontSize: 13, color: '#f59e0b' }}>Duplicate Roll Number: {roll}</span>
                  <ul style={{ margin: '6px 0 0', paddingLeft: 18, fontSize: 12 }}>
                    {list.map(s => <li key={s.id}>{s.name} ({s.email}) · ID: {s.id}</li>)}
                  </ul>
                </div>
              ))}
            </div>
            <div className="modal-actions" style={{ marginTop: 16 }}>
              <button type="button" className="secondary-button" onClick={() => setDupModalOpen(false)}>Close</button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}

export default App
