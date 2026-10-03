import hashlib
import os
import re
import secrets
from datetime import datetime, timezone
from typing import Optional

from fastapi import Depends, FastAPI, Header, HTTPException, Query, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text, create_engine, func, select
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column, sessionmaker


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./campuslive_hierarchy.db")
if DATABASE_URL.startswith("postgresql://"):
    DATABASE_URL = DATABASE_URL.replace("postgresql://", "postgresql+psycopg://", 1)
elif DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql+psycopg://", 1)

connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}
engine = create_engine(DATABASE_URL, pool_pre_ping=True, connect_args=connect_args)
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


class College(Base):
    __tablename__ = "cl_colleges"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(180))
    code: Mapped[str] = mapped_column(String(40), unique=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class Department(Base):
    __tablename__ = "cl_departments"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    college_id: Mapped[int] = mapped_column(ForeignKey("cl_colleges.id"), index=True)
    name: Mapped[str] = mapped_column(String(180))
    code: Mapped[str] = mapped_column(String(40))
    hod_user_id: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)


class User(Base):
    __tablename__ = "cl_users"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    college_id: Mapped[int] = mapped_column(ForeignKey("cl_colleges.id"), index=True)
    department_id: Mapped[Optional[int]] = mapped_column(ForeignKey("cl_departments.id"), nullable=True, index=True)
    name: Mapped[str] = mapped_column(String(160))
    email: Mapped[str] = mapped_column(String(220), index=True)
    password_hash: Mapped[str] = mapped_column(String(128))
    role: Mapped[str] = mapped_column(String(30), index=True)
    year: Mapped[str] = mapped_column(String(30), default="")
    section: Mapped[str] = mapped_column(String(30), default="")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class SessionToken(Base):
    __tablename__ = "cl_sessions"
    token: Mapped[str] = mapped_column(String(160), primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("cl_users.id"), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class Assignment(Base):
    __tablename__ = "cl_assignments"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    college_id: Mapped[int] = mapped_column(ForeignKey("cl_colleges.id"), index=True)
    sender_id: Mapped[int] = mapped_column(ForeignKey("cl_users.id"), index=True)
    recipient_id: Mapped[int] = mapped_column(ForeignKey("cl_users.id"), index=True)
    kind: Mapped[str] = mapped_column(String(40), default="information")
    title: Mapped[str] = mapped_column(String(180))
    body: Mapped[str] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(30), default="new")
    due_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class PortalConfig(Base):
    __tablename__ = "cl_portal_config"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    college_id: Mapped[int] = mapped_column(ForeignKey("cl_colleges.id"), index=True)
    role: Mapped[str] = mapped_column(String(30), index=True)
    module: Mapped[str] = mapped_column(String(60))
    label: Mapped[str] = mapped_column(String(100))
    enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    position: Mapped[int] = mapped_column(Integer, default=0)


class AuditLog(Base):
    __tablename__ = "cl_audit"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    college_id: Mapped[int] = mapped_column(ForeignKey("cl_colleges.id"), index=True)
    actor_id: Mapped[int] = mapped_column(ForeignKey("cl_users.id"), index=True)
    action: Mapped[str] = mapped_column(String(120))
    detail: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


ROLE_ORDER = ["admin", "principal", "hod", "staff", "student"]

DEFAULT_MODULES = {
    "admin": [
        ("overview", "College Overview"),
        ("users", "Users"),
        ("departments", "Departments"),
        ("portal_control", "Portal Control"),
        ("live_activity", "Live Activity"),
        ("inbox", "Inbox"),
        ("assign", "Assign / Broadcast"),
    ],
    "principal": [
        ("overview", "Principal Overview"),
        ("directory", "HODs"),
        ("inbox", "Inbox"),
        ("assign", "Send to HODs"),
    ],
    "hod": [
        ("overview", "Department Overview"),
        ("directory", "Staff"),
        ("inbox", "Inbox"),
        ("assign", "Assign to Staff"),
    ],
    "staff": [
        ("overview", "Staff Overview"),
        ("directory", "Students"),
        ("inbox", "Inbox"),
        ("assign", "Assign to Students"),
    ],
    "student": [
        ("overview", "My Overview"),
        ("inbox", "My Updates"),
        ("profile", "My Profile"),
    ],
}


class CollegeSetupBody(BaseModel):
    college_name: str = Field(min_length=2, max_length=180)
    college_code: str = Field(min_length=2, max_length=40)
    admin_name: str = Field(min_length=2, max_length=160)
    admin_email: str = Field(min_length=5, max_length=220)
    admin_password: str = Field(min_length=8, max_length=100)


