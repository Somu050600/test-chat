# Chat App

A multi-platform real-time chat application built with Flutter and Firebase.

## Features (V1)

- **Google OAuth authentication** — sign in / sign out with Google
- **1-to-1 real-time text chat** — Firestore-powered live messaging
- **Push notifications** — FCM-based notifications with foreground + background handling
- **Clean architecture** — feature-based folder structure, Riverpod state management
- **Cross-platform** — Android, iOS, Web

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.x |
| Auth | Firebase Auth + Google Sign-In |
| Database | Cloud Firestore |
| Notifications | Firebase Cloud Messaging |
| State Management | Riverpod |
| Routing | go_router |
| Backend Logic | Firebase Cloud Functions (Node.js) |

## Project Structure

```
lib/
├── core/
│   ├── constants/    # App-wide constants
│   ├── services/     # Firebase service abstractions
│   └── utils/        # Date formatters, helpers
├── features/
│   ├── auth/         # Login screen
│   ├── chat/         # Chat screen, message bubbles, input
│   └── home/         # Conversation list, new chat
├── models/           # Data models (User, Conversation, Message)
├── providers/        # Riverpod providers
├── routes/           # GoRouter configuration
└── main.dart         # Entry point
```

## Setup

### Prerequisites

- Flutter SDK 3.x
- Firebase project with Auth, Firestore, and Cloud Messaging enabled

### Install dependencies

```bash
flutter pub get
```

### Environment configuration

All Firebase keys and secrets are loaded from a `.env` file via `--dart-define-from-file`.

1. Copy the template:
   ```bash
   cp .env.example .env
   ```
2. Fill in your Firebase project values in `.env`

> **`.env` is git-ignored.** Never commit it. Share `.env.example` instead.

### Firebase setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable Google Sign-In in Authentication
3. Create a Firestore database
4. Deploy Firestore rules: `firebase deploy --only firestore:rules`
5. Deploy indexes: `firebase deploy --only firestore:indexes`
6. Deploy Cloud Functions: `cd functions && npm install && firebase deploy --only functions`

### Run

```bash
# Web
flutter run -d web-server --web-port=8080 --dart-define-from-file=.env

# Android
flutter run --dart-define-from-file=.env

# Build web release
flutter build web --dart-define-from-file=.env
```

### Test

```bash
flutter test
```

## Firestore Security Rules

Security rules enforce:
- Users can only read/write their own user document
- Only conversation members can read/write conversations and messages
- Message sender ID must match authenticated user

See `firestore.rules` for the complete ruleset.

## Push Notifications (Vercel Backend)

Push notifications are sent via a lightweight Vercel serverless function at `backend/api/notify.js`. The Flutter app calls this endpoint after sending a message.

### How it works

```
User sends message → Firestore write → Client calls POST /api/notify with conversationId + messageId and Firebase ID token → Backend verifies token, loads message from Firestore, sends FCM → Recipient gets push
```

The client does **not** send message text or sender id for the notify call; the server reads those from Firestore and checks the sender matches the verified ID token.

### Deploy to Vercel

1. **Get a Firebase service account key:**
   - Firebase Console → Project Settings → Service Accounts → Generate New Private Key
   - Save the JSON file

2. **Install Vercel CLI:**
   ```bash
   npm install -g vercel
   ```

3. **Deploy:**
   ```bash
   cd backend
   npm install
   vercel
   ```
   Follow the prompts (link to your Vercel account, pick a project name).

4. **Set environment variables in Vercel dashboard:**
   - `FIREBASE_SERVICE_ACCOUNT` — paste the entire service account JSON as a single line (used for Admin SDK: verify ID tokens, Firestore, FCM)

5. **Note your deployment URL** (e.g., `https://chat-app-notifications.vercel.app`)

6. **Update your Flutter `.env`:**
   ```
   NOTIFY_API_URL=https://your-project.vercel.app/api/notify
   ```
   `NOTIFY_API_KEY` is no longer required; auth uses `Authorization: Bearer <Firebase ID token>`.

7. **Rebuild and deploy the Flutter app:**
   ```bash
   flutter build web --dart-define-from-file=.env
   firebase deploy --only hosting
   ```

### Alternative: Firebase Cloud Functions (Blaze plan)

`functions/index.js` contains a Firestore trigger version that auto-fires on new messages. This requires the Blaze (pay-as-you-go) plan. If you upgrade later, deploy with:
```bash
cd functions && npm install && firebase deploy --only functions
```
Then remove the `NOTIFY_API_URL` from your `.env` to disable the client-side API call.
