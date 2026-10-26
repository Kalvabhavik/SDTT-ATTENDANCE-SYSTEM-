export type Role = 'teacher' | 'student'
export type AttendanceStatus = 'present' | 'absent' | 'pending'
export type SessionStatus = 'open' | 'closed' | 'finalized'

export interface User { id: string; name: string; email: string; role: Role }
export interface ClassItem { id: string; name: string; code?: string; schedule?: string; room?: string; student_count?: number }
export interface AttendanceEntry { student_id: string; student_name: string; student_email?: string; status: AttendanceStatus; note?: string; changed_at?: string; updated_at?: string }
export interface Session { id: string; class_id: string; class_name?: string; started_at: string; created_at?: string; starts_at?: string; ends_at?: string; server_time?: string; duration_minutes?: number; finalized_at?: string | null; status: SessionStatus; attendance?: AttendanceEntry[]; present_count?: number; absent_count?: number; pending_count?: number }
export interface AttendanceSummary { present: number; absent: number; pending: number; total_finalized: number; percentage: number | null }
export interface StudentAttendanceEntry { session_id: string; class_name?: string; created_at: string; updated_at?: string; status: AttendanceStatus; note?: string }
export interface StudentAttendance { entries: StudentAttendanceEntry[]; summary: AttendanceSummary }
export interface Notification { id: string; title: string; body: string; created_at: string; read_at?: string | null; read: boolean }
export interface AuditItem { id: string; session_id: string; action: string; timestamp: string; note?: string | null; metadata?: Record<string, unknown>; actor_name?: string; created_at?: string; details?: string }
export interface ReportRow { name: string; email: string; status: AttendanceStatus; note?: string | null; updated_at?: string }
export interface Report { session: Session; rows: ReportRow[]; csv: string; pdf_html: string }
export interface ReviewSubmission { attempt_id: string; student_id: string; reason_code: string; rules_json: Record<string, { passed: boolean | null; reason_code: string; detail: string }>; metrics_json: Record<string, unknown>; created_at: string; filmstrip: Array<{ storage_path: string; frame_offset_ms: number; heading_degrees: number; signed_url: string }> }