class LoginBody(BaseModel):
    college_code: str
    email: str
    password: str


class DepartmentBody(BaseModel):
    name: str = Field(min_length=2, max_length=180)
    code: str = Field(min_length=1, max_length=40)


class UserBody(BaseModel):
    name: str = Field(min_length=2, max_length=160)
    email: str = Field(min_length=5, max_length=220)
    password: str = Field(min_length=8, max_length=100)
    role: str
    department_id: Optional[int] = None
    year: str = ""
    section: str = ""


class UserPatchBody(BaseModel):
    name: Optional[str] = None
    department_id: Optional[int] = None
    year: Optional[str] = None
    section: Optional[str] = None
    is_active: Optional[bool] = None


class DepartmentPatchBody(BaseModel):
    name: Optional[str] = None
    code: Optional[str] = None
    hod_user_id: Optional[int] = None


class AssignmentBody(BaseModel):
    target_user_ids: list[int] = Field(default_factory=list)
    target_role: Optional[str] = None
    title: str = Field(min_length=1, max_length=180)
    body: str = Field(min_length=1, max_length=5000)
    kind: str = Field(default="information", max_length=40)
    due_at: Optional[datetime] = None


class AssignmentStatusBody(BaseModel):
    status: str


class PortalItemBody(BaseModel):
    module: str
    label: str
    enabled: bool
    position: int


class PortalUpdateBody(BaseModel):
    items: list[PortalItemBody]


app = FastAPI(title="CampusLive Hierarchy API", version="3.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


class RealtimeHub:
    def __init__(self) -> None:
        self.clients: dict[int, set[WebSocket]] = {}

    async def connect(self, college_id: int, websocket: WebSocket) -> None:
        await websocket.accept()
        self.clients.setdefault(college_id, set()).add(websocket)

    def disconnect(self, college_id: int, websocket: WebSocket) -> None:
        if college_id in self.clients:
            self.clients[college_id].discard(websocket)
            if not self.clients[college_id]:
                self.clients.pop(college_id, None)

    async def broadcast(self, college_id: int, event: str) -> None:
        dead: list[WebSocket] = []
        for ws in list(self.clients.get(college_id, set())):
            try:
                await ws.send_json({"event": event, "at": utcnow().isoformat()})
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.disconnect(college_id, ws)


hub = RealtimeHub()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def hash_password(password: str) -> str:
    salt = os.getenv("PASSWORD_SALT", "campuslive-v3")
    return hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 150_000).hex()


def normalize_code(code: str) -> str:
    value = re.sub(r"[^A-Za-z0-9_-]", "", code.strip()).upper()
    if len(value) < 2:
        raise HTTPException(status_code=400, detail="Invalid college code")
    return value


def current_user(
    authorization: Optional[str] = Header(default=None),
    db: Session = Depends(get_db),
) -> User:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    token = authorization.removeprefix("Bearer ").strip()
    session = db.get(SessionToken, token)
    if session is None:
        raise HTTPException(status_code=401, detail="Invalid session")
    user = db.get(User, session.user_id)
    if user is None or not user.is_active:
        raise HTTPException(status_code=401, detail="Inactive account")
    return user


def require_role(*roles: str):
    def dependency(user: User = Depends(current_user)) -> User:
        if user.role not in roles:
            raise HTTPException(status_code=403, detail="Role not allowed")
        return user
    return dependency


def user_json(user: User, db: Session) -> dict:
    dept = db.get(Department, user.department_id) if user.department_id else None
    college = db.get(College, user.college_id)
    return {
        "id": user.id,
        "name": user.name,
        "email": user.email,
        "role": user.role,
        "department_id": user.department_id,
        "department": dept.name if dept else None,
        "year": user.year,
        "section": user.section,
        "active": user.is_active,
        "college_id": user.college_id,
        "college_name": college.name if college else "",
        "college_code": college.code if college else "",
    }


def audit(db: Session, user: User, action: str, detail: str = "") -> None:
    db.add(
        AuditLog(
            college_id=user.college_id,
            actor_id=user.id,
            action=action,
            detail=detail,
        )
    )


def ensure_default_portal(db: Session, college_id: int) -> None:
    exists = db.scalar(select(PortalConfig.id).where(PortalConfig.college_id == college_id).limit(1))
    if exists is not None:
        return
    for role, modules in DEFAULT_MODULES.items():
        for position, (module, label) in enumerate(modules):
            db.add(
                PortalConfig(
                    college_id=college_id,
                    role=role,
                    module=module,
                    label=label,
                    enabled=True,
                    position=position,
                )
            )
    db.commit()


