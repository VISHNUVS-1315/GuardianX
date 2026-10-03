import hashlib
import os
import secrets
from datetime import datetime, timezone
from typing import Optional

from fastapi import Depends, FastAPI, Header, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text, create_engine, select
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column, sessionmaker


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./campuslive.db")
if DATABASE_URL.startswith("postgresql://"):
    DATABASE_URL = DATABASE_URL.replace("postgresql://", "postgresql+psycopg://", 1)
elif DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql+psycopg://", 1)

connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}
engine = create_engine(DATABASE_URL, pool_pre_ping=True, connect_args=connect_args)
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    email: Mapped[str] = mapped_column(String(200), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(120))
    role: Mapped[str] = mapped_column(String(30), index=True)
    department: Mapped[str] = mapped_column(String(120), default="")
    year: Mapped[str] = mapped_column(String(20), default="")
    section: Mapped[str] = mapped_column(String(20), default="")
    password_hash: Mapped[str] = mapped_column(String(128))


class StudentProfile(Base):
    __tablename__ = "student_profiles"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), unique=True, index=True)
    student_id: Mapped[str] = mapped_column(String(40), unique=True, index=True)
    semester: Mapped[str] = mapped_column(String(20), default="3")
    bus_code: Mapped[str] = mapped_column(String(30), default="")
    boarding_stop: Mapped[str] = mapped_column(String(120), default="")
    is_hosteller: Mapped[bool] = mapped_column(Boolean, default=False)
    attendance_percent: Mapped[int] = mapped_column(Integer, default=86)
    cgpa: Mapped[float] = mapped_column(Float, default=7.64)
    assignments_due: Mapped[int] = mapped_column(Integer, default=3)


class SessionToken(Base):
    __tablename__ = "session_tokens"
    token: Mapped[str] = mapped_column(String(160), primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class Room(Base):
    __tablename__ = "rooms"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    code: Mapped[str] = mapped_column(String(30), unique=True, index=True)
    block: Mapped[str] = mapped_column(String(100))
    available: Mapped[bool] = mapped_column(Boolean, default=True)
    note: Mapped[str] = mapped_column(String(220), default="")


class Announcement(Base):
    __tablename__ = "announcements"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    title: Mapped[str] = mapped_column(String(140))
    message: Mapped[str] = mapped_column(Text)
    audience: Mapped[str] = mapped_column(String(100), default="All campus")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class Complaint(Base):
    __tablename__ = "complaints"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    ticket: Mapped[str] = mapped_column(String(30), unique=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    category: Mapped[str] = mapped_column(String(80), default="General")
    location: Mapped[str] = mapped_column(String(80))
    description: Mapped[str] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(40), default="Reported")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class Bus(Base):
    __tablename__ = "buses"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    code: Mapped[str] = mapped_column(String(30), unique=True, index=True)
    route: Mapped[str] = mapped_column(String(140))
    eta_minutes: Mapped[int] = mapped_column(Integer, default=8)
    status: Mapped[str] = mapped_column(String(60), default="On time")
    latitude: Mapped[float] = mapped_column(Float, default=10.584)
    longitude: Mapped[float] = mapped_column(Float, default=77.251)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class Event(Base):
    __tablename__ = "events"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    title: Mapped[str] = mapped_column(String(160))
    date_text: Mapped[str] = mapped_column(String(50))
    seats_left: Mapped[int] = mapped_column(Integer, default=50)


class EventRegistration(Base):
    __tablename__ = "event_registrations"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id"))
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))


class Emergency(Base):
    __tablename__ = "emergencies"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    kind: Mapped[str] = mapped_column(String(80))
    status: Mapped[str] = mapped_column(String(40), default="Acknowledged")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class LoginBody(BaseModel):
    email: str
    password: str


class AnnouncementBody(BaseModel):
    title: str = Field(min_length=1, max_length=140)
    message: str = Field(min_length=1, max_length=2000)
    audience: str = Field(default="All campus", max_length=100)


class ComplaintBody(BaseModel):
    category: str = Field(default="General", max_length=80)
    location: str = Field(min_length=1, max_length=80)
    description: str = Field(min_length=1, max_length=2000)


class StatusBody(BaseModel):
    status: str = Field(min_length=1, max_length=40)


class RoomBody(BaseModel):
    available: bool
    note: str = Field(default="", max_length=220)


