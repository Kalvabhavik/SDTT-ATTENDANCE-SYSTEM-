import React, { useEffect, useRef, useState } from 'react'
import { Filter, ChevronDown, Check } from 'lucide-react'

export interface FilterOption {
  value: string
  label: string
}

export interface FilterDropdownProps {
  label: string
  options: FilterOption[]
  selected: string
  onChange: (val: string) => void
  icon?: React.ReactNode
  className?: string
}

export function FilterDropdown({
  label,
  options,
  selected,
  onChange,
  icon = <Filter size={14} />,
  className = '',
}: FilterDropdownProps) {
  const [open, setOpen] = useState(false)
  const menuRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (menuRef.current && !menuRef.current.contains(event.target as Node)) {
        setOpen(false)
      }
    }
    if (open) {
      document.addEventListener('mousedown', handleClickOutside)
    }
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [open])

  const currentLabel = options.find((o) => o.value === selected)?.label || label

  return (
    <div className={`attendrix-dropdown-wrap ${className}`} ref={menuRef}>
      <button
        type="button"
        className={`dropdown-trigger-pill ${open ? 'is-open' : ''}`}
        onClick={() => setOpen(!open)}
        aria-expanded={open}
        aria-haspopup="listbox"
      >
        <span className="dropdown-icon" aria-hidden="true">{icon}</span>
        <span className="dropdown-label">{currentLabel}</span>
        <ChevronDown size={14} className={`dropdown-chevron ${open ? 'rotated' : ''}`} aria-hidden="true" />
      </button>

      {open && (
        <div className="dropdown-menu-card" role="listbox">
          {options.map((option) => (
            <button
              key={option.value}
              type="button"
              role="option"
              aria-selected={selected === option.value}
              className={`dropdown-item ${selected === option.value ? 'selected' : ''}`}
              onClick={() => {
                onChange(option.value)
                setOpen(false)
              }}
            >
              <span>{option.label}</span>
              {selected === option.value && <Check size={14} className="dropdown-check" />}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