def allowed_recipient(sender: User, recipient: User) -> bool:
    if sender.college_id != recipient.college_id or not recipient.is_active:
        return False
    if sender.role == "admin":
        return recipient.id != sender.id
    if sender.role == "principal":
        return recipient.role == "hod"
    if sender.role == "hod":
        return recipient.role == "staff" and recipient.department_id == sender.department_id
    if sender.role == "staff":
        return recipient.role == "student" and recipient.department_id == sender.department_id
    return False


def directory_stmt(user: User):
    stmt = select(User).where(
        User.college_id == user.college_id,
        User.is_active.is_(True),
    )
    if user.role == "admin":
        return stmt.where(User.id != user.id)
    if user.role == "principal":
        return stmt.where(User.role == "hod")
    if user.role == "hod":
        return stmt.where(User.role == "staff", User.department_id == user.department_id)
    if user.role == "staff":
        return stmt.where(User.role == "student", User.department_id == user.department_id)
    return stmt.where(User.id == -1)


@app.on_event("startup")
def startup() -> None:
    Base.metadata.create_all(engine)


@app.get("/")
def root():
    return {"name": "CampusLive Hierarchy API", "version": "3.0.0", "status": "online"}


@app.get("/health")
def health():
    return {"ok": True, "time": utcnow().isoformat()}


@app.post("/setup/college")
def setup_college(body: CollegeSetupBody, db: Session = Depends(get_db)):
    code = normalize_code(body.college_code)
    if db.scalar(select(College).where(College.code == code)) is not None:
        raise HTTPException(status_code=409, detail="College code already exists")

    college = College(name=body.college_name.strip(), code=code)
    db.add(college)
    db.flush()

    email = body.admin_email.strip().lower()
    admin_user = User(
        college_id=college.id,
        name=body.admin_name.strip(),
        email=email,
        password_hash=hash_password(body.admin_password),
        role="admin",
    )
    db.add(admin_user)
    db.flush()
    ensure_default_portal(db, college.id)
    audit(db, admin_user, "college.created", college.name)
    db.commit()

    token = secrets.token_urlsafe(32)
    db.add(SessionToken(token=token, user_id=admin_user.id))
    db.commit()
    return {"token": token, "user": user_json(admin_user, db)}


@app.post("/auth/login")
def login(body: LoginBody, db: Session = Depends(get_db)):
    code = normalize_code(body.college_code)
    college = db.scalar(select(College).where(College.code == code))
    if college is None:
        raise HTTPException(status_code=401, detail="Invalid college code or credentials")
    user = db.scalar(
        select(User).where(
            User.college_id == college.id,
            func.lower(User.email) == body.email.strip().lower(),
        )
    )
    if user is None or not user.is_active or user.password_hash != hash_password(body.password):
        raise HTTPException(status_code=401, detail="Invalid college code or credentials")
    token = secrets.token_urlsafe(32)
    db.add(SessionToken(token=token, user_id=user.id))
    db.commit()
    return {"token": token, "user": user_json(user, db)}


@app.get("/me")
def me(user: User = Depends(current_user), db: Session = Depends(get_db)):
    return user_json(user, db)


@app.get("/portal")
def portal(user: User = Depends(current_user), db: Session = Depends(get_db)):
    ensure_default_portal(db, user.college_id)
    rows = db.scalars(
        select(PortalConfig)
        .where(PortalConfig.college_id == user.college_id, PortalConfig.role == user.role)
        .order_by(PortalConfig.position)
    ).all()
    return [
        {
            "module": row.module,
            "label": row.label,
            "enabled": row.enabled,
            "position": row.position,
        }
        for row in rows
    ]