class BusBody(BaseModel):
    eta_minutes: int = Field(ge=0, le=300)
    status: str = Field(default="On time", max_length=60)
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class EmergencyBody(BaseModel):
    kind: str = Field(min_length=1, max_length=80)


app = FastAPI(title="CampusLive API", version="2.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


class Hub:
    def __init__(self) -> None:
        self.clients: set[WebSocket] = set()

    async def connect(self, websocket: WebSocket) -> None:
        await websocket.accept()
        self.clients.add(websocket)

    def disconnect(self, websocket: WebSocket) -> None:
        self.clients.discard(websocket)

    async def broadcast(self, event: str) -> None:
        dead: list[WebSocket] = []
        for ws in self.clients:
            try:
                await ws.send_json({"event": event, "at": utcnow().isoformat()})
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.disconnect(ws)


hub = Hub()


def hash_password(password: str) -> str:
    salt = "campuslive-demo-v2"
    return hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 120_000).hex()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def token_from_header(authorization: Optional[str]) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    return authorization.removeprefix("Bearer ").strip()


def current_user(
    authorization: Optional[str] = Header(default=None),
    db: Session = Depends(get_db),
) -> User:
    token = token_from_header(authorization)
    row = db.get(SessionToken, token)
    if row is None:
        raise HTTPException(status_code=401, detail="Invalid session")
    user = db.get(User, row.user_id)
    if user is None:
        raise HTTPException(status_code=401, detail="Unknown user")
    return user


def require_roles(*roles: str):
    def dependency(user: User = Depends(current_user)) -> User:
        if user.role not in roles:
            raise HTTPException(status_code=403, detail="Insufficient role")
        return user
    return dependency


def serialize_user(user: User) -> dict:
    return {
        "id": user.id,
        "email": user.email,
        "name": user.name,
        "role": user.role,
        "department": user.department,
        "year": user.year,
        "section": user.section,
    }


def seed(db: Session) -> None:
    if db.scalar(select(User.id).limit(1)) is None:
        password = hash_password("Campus@123")
        db.add_all(
            [
                User(email="student@campuslive.demo", name="Vishnu S", role="student", department="Mechanical Engineering", year="2", section="A", password_hash=password),
                User(email="admin@campuslive.demo", name="Campus Administrator", role="admin", department="Administration", password_hash=password),
                User(email="faculty@campuslive.demo", name="Dr. Kumar", role="faculty", department="Mechanical Engineering", password_hash=password),
                User(email="driver@campuslive.demo", name="Bus 07 Driver", role="driver", department="Transport", password_hash=password),
            ]
        )
        db.commit()

    if db.scalar(select(Room.id).limit(1)) is None:
        db.add_all(
            [
                Room(code="M201", block="Mechanical Block", available=True, note="Free until 12:20 PM"),
                Room(code="M202", block="Mechanical Block", available=False, note="Thermodynamics until 12:20 PM"),
                Room(code="M203", block="Mechanical Block", available=True, note="Free until 1:10 PM"),
                Room(code="C301", block="Main Block", available=False, note="Programming class until 11:50 AM"),
                Room(code="A102", block="AI Block", available=True, note="Free until 2:00 PM"),
            ]
        )

    if db.scalar(select(Announcement.id).limit(1)) is None:
        db.add_all(
            [
                Announcement(title="Room changed", message="Engineering Mechanics: M204 → C302", audience="Mechanical • Year 2"),
                Announcement(title="My bus update", message="Bus 07 is running on time for Udumalpet students.", audience="Bus 07 Users"),
                Announcement(title="EV Workshop", message="Registration is open. 42 seats remaining.", audience="All campus"),
                Announcement(title="CSE notice", message="CSE Lab 3 maintenance today.", audience="Computer Science • Year 2"),
            ]
        )

    if db.scalar(select(Bus.id).limit(1)) is None:
        db.add(Bus(code="BUS07", route="Udumalpet → Pollachi Road → Campus", eta_minutes=8, status="On time"))

    if db.scalar(select(Event.id).limit(1)) is None:
        db.add_all(
            [
                Event(title="EV Design Workshop", date_text="Oct 04", seats_left=42),
                Event(title="TechFest 2026", date_text="Oct 12", seats_left=113),
                Event(title="CAD Sprint Challenge", date_text="Oct 18", seats_left=28),
            ]
        )
    db.commit()

    student = db.scalar(select(User).where(User.email == "student@campuslive.demo"))
    if student:
        profile = db.scalar(select(StudentProfile).where(StudentProfile.user_id == student.id))
        if profile is None:
            db.add(
                StudentProfile(
                    user_id=student.id,
                    student_id="25ME103",
                    semester="3",
                    bus_code="BUS07",
                    boarding_stop="Udumalpet Bus Stand",
                    is_hosteller=False,
                    attendance_percent=86,
                    cgpa=7.64,
                    assignments_due=3,
                )
            )

        existing_complaint = db.scalar(select(Complaint).where(Complaint.user_id == student.id).limit(1))
        if existing_complaint is None:
            db.add(
                Complaint(
                    ticket="CMP-1027",
                    user_id=student.id,
                    category="Electrical",
                    location="C204",
                    description="Fan not working",
                    status="Assigned",
                )
            )
        db.commit()


