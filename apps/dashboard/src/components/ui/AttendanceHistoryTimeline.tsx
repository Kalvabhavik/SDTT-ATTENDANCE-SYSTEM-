import React, { useState } from 'react'
import {
  Calendar,
  Clock,
  Download,
  Filter,
  RefreshCw,
  Search,
  ArrowUpDown,
  BookOpen,
  Kanban,
  CheckCircle2,
  AlertCircle,
  Building,
  Users
} from 'lucide-react'

export interface CollegeLectureEntry {
  id: string
  dayOfWeek: string
  date: string
  courseCode: string
  courseName: string
  lectureHall: string
  clockIn: string
  clockOut: string
  attendanceRate: string
  enrolledRatio: string
  recessTime: string
  sessionType: string
  status: 'present' | 'late' | 'verified' | 'cancelled'
}

const DEFAULT_COLLEGE_LECTURES: CollegeLectureEntry[] = [
  {
    id: 'entry-1',
    dayOfWeek: 'Mon',
    date: '19 Nov 2026',
    courseCode: 'CS 204',
    courseName: 'Human-Computer Interaction',
    lectureHall: 'North Hall 204',
    clockIn: '10:00 am',
    clockOut: '01:00 pm',
    attendanceRate: '96%',
    enrolledRatio: '27/28 Enrolled',
    recessTime: '1.00 hr recess',
    sessionType: 'Verified Lecture',
    status: 'verified'
  },
  {
    id: 'entry-2',
    dayOfWeek: 'Tue',
    date: '20 Nov 2026',
    courseCode: 'DES 112',
    courseName: 'Design Systems Studio Lab',
    lectureHall: 'Arts Annex 12',
    clockIn: '10:00 am',
    clockOut: '01:00 pm',
    attendanceRate: '95%',
    enrolledRatio: '18/19 Enrolled',
    recessTime: '1.00 hr recess',
    sessionType: 'Verified Lab',
    status: 'verified'
  },
  {
    id: 'entry-3',
    dayOfWeek: 'Wed',
    date: '21 Nov 2026',
    courseCode: 'CS 318',
    courseName: 'Responsible AI Seminar',
    lectureHall: 'Library Lab 3',
    clockIn: '10:00 am',
    clockOut: '01:00 pm',
    attendanceRate: '94%',
    enrolledRatio: '15/16 Enrolled',
    recessTime: '1.00 hr recess',
    sessionType: 'Verified Lecture',
    status: 'verified'
  },
  {
    id: 'entry-4',
    dayOfWeek: 'Thu',
    date: '22 Nov 2026',
    courseCode: 'CS 301',
    courseName: 'Distributed Systems Core',
    lectureHall: 'LH-120 Main',
    clockIn: '10:00 am',
    clockOut: '01:00 pm',
    attendanceRate: '92%',
    enrolledRatio: '46/50 Enrolled',
    recessTime: '1.00 hr recess',
    sessionType: 'Verified Lecture',
    status: 'verified'
  }
]

const TIME_COLUMNS = [
  '09:00 am',
  '10:00 am',
  '11:00 am',
  '12:00 pm',
  '01:00 pm',
  '02:00 pm',
  '03:00 pm',
  '04:00 pm',
  '05:00 pm',
  '06:00 pm',
  '07:00 pm'
]

export interface AttendanceHistoryTimelineProps {
  entries?: CollegeLectureEntry[]
  onDownloadReport?: () => void
  onRefresh?: () => void
  onSelectCourse?: (courseCode: string) => void
}

