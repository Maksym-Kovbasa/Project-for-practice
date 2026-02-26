# Project for Practice

Flutter auth UI project (designed in Pencil first, then implemented in code), currently using SQLite for local authentication.

## Work Completed

### 1) Auth UI and UX
- Built a custom light-mode authentication design inspired by the provided reference.
- Added both Sign In and Sign Up states.
- Added social login buttons (Google/Facebook visuals).
- Added smooth transitions between Sign In and Sign Up.
- Ensured form fields are cleared when switching auth modes.
- Added password visibility toggles for password and confirm password.

### 2) Pencil design updates
- File: `C:\Users\8887\Downloads\empty.pen`
- Created and refined phone-sized frames:
  - `Phone - Sign In`
  - `Phone - Sign Up`
  - `Phone - Registration Success`
- Synced Pencil designs multiple times to match live Flutter behavior and copy updates.

### 3) Registration success flow
- Added a custom success screen after registration.
- Current buttons on success screen:
  - `Continue`
  - `Back to Login`

### 4) Auth logic (migrated from in-memory to SQLite)
- Replaced temporary in-memory user store with SQLite-backed auth service.
- New file: `lib/auth/sqlite_auth_service.dart`
- Uses `sqflite` + `path`.
- Creates local DB `auth.db` with `users` table.
- Includes seeded demo user:
  - username: `demo`
  - password: `demo123`
  - email: `demo@example.com`

### 5) Validation rules implemented
- Sign Up:
  - username required
  - email required
  - email format required
  - password required
  - password length >= 6
  - password must match confirm password
- Sign In:
  - username required
  - password required

### 6) Navigation behavior (current)
- Successful Sign Up -> `RegistrationSuccessScreen`
- `Continue` on success screen -> `DemoScreen` (`lib/demo.dart`)
- `Back to Login` -> Auth screen in Sign In mode
- Successful Sign In -> `DemoScreen`

### 7) Demo screen target
- `lib/demo.dart` now contains `DemoScreen` and is used as the post-auth destination.

## Current File Highlights
- Main app and auth UI/flow: `lib/main.dart`
- SQLite auth service: `lib/auth/sqlite_auth_service.dart`
- Post-auth destination: `lib/demo.dart`

## Setup Notes
After pulling/installing, run:

```bash
flutter pub get
```

Then run the app as usual:

```bash
flutter run
```

## Planned next step
- Replace local SQLite auth with a remote/backend auth provider in future (keeping the same service abstraction approach).