@app.on_event("startup")
def startup() -> None:
    Base.metadata.create_all(engine)
    with SessionLocal() as db:
        seed(db)


@app.get("/")
def root():
    return {"name": "CampusLive API", "version": "2.0.0", "status": "online"}


@app.get("/health")
def health():
    return {"ok": True, "time": utcnow().isoformat()}


@app.post("/auth/login")
def login(body: LoginBody, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.email == body.email.strip().lower()))
    if user is None or user.password_hash != hash_password(body.password):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    token = secrets.token_urlsafe(32)
    db.add(SessionToken(token=token, user_id=user.id))
    db.commit()
    return {"token": token, "user": serialize_user(user)}


@app.get("/me")
def me(user: User = Depends(current_user)):
    return serialize_user(user)


@app.get("/student/context")
def student_context(user: User = Depends(current_user), db: Session = Depends(get_db)):
    if user.role != "student":
        raise HTTPException(status_code=403, detail="Student profile only")
    profile = db.scalar(select(StudentProfile).where(StudentProfile.user_id == user.id))
    if profile is None:
        raise HTTPException(status_code=404, detail="Student profile not found")
    return {
        "student_id": profile.student_id,
        "name": user.name,
        "department": user.department,
        "year": user.year,
        "section": user.section,
        "semester": profile.semester,
        "bus_code": profile.bus_code,
        "bus_display": "Bus 07" if profile.bus_code == "BUS07" else profile.bus_code,
        "boarding_stop": profile.boarding_stop,
        "student_type": "Hosteller" if profile.is_hosteller else "Day Scholar",
        "is_hosteller": profile.is_hosteller,
        "attendance_percent": profile.attendance_percent,
        "cgpa": profile.cgpa,
        "assignments_due": profile.assignments_due,
        "placement_eligible": profile.cgpa >= 7.0,
    }


def _student_profile(db: Session, user: User) -> StudentProfile | None:
    if user.role != "student":
        return None
    return db.scalar(select(StudentProfile).where(StudentProfile.user_id == user.id))


def _announcement_visible(user: User, profile: StudentProfile | None, audience: str) -> bool:
    if user.role in {"admin", "faculty"}:
        return True
    a = audience.strip().lower()
    if not a or a == "all campus":
        return True
    if "transport" in a:
        return bool(profile and profile.bus_code)
    if "bus 07" in a or "bus07" in a:
        return bool(profile and profile.bus_code == "BUS07")
    dept_key = user.department.split()[0].lower() if user.department else ""
    if dept_key and dept_key in a:
        if "year" in a and f"year {user.year}" not in a:
            return False
        if "section" in a and f"section {user.section.lower()}" not in a:
            return False
        return True
    if "placement" in a:
        return bool(profile and profile.cgpa >= 7.0)
    return False


