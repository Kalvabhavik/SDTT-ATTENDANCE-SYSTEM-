import React from 'react'
import { Building2, Users, CheckCircle2, Clock, XCircle } from 'lucide-react'

export interface DepartmentMetricItem {
  id: string
  name: string
  totalEnrolled: number
  onTime: number
  late: number
  absent: number
}

const DEFAULT_DEPARTMENTS: DepartmentMetricItem[] = [
  { id: 'cs', name: 'Computer Science Core', totalEnrolled: 50, onTime: 45, late: 3, absent: 2 },
  { id: 'des', name: 'Design Systems', totalEnrolled: 28, onTime: 25, late: 2, absent: 1 },
  { id: 'ds', name: 'Data Science & AI', totalEnrolled: 40, onTime: 36, late: 3, absent: 1 },
  { id: 'ee', name: 'Embedded Systems', totalEnrolled: 32, onTime: 30, late: 2, absent: 0 }
]

export interface DepartmentSummariesGridProps {
  departments?: DepartmentMetricItem[]
  dateLabel?: string
}

export function DepartmentSummariesGrid({
  departments = DEFAULT_DEPARTMENTS,
  dateLabel = 'Fall Semester 2026'
}: DepartmentSummariesGridProps) {
  return (
    <div className="attendrix-dept-summary-section">
      <div className="dept-summary-header">
        <div>
          <h3 className="dept-summary-title">Department & Academic Sections</h3>
          <span className="dept-summary-subtext">Class-level attendance breakdowns</span>
        </div>
        <span className="dept-date-tag">{dateLabel}</span>
      </div>

      <div className="dept-cards-grid">
        {departments.map(dept => (
          <div key={dept.id} className="dept-metric-card">
            <div className="dept-card-top">
              <span className="dept-name-label">{dept.name}</span>
            </div>

            <div className="dept-card-body">
              <div className="dept-total-number-wrap">
                <span className="dept-total-val">{dept.totalEnrolled}</span>
                <span className="dept-total-sub">Students</span>
              </div>

              <div className="dept-breakdown-cluster">
                <div className="breakdown-stat-row">
                  <span className="breakdown-label">On Time</span>
                  <span className="breakdown-val ontime-val">{dept.onTime}</span>
                </div>
                <div className="breakdown-stat-row">
                  <span className="breakdown-label">Late</span>
                  <span className="breakdown-val late-val">{dept.late}</span>
                </div>
                <div className="breakdown-stat-row">
                  <span className="breakdown-label">Absent</span>
                  <span className="breakdown-val absent-val">{dept.absent}</span>
                </div>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
