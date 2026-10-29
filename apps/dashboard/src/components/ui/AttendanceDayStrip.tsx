import React, { useRef } from 'react'
import { Check, Clock, X, ChevronRight, ChevronLeft, Star } from 'lucide-react'

export type DayStatus = 'present' | 'late' | 'half-day' | 'day-off' | 'holiday' | 'weekend' | 'absent'

export interface AttendanceDayItem {
  dayNumber: number | string
  dateString?: string
  status: DayStatus
  tooltip?: string
}

export interface AttendanceDayStripProps {
  days?: AttendanceDayItem[]
  title?: string
  onDayClick?: (day: AttendanceDayItem) => void
  className?: string
}

const DEFAULT_DAYS: AttendanceDayItem[] = [
  { dayNumber: '01', status: 'present', tooltip: 'Nov 01: CS 204 (10:00 AM) - 96% Verified Present' },
  { dayNumber: '02', status: 'weekend', tooltip: 'Nov 02: Weekend / Campus Closed' },
  { dayNumber: '03', status: 'weekend', tooltip: 'Nov 03: Weekend / Campus Closed' },
  { dayNumber: '04', status: 'present', tooltip: 'Nov 04: CS 204 & DES 112 - 95% Verified Present' },
  { dayNumber: '05', status: 'present', tooltip: 'Nov 05: CS 318 AI Seminar - 98% Verified Present' },
  { dayNumber: '06', status: 'present', tooltip: 'Nov 06: CS 301 Distributed Systems - 92% Present' },
  { dayNumber: '07', status: 'present', tooltip: 'Nov 07: CS 204 (10:00 AM) - 94% Verified Present' },
  { dayNumber: '08', status: 'present', tooltip: 'Nov 08: DES 112 Design Studio Lab - 97% Present' },
  { dayNumber: '09', status: 'weekend', tooltip: 'Nov 09: Weekend' },
  { dayNumber: '10', status: 'weekend', tooltip: 'Nov 10: Weekend' },
  { dayNumber: '11', status: 'present', tooltip: 'Nov 11: CS 204 (10:00 AM) - 96% Present' },
  { dayNumber: '12', status: 'present', tooltip: 'Nov 12: CS 318 AI Seminar - 93% Present' },
  { dayNumber: '13', status: 'present', tooltip: 'Nov 13: CS 301 Distributed Systems - 95% Present' },
  { dayNumber: '14', status: 'present', tooltip: 'Nov 14: CS 204 (10:00 AM) - 94% Present' },
  { dayNumber: '15', status: 'half-day', tooltip: 'Nov 15: Half Day / Faculty Academic Assembly' },
  { dayNumber: '16', status: 'weekend', tooltip: 'Nov 16: Weekend' },
  { dayNumber: '17', status: 'weekend', tooltip: 'Nov 17: Weekend' },
  { dayNumber: '18', status: 'present', tooltip: 'Nov 18: CS 204 & DES 112 - 96% Present' },
  { dayNumber: '19', status: 'present', tooltip: 'Nov 19: CS 204 (10:00 AM) - 96% Present' },
  { dayNumber: '20', status: 'present', tooltip: 'Nov 20: DES 112 Studio Lab - 95% Present' },
  { dayNumber: '21', status: 'present', tooltip: 'Nov 21: CS 318 AI Seminar - 94% Present' },
  { dayNumber: '22', status: 'present', tooltip: 'Nov 22: CS 301 Distributed Sys - 92% Present' },
  { dayNumber: '23', status: 'weekend', tooltip: 'Nov 23: Weekend' },
  { dayNumber: '24', status: 'weekend', tooltip: 'Nov 24: Weekend' },
  { dayNumber: '25', status: 'present', tooltip: 'Nov 25: CS 204 (10:00 AM) - 95% Present' },
  { dayNumber: '26', status: 'present', tooltip: 'Nov 26: DES 112 Studio Lab - 96% Present' },
  { dayNumber: '27', status: 'late', tooltip: 'Nov 27: CS 318 - Delayed Start / Weather Warning' },
  { dayNumber: '28', status: 'present', tooltip: 'Nov 28: CS 301 (10:00 AM) - 94% Present' },
  { dayNumber: '29', status: 'holiday', tooltip: 'Nov 29: University Foundation Day Holiday' },
  { dayNumber: '30', status: 'day-off', tooltip: 'Nov 30: Reading Day / Self-Study Recess' },
]

export function AttendanceDayStrip({
  days = DEFAULT_DAYS,
  title = 'Monthly Lecture Attendance',
  onDayClick,
  className = '',
}: AttendanceDayStripProps) {
  const containerRef = useRef<HTMLDivElement>(null)

  const scroll = (direction: 'left' | 'right') => {
    if (containerRef.current) {
      const offset = direction === 'left' ? -260 : 260
      containerRef.current.scrollBy({ left: offset, behavior: 'smooth' })
    }
  }

  return (
    <div className={`attendrix-day-strip-card ${className}`}>
      <div className="day-strip-header">
        <h3 className="day-strip-title">{title}</h3>
        {/* Exact Legend with College Attendance Labels */}
        <div className="day-strip-legend">
          <div className="legend-item">
            <span className="legend-dot dot-present" />
            <span>Present</span>
          </div>
          <div className="legend-item">
            <span className="legend-dot dot-late" />
            <span>Late Entry</span>
          </div>
          <div className="legend-item">
            <span className="legend-dot dot-half-day" />
            <span>Half Day / Leave</span>
          </div>
          <div className="legend-item">
            <span className="legend-dot dot-day-off" />
            <span>No Lecture</span>
          </div>
          <div className="legend-item">
            <Star size={11} className="legend-star-icon" fill="#8b5cf6" color="#8b5cf6" />
            <span>College Holiday</span>
          </div>
          <div className="legend-item">
            <span className="legend-circle-outline" />
            <span>Weekend</span>
          </div>
        </div>
      </div>

      <div className="day-strip-body">
        <div className="day-strip-track" ref={containerRef}>
          {days.map((item, index) => {
            let statusIcon: React.ReactNode = null
            if (item.status === 'present') {
              statusIcon = <Check size={13} strokeWidth={3} className="circle-icon check-icon" />
            } else if (item.status === 'half-day') {
              statusIcon = <div className="half-day-inner-circle" />
            } else if (item.status === 'late') {
              statusIcon = <Clock size={11} strokeWidth={2.5} className="circle-icon" />
            } else if (item.status === 'holiday') {
              statusIcon = <Star size={11} fill="#ffffff" color="#ffffff" />
            }

            return (
              <div
                key={index}
                className={`day-strip-col col-${item.status}`}
                title={item.tooltip || `Day ${item.dayNumber}: ${item.status}`}
                onClick={() => onDayClick?.(item)}
                role={onDayClick ? 'button' : undefined}
                tabIndex={onDayClick ? 0 : undefined}
              >
                <span className="day-number">{item.dayNumber}</span>
                <div className={`day-circle circle-${item.status}`} aria-hidden="true">
                  {statusIcon}
                </div>
              </div>
            )
          })}
        </div>

        <button
          type="button"
          className="day-strip-nav-btn nav-right"
          onClick={() => scroll('right')}
          aria-label="Scroll right"
          title="Scroll next days"
        >
          <ChevronRight size={16} />
        </button>
      </div>
    </div>
  )
}