@app.get("/dashboard")
def dashboard(user: User = Depends(current_user), db: Session = Depends(get_db)):
    unread = db.scalar(
        select(func.count(Assignment.id)).where(
            Assignment.recipient_id == user.id,
            Assignment.status == "new",
        )
    ) or 0

    base = {
        "role": user.role,
        "unread": unread,
        "college": user_json(user, db)["college_name"],
    }

    if user.role == "admin":
        counts = {}
        for role in ROLE_ORDER:
            counts[role] = db.scalar(
                select(func.count(User.id)).where(
                    User.college_id == user.college_id,
                    User.role == role,
                    User.is_active.is_(True),
                )
            ) or 0
        departments = db.scalar(
            select(func.count(Department.id)).where(Department.college_id == user.college_id)
        ) or 0
        pending = db.scalar(
            select(func.count(Assignment.id)).where(
                Assignment.college_id == user.college_id,
                Assignment.status != "done",
            )
        ) or 0
        base.update({"counts": counts, "departments": departments, "pending_assignments": pending})

    elif user.role == "principal":
        hods = db.scalar(
            select(func.count(User.id)).where(
                User.college_id == user.college_id,
                User.role == "hod",
                User.is_active.is_(True),
            )
        ) or 0
        base.update({"hod_count": hods})

    elif user.role == "hod":
        staff = db.scalar(
            select(func.count(User.id)).where(
                User.college_id == user.college_id,
                User.department_id == user.department_id,
                User.role == "staff",
                User.is_active.is_(True),
            )
        ) or 0
        base.update({"staff_count": staff})

    elif user.role == "staff":
        students = db.scalar(
            select(func.count(User.id)).where(
                User.college_id == user.college_id,
                User.department_id == user.department_id,
                User.role == "student",
                User.is_active.is_(True),
            )
        ) or 0
        base.update({"student_count": students})

    return base


@app.get("/directory")
def directory(user: User = Depends(current_user), db: Session = Depends(get_db)):
    rows = db.scalars(directory_stmt(user).order_by(User.role, User.name)).all()
    return [user_json(row, db) for row in rows]


@app.get("/inbox")
def inbox(user: User = Depends(current_user), db: Session = Depends(get_db)):
    rows = db.scalars(
        select(Assignment)
        .where(Assignment.recipient_id == user.id)
        .order_by(Assignment.created_at.desc())
        .limit(200)
    ).all()
    result = []
    for row in rows:
        sender = db.get(User, row.sender_id)
        result.append(
            {
                "id": row.id,
                "kind": row.kind,
                "title": row.title,
                "body": row.body,
                "status": row.status,
                "due_at": row.due_at.isoformat() if row.due_at else None,
                "created_at": row.created_at.isoformat(),
                "sender_name": sender.name if sender else "Unknown",
                "sender_role": sender.role if sender else "",
            }
        )
    return result


@app.get("/sent")
def sent(user: User = Depends(current_user), db: Session = Depends(get_db)):
    rows = db.scalars(
        select(Assignment)
        .where(Assignment.sender_id == user.id)
        .order_by(Assignment.created_at.desc())
        .limit(200)
    ).all()
    result = []
    for row in rows:
        recipient = db.get(User, row.recipient_id)
        result.append(
            {
                "id": row.id,
                "kind": row.kind,
                "title": row.title,
                "body": row.body,
                "status": row.status,
                "created_at": row.created_at.isoformat(),
                "recipient_name": recipient.name if recipient else "Unknown",
                "recipient_role": recipient.role if recipient else "",
            }
        )
    return result


@app.post("/assignments")
async def create_assignments(
    body: AssignmentBody,
    user: User = Depends(require_role("admin", "principal", "hod", "staff")),
    db: Session = Depends(get_db),
):
    recipients: list[User] = []

    if body.target_user_ids:
        rows = db.scalars(
            select(User).where(User.id.in_(body.target_user_ids), User.college_id == user.college_id)
        ).all()
        recipients.extend([row for row in rows if allowed_recipient(user, row)])

    if body.target_role:
        role = body.target_role.lower().strip()
        stmt = select(User).where(
            User.college_id == user.college_id,
            User.role == role,
            User.is_active.is_(True),
        )
        if user.role in {"hod", "staff"}:
            stmt = stmt.where(User.department_id == user.department_id)
        rows = db.scalars(stmt).all()
        recipients.extend([row for row in rows if allowed_recipient(user, row)])

    unique = {row.id: row for row in recipients}
    if not unique:
        raise HTTPException(status_code=400, detail="No permitted recipients selected")

    created = 0
    for recipient in unique.values():
        db.add(
            Assignment(
                college_id=user.college_id,
                sender_id=user.id,
                recipient_id=recipient.id,
                kind=body.kind.strip().lower() or "information",
                title=body.title.strip(),
                body=body.body.strip(),
                due_at=body.due_at,
            )
        )
        created += 1

    audit(db, user, "assignment.sent", f"{body.title} -> {created} recipients")
    db.commit()
    await hub.broadcast(user.college_id, "assignments.changed")
    return {"ok": True, "created": created}


