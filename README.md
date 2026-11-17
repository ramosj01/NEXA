# NEXA

Smart messaging that turns conversations into actions — chat, plus tasks,
decisions and (later) AI assistance, while keeping messaging simple,
reliable and secure. See [`docs/product-proposal.txt`](docs/product-proposal.txt)
for the full vision and [`docs/ROADMAP.md`](docs/ROADMAP.md) for build status.

## Repository layout

| Path | What |
|---|---|
| `app/` | Flutter mobile client (Material 3, NEXA theme) |
| `backend/` | FastAPI API + WebSocket real-time server |
| `design/` | Theme sheet and `tokens.json` (single source for colors) |
| `docs/` | Product proposal, roadmap |

## Backend

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
uvicorn app.main:app --reload        # http://localhost:8000/docs
pytest
```

Configuration (environment variables):

| Variable | Default | Notes |
|---|---|---|
| `NEXA_DATABASE_URL` | `sqlite:///./nexa-dev.db` | Use `postgresql+psycopg://…` in production |
| `NEXA_AUTH_MODE` | `dev` | `firebase` verifies Firebase ID tokens. **Never run `dev` in production.** |
| `NEXA_CORS_ORIGINS` | `*` | Comma-separated list |

In dev mode, authenticate with `Authorization: Bearer dev:<uid>` (or
`dev:<uid>:<Display Name>`); the WebSocket takes the same token as `/ws?token=…`.

### MVP API

- **Messaging** — `POST/GET /conversations`, `GET/POST /conversations/{id}/messages`
  (cursor via `before`), `POST /conversations/{id}/read`. A `client_id` on a
  message makes retries idempotent, so an offline queue can safely resend.
- **Real time** — `WS /ws`: receives `message.new`, `task.*`, `poll.updated`,
  `typing`; sends `message.send`, `typing`.
- **Chat-to-Task** — `POST /messages/{id}/task` (one tap; message text becomes
  the title), `POST/GET /conversations/{id}/tasks`, `GET /tasks/mine`, `PATCH /tasks/{id}`.
- **Decision Rooms** — `POST/GET /conversations/{id}/polls`, `PUT /polls/{id}/vote`,
  `POST /polls/{id}/decision` (creator records the outcome; `?decided_only=true`
  gives the decision history).
- **Smart Inbox** — `GET /inbox[?category=work]`: conversations ranked by
  awaiting-my-reply, unread, recency, with open-task counts.
  `PUT /conversations/{id}/category` files a chat as personal/work/important.

## App

The Flutter SDK is needed (3.27+). Platform folders aren't committed yet;
generate them once, then run:

```bash
cd app
flutter create . --project-name nexa --platforms android,ios
flutter pub get
flutter run
```

The app currently runs on demo data: Smart Inbox list with filters, chat
screen (long-press a message → create task), profile with online toggle and
light/dark/system theme. Colors live in `lib/theme/nexa_colors.dart`, matching
`design/tokens.json`.
