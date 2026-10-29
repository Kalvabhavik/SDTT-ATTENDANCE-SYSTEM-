import React from 'react'
import { Search, X } from 'lucide-react'

export interface SearchInputProps {
  value: string
  onChange: (val: string) => void
  placeholder?: string
  shortcut?: string
  className?: string
  id?: string
  ariaLabel?: string
}

export function SearchInput({
  value,
  onChange,
  placeholder = 'Search...',
  shortcut,
  className = '',
  id,
  ariaLabel = 'Search',
}: SearchInputProps) {
  return (
    <div className={`attendrix-search-wrap ${className}`}>
      <Search size={16} className="search-icon" aria-hidden="true" />
      <input
        id={id}
        type="text"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        aria-label={ariaLabel}
        className="search-input-pill"
      />
      {value ? (
        <button
          type="button"
          className="search-clear-btn"
          aria-label="Clear search"
          onClick={() => onChange('')}
        >
          <X size={14} />
        </button>
      ) : shortcut ? (
        <span className="search-shortcut-pill" aria-hidden="true">
          {shortcut}
        </span>
      ) : null}
    </div>
  )
}
