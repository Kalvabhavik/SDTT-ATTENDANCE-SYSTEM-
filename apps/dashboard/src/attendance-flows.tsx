import { useCallback, useEffect, useRef, useState, type FormEvent } from 'react'
import { Camera } from 'lucide-react'
import * as api from './api'
import type { AttendanceEntry, ClassItem, ImageSubmission, Report, Session, StudentAttendance, User } from './types'

const localDateTime = (date: Date) => new Date(date.getTime() - date.getTimezoneOffset() * 60000).toISOString().slice(0, 16)
const displayTime = (value?: string | null) => value ? new Date(value).toLocaleString() : '—'
const statusLabel = (value?: string | null) => value && value !== 'unknown' ? value.replaceAll('_', ' ').toLowerCase() : 'status unavailable'
const statusTone = (value?: string | null) => !value || value === 'unknown' ? 'unavailable' : value.toLowerCase().replaceAll('_', '-')

function Message({ children, error = false }: { children: string; error?: boolean }) {
  return <div className={error ? 'flow-message error' : 'flow-message'} role={error ? 'alert' : 'status'}>{children}</div>
}

export function ProfessorSessionsFlow() {
  const [classes, setClasses] = useState<ClassItem[]>([])
  const [sessions, setSessions] = useState<Session[]>([])
  const [active, setActive] = useState<Session | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [title, setTitle] = useState('Class attendance')
  const [classId, setClassId] = useState('')
  const now = new Date()
  const [opensAt, setOpensAt] = useState(localDateTime(now))
  const [deadlineAt, setDeadlineAt] = useState(localDateTime(new Date(now.getTime() + 60 * 60 * 1000)))
  const [stageRegion, setStageRegion] = useState({ x: 40, y: 0, width: 25, height: 100 })
  const [minimumPeople, setMinimumPeople] = useState(2)
  const [creating, setCreating] = useState(false)

  const load = useCallback(async () => {
    setLoading(true); setError('')
    try {
      const [classRows, sessionRows] = await Promise.all([api.getClasses(), api.getSessions()])
      setClasses(classRows); setSessions(sessionRows)
      setClassId(current => current || classRows[0]?.id || '')
    } catch (reason) { setError(reason instanceof Error ? reason.message : 'Could not load classes and sessions.') }
    finally { setLoading(false) }
  }, [])
  useEffect(() => { void load(); const listener = () => void load(); window.addEventListener('rollcall:refresh', listener); return () => window.removeEventListener('rollcall:refresh', listener) }, [load])

  async function createSession(event: FormEvent) {
    event.preventDefault(); setError('')
    if (!classId) { setError('Select a class first.'); return }
    const start = new Date(opensAt); const deadline = new Date(deadlineAt)
    if (!Number.isFinite(start.getTime()) || !Number.isFinite(deadline.getTime()) || deadline <= start) { setError('Set a valid opening time and a later deadline.'); return }
    if (stageRegion.x < 0 || stageRegion.y < 0 || stageRegion.width <= 0 || stageRegion.height <= 0 || stageRegion.x + stageRegion.width > 100 || stageRegion.y + stageRegion.height > 100) { setError('The stage rectangle must fit inside the image.'); return }
    setCreating(true)
    try {
      const created = await api.startSession(classId, {
        title: title.trim() || 'Class attendance',
        opens_at: start.toISOString(),
        deadline_at: deadline.toISOString(),
        stage_region: { x: stageRegion.x / 100, y: stageRegion.y / 100, width: stageRegion.width / 100, height: stageRegion.height / 100 },
        minimum_people_visible: minimumPeople,
      })
      setSessions(previous => [created, ...previous.filter(item => item.id !== created.id)])
      setActive(created)
    } catch (reason) { setError(reason instanceof Error ? reason.message : 'Could not create the session.') }
    finally { setCreating(false) }
  }

  if (active) return <ProfessorSessionWorkspace session={active} onBack={() => { setActive(null); void load() }} />
  return <main className="attendance-flow">
    <header className="flow-heading"><div><p className="eyebrow">Professor workspace</p><h1>Attendance sessions</h1><p>Create a timed session, configure the stage area, then review uncertain images before finalizing.</p></div><button className="secondary-button" onClick={() => void load()} disabled={loading}>Refresh</button></header>
    {error && <Message error>{error}</Message>}
    <section className="flow-panel"><h2>Create a session</h2>
      <form className="flow-form" onSubmit={createSession}>
        <label>Course / section<select value={classId} onChange={event => setClassId(event.target.value)} required><option value="">Select a class</option>{classes.map(item => <option value={item.id} key={item.id}>{item.name}{item.code ? ` · ${item.code}` : ''}</option>)}</select></label>
        <label>Session title<input value={title} onChange={event => setTitle(event.target.value)} maxLength={120} required /></label>
        <label>Attendance opens<input type="datetime-local" value={opensAt} onChange={event => setOpensAt(event.target.value)} required /></label>
        <label>Submission deadline<input type="datetime-local" value={deadlineAt} onChange={event => setDeadlineAt(event.target.value)} required /></label>
        <fieldset className="flow-region"><legend>Stage / lecturer region in panorama (percent)</legend><p>Set the expected region in the captured image. A person detected there is only scene evidence; this does not identify a lecturer or confirm a stage.</p>
          <label>Left %<input type="number" min="0" max="99" value={stageRegion.x} onChange={event => setStageRegion(value => ({ ...value, x: Number(event.target.value) }))} /></label>
          <label>Top %<input type="number" min="0" max="99" value={stageRegion.y} onChange={event => setStageRegion(value => ({ ...value, y: Number(event.target.value) }))} /></label>
          <label>Width %<input type="number" min="1" max="100" value={stageRegion.width} onChange={event => setStageRegion(value => ({ ...value, width: Number(event.target.value) }))} /></label>
          <label>Height %<input type="number" min="1" max="100" value={stageRegion.height} onChange={event => setStageRegion(value => ({ ...value, height: Number(event.target.value) }))} /></label>
        </fieldset>
        <label>Minimum nearby people<input type="number" min="1" max="30" value={minimumPeople} onChange={event => setMinimumPeople(Number(event.target.value))} required /></label>
        <p className="flow-hint">Times are sent with a timezone. The API clock enforces the opening time and deadline; the browser clock is informational only.</p>
        <button className="primary-button" type="submit" disabled={creating || !classes.length}>{creating ? 'Creating…' : 'Create attendance session'}</button>
      </form>
      {!classes.length && !loading && <Message>No classes are assigned to this professor account.</Message>}
    </section>
    <section className="flow-panel"><div className="flow-section-heading"><h2>Recent sessions</h2><span>{sessions.length} total</span></div>
      {loading && <p>Loading sessions…</p>}
      {!loading && !sessions.length && <p>No sessions have been created yet.</p>}
      <div className="flow-session-list">{sessions.map(session => <button className="flow-session-item" key={session.id} onClick={() => setActive(session)}><span><strong>{session.title || session.class_name || 'Attendance session'}</strong><small>{session.class_name || 'Class'} · Opens {displayTime(session.opens_at)} · Deadline {displayTime(session.deadline_at)}</small></span><span className={`flow-status ${statusTone(session.status)}`}>{statusLabel(session.status)}</span></button>)}</div>
    </section>
  </main>
}

