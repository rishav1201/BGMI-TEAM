# BGMI Team Command Center V4

Native Flutter Android foundation for a professional BGMI esports team command center.

## V4 modules
- Firebase Auth
- Team workspace
- Role-based roster: Owner / Coach / IGL / Analyst / Player
- Realtime team chat
- Typing/presence-ready member state
- Player profiles
- Match schedule
- Tactical planner with free draw, circles, arrows, markers and eraser
- Strategy plan persistence
- Firebase Storage image upload foundation
- FCM notification foundation
- Native Android recorder foundation
- Dark tactical esports UI
- Local team-code persistence

## Setup
1. Install Flutter stable.
2. Create a Firebase project.
3. Add Android app and place `google-services.json` in `android/app/`.
4. Enable Email/Password Auth, Firestore, Storage and Cloud Messaging.
5. Run:
   flutter pub get
   flutterfire configure
6. Replace generated Firebase Android configuration if needed.
7. Add real BGMI map images to `assets/maps/`:
   erangel.jpg, miramar.jpg, sanhok.jpg, vikendi.jpg, rondo.jpg
8. Run:
   flutter run

## Important recorder note
Android capture quality depends on the device, Android version and encoder. A Flutter/browser app cannot guarantee 60 FPS + 1080p on every phone. The V4 UI exposes 24/30/60 FPS and 360p/480p/720p/1080p targets; production capture should be validated on the target team's devices.

## Firebase security
Do not ship permissive Firestore rules. The project should use authenticated team membership checks before production. The included code is a foundation; connect it to your Firebase project's generated options and deploy rules tailored to your team model.

## Suggested V4 production additions
- Admin invitation links
- Push notification topics per team
- Cloud Storage thumbnails for tactical plans
- Coach/IGL-only strategy editing
- Match result/statistics dashboard
- Voice rooms
- Replay/video library
- Team analytics
