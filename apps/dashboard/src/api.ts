import { demoClasses, demoNotifications, demoNotifications2, demoRoster, demoSessions, demoStudent, demoStudent2, demoStudentAttendance, demoStudentAttendance2, demoTeacher, type AttendanceEntry, type AuditItem, type ClassItem, type Notification, type Report, type ReportRow, type ReviewItem, type Role, type Session, type StudentAttendance, type Suggestion, type User } from './types'

const API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000/api').replace(/\/$/, '')
const localModeKey = 'rollcall-local-mode'

export const getApiBase = () => API_BASE
export const isLocalMode = () => window.localStorage.getItem(localModeKey) === 'true'
const setLocalMode = (value: boolean) => window.localStorage.setItem(localModeKey, String(value))

function record(value: unknown): Record<string, unknown> { return value && typeof value === 'object' ? value as Record<string, unknown> : {} }
function list(value: unknown): unknown[] { return Array.isArray(value) ? value : [] }
function text(value: unknown, fallback = ''): string { return value === null || value === undefined ? fallback : String(value) }
function id(value: unknown): string { return text(value) }
function number(value: unknown, fallback = 0): number { return typeof value === 'number' ? value : Number(value ?? fallback) || fallback }
function status(value: unknown): AttendanceEntry['status'] { return value === 'present' || value === 'absent' || value === 'pending' ? value : 'pending' }
function normalizeUser(value: unknown): User {
  const raw = record(value)
  return { id: id(raw.id), name: text(raw.name, 'User'), email: text(raw.email), role: raw.role === 'teacher' ? 'teacher' : 'student' }
}
function normalizeAttendance(value: unknown): AttendanceEntry {
  const raw = record(value)
  const updatedAt = raw.updated_at === null || raw.updated_at === undefined ? undefined : text(raw.updated_at)
  return {
    student_id: id(raw.student_id ?? raw.id),
    student_name: text(raw.name ?? raw.student_name, 'Student'),
    student_email: raw.email === undefined || raw.email === null ? undefined : text(raw.email),
    status: status(raw.status),
    confidence: raw.confidence === undefined || raw.confidence === null ? undefined : number(raw.confidence),
    note: raw.note === null || raw.note === undefined ? undefined : text(raw.note),
    changed_at: updatedAt,
    updated_at: updatedAt,
  }
}
function normalizeSuggestion(value: unknown): Suggestion {
  const raw = record(value)
  return { student_id: id(raw.student_id ?? raw.id), student_name: text(raw.name ?? raw.student_name, 'Student'), confidence: number(raw.confidence), status: raw.status === 'suggestion' ? 'suggestion' : status(raw.status) }
}
function normalizeReviewItem(value: unknown): ReviewItem {
  const raw = record(value)
  return {
    id: id(raw.id),
    session_id: id(raw.session_id),
    student_id: id(raw.student_id),
    student_name: text(raw.student_name, 'Student'),
    student_email: text(raw.student_email),
    status: (raw.status as ReviewItem['status']) || 'flagged',
    reason_codes: list(raw.reason_codes).map(r => String(r)),
    created_at: text(raw.created_at),
    filmstrip_urls: list(raw.filmstrip_urls).map(u => String(u)),
    metrics: record(raw.metrics),
  }
}
function normalizeSession(value: unknown): Session {
  const raw = record(value)
  const createdAt = text(raw.created_at ?? raw.started_at)
  const rawStatus = text(raw.status)
  const statusVal: Session['status'] = rawStatus === 'finalized' ? 'finalized' : rawStatus === 'closed' ? 'closed' : 'open'
  return {
    id: id(raw.id ?? raw.session_id),
    class_id: id(raw.class_id),
    class_name: raw.class_name === null || raw.class_name === undefined ? undefined : text(raw.class_name),
    started_at: createdAt,
    created_at: createdAt,
    starts_at: raw.starts_at === undefined || raw.starts_at === null ? undefined : text(raw.starts_at),
    ends_at: raw.ends_at === undefined || raw.ends_at === null ? undefined : text(raw.ends_at),
    duration_minutes: raw.duration_minutes === undefined ? undefined : number(raw.duration_minutes),
    finalized_at: raw.finalized_at === null || raw.finalized_at === undefined ? null : text(raw.finalized_at),
    status: statusVal,
    attendance: list(raw.attendance).map(normalizeAttendance),
    suggestions: list(raw.suggestions).map(normalizeSuggestion),
    present_count: raw.present_count === undefined ? undefined : number(raw.present_count),
    absent_count: raw.absent_count === undefined ? undefined : number(raw.absent_count),
    pending_count: raw.pending_count === undefined ? undefined : number(raw.pending_count),
    needs_review_count: raw.needs_review_count === undefined ? undefined : number(raw.needs_review_count),
    rejected_count: raw.rejected_count === undefined ? undefined : number(raw.rejected_count),
    total_enrolled: raw.total_enrolled === undefined ? undefined : number(raw.total_enrolled),
  }
}
function normalizeClass(value: unknown): ClassItem {
  const raw = record(value)
  return { id: id(raw.id ?? raw.class_id), name: text(raw.name ?? raw.title, 'Class'), code: raw.code === undefined ? undefined : text(raw.code), schedule: raw.schedule === undefined ? undefined : text(raw.schedule), room: raw.room === undefined ? undefined : text(raw.room), student_count: raw.student_count === undefined ? undefined : number(raw.student_count) }
}
function normalizeStudentAttendance(value: unknown): StudentAttendance {
  const raw = record(value)
  const summary = record(raw.summary)
  return {
    entries: list(raw.entries).map(entry => {
      const item = record(entry)
      return { session_id: id(item.session_id), class_name: item.class_name === undefined ? undefined : text(item.class_name), created_at: text(item.created_at), updated_at: item.updated_at === null || item.updated_at === undefined ? undefined : text(item.updated_at), status: status(item.status), note: item.note === null || item.note === undefined ? undefined : text(item.note) }
    }),
    summary: { present: number(summary.present), absent: number(summary.absent), pending: number(summary.pending), total_finalized: number(summary.total_finalized), percentage: summary.percentage === null || summary.percentage === undefined ? null : number(summary.percentage) },
  }
}
function normalizeAudit(value: unknown): AuditItem {
  const raw = record(value)
  const timestamp = text(raw.timestamp)
  return { id: id(raw.id), session_id: id(raw.session_id), action: text(raw.action, 'event'), timestamp, created_at: timestamp, note: raw.note === null || raw.note === undefined ? undefined : text(raw.note), metadata: record(raw.metadata), actor_name: raw.actor_name === undefined ? undefined : text(raw.actor_name), details: raw.note === null || raw.note === undefined ? undefined : text(raw.note) }
}
function normalizeNotification(value: unknown): Notification {
  const raw = record(value)
  const readAt = raw.read_at === null || raw.read_at === undefined ? null : text(raw.read_at)
  return { id: id(raw.id), title: text(raw.title, 'Attendance update'), body: text(raw.body), created_at: text(raw.created_at), read_at: readAt, read: Boolean(readAt) }
}
function normalizeReportRow(value: unknown): ReportRow {
  const raw = record(value)
  return { name: text(raw.name ?? raw.student_name, 'Student'), email: text(raw.email), status: status(raw.status), note: raw.note === null || raw.note === undefined ? undefined : text(raw.note), updated_at: raw.updated_at === null || raw.updated_at === undefined ? undefined : text(raw.updated_at) }
}
function demoReport(sessionId: string): Report {
  const session = normalizeSession({ ...demoSessions[0], id: sessionId })
  const rows = demoRoster.map(row => ({ name: row.student_name, email: `${row.student_id}@demo.edu`, status: row.status, note: row.note, updated_at: row.updated_at }))
  const csv = [['student_name', 'student_email', 'status', 'note', 'updated_at'], ...rows.map(row => [row.name, row.email, row.status, row.note || '', row.updated_at || ''])].map(row => row.map(value => `"${String(value).replaceAll('"', '""')}"`).join(',')).join('\n')
  return { session, rows, csv, pdf_html: `<h1>${session.class_name || 'Attendance'} attendance</h1><p>Session ${session.id}</p>` }
}