function ProfessorSessionWorkspace({ session: initialSession, onBack }: { session: Session; onBack: () => void }) {
  const [session, setSession] = useState(initialSession)
  const [submissions, setSubmissions] = useState<ImageSubmission[]>([])
  const [report, setReport] = useState<Report | null>(null)
  const [busy, setBusy] = useState(false)
  const [refreshing, setRefreshing] = useState(false)
  const [loaded, setLoaded] = useState(false)
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null)
  const [error, setError] = useState('')
  const [message, setMessage] = useState('')
  const [search, setSearch] = useState('')
  const [submissionFilter, setSubmissionFilter] = useState('all')
  const [rosterFilter, setRosterFilter] = useState('all')
  const [reasonAction, setReasonAction] = useState<{ kind: 'review'; item: ImageSubmission; decision: 'approve' | 'reject' } | { kind: 'attendance'; row: AttendanceEntry; status: AttendanceEntry['status'] } | null>(null)
  const [reason, setReason] = useState('')

  const load = useCallback(async () => {
    setRefreshing(true); setError('')
    try {
      const [detail, items] = await Promise.all([api.getRoster(initialSession.id), api.listSubmissions(initialSession.id)])
      setSession(detail); setSubmissions(items); setLoaded(true); setLastUpdated(new Date())
    } catch (reason) { setError(reason instanceof Error ? reason.message : 'Could not refresh this session.') }
    finally { setRefreshing(false) }
  }, [initialSession.id])
  useEffect(() => { void load(); const timer = window.setInterval(() => void load(), 15000); return () => window.clearInterval(timer) }, [load])

  async function changeWindow(action: 'open' | 'close') {
    setBusy(true); setError(''); setMessage('')
    try { if (action === 'open') await api.openSession(session.id); else await api.closeSession(session.id); await load(); setMessage(action === 'open' ? 'Attendance window opened.' : 'Attendance window closed. New uploads are now blocked.') }
    catch (reason) { setError(reason instanceof Error ? reason.message : 'Could not update the session window.') }
    finally { setBusy(false) }
  }
  function openReasonForm(action: NonNullable<typeof reasonAction>) {
    setReasonAction(action); setReason(''); setError(''); setMessage('')
  }
  function closeReasonForm() { setReasonAction(null); setReason('') }
  async function submitReason(event: FormEvent) {
    event.preventDefault()
    const note = reason.trim()
    if (!note || !reasonAction) return
    setBusy(true); setError(''); setMessage('')
    try {
      if (reasonAction.kind === 'review') {
        const { item, decision } = reasonAction
        await api.reviewSubmission(session.id, item.id, decision, note)
        closeReasonForm(); await load(); setMessage(`Submission ${decision === 'approve' ? 'approved' : 'rejected'}.`)
      } else {
        const { row, status } = reasonAction
        await api.patchAttendance(session.id, row.student_id, status, note)
        closeReasonForm(); await load(); setMessage(`Attendance updated for ${row.student_name}.`)
      }
    }
    catch (reasonError) { setError(reasonError instanceof Error ? reasonError.message : 'Could not save this decision.') }
    finally { setBusy(false) }
  }
  async function finalize() {
    if (!window.confirm('Finalize this closed session? Remaining pending students will be marked absent.')) return
    setBusy(true); setError('')
    try { await api.finalize(session.id); await load(); setMessage('Session finalized. The report is ready.') }
    catch (reason) { setError(reason instanceof Error ? reason.message : 'Could not finalize the session.') }
    finally { setBusy(false) }
  }
  async function loadReport() {
    setError('')
    try { setReport(await api.reports(session.id)) }
    catch (reason) { setError(reason instanceof Error ? reason.message : 'Could not build the final report.') }
  }
  function downloadCsv() {
    if (!report) return
    const url = URL.createObjectURL(new Blob([report.csv], { type: 'text/csv;charset=utf-8' }))
    const anchor = document.createElement('a'); anchor.href = url; anchor.download = `${session.id}-attendance.csv`; anchor.click(); URL.revokeObjectURL(url)
  }

  const roster = session.attendance || []
  const summary = report?.summary
  const query = search.trim().toLocaleLowerCase()
  const matches = (values: Array<string | null | undefined>) => !query || values.some(value => value?.toLocaleLowerCase().includes(query))
  const reviewOutcome = (item: ImageSubmission) => {
    const decision = item.review_decision?.toLowerCase()
    return decision?.includes('approv') ? 'approved' : decision?.includes('reject') ? 'rejected' : ''
  }
  const requiresProfessorReview = (item: ImageSubmission) => !item.review_decision && ['NEEDS_REVIEW', 'REJECTED'].includes(item.status)
  const submissionStatuses = Array.from(new Set(submissions.map(item => item.status).filter(Boolean)))
  const visibleSubmissions = submissions.filter(item => {
    const fitsStatus = submissionFilter === 'all' ||
      (submissionFilter === 'awaiting' && requiresProfessorReview(item)) ||
      (submissionFilter === 'approved' && reviewOutcome(item) === 'approved') ||
      (submissionFilter === 'rejected' && reviewOutcome(item) === 'rejected') ||
      (submissionFilter.startsWith('status:') && item.status === submissionFilter.slice(7))
    return fitsStatus && matches([item.student_name, item.student_email, item.student_id, item.explanation, item.status, item.review_decision])
  })
  const visibleRoster = roster.filter(row => (rosterFilter === 'all' || row.status === rosterFilter) && matches([row.student_name, row.student_email, row.registration_id, row.student_id, row.status, row.verification_status]))
  const awaitingReview = submissions.filter(requiresProfessorReview).length
  const approvedReviews = submissions.filter(item => reviewOutcome(item) === 'approved').length
  const rejectedReviews = submissions.filter(item => reviewOutcome(item) === 'rejected').length
  const countOrUnknown = (count: number) => loaded ? String(count) : 'Unknown'
  return <main className="attendance-flow">
    <button className="text-button" onClick={onBack}>← All sessions</button>
    <header className="flow-heading"><div><p className="eyebrow">Professor review</p><h1>{session.title || session.class_name || 'Attendance session'}</h1><p>{session.class_name} · Opens {displayTime(session.opens_at)} · Deadline {displayTime(session.deadline_at)}</p></div><span className={`flow-status ${statusTone(session.status)}`}>{statusLabel(session.status)}</span></header>
    <div className="flow-refresh-bar"><span>{lastUpdated ? `Last updated ${lastUpdated.toLocaleTimeString()}` : loaded ? 'Session data loaded' : 'Session data not loaded yet'}</span><button className="secondary-button" type="button" onClick={() => void load()} disabled={refreshing}>{refreshing ? 'Refreshing…' : 'Refresh session'}</button></div>
    {error && <Message error>{error}</Message>}{message && <Message>{message}</Message>}
    <section className="flow-panel"><div className="flow-section-heading"><h2>Session snapshot</h2><span>{loaded ? 'Counts from this session’s loaded roster and submissions' : 'Counts remain unknown until session data loads'}</span></div><div className="flow-summary-grid"><Summary label="Rostered" value={countOrUnknown(roster.length)} /><Summary label="Submissions" value={countOrUnknown(submissions.length)} /><Summary label="Awaiting professor review" value={countOrUnknown(awaitingReview)} /><Summary label="Manually approved" value={countOrUnknown(approvedReviews)} /><Summary label="Manually rejected" value={countOrUnknown(rejectedReviews)} /><Summary label="Present on roster" value={countOrUnknown(roster.filter(row => row.status === 'present').length)} /><Summary label="Absent on roster" value={countOrUnknown(roster.filter(row => row.status === 'absent').length)} /><Summary label="Pending on roster" value={countOrUnknown(roster.filter(row => row.status === 'pending').length)} /><Summary label="Status unavailable" value={countOrUnknown(roster.filter(row => row.status === 'unknown').length)} /></div><p className="flow-hint">Review counts include only unreviewed NEEDS_REVIEW and REJECTED submissions. Roster counts use each loaded attendance status. These are session-only counts, not identity or audit metrics.</p></section>
    <section className="flow-panel flow-actions"><div><strong>Window control</strong><p>{session.status === 'scheduled' ? 'The session is scheduled; students cannot submit until it opens.' : session.status === 'open' ? 'Students may submit until you close the window or the deadline passes.' : session.status === 'closed' ? 'Submissions are closed. Review any remaining cases before finalizing.' : session.status === 'finalized' ? 'This session is finalized and read-only.' : 'Session status is unavailable. Refresh before taking an action.'}</p></div>
      {session.status === 'scheduled' && <button className="primary-button" disabled={busy} onClick={() => void changeWindow('open')}>Open now</button>}
      {session.status === 'open' && <button className="secondary-button" disabled={busy} onClick={() => void changeWindow('close')}>Close window</button>}
      {session.status === 'closed' && <button className="primary-button" disabled={busy} onClick={() => void finalize()}>Finalize attendance</button>}
      {session.status === 'finalized' && <button className="secondary-button" onClick={() => void loadReport()}>Load final report</button>}
      {session.status === 'closed' && <button className="secondary-button" onClick={() => void loadReport()}>Preview report</button>}
    </section>
    <section className="flow-panel"><div className="flow-section-heading"><h2>Session review inbox</h2><span>{loaded ? `${visibleSubmissions.length} of ${submissions.length} submissions shown` : 'Submission data not loaded'}</span></div>
      <div className="flow-inbox-controls"><label>Search this session<input type="search" value={search} onChange={event => setSearch(event.target.value)} placeholder="Name, email, student ID, or text" /></label><label>Submission status<select value={submissionFilter} onChange={event => setSubmissionFilter(event.target.value)}><option value="all">All submissions</option><option value="awaiting">Awaiting professor decision</option><option value="approved">Approved by professor</option><option value="rejected">Rejected by professor</option>{submissionStatuses.map(status => <option value={`status:${status}`} key={status}>Submission status: {statusLabel(status)}</option>)}</select></label></div>
      {loaded && !submissions.length && <p>No student has submitted a classroom image yet.</p>}
      {loaded && submissions.length > 0 && !visibleSubmissions.length && <p>No submissions match the search and status filter.</p>}
      <div className="flow-submissions">{visibleSubmissions.map(item => <article className="flow-submission" key={item.id}>
        <div className="flow-submission-head"><div><h3>{item.student_name}</h3><small>{item.student_email || item.student_id} · {displayTime(item.submitted_at)} · attempt {item.attempt_number}</small></div><span className={`flow-status ${statusTone(item.review_decision ? `MANUALLY_${item.review_decision}` : item.status)}`}>{item.review_decision ? `Manual ${statusLabel(item.review_decision)}` : statusLabel(item.status)}</span></div>
        <div className="flow-submission-body">{item.image_url ? <a href={item.image_url} target="_blank" rel="noreferrer"><img src={item.image_url} alt={`Classroom image submitted by ${item.student_name}`} /></a> : <div className="flow-image-missing">Private image preview unavailable</div>}<div><p>{item.explanation}</p><p className="flow-hint">People detected: {item.detected_people ?? 'unknown'} · Nearby people: {item.nearby_people ?? 'unknown'} · Person in configured region: {item.stage_person_detected === null || item.stage_person_detected === undefined ? 'unknown' : item.stage_person_detected ? 'yes' : 'no'}</p>{item.review_reason && <p><strong>Professor note:</strong> {item.review_reason}</p>}
          {!item.review_decision && requiresProfessorReview(item) && session.status !== 'finalized' && <div className="flow-row-actions"><button className="primary-button" disabled={busy} onClick={() => openReasonForm({ kind: 'review', item, decision: 'approve' })}>Approve present</button><button className="secondary-button" disabled={busy} onClick={() => openReasonForm({ kind: 'review', item, decision: 'reject' })}>Reject submission</button></div>}
          {!item.review_decision && item.status === 'VERIFIED' && <p className="flow-hint">Configured scene criteria passed automatically; use the roster controls below if you need to correct attendance.</p>}
          {reasonAction?.kind === 'review' && reasonAction.item.id === item.id && <form className="flow-reason-form" onSubmit={event => void submitReason(event)}><h4 id={`review-reason-heading-${item.id}`}>{reasonAction.decision === 'approve' ? 'Reason for approving' : 'Reason for rejecting'} this submission</h4><label htmlFor={`review-reason-${item.id}`}>Required reason</label><textarea id={`review-reason-${item.id}`} aria-labelledby={`review-reason-heading-${item.id}`} value={reason} onChange={event => setReason(event.target.value)} rows={3} required maxLength={1000} autoFocus /><div className="flow-row-actions"><button className="primary-button" type="submit" disabled={busy || !reason.trim()}>{busy ? 'Saving…' : 'Save review'}</button><button className="secondary-button" type="button" onClick={closeReasonForm} disabled={busy}>Cancel</button></div></form>}
        </div></div>
      </article>)}</div>
    </section>
    <section className="flow-panel"><div className="flow-section-heading"><h2>Attendance roster</h2><span>{loaded ? `${visibleRoster.length} of ${roster.length} rostered students shown` : 'Roster data not loaded'}</span></div><div className="flow-inbox-controls"><label>Roster status<select value={rosterFilter} onChange={event => setRosterFilter(event.target.value)}><option value="all">All roster statuses</option><option value="present">Present</option><option value="absent">Absent</option><option value="pending">Pending</option><option value="unknown">Status unavailable</option></select></label></div><div className="flow-roster">
      {visibleRoster.map(row => <div className="flow-roster-row" key={row.student_id}><div><strong>{row.student_name}</strong><small>{row.registration_id || row.student_email || row.student_id} · {row.verification_status ? statusLabel(row.verification_status) : 'no image submission'}</small></div><span className={`flow-status ${statusTone(row.status)}`}>{statusLabel(row.status)}</span>{session.status !== 'finalized' && <div className="flow-row-actions"><button className="secondary-button small" disabled={busy} onClick={() => openReasonForm({ kind: 'attendance', row, status: 'present' })}>Mark present</button><button className="secondary-button small" disabled={busy} onClick={() => openReasonForm({ kind: 'attendance', row, status: 'absent' })}>Mark absent</button></div>}{reasonAction?.kind === 'attendance' && reasonAction.row.student_id === row.student_id && <form className="flow-reason-form flow-reason-form-wide" onSubmit={event => void submitReason(event)}><h4 id={`attendance-reason-heading-${row.student_id}`}>Reason for marking {row.student_name} {reasonAction.status}</h4><label htmlFor={`attendance-reason-${row.student_id}`}>Required correction reason</label><textarea id={`attendance-reason-${row.student_id}`} aria-labelledby={`attendance-reason-heading-${row.student_id}`} value={reason} onChange={event => setReason(event.target.value)} rows={3} required maxLength={1000} autoFocus /><div className="flow-row-actions"><button className="primary-button" type="submit" disabled={busy || !reason.trim()}>{busy ? 'Saving…' : 'Save attendance correction'}</button><button className="secondary-button" type="button" onClick={closeReasonForm} disabled={busy}>Cancel</button></div></form>}</div>)}
      {loaded && !roster.length && <p>No roster entries were returned for this session.</p>}
      {loaded && roster.length > 0 && !visibleRoster.length && <p>No roster entries match the search and status filter.</p>}
    </div></section>
    {report && <section className="flow-panel"><div className="flow-section-heading"><h2>Session attendance report</h2><button className="secondary-button" onClick={downloadCsv}>Download CSV</button></div><p className="flow-hint">Summary is limited to rows and summary fields returned by this session’s report.</p><div className="flow-summary-grid"><Summary label="Enrolled" value={summary?.total_enrolled ?? report.rows.length} /><Summary label="Present in report" value={report.rows.filter(row => row.status === 'present').length} /><Summary label="Absent in report" value={report.rows.filter(row => row.status === 'absent').length} /><Summary label="Pending in report" value={report.rows.filter(row => row.status === 'pending').length} /><Summary label="Auto-verified present" value={summary?.automatically_verified_present ?? '—'} /><Summary label="Manually approved present" value={summary?.manually_approved_present ?? '—'} /><Summary label="Rejected submissions" value={summary?.rejected_submissions ?? '—'} /><Summary label="Awaiting review" value={summary?.awaiting_review ?? '—'} /><Summary label="Did not submit" value={summary?.did_not_submit ?? '—'} /><Summary label="Final absent" value={summary?.final_absent ?? report.rows.filter(row => row.status === 'absent').length} /></div></section>}
  </main>
}