@app.get("/student/modules")
def student_modules(user: User = Depends(current_user), db: Session = Depends(get_db)):
    if user.role != "student":
        raise HTTPException(status_code=403, detail="Student modules only")
    profile = _student_profile(db, user)
    if profile is None:
        raise HTTPException(status_code=404, detail="Student profile not found")

    return {
        "Attendance": [
            "Engineering Mechanics — 86% • Present 31/36",
            "Engineering Thermodynamics — 91% • Present 32/35",
            "Material Science — 82% • Present 28/34",
            "CAD Lab — 94% • Present 17/18",
            f"Overall attendance — {profile.attendance_percent}%"
        ],
        "Assignments": [
            "Thermodynamics Assignment 2 — Due Oct 05 • Pending",
            "CAD Drawing Sheet 4 — Due Oct 06 • Pending",
            "Material Science Report — Due Oct 08 • Pending",
            "Engineering Mechanics Tutorial 3 — Submitted"
        ],
        "Tests & Exams": [
            "Internal Assessment 2 — Oct 09 • 09:30 AM",
            "Thermodynamics — Oct 09 • M204",
            "Material Science — Oct 10 • M202",
            "Engineering Mechanics — Oct 12 • M201",
            "CAD Practical — Oct 14 • CAD Lab"
        ],
        "Marks": [
            "Engineering Mechanics — IA1 76/100",
            "Thermodynamics — IA1 82/100",
            "Material Science — IA1 79/100",
            "CAD Practical — 88/100",
            f"Current CGPA — {profile.cgpa:.2f}"
        ],
        "Materials": [
            "Thermodynamics Unit 1–3 Notes • Updated Oct 01",
            "Engineering Mechanics Formula Sheet",
            "Material Science Unit 2 PPT",
            "CAD Lab Exercise Manual",
            "Manufacturing Process Question Bank"
        ],
        "Faculty": [
            "Dr. Kumar — Engineering Thermodynamics • Mechanical Block",
            "Dr. Ravi — Engineering Mechanics • Mechanical Block",
            "Dr. Priya — Material Science • Mechanical Block",
            "Mr. Arun — CAD Lab • CAD Centre",
            "Dr. Devi — Manufacturing Process • Mechanical Block"
        ],
        "Fees": [
            "Tuition fee 2026–27 — Paid",
            "Exam fee — ₹1,500 • Due Oct 15",
            "Transport fee — Paid • Bus 07",
            "No overdue payment"
        ],
        "Certificates": [
            "Bonafide Certificate — Request available",
            "Student Verification Letter — Request available",
            "Fee Receipt — Download available",
            "Attendance Certificate — Request available"
        ],
        "Lost & Found": [
            "Black earbuds case — Found near Library • Oct 02",
            "Blue ID card holder — Found in Main Block • Oct 01",
            "Scientific calculator — Found in M203 • Sep 30"
        ],
        "Library": [
            "Library status — Open until 8:00 PM",
            "Available seats — 182",
            "Borrowed: Engineering Thermodynamics — Due Oct 11",
            "Borrowed: Material Science — Due Oct 16",
            "Mechanical collection — 2,340 titles"
        ],
        "Canteen": [
            "Main canteen — Open",
            "Breakfast — 08:00 to 10:00",
            "Lunch — 12:00 to 14:30",
            "Snacks — 15:30 to 17:30",
            "Today's lunch: Rice, sambar, poriyal, curd"
        ],
        "Help Desk": [
            "Academic office — Main Block Ground Floor",
            "Transport desk — 08:00 to 17:00",
            "Placement cell — Block A First Floor",
            "IT support — support desk near CSE Block",
            "Emergency campus security — available 24×7"
        ],
        "Hostel": [
            "Hostel module is shown only for hostellers",
            "Room details, mess timing, leave request and hostel notices"
        ]
    }


@app.get("/departments")
def departments(user: User = Depends(current_user)):
    return [
        "Mechanical Engineering",
        "Computer Science & Engineering",
        "Artificial Intelligence & ML",
        "Electronics & Communication",
        "Electrical & Electronics",
        "Civil Engineering",
        "Information Technology",
        "Science & Humanities",
    ]


@app.get("/timetable")
def timetable(user: User = Depends(current_user)):
    return [
        {"time": "09:00", "subject": "Engineering Mechanics", "room": "M201", "faculty": "Dr. Ravi"},
        {"time": "09:50", "subject": "Material Science", "room": "M202", "faculty": "Dr. Priya"},
        {"time": "10:40", "subject": "Break", "room": "-", "faculty": "-"},
        {"time": "11:30", "subject": "Engineering Thermodynamics", "room": "M204", "faculty": "Dr. Kumar"},
        {"time": "12:20", "subject": "CAD Lab", "room": "CAD LAB 2", "faculty": "Mr. Arun"},
        {"time": "13:10", "subject": "Lunch", "room": "-", "faculty": "-"},
        {"time": "14:00", "subject": "Manufacturing Process", "room": "M203", "faculty": "Dr. Devi"},
    ]