function readStoredUser(): User | null {
  try { const value = window.localStorage.getItem('rollcall-user'); return value ? normalizeUser(JSON.parse(value)) : null } catch { return null }
}

let token = window.localStorage.getItem('rollcall-token') || ''
let cachedUser: User | null = readStoredUser()

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const headers = new Headers(init.headers)
  if (token) headers.set('Authorization', `Bearer ${token}`)
  if (!(init.body instanceof FormData)) headers.set('Content-Type', 'application/json')
  const response = await fetch(`${API_BASE}${path}`, { ...init, headers })
  if (!response.ok) throw new Error((await response.text()) || `Request failed (${response.status})`)
  if (response.status === 204) return undefined as T
  return response.json() as Promise<T>
}

export function currentUser() { return cachedUser }
export function signOut() { token = ''; cachedUser = null; window.localStorage.removeItem('rollcall-token'); window.localStorage.removeItem('rollcall-user'); setLocalMode(false) }

export async function login(email: string, password: string): Promise<{ user: User; local: boolean }> {
  try {
    const result = await request<{ access_token: string; user: unknown }>('/auth/login', { method: 'POST', body: JSON.stringify({ email, password }) })
    token = result.access_token; cachedUser = normalizeUser(result.user); setLocalMode(false)
    window.localStorage.setItem('rollcall-token', token); window.localStorage.setItem('rollcall-user', JSON.stringify(cachedUser))
    return { user: cachedUser, local: false }
  } catch (error) {
    const isTeacher = email === demoTeacher.email && password === 'teach123'
    const isStudent1 = email === demoStudent.email && password === 'student123'
    const isStudent2 = email === demoStudent2.email && password === 'student123'
    if (!isTeacher && !isStudent1 && !isStudent2) throw error
    cachedUser = isTeacher ? demoTeacher : isStudent2 ? demoStudent2 : demoStudent
    token = `demo-${cachedUser.id}`; setLocalMode(true)
    window.localStorage.setItem('rollcall-token', token); window.localStorage.setItem('rollcall-user', JSON.stringify(cachedUser))
    return { user: cachedUser, local: true }
  }
}

