"""
Seed script to populate Supabase database with diverse classroom tiers
(80, 120, 240, 260, and Lab), weekly timetables, and student enrollments.
"""
import os
import sys
from datetime import datetime, timezone
from dotenv import load_dotenv

load_dotenv("backend/.env")
from supabase import create_client

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    print("Error: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY not configured in backend/.env")
    sys.exit(1)

client = create_client(SUPABASE_URL, SUPABASE_KEY)

def seed_data():
    print("=== Seeding Classes, Timetables, and Enrollments ===")
    
    # 1. Fetch available teacher
    teachers = client.table("profiles").select("id, name, email").eq("role", "teacher").execute().data or []
    if not teachers:
        print("No teacher found, querying any profile...")
        profiles = client.table("profiles").select("id, name, email").execute().data or []
        teacher_id = profiles[0]["id"]
    else:
        teacher_id = teachers[0]["id"]
    print(f"Using teacher ID: {teacher_id} ({teachers[0]['name'] if teachers else 'Profile'})")

    # 2. Define diverse classes
    new_classes = [
        {
            "name": "CS 310 - Advanced Algorithms & Optimization",
            "code": "CS-310",
            "section": "Section A",
            "room_number": "LH-80",
            "capacity": 80,
            "hall_type": "80-Seater Seminar Hall",
            "teacher_id": teacher_id,
            "room_photo": "https://images.unsplash.com/photo-1517245386807-bb43f82c33c4?w=800",
        },
        {
            "name": "CS 201 - Operating Systems & Distributed Architecture",
            "code": "CS-201",
            "section": "Section A",
            "room_number": "LH-240",
            "capacity": 240,
            "hall_type": "240-Seater Tiered Amphitheater",
            "teacher_id": teacher_id,
            "room_photo": "https://images.unsplash.com/photo-1577495508048-b635879837f1?w=800",
        },
        {
            "name": "CS 401 - Artificial Intelligence & Deep Learning",
            "code": "CS-401",
            "section": "Section B",
            "room_number": "AUD-260",
            "capacity": 260,
            "hall_type": "260-Seater Grand Auditorium",
            "teacher_id": teacher_id,
            "room_photo": "https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=800",
        },
        {
            "name": "CS 225 - Systems & Networks Hardware Lab",
            "code": "CS-225",
            "section": "Lab Batch 1",
            "room_number": "LAB-102",
            "capacity": 80,
            "hall_type": "Computing & Systems Lab",
            "teacher_id": teacher_id,
            "room_photo": "https://images.unsplash.com/photo-1562774053-701939374585?w=800",
        },
    ]

    class_id_map = {}
    for c in new_classes:
        # Check if already exists
        existing = client.table("classes").select("*").eq("code", c["code"]).execute().data or []
        if existing:
            cid = existing[0]["id"]
            print(f"Class {c['code']} already exists: {cid}")
            class_id_map[c["code"]] = cid
            # Update fields
            client.table("classes").update({
                "name": c["name"],
                "section": c["section"],
                "room_number": c["room_number"],
                "capacity": c["capacity"],
                "hall_type": c["hall_type"],
                "room_photo": c["room_photo"],
            }).eq("id", cid).execute()
        else:
            res = client.table("classes").insert(c).execute()
            if res.data:
                cid = res.data[0]["id"]
                print(f"Created class {c['code']}: {cid}")
                class_id_map[c["code"]] = cid

    # Include existing classes
    all_classes = client.table("classes").select("*").execute().data or []
    for c in all_classes:
        class_id_map[c["code"]] = c["id"]
        print(f"Available class: {c['code']} -> {c['id']} ({c['name']})")

    # 3. Seed Timetable Schedule
    # day_of_week: 0=Mon, 1=Tue, 2=Wed, 3=Thu, 4=Fri, 5=Sat, 6=Sun
    day_names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    
    # Check existing timetable rows
    existing_tt = client.table("timetable").select("id").execute().data or []
    if len(existing_tt) < 5:
        timetable_entries = [
            # Monday
            {"code": "CS-101", "day": 0, "start": "09:00", "end": "10:30", "room": "LH-120"},
            {"code": "CS-201", "day": 0, "start": "11:00", "end": "12:30", "room": "LH-240"},
            {"code": "CS-225", "day": 0, "start": "14:00", "end": "16:00", "room": "LAB-102"},
            
            # Tuesday
            {"code": "CS-220", "day": 1, "start": "09:00", "end": "10:30", "room": "C002"},
            {"code": "CS-310", "day": 1, "start": "11:00", "end": "12:30", "room": "LH-80"},
            {"code": "CS-401", "day": 1, "start": "14:00", "end": "15:30", "room": "AUD-260"},
            
            # Wednesday
            {"code": "CS-101", "day": 2, "start": "09:00", "end": "10:30", "room": "LH-120"},
            {"code": "CS-201", "day": 2, "start": "11:00", "end": "12:30", "room": "LH-240"},
            {"code": "CS-310", "day": 2, "start": "14:00", "end": "15:30", "room": "LH-80"},
            
            # Thursday
            {"code": "CS-220", "day": 3, "start": "09:00", "end": "10:30", "room": "C002"},
            {"code": "CS-401", "day": 3, "start": "11:00", "end": "12:30", "room": "AUD-260"},
            {"code": "CS-225", "day": 3, "start": "14:00", "end": "16:00", "room": "LAB-102"},
            
            # Friday (Today)
            {"code": "CS-310", "day": 4, "start": "08:30", "end": "10:00", "room": "LH-80"},
            {"code": "CS-201", "day": 4, "start": "10:15", "end": "11:45", "room": "LH-240"},
            {"code": "CS-220", "day": 4, "start": "12:00", "end": "13:30", "room": "C002"},
            {"code": "CS-401", "day": 4, "start": "14:00", "end": "15:30", "room": "AUD-260"},
            {"code": "CS-225", "day": 4, "start": "16:00", "end": "17:30", "room": "LAB-102"},
        ]

        inserted_count = 0
        for entry in timetable_entries:
            cid = class_id_map.get(entry["code"])
            if not cid:
                continue
            row = {
                "class_id": cid,
                "day_of_week": entry["day"],
                "day_name": day_names[entry["day"]],
                "start_time": entry["start"],
                "end_time": entry["end"],
                "room_number": entry["room"],
                "is_cancelled": False,
                "academic_year": "2026-2027",
                "semester": "Fall 2026",
            }
            try:
                client.table("timetable").insert(row).execute()
                inserted_count += 1
            except Exception as e:
                print(f"Error inserting timetable {entry['code']}: {e}")
        print(f"Inserted {inserted_count} timetable slots!")
    else:
        print(f"Timetable already has {len(existing_tt)} slots.")

    # 4. Enroll all students in these classes
    students = client.table("profiles").select("id, name, email").eq("role", "student").execute().data or []
    print(f"Enrolling {len(students)} students across classes...")
    for s in students:
        for code, cid in class_id_map.items():
            enrollment = {"class_id": cid, "student_id": s["id"]}
            try:
                client.table("enrollments").upsert(enrollment).execute()
            except Exception:
                pass
    print("Enrollments completed successfully!")

if __name__ == "__main__":
    seed_data()
