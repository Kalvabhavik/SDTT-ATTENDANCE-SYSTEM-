import React, { useState } from 'react'
import { Calendar, Info, TrendingUp, AlertCircle, CheckCircle2 } from 'lucide-react'

export interface HeatmapCourseRow {
  classId: string
  classCode: string
  className: string
  room: string
  rates: {
    mon: number
    tue: number
    wed: number
    thu: number
    fri: number
  }
}

const DEFAULT_HEATMAP_DATA: HeatmapCourseRow[] = [
  {
    classId: 'cs-204',
    classCode: 'CS 204',
    className: 'Human-Computer Interaction',
    room: 'North Hall 204',
    rates: { mon: 92, tue: 90, wed: 88, thu: 95, fri: 91 }
  },
  {
    classId: 'des-112',
    classCode: 'DES 112',
    className: 'Design Systems Studio Lab',
    room: 'Arts Annex 12',
    rates: { mon: 60, tue: 90, wed: 88, thu: 95, fri: 91 }
  },
  {
    classId: 'cs-318',
    classCode: 'CS 318',
    className: 'Responsible AI Seminar',
    room: 'Library Lab 3',
    rates: { mon: 92, tue: 9, wed: 88, thu: 95, fri: 91 }
  },
  {
    classId: 'cs-301',
    classCode: 'CS 301',
    className: 'Distributed Systems Core',
    room: 'LH-120 Main',
    rates: { mon: 92, tue: 90, wed: 88, thu: 95, fri: 91 }
  },
  {
    classId: 'ai-402',
    classCode: 'AI 402',
    className: 'Computer Vision & Robotics',
    room: 'Hall CS-2',
    rates: { mon: 92, tue: 9, wed: 8, thu: 95, fri: 91 }
  },
  {
    classId: 'math-201',
    classCode: 'MATH 201',
    className: 'Linear Algebra for Computing',
    room: 'LH-105',
    rates: { mon: 92, tue: 90, wed: 88, thu: 5, fri: 91 }
  },
  {
    classId: 'ee-104',
    classCode: 'EE 104',
    className: 'Embedded Logic Systems',
    room: 'Hardware Lab 1',
    rates: { mon: 92, tue: 90, wed: 88, thu: 95, fri: 91 }
  }
]

export interface ClassAttendanceHeatmapProps {
  data?: HeatmapCourseRow[]
  onSelectClass?: (classCode: string) => void
}

export function ClassAttendanceHeatmap({
  data = DEFAULT_HEATMAP_DATA,
  onSelectClass
}: ClassAttendanceHeatmapProps) {
  const [hoveredCell, setHoveredCell] = useState<{ code: string; day: string; rate: number } | null>(null)

  const getHeatmapColorClass = (rate: number) => {
    if (rate >= 90) return 'heat-green-dark' // High attendance ~90-100%
    if (rate >= 75) return 'heat-green-light' // Medium-high ~75-89%
    if (rate >= 50) return 'heat-amber' // Warning ~50-74%
    return 'heat-red' // Critical <50%
  }

  return (
    <div className="attendrix-heatmap-card">
      <div className="heatmap-header">
        <div>
          <h3 className="heatmap-title">Class Attendance Heatmap</h3>
          <span className="heatmap-subtext">Weekly classroom attendance distribution by course</span>
        </div>
        <div className="heatmap-legend">
          <div className="legend-chip">
            <span className="legend-box heat-green-dark" />
            <span>≥90% High</span>
          </div>
          <div className="legend-chip">
            <span className="legend-box heat-green-light" />
            <span>75-89% Normal</span>
          </div>
          <div className="legend-chip">
            <span className="legend-box heat-amber" />
            <span>50-74% Warning</span>
          </div>
          <div className="legend-chip">
            <span className="legend-box heat-red" />
            <span>&lt;50% Critical</span>
          </div>
        </div>
      </div>

      <div className="heatmap-table-container">
        <table className="heatmap-table">
          <thead>
            <tr>
              <th className="th-class">CLASS / COURSE</th>
              <th>MON</th>
              <th>TUE</th>
              <th>WED</th>
              <th>THU</th>
              <th>FRI</th>
            </tr>
          </thead>
          <tbody>
            {data.map(row => (
              <tr key={row.classId} onClick={() => onSelectClass?.(row.classCode)}>
                <td className="td-class-name">
                  <span className="course-code-pill">{row.classCode}</span>
                  <span className="course-title-sub truncate">{row.className}</span>
                </td>
                <td
                  className={`heatmap-cell ${getHeatmapColorClass(row.rates.mon)}`}
                  onMouseEnter={() => setHoveredCell({ code: row.classCode, day: 'Mon', rate: row.rates.mon })}
                  onMouseLeave={() => setHoveredCell(null)}
                >
                  <span className="cell-rate-text">{row.rates.mon}%</span>
                </td>
                <td
                  className={`heatmap-cell ${getHeatmapColorClass(row.rates.tue)}`}
                  onMouseEnter={() => setHoveredCell({ code: row.classCode, day: 'Tue', rate: row.rates.tue })}
                  onMouseLeave={() => setHoveredCell(null)}
                >
                  <span className="cell-rate-text">{row.rates.tue}%</span>
                </td>
                <td
                  className={`heatmap-cell ${getHeatmapColorClass(row.rates.wed)}`}
                  onMouseEnter={() => setHoveredCell({ code: row.classCode, day: 'Wed', rate: row.rates.wed })}
                  onMouseLeave={() => setHoveredCell(null)}
                >
                  <span className="cell-rate-text">{row.rates.wed}%</span>
                </td>
                <td
                  className={`heatmap-cell ${getHeatmapColorClass(row.rates.thu)}`}
                  onMouseEnter={() => setHoveredCell({ code: row.classCode, day: 'Thu', rate: row.rates.thu })}
                  onMouseLeave={() => setHoveredCell(null)}
                >
                  <span className="cell-rate-text">{row.rates.thu}%</span>
                </td>
                <td
                  className={`heatmap-cell ${getHeatmapColorClass(row.rates.fri)}`}
                  onMouseEnter={() => setHoveredCell({ code: row.classCode, day: 'Fri', rate: row.rates.fri })}
                  onMouseLeave={() => setHoveredCell(null)}
                >
                  <span className="cell-rate-text">{row.rates.fri}%</span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {hoveredCell && (
        <div className="heatmap-tooltip-pill">
          <Info size={13} />
          <span>
            {hoveredCell.code} on {hoveredCell.day}: <strong>{hoveredCell.rate}% presence</strong>
            {hoveredCell.rate < 50 ? ' (Severe drop - proxy alert logged)' : ''}
          </span>
        </div>
      )}
    </div>
  )
}