export async function getClasses(): Promise<ClassItem[]> { if (isLocalMode()) return demoClasses; return list(await request<unknown>('/classes')).map(normalizeClass) }
export async function getSessions(): Promise<Session[]> { if (isLocalMode()) return demoSessions; return list(await request<unknown>('/sessions')).map(normalizeSession) }
export async function getRoster(sessionId: string): Promise<Session> { if (isLocalMode()) return { ...demoSessions[0], id: sessionId, status: 'open', started_at: new Date().toISOString(), created_at: new Date().toISOString(), attendance: demoRoster, suggestions: [] }; return normalizeSession(await request<unknown>(`/sessions/${encodeURIComponent(sessionId)}`)) }

export async function serverTime(): Promise<Date> {
  if (isLocalMode()) return new Date()
  try {
    const res = await request<{ server_time: string }>('/time')
    return new Date(res.server_time)
  } catch {
    return new Date()
  }
}

export async function startSession(classId: string, durationMinutes = 10): Promise<Session> {
  if (isLocalMode()) return {
    id: `local-${Date.now()}`,
    class_id: classId,
    class_name: demoClasses.find(c => c.id === classId)?.name,
    started_at: new Date().toISOString(),
    created_at: new Date().toISOString(),
    starts_at: new Date().toISOString(),
    ends_at: new Date(Date.now() + durationMinutes * 60000).toISOString(),
    duration_minutes: durationMinutes,
    status: 'open',
    attendance: demoRoster.map(s => ({ ...s, status: 'pending', confidence: undefined })),
  }
  return normalizeSession(await request<unknown>('/sessions', {
    method: 'POST',
    body: JSON.stringify({ class_id: classId, duration_minutes: durationMinutes }),
  }))
}

export async function getReviewQueue(sessionId: string): Promise<ReviewItem[]> {
  if (isLocalMode()) return []
  return list(await request<unknown>(`/sessions/${encodeURIComponent(sessionId)}/review-queue`)).map(normalizeReviewItem)
}

