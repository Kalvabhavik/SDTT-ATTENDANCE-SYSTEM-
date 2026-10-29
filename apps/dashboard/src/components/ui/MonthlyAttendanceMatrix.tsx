import React, { useState } from 'react'
import {
  Check,
  X,
  Plane,
  HeartPulse,
  Filter,
  Download,
  Calendar,
  ChevronLeft,
  ChevronRight,
  Info,
  CheckCircle2,
  Clock,
  Sparkles,
  Search
} from 'lucide-react'

export type MatrixStatus = 'present' | 'late' | 'absent' | 'duty' | 'medical'

export interface StudentMatrixRow {
  rollNo: string
  name: string
  email: string
  records: Record<string, MatrixStatus> // dateKey -> status
}

const DEFAULT_DATE_COLS = [
  '01-09',
  '05-09',
  '08-09',
  '12-09',
  '15-09',
  '19-09',
  '22-09',
  '26-09'
]

const DEFAULT_STUDENTS: StudentMatrixRow[] = [
  {
    rollNo: '#13',
    name: 'JORDAN ELLIS',
    email: 'jordan@demo.edu',
    records: {
      '01-09': 'present',
      '05-09': 'present',
      '08-09': 'present',
      '12-09': 'present',
      '15-09': 'present',
      '19-09': 'present',
      '22-09': 'present',
      '26-09': 'present'
    }
  },
  {
    rollNo: '#1957',
    name: 'SAMIRA PATEL',
    email: 'samira@demo.edu',
    records: {
      '01-09': 'present',
      '05-09': 'present',
      '08-09': 'late',
      '12-09': 'present',
      '15-09': 'late',
      '19-09': 'present',
      '22-09': 'present',
      '26-09': 'duty'
    }
  },
  {
    rollNo: '#24',
    name: 'THEO MARTINEZ',
    email: 'theo@demo.edu',
    records: {
      '01-09': 'present',
      '05-09': 'present',
      '08-09': 'present',
      '12-09': 'present',
      '15-09': 'present',
      '19-09': 'present',
      '22-09': 'present',
      '26-09': 'duty'
    }
  },
  {
    rollNo: '#31',
    name: 'CASEY NGUYEN',
    email: 'casey@demo.edu',
    records: {
      '01-09': 'present',
      '05-09': 'present',
      '08-09': 'present',
      '12-09': 'present',
      '15-09': 'present',
      '19-09': 'present',
      '22-09': 'present',
      '26-09': 'duty'
    }
  },
  {
    rollNo: '#39',
    name: 'ARI WILSON',
    email: 'ari@demo.edu',
    records: {
      '01-09': 'present',
      '05-09': 'absent',
      '08-09': 'present',
      '12-09': 'present',
      '15-09': 'present',
      '19-09': 'present',
      '22-09': 'present',
      '26-09': 'present'
    }
  },
  {
    rollNo: '#394',
    name: 'NAOMI BROOKS',
    email: 'naomi@demo.edu',
    records: {
      '01-09': 'present',
      '05-09': 'present',
      '08-09': 'present',
      '12-09': 'present',
      '15-09': 'present',
      '19-09': 'present',
      '22-09': 'late',
      '26-09': 'present'
    }
  },
  {
    rollNo: '#4040',
    name: 'MARCUS CHEN',
    email: 'marcus@demo.edu',
    records: {
      '01-09': 'present',
      '05-09': 'present',
      '08-09': 'present',
      '12-09': 'late',
      '15-09': 'present',
      '19-09': 'present',
      '22-09': 'present',
      '26-09': 'present'
    }
  },
  {
    rollNo: '#537',
    name: 'PRIYA SHARMA',
    email: 'priya@demo.edu',
    records: {
      '01-09': 'present',
      '05-09': 'medical',
      '08-09': 'medical',
      '12-09': 'present',
      '15-09': 'present',
      '19-09': 'present',
      '22-09': 'present',
      '26-09': 'present'
    }
  },
  {
    rollNo: '#666',
    name: 'ALEX RIVERA',
    email: 'alex@demo.edu',
    records: {
      '01-09': 'present',
      '05-09': 'present',
      '08-09': 'present',
      '12-09': 'present',
      '15-09': 'present',
      '19-09': 'present',
      '22-09': 'present',
      '26-09': 'present'
    }
  },
  {
    rollNo: '#80',
    name: 'DAVID KIM',
    email: 'david@demo.edu',
    records: {
      '01-09': 'late',
      '05-09': 'present',
      '08-09': 'present',
      '12-09': 'late',
      '15-09': 'present',
      '19-09': 'present',
      '22-09': 'present',
      '26-09': 'late'
    }
  },
  {
    rollNo: '#89',
    name: 'SOPHIA WANG',
    email: 'sophia@demo.edu',
    records: {
      '01-09': 'present',
      '05-09': 'present',
      '08-09': 'present',
      '12-09': 'present',
      '15-09': 'present',
      '19-09': 'present',
      '22-09': 'present',
      '26-09': 'present'
    }
  },
  {
    rollNo: '#9',
    name: 'LIAM O\'CONNOR',
    email: 'liam@demo.edu',
    records: {
      '01-09': 'present',
      '05-09': 'present',
      '08-09': 'present',
      '12-09': 'present',
      '15-09': 'present',
      '19-09': 'present',
      '22-09': 'present',
      '26-09': 'present'
    }
  },
  {
    rollNo: '#934',
    name: 'LUCAS SCOTT',
    email: 'lucas@demo.edu',
    records: {
      '01-09': 'present',
      '05-09': 'present',
      '08-09': 'present',
      '12-09': 'present',
      '15-09': 'present',
      '19-09': 'present',
      '22-09': 'present',
      '26-09': 'present'
    }
  }
]

