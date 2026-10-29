import React from 'react'
import { Check, Clock, AlertTriangle, X, Shield, Minus } from 'lucide-react'

export type AttendanceStatusType =
  | 'present'
  | 'late'
  | 'absent'
  | 'flagged'
  | 'pending'
  | 'excused'
  | 'open'
  | 'closed'
  | 'finalized'

export interface StatusBadgeProps {
  status: AttendanceStatusType | string
  label?: string
  showIcon?: boolean
  size?: 'sm' | 'md' | 'lg'
  className?: string
}

export function StatusBadge({
  status,
  label,
  showIcon = true,
  size = 'md',
  className = '',
}: StatusBadgeProps) {
  const normStatus = (status || '').toLowerCase()

  let iconNode: React.ReactNode = null
  let defaultText = status
  let badgeClass = 'status-neutral'

  switch (normStatus) {
    case 'present':
    case 'verified':
      iconNode = <Check size={12} strokeWidth={3} />
      defaultText = 'Present'
      badgeClass = 'status-present'
      break
    case 'late':
      iconNode = <Clock size={12} strokeWidth={2.5} />
      defaultText = 'Late'
      badgeClass = 'status-late'
      break
    case 'absent':
    case 'rejected':
      iconNode = <X size={12} strokeWidth={3} />
      defaultText = 'Absent'
      badgeClass = 'status-absent'
      break
    case 'flagged':
    case 'needs review':
    case 'needs_review':
    case 'review':
      iconNode = <AlertTriangle size={12} strokeWidth={2.5} />
      defaultText = 'Needs Review'
      badgeClass = 'status-flagged'
      break
    case 'excused':
    case 'od':
    case 'medical':
      iconNode = <Shield size={12} strokeWidth={2.5} />
      defaultText = 'Excused OD'
      badgeClass = 'status-excused'
      break
    case 'open':
    case 'running':
    case 'active':
      iconNode = <span className="status-pulse-dot" />
      defaultText = 'In Progress'
      badgeClass = 'status-active'
      break
    case 'closed':
    case 'finalized':
      iconNode = <Check size={12} strokeWidth={2.5} />
      defaultText = 'Finalized'
      badgeClass = 'status-finalized'
      break
    default:
      iconNode = <Minus size={12} strokeWidth={2} />
      defaultText = status || 'Pending'
      badgeClass = 'status-neutral'
      break
  }

  const displayText = label || defaultText

  return (
    <span className={`attendrix-badge badge-${size} ${badgeClass} ${className}`}>
      {showIcon && <span className="badge-icon" aria-hidden="true">{iconNode}</span>}
      <span className="badge-text">{displayText}</span>
    </span>
  )
}
