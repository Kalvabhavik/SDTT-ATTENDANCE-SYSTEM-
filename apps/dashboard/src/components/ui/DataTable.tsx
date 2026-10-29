import React from 'react'
import { EmptyState } from './EmptyState'
import { TableRowSkeleton } from './SkeletonLoader'

export interface Column<T> {
  header: string
  accessor?: keyof T
  render?: (row: T, index: number) => React.ReactNode
  className?: string
  width?: string | number
  align?: 'left' | 'center' | 'right'
}

export interface DataTableProps<T> {
  columns: Column<T>[]
  data: T[]
  keyExtractor: (item: T, index: number) => string | number
  loading?: boolean
  emptyTitle?: string
  emptyDescription?: string
  emptyActionLabel?: string
  onEmptyAction?: () => void
  onRowClick?: (item: T) => void
  className?: string
}

export function DataTable<T>({
  columns,
  data,
  keyExtractor,
  loading = false,
  emptyTitle = 'No records found',
  emptyDescription = 'There is currently no attendance or roster data to display.',
  emptyActionLabel,
  onEmptyAction,
  onRowClick,
  className = '',
}: DataTableProps<T>) {
  return (
    <div className={`attendrix-table-container ${className}`}>
      <table className="attendrix-data-table">
        <thead>
          <tr>
            {columns.map((col, idx) => (
              <th
                key={idx}
                className={`table-th ${col.className || ''} align-${col.align || 'left'}`}
                style={{ width: col.width }}
              >
                {col.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {loading ? (
            Array.from({ length: 4 }).map((_, i) => (
              <TableRowSkeleton key={i} cols={columns.length} />
            ))
          ) : data.length === 0 ? (
            <tr>
              <td colSpan={columns.length} className="table-empty-cell">
                <EmptyState
                  title={emptyTitle}
                  description={emptyDescription}
                  actionLabel={emptyActionLabel}
                  onAction={onEmptyAction}
                />
              </td>
            </tr>
          ) : (
            data.map((row, rowIdx) => {
              const rowKey = keyExtractor(row, rowIdx)
              return (
                <tr
                  key={rowKey}
                  className={`table-row ${onRowClick ? 'is-clickable' : ''}`}
                  onClick={() => onRowClick?.(row)}
                  tabIndex={onRowClick ? 0 : undefined}
                  onKeyDown={onRowClick ? (e) => (e.key === 'Enter' || e.key === ' ') && onRowClick(row) : undefined}
                >
                  {columns.map((col, colIdx) => {
                    const content = col.render
                      ? col.render(row, rowIdx)
                      : col.accessor
                      ? String(row[col.accessor] ?? '—')
                      : null

                    return (
                      <td
                        key={colIdx}
                        className={`table-td ${col.className || ''} align-${col.align || 'left'}`}
                      >
                        {content}
                      </td>
                    )
                  })}
                </tr>
              )
            })
          )}
        </tbody>
      </table>
    </div>
  )
}