function Summary({ label, value }: { label: string; value: number | string }) { return <div className="flow-summary"><span>{label}</span><strong>{value}</strong></div> }

export function StudentAttendanceFlow({ user }: { user: User }) {
  const [attendance, setAttendance] = useState<StudentAttendance | null>(null)
  const [session, setSession] = useState<Session | null>(null)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)
  const [now, setNow] = useState(Date.now())

  const load = useCallback(async () => {
    setError('')
    try {
      const [record, sessions] = await Promise.all([api.studentAttendance(), api.getSessions()])
      setAttendance(record)
      const candidate = sessions.find(item => ['open', 'scheduled', 'closed'].includes(item.status || ''))
      if (candidate) setSession(await api.getRoster(candidate.id))
      else setSession(null)
    } catch (reason) { setError(reason instanceof Error ? reason.message : 'Could not load attendance records.') }
    finally { setLoading(false) }
  }, [])
  useEffect(() => { void load(); const listener = () => void load(); window.addEventListener('rollcall:refresh', listener); const timer = window.setInterval(() => setNow(Date.now()), 1000); return () => { window.removeEventListener('rollcall:refresh', listener); window.clearInterval(timer) } }, [load])

  const summary = attendance?.summary
  const remaining = session?.deadline_at ? Math.max(0, Math.ceil((new Date(session.deadline_at).getTime() - now) / 1000)) : null
  const opening = session?.opens_at ? Math.max(0, Math.ceil((new Date(session.opens_at).getTime() - now) / 1000)) : null
  const timerLabel = (value: number) => `${Math.floor(value / 3600).toString().padStart(2, '0')}:${Math.floor((value % 3600) / 60).toString().padStart(2, '0')}:${(value % 60).toString().padStart(2, '0')}`

  return <main className="attendance-flow">
    <header className="flow-heading"><div><p className="eyebrow">Student attendance</p><h1>Hello, {user.name.split(' ')[0]}</h1><p>{user.registration_id ? `Student ID ${user.registration_id} · ` : ''}{user.email}</p></div><button className="secondary-button" onClick={() => void load()} disabled={loading}>Refresh</button></header>
    {error && <Message error>{error}</Message>}
    <div className="flow-summary-grid"><Summary label="Present" value={summary?.present ?? 0} /><Summary label="Absent" value={summary?.absent ?? 0} /><Summary label="Pending" value={summary?.pending ?? 0} /><Summary label="Attendance rate" value={`${Math.round(summary?.percentage ?? 0)}%`} /></div>
    <section className="flow-panel"><h2>Current attendance session</h2>
      {!session && <p>{loading ? 'Checking for a current session…' : 'No scheduled or open attendance session is available for your classes.'}</p>}
      {session && <><div className="flow-session-detail"><div><strong>{session.title || session.class_name}</strong><span>{session.class_name} · Professor {session.professor_name || 'assigned faculty'}</span></div><span className={`flow-status ${statusTone(session.status)}`}>{statusLabel(session.status)}</span></div>
        <p>Opens {displayTime(session.opens_at)} · Deadline {displayTime(session.deadline_at)}</p>
        {session.status === 'scheduled' && opening !== null && <p className="flow-countdown">Opens in {timerLabel(opening)} <small>Displayed timer only; the service controls the window.</small></p>}
        {session.status === 'open' && remaining !== null && <p className="flow-countdown">Time remaining {timerLabel(remaining)} <small>Displayed timer only; the service controls the deadline.</small></p>}
        {session.status === 'open' && <StudentSubmissionPanel session={session} onSubmitted={submission => setSession(current => current ? { ...current, submission } : current)} />}
        {session.status !== 'open' && session.submission && <div className="flow-submission-result"><strong>Your submission: {statusLabel(session.submission.review_decision ? `MANUALLY_${session.submission.review_decision}` : session.submission.status)}</strong><p>{session.submission.explanation}</p>{session.submission.review_reason && <p>Professor note: {session.submission.review_reason}</p>}</div>}
        {session.status === 'closed' && !session.submission && <p>The submission window is closed. Contact your professor if you believe you need a correction.</p>}
      </>}
    </section>
    <section className="flow-panel"><div className="flow-section-heading"><h2>Attendance history</h2><span>{attendance?.entries.length ?? 0} records</span></div>
      {!attendance?.entries.length && <p>No attendance records yet.</p>}
      <div className="flow-history">{(attendance?.entries || []).map(entry => <div className="flow-history-row" key={entry.session_id}><div><strong>{entry.class_name || 'Class session'}</strong><small>{displayTime(entry.created_at)}{entry.submission_time ? ` · Submitted ${displayTime(entry.submission_time)}` : ''}</small></div><span className={`flow-status ${statusTone(entry.verification_status || entry.status)}`}>{statusLabel(entry.verification_status || entry.status)}</span><span className={`flow-status ${statusTone(entry.status)}`}>{statusLabel(entry.status)}</span></div>)}</div>
    </section>
  </main>
}

