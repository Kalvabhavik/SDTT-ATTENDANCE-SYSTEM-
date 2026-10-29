import React from 'react'

export interface StatCardProps {
  label: string
  value: string | number
  subtext?: string
  icon?: React.ReactNode
  trend?: 'up' | 'down' | 'neutral'
  trendValue?: string
  variant?: 'default' | 'primary' | 'success' | 'warning' | 'danger'
  onClick?: () => void
}

export function StatCard({
  label,
  value,
  subtext,
  icon,
  trend,
  trendValue,
  variant = 'default',
  onClick,
}: StatCardProps) {
  return (
    <div
      className={`attendrix-stat-card ${variant !== 'default' ? `variant-${variant}` : ''} ${onClick ? 'is-clickable' : ''}`}
      onClick={onClick}
      role={onClick ? 'button' : undefined}
      tabIndex={onClick ? 0 : undefined}
      onKeyDown={onClick ? (e) => (e.key === 'Enter' || e.key === ' ') && onClick() : undefined}
    >
      <div className="stat-card-header">
        <span className="stat-card-label">{label}</span>
        {icon && <div className="stat-card-icon" aria-hidden="true">{icon}</div>}
      </div>
      <div className="stat-card-body">
        <div className="stat-card-value-wrap">
          <span className="stat-card-value">{value}</span>
          {subtext && <span className="stat-card-subtext">{subtext}</span>}
        </div>
        {trendValue && (
          <div className={`stat-card-trend trend-${trend || 'neutral'}`}>
            <span>{trend === 'up' ? '↑' : trend === 'down' ? '↓' : '•'}</span>
            <span>{trendValue}</span>
          </div>
        )}
      </div>
    </div>
  )
}