export interface MonthlyAttendanceMatrixProps {
  onExport?: () => void
  onSelectStudent?: (student: StudentMatrixRow, date: string, status: MatrixStatus) => void
}

export function MonthlyAttendanceMatrix({ onExport, onSelectStudent }: MonthlyAttendanceMatrixProps) {
  const [selectedClass, setSelectedClass] = useState('CS 204 — HCI')
  const [selectedMonth, setSelectedMonth] = useState('September')
  const [selectedYear, setSelectedYear] = useState('2026')
  const [isAdvanced, setIsAdvanced] = useState(false)
  const [students, setStudents] = useState<StudentMatrixRow[]>(DEFAULT_STUDENTS)
  const [filterSearch, setFilterSearch] = useState('')
  const [activeCellModal, setActiveCellModal] = useState<{
    student: StudentMatrixRow
    date: string
    status: MatrixStatus
  } | null>(null)

  const filteredStudents = students.filter(s =>
    s.name.toLowerCase().includes(filterSearch.toLowerCase()) ||
    s.rollNo.toLowerCase().includes(filterSearch.toLowerCase())
  )

  const handleCellClick = (student: StudentMatrixRow, date: string) => {
    const currentStatus = student.records[date] || 'present'
    setActiveCellModal({ student, date, status: currentStatus })
    onSelectStudent?.(student, date, currentStatus)
  }

  const handleUpdateStatus = (newStatus: MatrixStatus) => {
    if (!activeCellModal) return
    setStudents(prev =>
      prev.map(s => {
        if (s.rollNo === activeCellModal.student.rollNo) {
          return {
            ...s,
            records: {
              ...s.records,
              [activeCellModal.date]: newStatus
            }
          }
        }
        return s
      })
    )
    setActiveCellModal(null)
  }

  return (
    <div className="monthly-attendance-matrix-wrapper">
      {/* 1. Header: Monthly attendance + Selectors & Actions matching Image 0 */}
      <div className="matrix-page-header">
        <h1 className="matrix-main-title">Monthly attendance</h1>

        <div className="matrix-controls-row">
          <div className="matrix-selectors-group">
            <select
              value={selectedClass}
              onChange={e => setSelectedClass(e.target.value)}
              className="matrix-select-pill"
            >
              <option value="CS 204 — HCI">CS 204 — HCI</option>
              <option value="DES 112 — Studio">DES 112 — Studio</option>
              <option value="CS 318 — AI">CS 318 — AI</option>
              <option value="CS 301 — Distributed">CS 301 — Distributed</option>
            </select>

            <select
              value={selectedMonth}
              onChange={e => setSelectedMonth(e.target.value)}
              className="matrix-select-pill"
            >
              <option value="September">September</option>
              <option value="October">October</option>
              <option value="November">November</option>
              <option value="December">December</option>
            </select>

            <select
              value={selectedYear}
              onChange={e => setSelectedYear(e.target.value)}
              className="matrix-select-pill"
            >
              <option value="2026">2026</option>
              <option value="2025">2025</option>
            </select>

            <button type="button" className="matrix-orange-btn">
              <Filter size={14} /> Filter
            </button>
          </div>

          <div className="matrix-actions-group">
            <button
              type="button"
              className={`matrix-orange-btn ${isAdvanced ? 'is-active' : ''}`}
              onClick={() => setIsAdvanced(!isAdvanced)}
            >
              Advanced attendance
            </button>

            <button
              type="button"
              className="matrix-orange-btn"
              onClick={onExport}
            >
              <Download size={14} /> Export (.xlsx)
            </button>
          </div>
        </div>
      </div>

      {/* 2. Student-by-Date Matrix Table Grid */}
      <div className="matrix-table-container">
        <table className="matrix-grid-table">
          <thead>
            <tr>
              <th className="matrix-th-member">MEMBER / ROLL NO</th>
              {DEFAULT_DATE_COLS.map(date => (
                <th key={date} className="matrix-th-date">
                  {date}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {filteredStudents.map(student => (
              <tr key={student.rollNo} className="matrix-student-row">
                {/* Left Dark Column */}
                <td className="matrix-td-member">
                  <span className="member-roll-tag">{student.rollNo}</span>
                  <span className="member-name-text">{student.name}</span>
                </td>

                {/* Color Coded Cells */}
                {DEFAULT_DATE_COLS.map(date => {
                  const status = student.records[date] || 'present'

                  return (
                    <td
                      key={date}
                      className={`matrix-status-cell cell-${status}`}
                      onClick={() => handleCellClick(student, date)}
                      title={`${student.name} on ${date}: ${status.toUpperCase()}`}
                    >
                      {status === 'present' && <Check size={16} strokeWidth={2.8} className="cell-icon-check" />}
                      {status === 'late' && <X size={15} strokeWidth={2.8} className="cell-icon-x" />}
                      {status === 'absent' && <X size={15} strokeWidth={2.8} className="cell-icon-x" />}
                      {status === 'duty' && <Plane size={15} className="cell-icon-plane" />}
                      {status === 'medical' && <HeartPulse size={15} className="cell-icon-med" />}
                    </td>
                  )
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* 3. Bottom Navigation Pills matching Image 0 */}
      <div className="matrix-bottom-nav">
        <button
          type="button"
          className="matrix-month-nav-pill"
          onClick={() => setSelectedMonth('August')}
        >
          <ChevronLeft size={14} /> August {selectedYear}
        </button>

        <div className="matrix-legend-row">
          <span className="legend-chip">
            <span className="legend-swatch swatch-present" /> Present (✓)
          </span>
          <span className="legend-chip">
            <span className="legend-swatch swatch-late" /> Late / Warning (✕)
          </span>
          <span className="legend-chip">
            <span className="legend-swatch swatch-absent" /> Absent (✕)
          </span>
          <span className="legend-chip">
            <span className="legend-swatch swatch-duty" /> Approved Duty (✈)
          </span>
          <span className="legend-chip">
            <span className="legend-swatch swatch-medical" /> Medical Leave (✚)
          </span>
        </div>

        <button
          type="button"
          className="matrix-month-nav-pill"
          onClick={() => setSelectedMonth('October')}
        >
          October {selectedYear} <ChevronRight size={14} />
        </button>
      </div>

      {/* Active Cell Click Dialog (for reviewing or updating record) */}
      {activeCellModal && (
        <div className="scrim" style={{ display: 'grid', placeItems: 'center', zIndex: 120 }}>
          <div className="attendrix-modal-window" style={{ width: '420px', background: '#ffffff', borderRadius: '16px', padding: '24px' }}>
            <h3 style={{ margin: '0 0 8px', fontSize: '17px', fontWeight: 800, color: '#0f172a' }}>
              Attendance Record · {activeCellModal.date}
            </h3>
            <p style={{ margin: '0 0 16px', fontSize: '13px', color: '#64748b' }}>
              Student: <strong>{activeCellModal.student.name}</strong> ({activeCellModal.student.rollNo})
            </p>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px', marginBottom: '16px' }}>
              <button
                type="button"
                className="attendrix-button"
                style={{ background: '#10b981', color: '#ffffff' }}
                onClick={() => handleUpdateStatus('present')}
              >
                <Check size={14} /> Present
              </button>
              <button
                type="button"
                className="attendrix-button"
                style={{ background: '#f59e0b', color: '#ffffff' }}
                onClick={() => handleUpdateStatus('late')}
              >
                <Clock size={14} /> Late
              </button>
              <button
                type="button"
                className="attendrix-button"
                style={{ background: '#ef4444', color: '#ffffff' }}
                onClick={() => handleUpdateStatus('absent')}
              >
                <X size={14} /> Absent
              </button>
              <button
                type="button"
                className="attendrix-button"
                style={{ background: '#3b82f6', color: '#ffffff' }}
                onClick={() => handleUpdateStatus('duty')}
              >
                <Plane size={14} /> Approved Duty
              </button>
              <button
                type="button"
                className="attendrix-button"
                style={{ gridColumn: 'span 2', background: '#8b5cf6', color: '#ffffff' }}
                onClick={() => handleUpdateStatus('medical')}
              >
                <HeartPulse size={14} /> Medical Leave
              </button>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
              <button
                type="button"
                className="attendrix-button button-secondary"
                onClick={() => setActiveCellModal(null)}
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
