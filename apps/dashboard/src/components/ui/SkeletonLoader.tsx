import React from 'react'

export interface SkeletonProps {
  variant?: 'text' | 'circular' | 'rectangular' | 'card'
  width?: string | number
  height?: string | number
  className?: string
}

export function SkeletonLoader({
  variant = 'text',
  width,
  height,
  className = '',
}: SkeletonProps) {
  const style: React.CSSProperties = {
    width: width,
    height: height,
  }

  return (
    <div
      className={`attendrix-skeleton skeleton-${variant} ${className}`}
      style={style}
      aria-hidden="true"
    />
  )
}

export function StatCardSkeleton() {
  return (
    <div className="attendrix-stat-card skeleton-stat-card">
      <SkeletonLoader variant="text" width="40%" height={14} />
      <SkeletonLoader variant="text" width="60%" height={32} className="mt-2" />
      <SkeletonLoader variant="text" width="30%" height={12} className="mt-2" />
    </div>
  )
}

export function TableRowSkeleton({ cols = 5 }: { cols?: number }) {
  return (
    <tr className="skeleton-row">
      {Array.from({ length: cols }).map((_, i) => (
        <td key={i} className="skeleton-cell">
          <SkeletonLoader variant="text" width={i === 0 ? '70%' : '50%'} height={16} />
        </td>
      ))}
    </tr>
  )
}
