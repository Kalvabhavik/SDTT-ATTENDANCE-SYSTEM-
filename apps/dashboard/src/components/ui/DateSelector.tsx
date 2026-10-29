import React, { useEffect, useRef, useState } from 'react'
import { Calendar, ChevronDown, Check } from 'lucide-react'

export interface DateSelectorProps {
  currentPeriod?: string
  options?: string[]
  onSelect?: (period: string) => void
  className?: string
}

const DEFAULT_PERIODS = [
  'Today',
  'This Week',
  'November 2026',
  'October 2026',
  'Fall Semester 2026',
  'Spring Semester 2026',
]

export function DateSelector({
  currentPeriod = 'November 2026',
  options = DEFAULT_PERIODS,
  onSelect,
  className = '',
}: DateSelectorProps) {
  const [open, setOpen] = useState(false)
  const [selected, setSelected] = useState(currentPeriod)
  const wrapRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (wrapRef.current && !wrapRef.current.contains(event.target as Node)) {
        setOpen(false)
      }
    }
    if (open) {
      document.addEventListener('mousedown', handleClickOutside)
    }
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [open])

  return (
    <div className={`attendrix-date-selector ${className}`} ref={wrapRef}>
      <button
        type="button"
        className="date-selector-btn"
        onClick={() => setOpen(!open)}
        aria-expanded={open}
        aria-haspopup="listbox"
      >
        <Calendar size={15} className="date-icon" aria-hidden="true" />
        <span className="date-label">{selected}</span>
        <ChevronDown size={14} className={`date-chevron ${open ? 'rotated' : ''}`} aria-hidden="true" />
      </button>

      {open && (
        <div className="date-dropdown-card" role="listbox">
          {options.map((option) => (
            <button
              key={option}
              type="button"
              role="option"
              aria-selected={selected === option}
              className={`date-dropdown-item ${selected === option ? 'selected' : ''}`}
              onClick={() => {
                setSelected(option)
                onSelect?.(option)
                setOpen(false)
              }}
            >
              <span>{option}</span>
              {selected === option && <Check size={14} className="date-check" />}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
