import React, { useState } from 'react'
import { BarChart3, TrendingUp, Calendar, ChevronDown } from 'lucide-react'

export interface DailyAttendanceBarItem {
  dateLabel: string
  onTime: number
  late: number
  absent: number
}

const DEFAULT_CHART_DATA: DailyAttendanceBarItem[] = [
  { dateLabel: '1 Jun', onTime: 1020, late: 120, absent: 50 },
  { dateLabel: '2 Jun', onTime: 1180, late: 180, absent: 35 },
  { dateLabel: '3 Jun', onTime: 950, late: 90, absent: 60 },
  { dateLabel: '4 Jun', onTime: 1080, late: 140, absent: 40 },
  { dateLabel: '5 Jun', onTime: 980, late: 110, absent: 55 },
  { dateLabel: '6 Jun', onTime: 1120, late: 160, absent: 45 },
  { dateLabel: '7 Jun', onTime: 1040, late: 130, absent: 50 },
  { dateLabel: '8 Jun', onTime: 1190, late: 190, absent: 30 },
  { dateLabel: '9 Jun', onTime: 1010, late: 115, absent: 52 },
  { dateLabel: '10 Jun', onTime: 1090, late: 150, absent: 42 }
]

export interface AttendanceMultiBarChartProps {
  data?: DailyAttendanceBarItem[]
  title?: string
}

export function AttendanceMultiBarChart({
  data = DEFAULT_CHART_DATA,
  title = 'Attendance Status'
}: AttendanceMultiBarChartProps) {
  const [period, setPeriod] = useState<'day' | 'week' | 'month' | 'year'>('month')
  const [hoveredBar, setHoveredBar] = useState<DailyAttendanceBarItem | null>(null)

  const maxVal = 1300

  return (
    <div className="attendrix-multibar-card">
      <div className="multibar-card-header">
        <div>
          <h3 className="multibar-title">{title}</h3>
          <span className="multibar-subtext">Classroom presence corroboration breakdown</span>
        </div>

        <div className="multibar-controls-right">
          {/* Legend from Image 3 */}
          <div className="multibar-legend">
            <span className="legend-chip">
              <span className="legend-dot dot-ontime" /> On time
            </span>
            <span className="legend-chip">
              <span className="legend-dot dot-chart-late" /> Late
            </span>
            <span className="legend-chip">
              <span className="legend-dot dot-chart-absent" /> Absent
            </span>
          </div>

          {/* Period Toggle Buttons */}
          <div className="period-toggle-pills">
            <button
              type="button"
              className={period === 'day' ? 'is-active' : ''}
              onClick={() => setPeriod('day')}
            >
              Day
            </button>
            <button
              type="button"
              className={period === 'week' ? 'is-active' : ''}
              onClick={() => setPeriod('week')}
            >
              Week
            </button>
            <button
              type="button"
              className={period === 'month' ? 'is-active' : ''}
              onClick={() => setPeriod('month')}
            >
              Month
            </button>
            <button
              type="button"
              className={period === 'year' ? 'is-active' : ''}
              onClick={() => setPeriod('year')}
            >
              Years
            </button>
          </div>
        </div>
      </div>

      {/* SVG / CSS Multi-Bar Chart Container */}
      <div className="chart-bars-viewport">
        <div className="chart-y-axis">
          <span>1200</span>
          <span>1000</span>
          <span>800</span>
          <span>500</span>
          <span>100</span>
          <span>0</span>
        </div>

        <div className="chart-bars-container">
          {data.map((item, idx) => (
            <div
              key={idx}
              className="chart-day-group"
              onMouseEnter={() => setHoveredBar(item)}
              onMouseLeave={() => setHoveredBar(null)}
            >
              <div className="bars-cluster">
                {/* On-Time Bar */}
                <div
                  className="bar-item bar-ontime"
                  style={{ height: `${(item.onTime / maxVal) * 100}%` }}
                  title={`${item.dateLabel} - On Time: ${item.onTime}`}
                />
                {/* Late Bar */}
                <div
                  className="bar-item bar-late"
                  style={{ height: `${Math.max(6, (item.late / maxVal) * 100 * 2.5)}%` }}
                  title={`${item.dateLabel} - Late: ${item.late}`}
                />
                {/* Absent Bar */}
                <div
                  className="bar-item bar-absent"
                  style={{ height: `${Math.max(4, (item.absent / maxVal) * 100 * 3.5)}%` }}
                  title={`${item.dateLabel} - Absent: ${item.absent}`}
                />
              </div>
              <span className="chart-x-label">{item.dateLabel}</span>
            </div>
          ))}
        </div>
      </div>

      {hoveredBar && (
        <div className="chart-hover-pill">
          <span>
            {hoveredBar.dateLabel} — <strong>{hoveredBar.onTime} On Time</strong> ·{' '}
            <strong style={{ color: '#06b6d4' }}>{hoveredBar.late} Late</strong> ·{' '}
            <strong style={{ color: '#ef4444' }}>{hoveredBar.absent} Absent</strong>
          </span>
        </div>
      )}
    </div>
  )
}