@app.patch("/assignments/{assignment_id}")
async def update_assignment(
    assignment_id: int,
    body: AssignmentStatusBody,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    row = db.get(Assignment, assignment_id)
    if row is None or row.college_id != user.college_id:
        raise HTTPException(status_code=404, detail="Assignment not found")
    if row.recipient_id != user.id and user.role != "admin":
        raise HTTPException(status_code=403, detail="Not allowed")
    status = body.status.strip().lower()
    if status not in {"new", "read", "done"}:
        raise HTTPException(status_code=400, detail="Invalid status")
    row.status = status
    row.updated_at = utcnow()
    db.commit()
    await hub.broadcast(user.college_id, "assignments.changed")
    return {"ok": True}


@app.get("/admin/users")
def admin_users(
    user: User = Depends(require_role("admin")),
    db: Session = Depends(get_db),
):
    rows = db.scalars(
        select(User)
        .where(User.college_id == user.college_id)
        .order_by(User.role, User.name)
    ).all()
    return [user_json(row, db) for row in rows]


@app.post("/admin/users")
async def create_user(
    body: UserBody,
    user: User = Depends(require_role("admin")),
    db: Session = Depends(get_db),
):
    role = body.role.strip().lower()
    if role not in ROLE_ORDER:
        raise HTTPException(status_code=400, detail="Invalid role")
    email = body.email.strip().lower()
    if db.scalar(
        select(User).where(User.college_id == user.college_id, func.lower(User.email) == email)
    ) is not None:
        raise HTTPException(status_code=409, detail="Email already exists in this college")

    if role in {"hod", "staff", "student"} and body.department_id is None:
        raise HTTPException(status_code=400, detail="Department is required")
    if body.department_id is not None:
        dept = db.get(Department, body.department_id)
        if dept is None or dept.college_id != user.college_id:
            raise HTTPException(status_code=400, detail="Invalid department")

    row = User(
        college_id=user.college_id,
        department_id=body.department_id,
        name=body.name.strip(),
        email=email,
        password_hash=hash_password(body.password),
        role=role,
        year=body.year.strip(),
        section=body.section.strip(),
    )
    db.add(row)
    db.flush()

    if role == "hod" and body.department_id:
        dept = db.get(Department, body.department_id)
        if dept:
            dept.hod_user_id = row.id

    audit(db, user, "user.created", f"{row.name} ({row.role})")
    db.commit()
    await hub.broadcast(user.college_id, "users.changed")
    return user_json(row, db)


@app.patch("/admin/users/{user_id}")
async def update_user(
    user_id: int,
    body: UserPatchBody,
    admin: User = Depends(require_role("admin")),
    db: Session = Depends(get_db),
):
    row = db.get(User, user_id)
    if row is None or row.college_id != admin.college_id:
        raise HTTPException(status_code=404, detail="User not found")
    if body.name is not None:
        row.name = body.name.strip()
    if body.department_id is not None:
        dept = db.get(Department, body.department_id)
        if dept is None or dept.college_id != admin.college_id:
            raise HTTPException(status_code=400, detail="Invalid department")
        row.department_id = body.department_id
    if body.year is not None:
        row.year = body.year.strip()
    if body.section is not None:
        row.section = body.section.strip()
    if body.is_active is not None:
        row.is_active = body.is_active
    audit(db, admin, "user.updated", f"user_id={row.id}")
    db.commit()
    await hub.broadcast(admin.college_id, "users.changed")
    return user_json(row, db)


@app.get("/admin/departments")
def admin_departments(
    user: User = Depends(require_role("admin")),
    db: Session = Depends(get_db),
):
    rows = db.scalars(
        select(Department)
        .where(Department.college_id == user.college_id)
        .order_by(Department.name)
    ).all()
    result = []
    for row in rows:
        hod = db.get(User, row.hod_user_id) if row.hod_user_id else None
        staff_count = db.scalar(
            select(func.count(User.id)).where(
                User.college_id == user.college_id,
                User.department_id == row.id,
                User.role == "staff",
                User.is_active.is_(True),
            )
        ) or 0
        student_count = db.scalar(
            select(func.count(User.id)).where(
                User.college_id == user.college_id,
                User.department_id == row.id,
                User.role == "student",
                User.is_active.is_(True),
            )
        ) or 0
        result.append(
            {
                "id": row.id,
                "name": row.name,
                "code": row.code,
                "hod_user_id": row.hod_user_id,
                "hod_name": hod.name if hod else None,
                "staff_count": staff_count,
                "student_count": student_count,
            }
        )
    return result


@app.post("/admin/departments")
async def create_department(
    body: DepartmentBody,
    user: User = Depends(require_role("admin")),
    db: Session = Depends(get_db),
):
    code = body.code.strip().upper()
    exists = db.scalar(
        select(Department).where(
            Department.college_id == user.college_id,
            func.lower(Department.code) == code.lower(),
        )
    )
    if exists is not None:
        raise HTTPException(status_code=409, detail="Department code already exists")
    row = Department(
        college_id=user.college_id,
        name=body.name.strip(),
        code=code,
    )
    db.add(row)
    db.flush()
    audit(db, user, "department.created", f"{row.code} - {row.name}")
    db.commit()
    await hub.broadcast(user.college_id, "departments.changed")
    return {"id": row.id, "name": row.name, "code": row.code}


@app.patch("/admin/departments/{department_id}")
async def update_department(
    department_id: int,
    body: DepartmentPatchBody,
    user: User = Depends(require_role("admin")),
    db: Session = Depends(get_db),
):
    row = db.get(Department, department_id)
    if row is None or row.college_id != user.college_id:
        raise HTTPException(status_code=404, detail="Department not found")
    if body.name is not None:
        row.name = body.name.strip()
    if body.code is not None:
        row.code = body.code.strip().upper()
    if body.hod_user_id is not None:
        hod = db.get(User, body.hod_user_id)
        if (
            hod is None
            or hod.college_id != user.college_id
            or hod.role != "hod"
            or hod.department_id != row.id
        ):
            raise HTTPException(status_code=400, detail="HOD must belong to this department")
        row.hod_user_id = hod.id
    audit(db, user, "department.updated", f"department_id={row.id}")
    db.commit()
    await hub.broadcast(user.college_id, "departments.changed")
    return {"ok": True}


@app.get("/admin/portal/{role}")
def admin_portal(
    role: str,
    user: User = Depends(require_role("admin")),
    db: Session = Depends(get_db),
):
    if role not in ROLE_ORDER:
        raise HTTPException(status_code=400, detail="Invalid role")
    ensure_default_portal(db, user.college_id)
    rows = db.scalars(
        select(PortalConfig)
        .where(PortalConfig.college_id == user.college_id, PortalConfig.role == role)
        .order_by(PortalConfig.position)
    ).all()
    return [
        {
            "module": row.module,
            "label": row.label,
            "enabled": row.enabled,
            "position": row.position,
        }
        for row in rows
    ]


@app.put("/admin/portal/{role}")
async def update_portal(
    role: str,
    body: PortalUpdateBody,
    user: User = Depends(require_role("admin")),
    db: Session = Depends(get_db),
):
    if role not in ROLE_ORDER:
        raise HTTPException(status_code=400, detail="Invalid role")
    db.query(PortalConfig).filter(
        PortalConfig.college_id == user.college_id,
        PortalConfig.role == role,
    ).delete(synchronize_session=False)
    for item in body.items:
        db.add(
            PortalConfig(
                college_id=user.college_id,
                role=role,
                module=item.module,
                label=item.label.strip() or item.module,
                enabled=item.enabled,
                position=item.position,
            )
        )
    audit(db, user, "portal.updated", role)
    db.commit()
    await hub.broadcast(user.college_id, "portal.changed")
    return {"ok": True}


@app.get("/admin/audit")
def admin_audit(
    user: User = Depends(require_role("admin")),
    db: Session = Depends(get_db),
):
    rows = db.scalars(
        select(AuditLog)
        .where(AuditLog.college_id == user.college_id)
        .order_by(AuditLog.created_at.desc())
        .limit(200)
    ).all()
    result = []
    for row in rows:
        actor = db.get(User, row.actor_id)
        result.append(
            {
                "id": row.id,
                "action": row.action,
                "detail": row.detail,
                "actor": actor.name if actor else "Unknown",
                "created_at": row.created_at.isoformat(),
            }
        )
    return result


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, token: str = Query(...)):
    db = SessionLocal()
    college_id: Optional[int] = None
    try:
        session = db.get(SessionToken, token)
        if session is None:
            await websocket.close(code=4401)
            return
        user = db.get(User, session.user_id)
        if user is None or not user.is_active:
            await websocket.close(code=4401)
            return
        college_id = user.college_id
        await hub.connect(college_id, websocket)
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        if college_id is not None:
            hub.disconnect(college_id, websocket)
    except Exception:
        if college_id is not None:
            hub.disconnect(college_id, websocket)
    finally:
        db.close()
