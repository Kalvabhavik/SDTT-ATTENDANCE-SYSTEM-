import type { AttendanceEntry, AuditItem, ClassItem, Notification, Report, ReportRow, ReviewSubmission, Role, Session, StudentAttendance, User } from './types'

const API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000/api').replace(/\/$/, '')
export const getApiBase = () => API_BASE
function record(value: unknown): Record<string, unknown> { return value && typeof value === 'object' ? value as Record<string, unknown> : {} }
function list(value: unknown): unknown[] { return Array.isArray(value) ? value : [] }
function text(value: unknown, fallback = ''): string { return value === null || value === undefined ? fallback : String(value) }
function id(value: unknown): string { return text(value) }
function number(value: unknown, fallback = 0): number { return typeof value === 'number' ? value : Number(value ?? fallback) || fallback }
function attendanceStatus(value: unknown): AttendanceEntry['status'] { return value === 'present' || value === 'absent' || value === 'pending' ? value : 'pending' }
function normalizeUser(value: unknown): User {
  const raw = record(value)
  if (raw.role !== 'teacher' && raw.role !== 'student') throw new Error('The account role returned by the service is invalid.')
  return { id: id(raw.id), name: text(raw.name, 'User'), email: text(raw.email), role: raw.role }
}
function normalizeAttendance(value: unknown): AttendanceEntry {
  const raw = record(value); const updated = raw.updated_at == null ? undefined : text(raw.updated_at)
  return { student_id: id(raw.student_id ?? raw.id), student_name: text(raw.name ?? raw.student_name, 'Student'), student_email: raw.email == null ? undefined : text(raw.email), status: attendanceStatus(raw.status), note: raw.note == null ? undefined : text(raw.note), changed_at: updated, updated_at: updated }
}
function normalizeSession(value: unknown): Session {
  const raw = record(value); const created = text(raw.created_at ?? raw.started_at)
  const status = raw.status === 'closed' || raw.status === 'finalized' ? raw.status : 'open'
  return { id: id(raw.id ?? raw.session_id), class_id: id(raw.class_id), class_name: raw.class_name == null ? undefined : text(raw.class_name), started_at: text(raw.starts_at ?? created), created_at: created, starts_at: raw.starts_at == null ? undefined : text(raw.starts_at), ends_at: raw.ends_at == null ? undefined : text(raw.ends_at), server_time: raw.server_time == null ? undefined : text(raw.server_time), duration_minutes: raw.duration_minutes == null ? undefined : number(raw.duration_minutes), finalized_at: raw.finalized_at == null ? null : text(raw.finalized_at), status, attendance: list(raw.attendance).map(normalizeAttendance), present_count: raw.present_count == null ? undefined : number(raw.present_count), absent_count: raw.absent_count == null ? undefined : number(raw.absent_count), pending_count: raw.pending_count == null ? undefined : number(raw.pending_count) }
}
function normalizeClass(value: unknown): ClassItem {
  const raw = record(value)
  return { id: id(raw.id ?? raw.class_id), name: text(raw.name ?? raw.title, 'Class'), code: raw.code == null ? undefined : text(raw.code), schedule: raw.schedule == null ? undefined : text(raw.schedule), room: raw.room == null ? undefined : text(raw.room), student_count: raw.student_count == null ? undefined : number(raw.student_count) }
}
function normalizeStudentAttendance(value: unknown): StudentAttendance {
  const raw = record(value); const summary = record(raw.summary)
  return { entries: list(raw.entries).map(value => { const item = record(value); return { session_id: id(item.session_id), class_name: item.class_name == null ? undefined : text(item.class_name), created_at: text(item.created_at), updated_at: item.updated_at == null ? undefined : text(item.updated_at), status: attendanceStatus(item.status), note: item.note == null ? undefined : text(item.note) } }), summary: { present: number(summary.present), absent: number(summary.absent), pending: number(summary.pending), total_finalized: number(summary.total_finalized), percentage: summary.percentage == null ? null : number(summary.percentage) } }
}
function normalizeAudit(value: unknown): AuditItem {
  const raw = record(value); const timestamp = text(raw.timestamp)
  return { id: id(raw.id), session_id: id(raw.session_id), action: text(raw.action, 'event'), timestamp, created_at: timestamp, note: raw.note == null ? undefined : text(raw.note), metadata: record(raw.metadata), actor_name: raw.actor_name == null ? undefined : text(raw.actor_name), details: raw.note == null ? undefined : text(raw.note) }
}
function normalizeNotification(value: unknown): Notification {
  const raw = record(value); const readAt = raw.read_at == null ? null : text(raw.read_at)
  return { id: id(raw.id), title: text(raw.title, 'Attendance update'), body: text(raw.body), created_at: text(raw.created_at), read_at: readAt, read: Boolean(readAt) }
}
function normalizeReportRow(value: unknown): ReportRow {
  const raw = record(value)
  return { name: text(raw.name ?? raw.student_name, 'Student'), email: text(raw.email), status: attendanceStatus(raw.status), note: raw.note == null ? undefined : text(raw.note), updated_at: raw.updated_at == null ? undefined : text(raw.updated_at) }
}

