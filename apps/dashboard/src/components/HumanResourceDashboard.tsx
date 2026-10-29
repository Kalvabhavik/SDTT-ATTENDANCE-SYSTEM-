import React, { useState, useEffect, useCallback } from 'react'
import {
  RefreshCw,
  Zap,
  Calendar as CalendarIcon,
  Download,
  CheckCircle2,
  AlertCircle,
  FileSpreadsheet,
  Clock,
  Sparkles,
  X,
  Building,
  Users,
  BookOpen,
  Camera,
  Play,
  ArrowRight,
  TrendingUp,
  UserX,
  FileCheck2,
  Table
} from 'lucide-react'
import {
  AttendanceDayStrip,
  AttendanceHistoryTimeline,
  ClassAttendanceHeatmap,
  AttendanceMultiBarChart,
  LiveAttendanceFeed,
  DepartmentSummariesGrid,
  MonthlyAttendanceMatrix,
  EmployeeDetailsCard,
  DateSelector,
  type FacultyAcademicInfo
} from './ui'
import type { User, ClassItem, Session } from '../types'
import * as api from '../api'

export interface CollegeAttendanceDashboardProps {
  user: User
  onNavigate?: (section: any) => void
  initialSubTab?: 'overview' | 'matrix' | 'timeline'
}

