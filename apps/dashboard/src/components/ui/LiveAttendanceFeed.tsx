import React, { useState } from 'react'
import { CheckCircle2, Clock, ShieldAlert, ArrowRight, UserCheck } from 'lucide-react'

export interface LiveFeedStudentItem {
  id: string
  name: string
  rollNumber: string
  major: string
  clockInTime: string
  status: 'on-time' | 'late' | 'flagged'
  avatarUrl: string
  confidence?: number
}

const DEFAULT_FEED_ITEMS: LiveFeedStudentItem[] = [
  {
    id: 's-1',
    name: 'Hanah Smeat',
    rollNumber: 'CS-2023-014',
    major: 'Computer Science Core',
    clockInTime: '09:30 AM',
    status: 'late',
    avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=80&auto=format&fit=crop&q=80',
    confidence: 0.96
  },
  {
    id: 's-2',
    name: 'Adrian Legi',
    rollNumber: 'CS-2023-019',
    major: 'Computer Science Core',
    clockInTime: '09:00 AM',
    status: 'on-time',
    avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=80&auto=format&fit=crop&q=80',
    confidence: 0.98
  },
  {
    id: 's-3',
    name: 'Rodes Johnes',
    rollNumber: 'DS-2023-042',
    major: 'Data Science & AI',
    clockInTime: '09:00 AM',
    status: 'on-time',
    avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=80&auto=format&fit=crop&q=80',
    confidence: 0.95
  },
  {
    id: 's-4',
    name: 'Steven Williw',
    rollNumber: 'CS-2023-088',
    major: 'Software Engineering',
    clockInTime: '09:00 AM',
    status: 'on-time',
    avatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=80&auto=format&fit=crop&q=80',
    confidence: 0.97
  },
  {
    id: 's-5',
    name: 'Brian Malik',
    rollNumber: 'CS-2023-022',
    major: 'Computer Science Core',
    clockInTime: '09:20 AM',
    status: 'late',
    avatarUrl: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=80&auto=format&fit=crop&q=80',
    confidence: 0.94
  },
  {
    id: 's-6',
    name: 'Dominique Halin',
    rollNumber: 'EE-2023-005',
    major: 'Embedded Systems',
    clockInTime: '09:00 AM',
    status: 'on-time',
    avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=80&auto=format&fit=crop&q=80',
    confidence: 0.99
  },
  {
    id: 's-7',
    name: 'Emily Buttler',
    rollNumber: 'DS-2023-011',
    major: 'Data Science & AI',
    clockInTime: '09:00 AM',
    status: 'on-time',
    avatarUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=80&auto=format&fit=crop&q=80',
    confidence: 0.97
  }
]

export interface LiveAttendanceFeedProps {
  items?: LiveFeedStudentItem[]
  onViewAll?: () => void
}

export function LiveAttendanceFeed({
  items = DEFAULT_FEED_ITEMS,
  onViewAll
}: LiveAttendanceFeedProps) {
  const [filter, setFilter] = useState<'all' | 'on-time' | 'late'>('all')

  const filteredItems = items.filter(item => {
    if (filter === 'all') return true
    return item.status === filter
  })

  return (
    <div className="attendrix-live-feed-card">
      <div className="live-feed-header">
        <div>
          <h3 className="live-feed-title">Attendance Stream</h3>
          <span className="live-feed-subtext">Real-time classroom check-ins</span>
        </div>
        <button type="button" className="live-feed-see-all-btn" onClick={onViewAll}>
          See all <ArrowRight size={12} />
        </button>
      </div>

      {/* Filter Tabs matching Image 3 */}
      <div className="live-feed-tabs-row">
        <button
          type="button"
          className={`feed-tab-btn ${filter === 'all' ? 'is-active' : ''}`}
          onClick={() => setFilter('all')}
        >
          Logged in <span className="tab-count">{items.length}</span>
        </button>
        <button
          type="button"
          className={`feed-tab-btn ${filter === 'on-time' ? 'is-active' : ''}`}
          onClick={() => setFilter('on-time')}
        >
          On time <span className="tab-count">{items.filter(i => i.status === 'on-time').length}</span>
        </button>
        <button
          type="button"
          className={`feed-tab-btn ${filter === 'late' ? 'is-active' : ''}`}
          onClick={() => setFilter('late')}
        >
          Late <span className="tab-count">{items.filter(i => i.status === 'late').length}</span>
        </button>
      </div>

      <div className="live-feed-list">
        {filteredItems.map(item => (
          <div key={item.id} className="live-feed-item">
            <img src={item.avatarUrl} alt={item.name} className="feed-avatar" />
            <div className="feed-info-block">
              <div className="feed-name-row">
                <span className="feed-student-name">{item.name}</span>
                <span className={`feed-status-dot-tag ${item.status}`}>
                  <span className="dot" /> {item.status === 'on-time' ? 'On time' : 'Late'}
                </span>
              </div>
              <div className="feed-meta-row">
                <span className="feed-major-text">{item.major} · {item.rollNumber}</span>
                <span className="feed-time-text">Clock In · {item.clockInTime}</span>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
