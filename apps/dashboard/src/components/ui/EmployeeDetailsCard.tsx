import React, { useState } from 'react'
import { Calendar, Download, Edit3, Check, X, Phone, Mail, Building, GraduationCap } from 'lucide-react'
import { DateSelector } from './DateSelector'

export interface FacultyAcademicInfo {
  name: string
  role: string
  affiliationBadge: string
  department: string
  email: string
  assignedHall: string
  avatarUrl: string
}

export interface EmployeeDetailsCardProps {
  info?: FacultyAcademicInfo
  onDownloadInfo?: () => void
  onUpdateInfo?: (updated: FacultyAcademicInfo) => void
  yearOptions?: string[]
}

const DEFAULT_ACADEMIC_INFO: FacultyAcademicInfo = {
  name: 'Dr. Mira Chen',
  role: 'Associate Professor',
  affiliationBadge: 'Faculty · Verified',
  department: 'Computer Science & Engineering',
  email: 'teacher@demo.edu',
  assignedHall: 'North Hall 204 (LH-2)',
  avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=160&auto=format&fit=crop&q=80'
}

export function EmployeeDetailsCard({
  info = DEFAULT_ACADEMIC_INFO,
  onDownloadInfo,
  onUpdateInfo,
  yearOptions = ['2026-2027', '2025-2026', '2024-2025']
}: EmployeeDetailsCardProps) {
  const [selectedYear, setSelectedYear] = useState('2026-2027')
  const [isEditing, setIsEditing] = useState(false)
  const [formData, setFormData] = useState<FacultyAcademicInfo>(info)

  const handleSave = () => {
    setIsEditing(false)
    onUpdateInfo?.(formData)
  }

  return (
    <div className="attendrix-employee-card">
      {/* 1. Header: • Faculty Profile, Pencil Edit, Academic Year, Download Roster */}
      <div className="employee-card-header">
        <div className="employee-card-title-group">
          <span className="employee-blue-bullet" />
          <h3 className="employee-card-title">Academic Profile & Verification</h3>
        </div>

        <div className="employee-card-actions">
          <button
            type="button"
            className="employee-icon-btn"
            title="Edit profile details"
            onClick={() => setIsEditing(!isEditing)}
          >
            <Edit3 size={15} />
          </button>

          <DateSelector
            currentPeriod={selectedYear}
            options={yearOptions}
            onSelect={setSelectedYear}
          />

          <button
            type="button"
            className="attendrix-button button-primary employee-download-btn"
            onClick={onDownloadInfo}
          >
            <Download size={14} />
            <span>Download Roster</span>
          </button>
        </div>
      </div>

      {/* 2. Body: Avatar + Verification Tag + Name + 3 Columns */}
      <div className="employee-card-body">
        <div className="employee-avatar-wrapper">
          <img
            src={formData.avatarUrl || info.avatarUrl}
            alt={formData.name}
            className="employee-avatar-img"
          />
          <span className="employee-tag-badge">{formData.affiliationBadge}</span>
        </div>

        <div className="employee-main-info">
          {isEditing ? (
            <div className="employee-edit-form">
              <div className="edit-form-row">
                <input
                  type="text"
                  value={formData.name}
                  onChange={e => setFormData({ ...formData, name: e.target.value })}
                  placeholder="Full Name / Title"
                  className="edit-input"
                />
                <input
                  type="text"
                  value={formData.role}
                  onChange={e => setFormData({ ...formData, role: e.target.value })}
                  placeholder="Role / Title"
                  className="edit-input"
                />
              </div>
              <div className="edit-form-row">
                <input
                  type="text"
                  value={formData.department}
                  onChange={e => setFormData({ ...formData, department: e.target.value })}
                  placeholder="Department"
                  className="edit-input"
                />
                <input
                  type="text"
                  value={formData.assignedHall}
                  onChange={e => setFormData({ ...formData, assignedHall: e.target.value })}
                  placeholder="Primary Lecture Hall"
                  className="edit-input"
                />
              </div>
              <div className="edit-form-actions">
                <button type="button" className="attendrix-button button-primary" onClick={handleSave}>
                  <Check size={14} /> Save
                </button>
                <button type="button" className="attendrix-button button-secondary" onClick={() => setIsEditing(false)}>
                  <X size={14} /> Cancel
                </button>
              </div>
            </div>
          ) : (
            <>
              <h2 className="employee-name-heading">{formData.name}</h2>
              <div className="employee-details-columns">
                <div className="detail-column">
                  <span className="detail-column-label">Department</span>
                  <span className="detail-column-value">{formData.department}</span>
                </div>
                <div className="detail-column">
                  <span className="detail-column-label">Institutional Email</span>
                  <span className="detail-column-value" title={formData.email}>
                    {formData.email}
                  </span>
                </div>
                <div className="detail-column">
                  <span className="detail-column-label">Primary Lecture Hall</span>
                  <span className="detail-column-value">{formData.assignedHall}</span>
                </div>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  )
}
