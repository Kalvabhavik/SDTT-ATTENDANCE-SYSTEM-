import type { Metadata, Viewport } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 5,
};

export const metadata: Metadata = {
  title: "Attendrix — Computer-Vision-Assisted Attendance System | 3D Experience",
  description:
    "An immersive 3D scrollytelling demonstration of Attendrix, a computer-vision-assisted attendance verification system designed for 80, 120, and 240-seat lecture halls. Combining dynamic projector challenges, student selfie verification, and teacher audit workflows.",
  keywords: [
    "Attendrix",
    "Attendance System",
    "Computer Vision",
    "Lecture Hall",
    "ArcFace",
    "YuNet",
    "SDTT",
    "Verification Pipeline",
  ],
  authors: [{ name: "SDTT Project Team" }],
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html
      lang="en"
      className={`${geistSans.variable} ${geistMono.variable} dark h-full antialiased scroll-smooth`}
    >
      <body className="min-h-full flex flex-col bg-[#05070d] text-slate-100 selection:bg-cyan-500/30 selection:text-cyan-200">
        {children}
      </body>
    </html>
  );
}