export async function submitReviewDecision(sessionId: string, attemptId: string, decision: 'verified' | 'rejected', note?: string): Promise<void> {
  if (isLocalMode()) return
  await request(`/sessions/${encodeURIComponent(sessionId)}/review/${encodeURIComponent(attemptId)}`, {
    method: 'POST',
    body: JSON.stringify({ decision, note }),
  })
}
export async function patchAttendance(sessionId: string, studentId: string, attendanceStatus: AttendanceEntry['status'], note?: string) { if (isLocalMode()) return; return request(`/sessions/${encodeURIComponent(sessionId)}/attendance/${encodeURIComponent(studentId)}`, { method: 'PATCH', body: JSON.stringify({ status: attendanceStatus, note }) }) }
export async function finalize(sessionId: string) { if (isLocalMode()) return; return request(`/sessions/${encodeURIComponent(sessionId)}/finalize`, { method: 'POST', body: JSON.stringify({ mark_pending_absent: true }) }) }
export async function reports(sessionId: string): Promise<Report> {
  if (isLocalMode()) return demoReport(sessionId)
  const raw = record(await request<unknown>(`/reports/sessions/${encodeURIComponent(sessionId)}`))
  return { session: normalizeSession(raw.session), rows: list(raw.rows).map(normalizeReportRow), csv: text(raw.csv), pdf_html: text(raw.pdf_html ?? raw.pdf) }
}
export async function audit(sessionId: string): Promise<AuditItem[]> {
  if (isLocalMode()) return [{ id: 'audit-1', session_id: sessionId, action: 'session.created', actor_name: demoTeacher.name, timestamp: new Date(Date.now() - 3600000).toISOString(), created_at: new Date(Date.now() - 3600000).toISOString(), note: 'Created from HCI class' }, { id: 'audit-2', session_id: sessionId, action: 'capture.simulated', actor_name: demoTeacher.name, timestamp: new Date(Date.now() - 1800000).toISOString(), created_at: new Date(Date.now() - 1800000).toISOString(), note: '3 synthetic suggestions generated; image discarded' }]
  return list(await request<unknown>(`/audit?session_id=${encodeURIComponent(sessionId)}`)).map(normalizeAudit)
}
export async function studentAttendance(): Promise<StudentAttendance> { if (isLocalMode()) return cachedUser?.id === demoStudent2.id ? demoStudentAttendance2 : demoStudentAttendance; return normalizeStudentAttendance(await request<unknown>('/students/me/attendance')) }
export async function notifications(): Promise<Notification[]> { if (isLocalMode()) return cachedUser?.role === 'teacher' ? [] : cachedUser?.id === demoStudent2.id ? demoNotifications2 : demoNotifications; return list(await request<unknown>('/notifications')).map(normalizeNotification) }
export async function markRead(notificationId: string) { if (isLocalMode()) return; return request(`/notifications/${encodeURIComponent(notificationId)}/read`, { method: 'POST' }) }
export async function wsTicket(): Promise<string> { if (isLocalMode()) return `demo-ticket-${Date.now()}`; const result = record(await request<unknown>('/auth/ws-ticket', { method: 'POST' })); return text(result.ticket) }

export function openRealtime(ticket: string, onMessage: (event: { type: string; data?: unknown }) => void, onState: (state: 'connected' | 'closed' | 'error') => void) {
  if (isLocalMode()) { onState('connected'); return () => onState('closed') }
  const origin = new URL(API_BASE)
  const protocol = origin.protocol === 'https:' ? 'wss:' : 'ws:'
  const socket = new WebSocket(`${protocol}//${origin.host}/ws?ticket=${encodeURIComponent(ticket)}`)
  socket.onopen = () => onState('connected'); socket.onclose = () => onState('closed'); socket.onerror = () => onState('error'); socket.onmessage = event => { try { onMessage(JSON.parse(event.data)) } catch { /* ignore malformed event */ } }
  return () => socket.close()
}

export const roleLabel = (role: Role) => role === 'teacher' ? 'Lecturer workspace' : 'Student view'