function StudentSubmissionPanel({ session, onSubmitted }: { session: Session; onSubmitted: (submission: NonNullable<Session['submission']>) => void }) {
  const [file, setFile] = useState<File | null>(null)
  const [preview, setPreview] = useState('')
  const [busy, setBusy] = useState(false)
  const [progress, setProgress] = useState(0)
  const [error, setError] = useState('')
  const [result, setResult] = useState<NonNullable<Session['submission']> | null>(session.submission || null)
  const inputRef = useRef<HTMLInputElement>(null)
  const canRetry = result?.status === 'REJECTED' && !result.review_decision

  useEffect(() => {
    if (!file) { setPreview(''); return }
    const url = URL.createObjectURL(file); setPreview(url)
    return () => URL.revokeObjectURL(url)
  }, [file])

  function chooseImage(event: React.ChangeEvent<HTMLInputElement>) {
    setError('')
    const selected = event.target.files?.[0]
    if (!selected) return
    if (selected.size > 10 * 1024 * 1024) { setError('Image must be 10 MB or smaller.'); event.target.value = ''; return }
    setFile(selected); setProgress(0); setResult(null)
  }
  async function submit() {
    if (!file) { setError('Capture or choose a classroom panorama first.'); return }
    setBusy(true); setError('')
    try {
      const saved = await api.submitPhoto(session.id, file, setProgress)
      const submission = { id: saved.id, status: saved.status, submitted_at: saved.submitted_at, explanation: saved.explanation, review_decision: null, review_reason: null }
      setResult(submission); onSubmitted(submission); setFile(null); if (inputRef.current) inputRef.current.value = ''
    } catch (reason) { setError(reason instanceof Error ? reason.message : 'Upload failed. Retake or retry.') }
    finally { setBusy(false) }
  }
  function retake() { setFile(null); setError(''); setProgress(0); if (inputRef.current) inputRef.current.value = '' }

  return <div className="flow-upload">
    <h3>Submit a classroom panorama</h3>
    <ol><li>Use your phone camera's Panorama mode and sweep slowly from one side of the room to the other.</li><li>Include nearby classmates and the professor-configured stage area. Avoid selfie framing.</li><li>Preview the image, retake if needed, then submit. The service checks image quality and visible people; it does not identify anyone.</li></ol>
    {preview && <div className="flow-preview"><img src={preview} alt="Preview of selected classroom panorama" /><button className="secondary-button" onClick={retake} disabled={busy}>Retake / choose another</button></div>}
    {!preview && <label className="flow-file"><Camera size={20} /><strong>Take or choose panorama</strong><span>On a phone, choose the camera's Panorama mode if available. On desktop, select a saved panorama.</span><input ref={inputRef} type="file" accept="image/jpeg,image/png,image/webp" capture="environment" onChange={chooseImage} disabled={busy || (!!result && !canRetry)} /></label>}
    {file && <div className="flow-file-info">{file.name} · {(file.size / 1024 / 1024).toFixed(1)} MB</div>}
    {file && <div className="flow-row-actions"><button className="primary-button" onClick={() => void submit()} disabled={busy}>{busy ? `Uploading ${progress}%…` : canRetry ? 'Submit replacement image' : 'Submit image'}</button><button className="secondary-button" onClick={retake} disabled={busy}>Retake</button></div>}
    {busy && <progress max="100" value={progress} aria-label="Image upload progress" />}
    {error && <Message error>{error}</Message>}
    {result && <div className="flow-submission-result"><strong>Submission status: {statusLabel(result.review_decision ? `MANUALLY_${result.review_decision}` : result.status)}</strong><p>{result.explanation}</p>{result.status === 'REJECTED' && !result.review_decision && <p>You may retake and resubmit while the attendance window remains open.</p>}</div>}
    <p className="flow-hint">A successful scene check is not identity verification. A professor may review uncertain images. Images are stored in a private bucket for authorized review according to your institution's retention policy.</p>
  </div>
}