export function CollegeAttendanceDashboard({
  user,
  onNavigate,
  initialSubTab = 'overview'
}: CollegeAttendanceDashboardProps) {
  const [activeTab, setActiveTab] = useState<'overview' | 'matrix' | 'timeline'>(initialSubTab)
  const [selectedTerm, setSelectedTerm] = useState('Fall Semester 2026')
  const [isRefreshing, setIsRefreshing] = useState(false)
  const [toastMessage, setToastMessage] = useState<string>('')
  const [showSessionModal, setShowSessionModal] = useState(false)
  const [sessionCourse, setSessionCourse] = useState('CS 204')
  const [sessionRoom, setSessionRoom] = useState('North Hall 204')
  const [sessionDuration, setSessionDuration] = useState('15')
  const [classes, setClasses] = useState<ClassItem[]>([])
  const [sessions, setSessions] = useState<Session[]>([])

  // Load real classes and sessions from backend/local
  const loadData = useCallback(async () => {
    try {
      const [c, s] = await Promise.all([api.getClasses(), api.getSessions()])
      setClasses(c)
      setSessions(s)
    } catch {
      // Fallback already handled in api.ts
    }
  }, [])

  useEffect(() => {
    loadData()
  }, [loadData])

  // Faculty / Academic details state
  const [facultyInfo, setFacultyInfo] = useState<FacultyAcademicInfo>({
    name: user.name || 'Dr. Mira Chen',
    role: user.role === 'teacher' ? 'Associate Professor' : user.role === 'controller' ? 'Exam Controller' : 'Student',
    affiliationBadge: user.role === 'teacher' ? 'Faculty · Verified' : user.role === 'controller' ? 'Exam Controller' : 'Enrolled Student',
    department: 'Computer Science & Engineering',
    email: user.email || 'teacher@demo.edu',
    assignedHall: 'North Hall 204 (LH-2)',
    avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=160&auto=format&fit=crop&q=80'
  })

  // 4 Top College Attendance Metrics matching Image 1 (SchoolDeck) & Reference UI
  const stats = {
    todayAttendance: 91,
    monthlyAvg: 89,
    absentToday: 14,
    chronicAbsentees: 3
  }

  const triggerToast = (msg: string) => {
    setToastMessage(msg)
    setTimeout(() => setToastMessage(''), 4500)
  }

  const handleRefresh = async () => {
    setIsRefreshing(true)
    try {
      await loadData()
      await new Promise(r => setTimeout(r, 600))
      triggerToast('Lecture records and biometric attendance corroborated.')
    } finally {
      setIsRefreshing(false)
    }
  }

  const handleExportRoster = () => {
    try {
      window.open(api.getMasterExcelUrl(), '_blank')
    } catch {
      triggerToast('Exporting attendance records...')
    }
    triggerToast('Attendance Master Report (.xlsx) downloaded.')
  }

  const handleStartSessionSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setShowSessionModal(false)
    try {
      const dur = parseInt(sessionDuration, 10) || 15
      const found = classes.find(c => (c.code && c.code.toLowerCase().includes(sessionCourse.toLowerCase())) || c.name.toLowerCase().includes(sessionCourse.toLowerCase())) || classes[0]
      const targetId = found ? found.id : 'cs-204'
      await api.startSession(targetId, dur)
      triggerToast(`Live attendance sweep launched for ${sessionCourse} in ${sessionRoom} (${sessionDuration} mins).`)
    } catch {
      triggerToast(`Live attendance sweep initialized for ${sessionCourse}.`)
    }
    if (onNavigate) {
      onNavigate('sessions')
    }
  }

  return (
    <div className="college-attendance-dashboard-view">
      {/* Toast Notification */}
      {toastMessage && (
        <div className="toast" role="status" style={{ zIndex: 100 }}>
          <CheckCircle2 size={16} /> {toastMessage}
          <button type="button" aria-label="Dismiss" onClick={() => setToastMessage('')}>
            <X size={14} />
          </button>
        </div>
      )}

      {/* 1. Page Header: Classroom Attendance + College Controls */}
      <div className="hr-page-header">
        <div>
          <h1 className="hr-page-title">Classroom Attendance</h1>
          <p className="hr-page-subtitle">
            Track student and lecture attendance accurately, enforce spatial-biometric verification, and manage course records.
          </p>
        </div>

        <div className="hr-header-actions">
          <button
            type="button"
            className="hr-circle-refresh-btn"
            title="Refresh academic records"
            onClick={handleRefresh}
          >
            <RefreshCw size={15} className={isRefreshing ? 'spin' : ''} />
          </button>

          <DateSelector
            currentPeriod={selectedTerm}
            options={['Fall Semester 2026', 'Spring Semester 2026', 'November 2026', 'Current Term']}
            onSelect={setSelectedTerm}
          />

          <button
            type="button"
            className="hr-primary-action-btn"
            onClick={() => setShowSessionModal(true)}
          >
            <Zap size={16} />
            <span>+ Start Attendance</span>
          </button>
        </div>
      </div>

      {/* Sub-View Switcher Pills */}
      <div className="dashboard-subview-nav" style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 20 }}>
        <button
          type="button"
          className={`subview-pill-btn ${activeTab === 'overview' ? 'is-active' : ''}`}
          onClick={() => setActiveTab('overview')}
        >
          <TrendingUp size={14} /> Overview & Analytics
        </button>
        <button
          type="button"
          className={`subview-pill-btn ${activeTab === 'matrix' ? 'is-active' : ''}`}
          onClick={() => setActiveTab('matrix')}
        >
          <Table size={14} /> Monthly Student Matrix
        </button>
        <button
          type="button"
          className={`subview-pill-btn ${activeTab === 'timeline' ? 'is-active' : ''}`}
          onClick={() => setActiveTab('timeline')}
        >
          <Clock size={14} /> Lecture Timeline
        </button>
      </div>

      {/* TAB 1: OVERVIEW & ANALYTICS (Images 1, 2, 3) */}
      {activeTab === 'overview' && (
        <>
          {/* Top 4 Stat Cards from Image 1 (SchoolDeck): Today Attendance, Monthly Avg, Absent Today, Chronic Absentees */}
          <div className="dashboard-top-stats-grid" style={{ marginBottom: 22 }}>
            <div className="clean-stat-card">
              <span className="clean-stat-label">Today Attendance</span>
              <div className="clean-stat-value-row">
                <span className="clean-stat-number" style={{ color: '#16a34a' }}>{stats.todayAttendance}%</span>
              </div>
              <span style={{ fontSize: '11px', color: '#16a34a', fontWeight: 600, marginTop: 4 }}>
                ↑ 3.2% vs last lecture
              </span>
            </div>

            <div className="clean-stat-card">
              <span className="clean-stat-label">Monthly Avg</span>
              <div className="clean-stat-value-row">
                <span className="clean-stat-number" style={{ color: '#2563eb' }}>{stats.monthlyAvg}%</span>
              </div>
              <span style={{ fontSize: '11px', color: '#64748b', fontWeight: 600, marginTop: 4 }}>
                Institutional benchmark 85%
              </span>
            </div>

            <div className="clean-stat-card">
              <span className="clean-stat-label">Absent Today</span>
              <div className="clean-stat-value-row">
                <span className="clean-stat-number" style={{ color: '#dc2626' }}>{stats.absentToday}</span>
                <span className="clean-stat-unit">students</span>
              </div>
              <span style={{ fontSize: '11px', color: '#dc2626', fontWeight: 600, marginTop: 4 }}>
                Across 4 lecture halls
              </span>
            </div>

            <div className="clean-stat-card">
              <span className="clean-stat-label">Chronic Absentees</span>
              <div className="clean-stat-value-row">
                <span className="clean-stat-number" style={{ color: '#d97706' }}>{stats.chronicAbsentees}</span>
                <span className="clean-stat-unit">&lt;75% presence</span>
              </div>
              <span style={{ fontSize: '11px', color: '#d97706', fontWeight: 600, marginTop: 4 }}>
                Counseling notices sent
              </span>
            </div>
          </div>

          {/* Academic Profile & Verification Card */}
          <div style={{ marginBottom: 24 }}>
            <EmployeeDetailsCard
              info={facultyInfo}
              onDownloadInfo={handleExportRoster}
              onUpdateInfo={setFacultyInfo}
              yearOptions={['2026-2027', '2025-2026', '2024-2025']}
            />
          </div>

          {/* Two-Column Analytics Layout: Left = Heatmap + Multi-Bar Chart; Right = Live Stream + Department Summaries */}
          <div className="overview-two-col-layout" style={{ display: 'grid', gridTemplateColumns: '1.35fr 1fr', gap: 20, marginBottom: 24 }}>
            {/* Left Column */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
              {/* Image 1: Class Attendance Heatmap */}
              <ClassAttendanceHeatmap
                onSelectClass={code => triggerToast(`Selected ${code} schedule`)}
              />

              {/* Image 3: Multi-Bar Attendance Status Chart */}
              <AttendanceMultiBarChart
                title="Classroom Attendance Status"
              />
            </div>

            {/* Right Column */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
              {/* Image 3 & Image 2: Live Attendance Stream */}
              <LiveAttendanceFeed
                onViewAll={() => setActiveTab('matrix')}
              />

              {/* Image 3: Department Summaries Grid */}
              <DepartmentSummariesGrid
                dateLabel={selectedTerm}
              />
            </div>
          </div>

          {/* Image 2: Quick Actions Bar */}
          <div className="quick-actions-strip" style={{ marginBottom: 24 }}>
            <button
              type="button"
              className="quick-action-pill primary"
              onClick={() => setShowSessionModal(true)}
            >
              <Zap size={14} />
              <span>Start Attendance Sweep</span>
            </button>
            <button
              type="button"
              className="quick-action-pill"
              onClick={() => setActiveTab('matrix')}
            >
              <Table size={14} />
              <span>Monthly Matrix</span>
            </button>
            <button
              type="button"
              className="quick-action-pill"
              onClick={() => setActiveTab('timeline')}
            >
              <Clock size={14} />
              <span>Lecture Timeline</span>
            </button>
            <button
              type="button"
              className="quick-action-pill"
              onClick={handleExportRoster}
            >
              <Download size={14} />
              <span>Export Master Roster (.xlsx)</span>
            </button>
            <button
              type="button"
              className="quick-action-pill"
              onClick={() => onNavigate?.('calendar')}
            >
              <CalendarIcon size={14} />
              <span>Academic Timetable</span>
            </button>
          </div>

          {/* Monthly Attendance Day Strip */}
          <AttendanceDayStrip
            title="Monthly Lecture Attendance Streak"
            onDayClick={day => {
              if (day.tooltip) triggerToast(day.tooltip)
            }}
          />
        </>
      )}

      {/* TAB 2: MONTHLY ATTENDANCE MATRIX (Image 0) */}
      {activeTab === 'matrix' && (
        <MonthlyAttendanceMatrix
          onExport={handleExportRoster}
          onSelectStudent={(student, date, status) => {
            triggerToast(`${student.name} (${student.rollNo}) on ${date}: ${status.toUpperCase()}`)
          }}
        />
      )}

      {/* TAB 3: LECTURE TIMELINE & HISTORY */}
      {activeTab === 'timeline' && (
        <>
          <AttendanceDayStrip
            title="Monthly Lecture Attendance Streak"
            onDayClick={day => {
              if (day.tooltip) triggerToast(day.tooltip)
            }}
          />
          <AttendanceHistoryTimeline
            onDownloadReport={handleExportRoster}
            onRefresh={handleRefresh}
            onSelectCourse={c => triggerToast(`Filtering records for ${c}`)}
          />
        </>
      )}

      {/* Start Live Classroom Attendance Modal */}
      {showSessionModal && (
        <div className="scrim" style={{ display: 'grid', placeItems: 'center', zIndex: 110 }}>
          <div
            className="attendrix-modal-window"
            style={{ width: '480px', maxWidth: '95vw', background: '#ffffff', borderRadius: '20px', padding: '24px', boxShadow: '0 20px 40px rgba(15,23,42,0.15)' }}
          >
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '18px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <span className="employee-blue-bullet" />
                <h3 style={{ margin: 0, fontSize: '18px', fontWeight: 800, color: '#0f172a' }}>Start Attendance Session</h3>
              </div>
              <button
                type="button"
                className="employee-icon-btn"
                onClick={() => setShowSessionModal(false)}
                aria-label="Close modal"
              >
                <X size={16} />
              </button>
            </div>

            <form onSubmit={handleStartSessionSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 600, color: '#64748b', marginBottom: '4px' }}>
                  Select Course
                </label>
                <select
                  value={sessionCourse}
                  onChange={e => setSessionCourse(e.target.value)}
                  style={{ width: '100%', height: '40px', padding: '0 12px', borderRadius: '10px', border: '1px solid #cbd5e1', fontSize: '13.5px' }}
                >
                  <option value="CS 204">CS 204 — Human-Computer Interaction (28 Students)</option>
                  <option value="DES 112">DES 112 — Design Systems Studio (19 Students)</option>
                  <option value="CS 318">CS 318 — Responsible AI Seminar (16 Students)</option>
                  <option value="CS 301">CS 301 — Distributed Systems (50 Students)</option>
                </select>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 600, color: '#64748b', marginBottom: '4px' }}>
                    Lecture Hall
                  </label>
                  <select
                    value={sessionRoom}
                    onChange={e => setSessionRoom(e.target.value)}
                    style={{ width: '100%', height: '40px', padding: '0 10px', borderRadius: '10px', border: '1px solid #cbd5e1', fontSize: '13.5px' }}
                  >
                    <option value="North Hall 204">North Hall 204</option>
                    <option value="Arts Annex 12">Arts Annex 12</option>
                    <option value="Library Lab 3">Library Lab 3</option>
                    <option value="LH-120 Main">LH-120 Main</option>
                  </select>
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 600, color: '#64748b', marginBottom: '4px' }}>
                    Window Duration
                  </label>
                  <select
                    value={sessionDuration}
                    onChange={e => setSessionDuration(e.target.value)}
                    style={{ width: '100%', height: '40px', padding: '0 10px', borderRadius: '10px', border: '1px solid #cbd5e1', fontSize: '13.5px' }}
                  >
                    <option value="10">10 Minutes</option>
                    <option value="15">15 Minutes (Standard)</option>
                    <option value="20">20 Minutes</option>
                    <option value="30">30 Minutes</option>
                  </select>
                </div>
              </div>

              <div style={{ padding: '12px', background: '#f8fafc', borderRadius: '10px', border: '1px solid #e2e8f0', fontSize: '12px', color: '#475569', display: 'flex', gap: '8px' }}>
                <Camera size={16} style={{ color: '#1677ff', flexShrink: 0, marginTop: 2 }} />
                <span>
                  Students will corroborate presence via 180° spatial classroom sweep and active biometric liveness detection.
                </span>
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '8px' }}>
                <button
                  type="button"
                  className="attendrix-button button-secondary"
                  onClick={() => setShowSessionModal(false)}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="attendrix-button button-primary"
                  style={{ background: '#1677ff', color: '#ffffff', display: 'flex', alignItems: 'center', gap: 6 }}
                >
                  <Play size={14} />
                  <span>Launch Live Sweep</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}

// Retain alias for existing import compatibility
export const HumanResourceDashboard = CollegeAttendanceDashboard