let token = ''
let cachedUser: User | null = null
try { const saved = window.localStorage.getItem('rollcall-user'); cachedUser = saved ? normalizeUser(JSON.parse(saved)) : null } catch { cachedUser = null }

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const headers = new Headers(init.headers)
  if (token) headers.set('Authorization', `Bearer ${token}`)
  if (!(init.body instanceof FormData)) headers.set('Content-Type', 'application/json')
  const response = await fetch(`${API_BASE}${path}`, { ...init, headers })
  const body = response.status === 204 ? null : await response.json().catch(() => null)
  if (!response.ok) throw new Error(text(record(body).detail, `Request failed (${response.status}).`))
  return body as T
}
export const currentUser = () => cachedUser
export async function verifyCurrentUser(): Promise<User> {
  const user = normalizeUser(await request<unknown>('/me'))
  cachedUser = user
  window.localStorage.setItem('rollcall-user', JSON.stringify(user))
  return user
}
export function signOut() { token = ''; cachedUser = null; window.localStorage.removeItem('rollcall-user') }
export async function login(email: string, password: string, selectedRole: Role): Promise<User> {
  const result = await request<{ access_token: string; user: unknown }>('/auth/login', { method: 'POST', body: JSON.stringify({ email, password, selected_role: selectedRole }) })
  token = result.access_token; cachedUser = normalizeUser(result.user)
  window.localStorage.setItem('rollcall-user', JSON.stringify(cachedUser))
  return cachedUser
}
export async function getConfig() { return request<{ max_session_minutes: number; server_time: string }>('/config') }
export async function getClasses(): Promise<ClassItem[]> { return list(await request<unknown>('/classes')).map(normalizeClass) }
export async function getSessions(): Promise<Session[]> { return list(await request<unknown>('/sessions')).map(normalizeSession) }
export async function getRoster(sessionId: string): Promise<Session> { return normalizeSession(await request<unknown>(`/sessions/${encodeURIComponent(sessionId)}`)) }
export async function startSession(classId: string, durationMinutes: number): Promise<Session> { return normalizeSession(await request<unknown>('/sessions', { method: 'POST', body: JSON.stringify({ class_id: classId, duration_minutes: durationMinutes }) })) }
export async function patchAttendance(sessionId: string, studentId: string, status: AttendanceEntry['status'], note?: string) { return request(`/sessions/${encodeURIComponent(sessionId)}/attendance/${encodeURIComponent(studentId)}`, { method: 'PATCH', body: JSON.stringify({ status, note }) }) }
export async function finalize(sessionId: string) { return request(`/sessions/${encodeURIComponent(sessionId)}/finalize`, { method: 'POST', body: JSON.stringify({ mark_pending_absent: true }) }) }
export async function reports(sessionId: string): Promise<Report> {
  const raw = record(await request<unknown>(`/reports/sessions/${encodeURIComponent(sessionId)}`))
  return { session: normalizeSession(raw.session), rows: list(raw.rows).map(normalizeReportRow), csv: text(raw.csv), pdf_html: text(raw.pdf_html) }
}
export async function audit(sessionId: string): Promise<AuditItem[]> { return list(await request<unknown>(`/audit?session_id=${encodeURIComponent(sessionId)}`)).map(normalizeAudit) }
export async function reviewQueue(sessionId: string): Promise<ReviewSubmission[]> { return list(await request<unknown>(`/sessions/${encodeURIComponent(sessionId)}/review-queue`)).map(item => record(item) as unknown as ReviewSubmission) }
export async function reviewSubmission(sessionId: string, attemptId: string, decision: 'accepted' | 'rejected', note: string) { return request(`/sessions/${encodeURIComponent(sessionId)}/submissions/${encodeURIComponent(attemptId)}/review`, { method: 'PATCH', body: JSON.stringify({ decision, note }) }) }
export async function studentAttendance(): Promise<StudentAttendance> { return normalizeStudentAttendance(await request<unknown>('/students/me/attendance')) }
export async function notifications(): Promise<Notification[]> { return list(await request<unknown>('/notifications')).map(normalizeNotification) }
export async function markRead(notificationId: string) { return request(`/notifications/${encodeURIComponent(notificationId)}/read`, { method: 'POST' }) }
export async function wsTicket(): Promise<string> { const result = record(await request<unknown>('/auth/ws-ticket', { method: 'POST' })); return text(result.ticket) }
export function openRealtime(ticket: string, onMessage: (event: { type: string; data?: unknown }) => void, onState: (state: 'connected' | 'closed' | 'error') => void) {
  const origin = new URL(API_BASE); const protocol = origin.protocol === 'https:' ? 'wss:' : 'ws:'
  const socket = new WebSocket(`${protocol}//${origin.host}/ws?ticket=${encodeURIComponent(ticket)}`)
  socket.onopen = () => onState('connected'); socket.onclose = () => onState('closed'); socket.onerror = () => onState('error'); socket.onmessage = event => { try { onMessage(JSON.parse(event.data)) } catch { /* Ignore malformed server events; REST remains authoritative. */ } }
  return () => socket.close()
}
export const roleLabel = (role: Role) => role === 'teacher' ? 'Lecturer workspace' : 'Student view'