@app.get("/rooms")
def list_rooms(user: User = Depends(current_user), db: Session = Depends(get_db)):
    stmt = select(Room).order_by(Room.code)
    if user.role == "student" and user.department:
        dept_word = user.department.split()[0]
        stmt = stmt.where(Room.block.ilike(f"%{dept_word}%"))
    rows = db.scalars(stmt).all()
    return [{"code": r.code, "block": r.block, "available": r.available, "note": r.note} for r in rows]


@app.patch("/rooms/{code}")
async def update_room(
    code: str,
    body: RoomBody,
    user: User = Depends(require_roles("admin", "faculty")),
    db: Session = Depends(get_db),
):
    room = db.scalar(select(Room).where(Room.code == code))
    if room is None:
        raise HTTPException(status_code=404, detail="Room not found")
    room.available = body.available
    room.note = body.note or ("Available now" if body.available else "Marked occupied")
    db.commit()
    await hub.broadcast("rooms.changed")
    return {"ok": True}


@app.get("/announcements")
def list_announcements(user: User = Depends(current_user), db: Session = Depends(get_db)):
    rows = db.scalars(select(Announcement).order_by(Announcement.created_at.desc()).limit(50)).all()
    profile = _student_profile(db, user)
    visible = [r for r in rows if _announcement_visible(user, profile, r.audience)]
    return [
        {
            "id": r.id,
            "title": r.title,
            "message": r.message,
            "audience": r.audience,
            "created_at": r.created_at.isoformat(),
        }
        for r in visible
    ]


@app.post("/announcements")
async def create_announcement(
    body: AnnouncementBody,
    user: User = Depends(require_roles("admin", "faculty")),
    db: Session = Depends(get_db),
):
    row = Announcement(title=body.title, message=body.message, audience=body.audience)
    db.add(row)
    db.commit()
    await hub.broadcast("announcements.changed")
    return {"ok": True, "id": row.id}


@app.get("/complaints")
def list_complaints(user: User = Depends(current_user), db: Session = Depends(get_db)):
    stmt = select(Complaint).order_by(Complaint.created_at.desc())
    if user.role not in {"admin", "faculty"}:
        stmt = stmt.where(Complaint.user_id == user.id)
    rows = db.scalars(stmt).all()
    return [
        {
            "ticket": r.ticket,
            "category": r.category,
            "location": r.location,
            "description": r.description,
            "status": r.status,
        }
        for r in rows
    ]