export function AttendanceHistoryTimeline({
  entries = DEFAULT_COLLEGE_LECTURES,
  onDownloadReport,
  onRefresh,
  onSelectCourse
}: AttendanceHistoryTimelineProps) {
  const [viewMode, setViewMode] = useState<'timeline' | 'timecard'>('timeline')
  const [searchTerm, setSearchTerm] = useState('')
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc')
  const [selectedFilter, setSelectedFilter] = useState<string>('all')
  const [isFilterOpen, setIsFilterOpen] = useState(false)

  const filteredEntries = entries
    .filter(item => {
      const q = searchTerm.toLowerCase()
      const matchSearch =
        item.date.toLowerCase().includes(q) ||
        item.dayOfWeek.toLowerCase().includes(q) ||
        item.courseCode.toLowerCase().includes(q) ||
        item.courseName.toLowerCase().includes(q) ||
        item.lectureHall.toLowerCase().includes(q)
      if (selectedFilter === 'all') return matchSearch
      return matchSearch && (item.courseCode === selectedFilter || item.status === selectedFilter)
    })
    .sort((a, b) => {
      return sortOrder === 'asc' ? a.date.localeCompare(b.date) : b.date.localeCompare(a.date)
    })

  return (
    <div className="attendrix-history-section">
      {/* 1. Header: Lecture Attendance History + Refresh & Download */}
      <div className="history-section-header">
        <div>
          <h3 className="history-section-title">Lecture Attendance History</h3>
          <span style={{ fontSize: '12px', color: '#64748b' }}>
            Auditable classroom presence verified with ArcFace biometrics & spatial sweeps
          </span>
        </div>
        <div className="history-header-actions">
          <button
            type="button"
            className="topbar-circle-btn history-refresh-btn"
            title="Refresh lecture history"
            onClick={onRefresh}
          >
            <RefreshCw size={15} />
          </button>
          <button
            type="button"
            className="attendrix-button button-primary history-download-btn"
            onClick={onDownloadReport}
          >
            <Download size={14} />
            <span>Export Roster (.xlsx)</span>
          </button>
        </div>
      </div>

      {/* 2. Controls Toolbar: Roster / Timeline Toggle, Search, Filter, Sort */}
      <div className="history-controls-toolbar">
        <div className="view-mode-toggle-group">
          <button
            type="button"
            className={`view-mode-btn ${viewMode === 'timecard' ? 'is-active' : ''}`}
            onClick={() => setViewMode('timecard')}
          >
            <BookOpen size={14} />
            <span>Class Roster</span>
          </button>
          <button
            type="button"
            className={`view-mode-btn ${viewMode === 'timeline' ? 'is-active' : ''}`}
            onClick={() => setViewMode('timeline')}
          >
            <Kanban size={14} />
            <span>Lecture Timeline</span>
          </button>
        </div>

        <div className="history-filters-cluster">
          <div className="history-search-input-wrap">
            <Search size={14} className="history-search-icon" />
            <input
              type="text"
              placeholder="Search course, hall, date..."
              value={searchTerm}
              onChange={e => setSearchTerm(e.target.value)}
              className="history-search-input"
            />
          </div>

          <div style={{ position: 'relative' }}>
            <button
              type="button"
              className={`history-action-btn ${selectedFilter !== 'all' ? 'is-filtered' : ''}`}
              onClick={() => setIsFilterOpen(!isFilterOpen)}
            >
              <Filter size={14} />
              <span>{selectedFilter === 'all' ? 'All Courses' : selectedFilter}</span>
            </button>
            {isFilterOpen && (
              <div className="history-filter-menu">
                <button
                  type="button"
                  className={selectedFilter === 'all' ? 'is-active' : ''}
                  onClick={() => { setSelectedFilter('all'); setIsFilterOpen(false) }}
                >
                  All Courses
                </button>
                <button
                  type="button"
                  className={selectedFilter === 'CS 204' ? 'is-active' : ''}
                  onClick={() => { setSelectedFilter('CS 204'); setIsFilterOpen(false) }}
                >
                  CS 204 (HCI)
                </button>
                <button
                  type="button"
                  className={selectedFilter === 'DES 112' ? 'is-active' : ''}
                  onClick={() => { setSelectedFilter('DES 112'); setIsFilterOpen(false) }}
                >
                  DES 112 (Design)
                </button>
                <button
                  type="button"
                  className={selectedFilter === 'CS 318' ? 'is-active' : ''}
                  onClick={() => { setSelectedFilter('CS 318'); setIsFilterOpen(false) }}
                >
                  CS 318 (AI)
                </button>
                <button
                  type="button"
                  className={selectedFilter === 'CS 301' ? 'is-active' : ''}
                  onClick={() => { setSelectedFilter('CS 301'); setIsFilterOpen(false) }}
                >
                  CS 301 (Sys)
                </button>
              </div>
            )}
          </div>

          <button
            type="button"
            className="history-action-btn"
            onClick={() => setSortOrder(prev => prev === 'asc' ? 'desc' : 'asc')}
            title="Toggle sort direction"
          >
            <ArrowUpDown size={14} />
            <span>Sort</span>
          </button>
        </div>
      </div>

      {/* 3. Main View: Timeline or Class Roster Table */}
      {viewMode === 'timeline' ? (
        <div className="timeline-table-container">
          {/* Header Row: Date column + Hourly Columns */}
          <div className="timeline-header-row">
            <div className="timeline-date-col-header">Date / Day</div>
            <div className="timeline-hours-header-track">
              {TIME_COLUMNS.map((time, idx) => (
                <div key={idx} className="timeline-hour-col-header">
                  {time}
                </div>
              ))}
            </div>
          </div>

          {/* Timeline Rows */}
          <div className="timeline-body-rows">
            {filteredEntries.map(entry => (
              <div key={entry.id} className="timeline-data-row">
                {/* Left Date Cell */}
                <div className="timeline-date-cell">
                  <span className="timeline-day-pill">{entry.dayOfWeek}</span>
                  <span className="timeline-date-text">{entry.date.replace(/ 202\d/, '')}</span>
                </div>

                {/* Right Interactive Schedule Track */}
                <div className="timeline-track-cell">
                  {/* Vertical Column Guidelines */}
                  <div className="timeline-grid-guidelines">
                    {TIME_COLUMNS.map((_, i) => (
                      <div key={i} className="timeline-guideline" />
                    ))}
                  </div>

                  {/* Lecture Block (10:00 am to 01:00 pm) */}
                  <div className="timeline-work-block" style={{ width: '84%' }}>
                    <div className="work-block-main-card">
                      <div className="work-block-header-time" style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                        <span style={{ color: '#1677ff', fontWeight: 800 }}>{entry.courseCode}</span>
                        <span>{entry.courseName}</span>
                        <span style={{ fontSize: '11px', color: '#64748b', fontWeight: 500 }}>
                          ({entry.lectureHall})
                        </span>
                      </div>
                      <div className="work-block-metrics-sub">
                        <span style={{ color: '#10b981', fontWeight: 700 }}>Presence: {entry.attendanceRate}</span>
                        <span className="metrics-separator">•</span>
                        <span>{entry.enrolledRatio}</span>
                        <span className="metrics-separator">•</span>
                        <span>{entry.clockIn} - {entry.clockOut}</span>
                      </div>
                    </div>

                    {/* Recess / Break Interval */}
                    <div className="timeline-break-interval" title="College Recess / Lunch Interval">
                      <span className="break-label">Lunch Recess</span>
                    </div>

                    {/* Verified Session Tag */}
                    <div
                      className="timeline-overtime-badge"
                      style={{ color: '#10b981' }}
                      title="ArcFace biometric confidence ≥ 0.94"
                    >
                      <CheckCircle2 size={13} style={{ color: '#10b981' }} />
                      <span>Verified</span>
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      ) : (
        /* Class Roster Tabular Mode */
        <div className="timecard-table-container">
          <table className="timecard-table">
            <thead>
              <tr>
                <th>Date</th>
                <th>Day</th>
                <th>Course</th>
                <th>Lecture Hall</th>
                <th>Schedule</th>
                <th>Enrolled</th>
                <th>Presence</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {filteredEntries.map(entry => (
                <tr key={entry.id}>
                  <td style={{ fontWeight: 600 }}>{entry.date}</td>
                  <td>
                    <span className="timeline-day-pill">{entry.dayOfWeek}</span>
                  </td>
                  <td>
                    <strong>{entry.courseCode}</strong> — {entry.courseName}
                  </td>
                  <td>
                    <span style={{ display: 'flex', alignItems: 'center', gap: 4, color: '#475569' }}>
                      <Building size={13} /> {entry.lectureHall}
                    </span>
                  </td>
                  <td>{entry.clockIn} - {entry.clockOut}</td>
                  <td>{entry.enrolledRatio}</td>
                  <td>
                    <strong style={{ color: '#10b981' }}>{entry.attendanceRate}</strong>
                  </td>
                  <td>
                    <span className="history-status-badge present">
                      <CheckCircle2 size={12} /> {entry.sessionType}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
