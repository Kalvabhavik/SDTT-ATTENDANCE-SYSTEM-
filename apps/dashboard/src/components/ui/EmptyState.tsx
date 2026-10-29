import React from 'react'
import { Inbox } from 'lucide-react'

export interface EmptyStateProps {
  icon?: React.ReactNode
  title: string
  description?: string
  actionLabel?: string
  onAction?: () => void
  actionIcon?: React.ReactNode
  className?: string
}

export function EmptyState({
  icon = <Inbox size={32} />,
  title,
  description,
  actionLabel,
  onAction,
  actionIcon,
  className = '',
}: EmptyStateProps) {
  return (
    <div className={`attendrix-empty-state ${className}`}>
      <div className="empty-state-icon" aria-hidden="true">{icon}</div>
      <h4 className="empty-state-title">{title}</h4>
      {description && <p className="empty-state-desc">{description}</p>}
      {actionLabel && onAction && (
        <button type="button" className="attendrix-button button-primary empty-state-btn" onClick={onAction}>
          {actionIcon}
          <span>{actionLabel}</span>
        </button>
      )}
    </div>
  )
}
