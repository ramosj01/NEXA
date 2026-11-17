# Roadmap

## MVP (in progress)

| Feature | Backend | App |
|---|---|---|
| Real-time messaging | ✅ REST + WebSocket, idempotent sends | 🟡 UI on demo data; API client not wired |
| Chat-to-Task | ✅ | 🟡 Create-task sheet (review before create) |
| Smart Inbox | ✅ categories, unread, awaiting reply | 🟡 List + filter chips |
| Polls & decisions | ✅ vote, change vote, record decision, history | ⬜ |
| Auth | ✅ Firebase ID tokens (dev bypass for local) | ⬜ Firebase sign-in |

### Next steps
1. Flutter API/WebSocket client and Firebase sign-in; replace demo data.
2. Local outgoing queue (offline-first) using the `client_id` idempotency key.
3. Push notifications (FCM) for offline recipients.
4. DB migrations (Alembic) before the first Postgres deploy.
5. Multi-instance fan-out (Redis pub/sub or Postgres LISTEN/NOTIFY) behind `ConnectionManager.publish`.

## Version 2
Voice transcription · AI conversation assistant (opt-in, never silently sent) · Calendar integration

## Version 3
Shared workspace · advanced collaboration

## Open product decisions
Target audience, main differentiator and business model (proposal §7) are
still to be decided; they affect E2E encryption vs. server-side AI features.
