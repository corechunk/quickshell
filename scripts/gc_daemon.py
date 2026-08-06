import os
import sys
import json
import time
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

os.environ['OAUTHLIB_RELAX_TOKEN_SCOPE'] = '1'

# Google Classroom Scopes required for Courses, Coursework (Assignments), and Announcements
SCOPES = [
    "https://www.googleapis.com/auth/classroom.courses.readonly",
    "https://www.googleapis.com/auth/classroom.coursework.me.readonly",
    "https://www.googleapis.com/auth/classroom.student-submissions.me.readonly",
    "https://www.googleapis.com/auth/classroom.announcements.readonly",
    "https://www.googleapis.com/auth/classroom.profile.photos",
    "https://www.googleapis.com/auth/classroom.rosters.readonly"
]

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CREDENTIALS_FILE = os.path.join(BASE_DIR, "credentials.json")
TOKEN_FILE = os.path.join(BASE_DIR, "token.json")
OUTPUT_FILE = "/tmp/google_classroom_data.json"

def authenticate():
    creds = None
    if os.path.exists(TOKEN_FILE):
        try:
            creds = Credentials.from_authorized_user_file(TOKEN_FILE, SCOPES)
        except Exception as e:
            print(f"[!] Invalid token file: {e}")
            creds = None

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            try:
                creds.refresh(Request())
            except Exception:
                creds = None

        if not creds:
            if not os.path.exists(CREDENTIALS_FILE):
                error_data = {
                    "status": "missing_credentials",
                    "message": f"credentials.json not found at {CREDENTIALS_FILE}",
                    "courses": [],
                    "announcements": [],
                    "assignments": []
                }
                with open(OUTPUT_FILE, "w") as f:
                    json.dump(error_data, f, indent=2)
                print(f"[!] Please place your Google OAuth2 credentials.json at: {CREDENTIALS_FILE}")
                sys.exit(1)

            flow = InstalledAppFlow.from_client_secrets_file(CREDENTIALS_FILE, SCOPES)
            creds = flow.run_local_server(port=0)

        with open(TOKEN_FILE, "w") as token:
            token.write(creds.to_json())

    return creds

def fetch_classroom_data():
    creds = authenticate()
    service = build("classroom", "v1", credentials=creds)

    print("[+] Fetching enrolled courses...")
    courses_result = service.courses().list(studentId="me", courseStates=["ACTIVE"]).execute()
    courses_raw = courses_result.get("courses", [])

    courses = []
    palette = ["#a6e3a1", "#f9e2af", "#f38ba8", "#cba6f7", "#89dceb", "#fab387"]

    # Build teacher name cache per course via courses.teachers.list
    # (rosters.readonly scope — works even when userProfiles is restricted)
    course_teacher_cache = {}  # courseId -> teacher display name

    def get_course_teacher(cid):
        if cid in course_teacher_cache:
            return course_teacher_cache[cid]
        try:
            res = service.courses().teachers().list(courseId=cid).execute()
            teachers = res.get("teachers", [])
            if teachers:
                name = teachers[0].get("profile", {}).get("name", {}).get("fullName", "Faculty")
            else:
                name = "Faculty"
        except Exception:
            name = "Faculty"
        course_teacher_cache[cid] = name
        return name

    announcements_list = []
    assignments_list = []

    for idx, c in enumerate(courses_raw):
        cid = c.get("id")
        name = c.get("name", "Untitled Class")
        section = c.get("section", "")
        color = palette[idx % len(palette)]

        # Get teacher name for this course up front
        teacher_name = get_course_teacher(cid)

        courses.append({
            "courseId": cid,
            "title": name,
            "teacher": teacher_name,
            "section": section,
            "colorHex": color,
            "iconText": "󰆍"
        })

        # Fetch Announcements for this course
        try:
            anc_res = service.courses().announcements().list(courseId=cid, pageSize=5).execute()
            for a in anc_res.get("announcements", []):
                # Extract all attachments with type, title, link
                materials = []
                for m in a.get("materials", []):
                    if "driveFile" in m:
                        df = m["driveFile"].get("driveFile", {})
                        materials.append({"type": "drive",   "title": df.get("title", "File"),    "link": df.get("alternateLink", "")})
                    elif "youtubeVideo" in m:
                        yt = m["youtubeVideo"]
                        materials.append({"type": "youtube", "title": yt.get("title", "Video"),   "link": yt.get("alternateLink", "")})
                    elif "link" in m:
                        lk = m["link"]
                        materials.append({"type": "link",    "title": lk.get("title", lk.get("url", "Link")), "link": lk.get("url", "")})
                    elif "form" in m:
                        fm = m["form"]
                        materials.append({"type": "form",    "title": fm.get("title", "Form"),    "link": fm.get("formUrl", "")})

                announcements_list.append({
                    "id":          a.get("id"),
                    "courseId":    cid,
                    "courseName":  name,
                    "teacherName": teacher_name,
                    "timeAgo":     a.get("creationTime", ""),
                    "content":     a.get("text", ""),
                    "link":        a.get("alternateLink", ""),
                    "materials":   materials,
                })
        except Exception as e:
            print(f"[!] Error fetching announcements for {name}: {e}")

        # Fetch Coursework (Assignments) for this course
        try:
            work_res = service.courses().courseWork().list(courseId=cid, pageSize=5).execute()
            for w in work_res.get("courseWork", []):
                due = w.get("dueDate", {})
                due_str = f"{due.get('year', '')}-{due.get('month', '')}-{due.get('day', '')}" if due else "No due date"
                assignments_list.append({
                    "id": w.get("id"),
                    "courseId": cid,
                    "courseName": name,
                    "title": w.get("title", ""),
                    "description": w.get("description", ""),
                    "dueDate": due_str,
                    "state": w.get("state", "ASSIGNED")
                })
        except Exception as e:
            print(f"[!] Error fetching coursework for {name}: {e}")

    output_data = {
        "status": "connected",
        "lastUpdated": time.strftime("%Y-%m-%d %H:%M:%S"),
        "courses": courses,
        "announcements": announcements_list,
        "assignments": assignments_list
    }

    tmp_out = OUTPUT_FILE + ".tmp"
    with open(tmp_out, "w", encoding="utf-8") as f:
        json.dump(output_data, f, indent=2, ensure_ascii=False)
    os.replace(tmp_out, OUTPUT_FILE)

    print(f"[✓] Classroom data successfully cached to {OUTPUT_FILE}")

if __name__ == "__main__":
    fetch_classroom_data()
