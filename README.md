# Project for Practice

Flutter mobile app with Firebase authentication and a LiveKit voice-agent client.

## Current Architecture

- Frontend: Flutter app in `lib/`
- Auth: Firebase Auth
- Voice agent client: `lib/voice_agent/`
- Agent backend (separate project): `C:\Users\username\voice\agent-starter-node`
- Persistent memory store: Neon Postgres (handled by backend)

## Voice Agent Integration

The app launches the voice assistant after auth and connects to LiveKit using a sandbox token source.

Key points:
- Uses authenticated Firebase user `uid` as LiveKit participant identity.
- Sends identity attributes (`user_id`, `uid`, optional `email`) so backend can scope memory per user.
- Registers RPC handler `client.agentFieldUpdate` to receive agent-driven updates.
- Displays user profile fields in UI from backend sync events.

Implemented RPC actions:
- `profile_sync`: full profile state from backend
- `field_updated`: incremental/new captured preference
- `memory_cleared`: clear profile state in app immediately

## Backend Contract (agent-starter-node)

The backend agent currently supports these tool-driven flows:
- `update_field(field, value)` -> stores user preference in Neon and notifies frontend
- `perform_rpc_to_frontend(action, payloadJson)` -> sends explicit UI updates
- `clear_user_memory()` -> deletes user profile + conversation memory for the current user

Memory tables (backend side):
- `conversation_memory` (default)
- `user_profile_memory` (default)

## Environment

Required app env:
- `.env` with `LIVEKIT_SANDBOX_ID`

Required Firebase setup:
- `google-services.json` / platform Firebase config
- valid Firebase Auth project configuration

Backend env (in `agent-starter-node`):
- `LIVEKIT_URL`
- `LIVEKIT_API_KEY`
- `LIVEKIT_API_SECRET`
- `NEON_DATABASE_URL` (or `DATABASE_URL`)

## Run

Install dependencies:

```bash
flutter pub get
```

Run app:

```bash
flutter run
```

Run backend agent (separately):

```bash
cd C:\Users\username\voice\agent-starter-node
pnpm install
pnpm run dev
```

## Important Notes

- App and backend must use compatible LiveKit project credentials.
- User memory persistence and memory clearing are executed on backend; app reflects state via RPC.
- If session reconnect behavior changes, verify session lifecycle in `lib/voice_agent/controllers/app_ctrl.dart`.
- `recommended_links` are stored as structured pairs: `Title ||| url` (sent by the agent as `{ title, url }`).