@app.post("/complaints")
async def create_complaint(
    body: ComplaintBody,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    count = db.scalar(select(Complaint.id).order_by(Complaint.id.desc()).limit(1)) or 1100
    numeric = int(count) + 1
    row = Complaint(
        ticket=f"CMP-{numeric}",
        user_id=user.id,
        category=body.category,
        location=body.location,
        description=body.description,
        status="Reported",
    )
    db.add(row)
    db.commit()
    await hub.broadcast("complaints.changed")
    return {"ok": True, "ticket": row.ticket}


@app.patch("/complaints/{ticket}")
async def update_complaint(
    ticket: str,
    body: StatusBody,
    user: User = Depends(require_roles("admin", "faculty")),
    db: Session = Depends(get_db),
):
    row = db.scalar(select(Complaint).where(Complaint.ticket == ticket))
    if row is None:
        raise HTTPException(status_code=404, detail="Complaint not found")
    row.status = body.status
    db.commit()
    await hub.broadcast("complaints.changed")
    return {"ok": True}


@app.get("/transport/my")
def my_transport(user: User = Depends(current_user), db: Session = Depends(get_db)):
    if user.role != "student":
        raise HTTPException(status_code=403, detail="Student transport only")
    profile = _student_profile(db, user)
    if profile is None or not profile.bus_code:
        return {"assigned": False}
    bus = db.scalar(select(Bus).where(Bus.code == profile.bus_code))
    if bus is None:
        return {"assigned": False}
    return {
        "assigned": True,
        "code": bus.code,
        "display": "Bus 07" if bus.code == "BUS07" else bus.code,
        "route": bus.route,
        "boarding_stop": profile.boarding_stop,
        "eta_minutes": bus.eta_minutes,
        "status": bus.status,
        "latitude": bus.latitude,
        "longitude": bus.longitude,
        "updated_at": bus.updated_at.isoformat(),
        "route_stops": [
            profile.boarding_stop + " • My stop",
            "Pollachi Road",
            "Kinathukadavu",
            "Campus"
        ],
    }


@app.get("/transport/BUS07")
def bus_status(user: User = Depends(current_user), db: Session = Depends(get_db)):
    bus = db.scalar(select(Bus).where(Bus.code == "BUS07"))
    if bus is None:
        raise HTTPException(status_code=404, detail="Bus not found")
    return {
        "code": bus.code,
        "route": bus.route,
        "eta_minutes": bus.eta_minutes,
        "status": bus.status,
        "latitude": bus.latitude,
        "longitude": bus.longitude,
        "updated_at": bus.updated_at.isoformat(),
    }


@app.patch("/transport/BUS07")
async def update_bus(
    body: BusBody,
    user: User = Depends(require_roles("admin", "driver")),
    db: Session = Depends(get_db),
):
    bus = db.scalar(select(Bus).where(Bus.code == "BUS07"))
    if bus is None:
        raise HTTPException(status_code=404, detail="Bus not found")
    bus.eta_minutes = body.eta_minutes
    bus.status = body.status
    if body.latitude is not None:
        bus.latitude = body.latitude
    if body.longitude is not None:
        bus.longitude = body.longitude
    bus.updated_at = utcnow()
    db.commit()
    await hub.broadcast("transport.changed")
    return {"ok": True}


@app.get("/events")
def events(user: User = Depends(current_user), db: Session = Depends(get_db)):
    rows = db.scalars(select(Event).order_by(Event.id)).all()
    registered = set(
        db.scalars(select(EventRegistration.event_id).where(EventRegistration.user_id == user.id)).all()
    )
    return [
        {
            "id": r.id,
            "title": r.title,
            "date": r.date_text,
            "seats_left": r.seats_left,
            "registered": r.id in registered,
        }
        for r in rows
    ]


@app.post("/events/{event_id}/register")
async def register_event(
    event_id: int,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    event = db.get(Event, event_id)
    if event is None:
        raise HTTPException(status_code=404, detail="Event not found")
    existing = db.scalar(
        select(EventRegistration).where(
            EventRegistration.event_id == event_id,
            EventRegistration.user_id == user.id,
        )
    )
    if existing is None:
        if event.seats_left <= 0:
            raise HTTPException(status_code=409, detail="No seats left")
        db.add(EventRegistration(event_id=event_id, user_id=user.id))
        event.seats_left -= 1
        db.commit()
        await hub.broadcast("events.changed")
    return {"ok": True}


@app.get("/placement")
def placement(user: User = Depends(current_user)):
    return {
        "company": "Zoho",
        "role": "Software Developer",
        "round": "Technical",
        "queue": 7,
        "eta_minutes": 24,
        "stages": [
            {"name": "Aptitude", "status": "Qualified"},
            {"name": "Coding", "status": "Qualified"},
            {"name": "Technical", "status": "Waiting"},
            {"name": "HR", "status": "Not started"},
        ],
    }


@app.get("/labs")
def labs(user: User = Depends(current_user)):
    return [
        {"name": "CAD Lab", "available": 21, "total": 60},
        {"name": "CAM Lab", "available": 14, "total": 40},
        {"name": "AI Lab", "available": 42, "total": 60},
        {"name": "Thermal Lab", "available": 0, "total": 30, "note": "Scheduled at 2 PM"},
    ]


@app.get("/library")
def library(user: User = Depends(current_user)):
    return {"open": True, "closes": "20:00", "seats_available": 182, "mechanical_titles": 2340}


@app.get("/canteen")
def canteen(user: User = Depends(current_user)):
    return {
        "open": True,
        "windows": [
            "Breakfast 08:00–10:00",
            "Lunch 12:00–14:30",
            "Snacks counter open",
        ],
    }


@app.post("/emergency")
async def create_emergency(
    body: EmergencyBody,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    row = Emergency(user_id=user.id, kind=body.kind, status="Acknowledged")
    db.add(row)
    db.commit()
    await hub.broadcast("emergency.changed")
    return {"ok": True, "id": row.id, "status": row.status}


@app.get("/admin/departments")
def admin_departments(
    user: User = Depends(require_roles("admin")),
):
    return [
        {
            "code": "MECH",
            "name": "Mechanical Engineering",
            "block": "Mechanical Block",
            "hod": {
                "name": "Dr. Aravind Kumar",
                "designation": "Professor & Head of Department",
                "specialization": "Thermal Engineering",
                "email": "mech.hod@campuslive.demo",
                "phone": "+91 90000 11001",
                "office": "MECH-HOD-01",
            },
            "staff": [
                {"name": "Dr. Ravi M.", "designation": "Professor", "specialization": "Engineering Mechanics", "email": "ravi.mech@campuslive.demo", "phone": "+91 90000 11011", "office": "M-F12"},
                {"name": "Dr. Priya S.", "designation": "Associate Professor", "specialization": "Material Science", "email": "priya.mech@campuslive.demo", "phone": "+91 90000 11012", "office": "M-F14"},
                {"name": "Dr. Devi K.", "designation": "Associate Professor", "specialization": "Manufacturing Engineering", "email": "devi.mech@campuslive.demo", "phone": "+91 90000 11013", "office": "M-F16"},
                {"name": "Mr. Arun P.", "designation": "Assistant Professor", "specialization": "CAD / CAM", "email": "arun.mech@campuslive.demo", "phone": "+91 90000 11014", "office": "CAD Centre"},
            ],
        },
        {
            "code": "CSE",
            "name": "Computer Science & Engineering",
            "block": "CSE Block",
            "hod": {
                "name": "Dr. Meena R.",
                "designation": "Professor & Head of Department",
                "specialization": "Distributed Systems",
                "email": "cse.hod@campuslive.demo",
                "phone": "+91 90000 12001",
                "office": "CSE-HOD-01",
            },
            "staff": [
                {"name": "Dr. Karthik V.", "designation": "Professor", "specialization": "Data Structures & Algorithms", "email": "karthik.cse@campuslive.demo", "phone": "+91 90000 12011", "office": "C-F11"},
                {"name": "Ms. Nivetha S.", "designation": "Assistant Professor", "specialization": "Database Systems", "email": "nivetha.cse@campuslive.demo", "phone": "+91 90000 12012", "office": "C-F13"},
                {"name": "Mr. Sanjay R.", "designation": "Assistant Professor", "specialization": "Cloud Computing", "email": "sanjay.cse@campuslive.demo", "phone": "+91 90000 12013", "office": "C-F15"},
                {"name": "Ms. Aarthi P.", "designation": "Assistant Professor", "specialization": "Mobile Application Development", "email": "aarthi.cse@campuslive.demo", "phone": "+91 90000 12014", "office": "C-F18"},
            ],
        },
        {
            "code": "AIML",
            "name": "Artificial Intelligence & ML",
            "block": "AI Block",
            "hod": {
                "name": "Dr. Lakshmi N.",
                "designation": "Professor & Head of Department",
                "specialization": "Machine Learning",
                "email": "aiml.hod@campuslive.demo",
                "phone": "+91 90000 13001",
                "office": "AI-HOD-01",
            },
            "staff": [
                {"name": "Dr. Hari P.", "designation": "Associate Professor", "specialization": "Deep Learning", "email": "hari.aiml@campuslive.demo", "phone": "+91 90000 13011", "office": "AI-F10"},
                {"name": "Ms. Swetha K.", "designation": "Assistant Professor", "specialization": "Computer Vision", "email": "swetha.aiml@campuslive.demo", "phone": "+91 90000 13012", "office": "AI-F12"},
                {"name": "Mr. Naveen R.", "designation": "Assistant Professor", "specialization": "Natural Language Processing", "email": "naveen.aiml@campuslive.demo", "phone": "+91 90000 13013", "office": "AI-F14"},
            ],
        },
        {
            "code": "ECE",
            "name": "Electronics & Communication",
            "block": "ECE Block",
            "hod": {
                "name": "Dr. Revathi P.",
                "designation": "Professor & Head of Department",
                "specialization": "VLSI & Embedded Systems",
                "email": "ece.hod@campuslive.demo",
                "phone": "+91 90000 14001",
                "office": "ECE-HOD-01",
            },
            "staff": [
                {"name": "Dr. Vinoth K.", "designation": "Professor", "specialization": "Communication Systems", "email": "vinoth.ece@campuslive.demo", "phone": "+91 90000 14011", "office": "ECE-F11"},
                {"name": "Ms. Keerthana R.", "designation": "Assistant Professor", "specialization": "Embedded Systems", "email": "keerthana.ece@campuslive.demo", "phone": "+91 90000 14012", "office": "ECE-F13"},
                {"name": "Mr. Praveen S.", "designation": "Assistant Professor", "specialization": "Digital Electronics", "email": "praveen.ece@campuslive.demo", "phone": "+91 90000 14013", "office": "ECE-F15"},
            ],
        },
        {
            "code": "EEE",
            "name": "Electrical & Electronics",
            "block": "EEE Block",
            "hod": {
                "name": "Dr. Suresh B.",
                "designation": "Professor & Head of Department",
                "specialization": "Power Systems",
                "email": "eee.hod@campuslive.demo",
                "phone": "+91 90000 15001",
                "office": "EEE-HOD-01",
            },
            "staff": [
                {"name": "Dr. Anitha M.", "designation": "Associate Professor", "specialization": "Electrical Machines", "email": "anitha.eee@campuslive.demo", "phone": "+91 90000 15011", "office": "EEE-F11"},
                {"name": "Mr. Dinesh K.", "designation": "Assistant Professor", "specialization": "Power Electronics", "email": "dinesh.eee@campuslive.demo", "phone": "+91 90000 15012", "office": "EEE-F13"},
            ],
        },
        {
            "code": "CIVIL",
            "name": "Civil Engineering",
            "block": "Civil Block",
            "hod": {
                "name": "Dr. Mohan Raj",
                "designation": "Professor & Head of Department",
                "specialization": "Structural Engineering",
                "email": "civil.hod@campuslive.demo",
                "phone": "+91 90000 16001",
                "office": "CE-HOD-01",
            },
            "staff": [
                {"name": "Dr. Gayathri S.", "designation": "Associate Professor", "specialization": "Geotechnical Engineering", "email": "gayathri.civil@campuslive.demo", "phone": "+91 90000 16011", "office": "CE-F11"},
                {"name": "Mr. Ajay K.", "designation": "Assistant Professor", "specialization": "Surveying", "email": "ajay.civil@campuslive.demo", "phone": "+91 90000 16012", "office": "CE-F13"},
            ],
        },
        {
            "code": "IT",
            "name": "Information Technology",
            "block": "IT Block",
            "hod": {
                "name": "Dr. Priyanka S.",
                "designation": "Professor & Head of Department",
                "specialization": "Cyber Security",
                "email": "it.hod@campuslive.demo",
                "phone": "+91 90000 17001",
                "office": "IT-HOD-01",
            },
            "staff": [
                {"name": "Dr. Ashok R.", "designation": "Associate Professor", "specialization": "Networks & Security", "email": "ashok.it@campuslive.demo", "phone": "+91 90000 17011", "office": "IT-F11"},
                {"name": "Ms. Harini V.", "designation": "Assistant Professor", "specialization": "Web Technologies", "email": "harini.it@campuslive.demo", "phone": "+91 90000 17012", "office": "IT-F13"},
            ],
        },
        {
            "code": "S&H",
            "name": "Science & Humanities",
            "block": "Main Block",
            "hod": {
                "name": "Dr. Malathi K.",
                "designation": "Professor & Head",
                "specialization": "Engineering Mathematics",
                "email": "science.hod@campuslive.demo",
                "phone": "+91 90000 18001",
                "office": "SH-HOD-01",
            },
            "staff": [
                {"name": "Dr. Selvi R.", "designation": "Associate Professor", "specialization": "Engineering Chemistry", "email": "selvi.sh@campuslive.demo", "phone": "+91 90000 18011", "office": "SH-F11"},
                {"name": "Mr. Ganesh P.", "designation": "Assistant Professor", "specialization": "Engineering Physics", "email": "ganesh.sh@campuslive.demo", "phone": "+91 90000 18012", "office": "SH-F13"},
                {"name": "Ms. Divya N.", "designation": "Assistant Professor", "specialization": "Technical English", "email": "divya.sh@campuslive.demo", "phone": "+91 90000 18013", "office": "SH-F15"},
            ],
        },
    ]


@app.get("/admin/metrics")
def admin_metrics(
    user: User = Depends(require_roles("admin")),
    db: Session = Depends(get_db),
):
    free_rooms = len(db.scalars(select(Room).where(Room.available.is_(True))).all())
    total_rooms = len(db.scalars(select(Room)).all())
    open_complaints = len(db.scalars(select(Complaint).where(Complaint.status != "Resolved")).all())
    return {
        "students_online_demo": 2081,
        "buses_active_demo": 14,
        "free_rooms": free_rooms,
        "total_rooms": total_rooms,
        "open_complaints": open_complaints,
    }


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await hub.connect(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        hub.disconnect(websocket)
    except Exception:
        hub.disconnect(websocket)
