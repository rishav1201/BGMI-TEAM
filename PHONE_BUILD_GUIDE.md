# Build the APK using only your Android phone

## 1. Create GitHub repository
Open github.com in Chrome on your phone and create a new empty repository, e.g.
`bgmi-team-command-center`.

## 2. Upload this project
Extract the ZIP on your phone and upload the project files/folders to the repository.
The `.github/workflows/build-apk.yml` file must be included.

If GitHub's website is awkward for uploading many files, use the GitHub mobile app for the repository and a browser-based Git client.

## 3. Run the cloud build
On GitHub:
Actions → Build Android APK → Run workflow.

The workflow installs Flutter in GitHub's cloud runner and runs:
`flutter pub get`
`flutter build apk --release`

## 4. Download APK
When the workflow finishes:
Actions → latest successful run → Artifacts →
`BGMI-Team-Command-Center-V4-1-APK`

Download the ZIP artifact and extract `app-release.apk`.

## 5. Install
Tap the APK on your Android phone. Android may ask you to allow installation from that source.

## Firebase
For login/chat/database features, add your Firebase Android configuration before release.
Use FlutterFire:
`flutterfire configure`

The safest production setup is to create the Firebase project first and then add the generated
`google-services.json` / `firebase_options.dart` files.

## Important
The cloud workflow builds the Android package. It does not magically create a Firebase project
or production recorder backend. Those still need to be configured.
