import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'Rollcall · Campus Attendance',
  description: 'A review-first classroom attendance dashboard for faculty and students. Start sessions, review suggestions, and finalize attendance records with a clear audit trail.',
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
