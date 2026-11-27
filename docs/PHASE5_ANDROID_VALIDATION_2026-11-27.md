# Android package validation — 2026-11-27

Repository: `fadimatar112211-bit/Archer-fm`  
Branch: `feature/phase-5-account-cloud-persistence`  
PR: [#21](https://github.com/fadimatar112211-bit/Archer-fm/pull/21)  
Validated source commit: `6eaf68660d3611b6c743165f97ff34f3e6db06da)

## CI evidence

Android workflow run [45970518583](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45970518583) completed successfully.

- Flutter dependency resolution: passed.
- `flutter analyze --no-fatal-infos`: passed.
- Full `flutter test` suite: passed.
- `flutter build apk --debug`: passed.
- Artifact upload: passed.
- Artifact ID: `15185361109`.
- Artifact archive: `archer-fm-android-validation.zip`.
- Artifact retention expiry: 2026-12-11.
- Archive contains `app/outputs/flutter-apk/app-debug.apk` only.

A second branch-push validation run [45970509137](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45970509137) also completed successfully with the same build/test steps and artifact upload (artifact ID `15185465904`).

## APK inspection

The artifact was downloaded and inspected in the working environment.

- APK path inside archive: `app/outputs/flutter-apk/app-debug.apk`.
- APK byte size: 222,519,658 bytes.
- SHA-256: `2c5d798fe4d9caed877891347f746f745e3ead9f19dc276ed84197b396a24b88`.
- This is a debug APK, not a signed release package.

## Emulator limitation

The emulator step was skipped in both automatic CI runs because the workflow intentionally gates emulator execution behind `github.event_name == 'workflow_dispatch'`. The step performs install, launch, process/activity checks, screenshot capture and logcat collection. No emulator boot/install/launch evidence exists from these two runs.

Do not claim on-device or emulator acceptance based on APK compilation alone. Run the workflow manually from GitHub Actions when an explicit Android QA run is authorized.

## Phase 5 acceptance remains open

The successful APK build does not close Phase 5. Remaining acceptance includes live Supabase staging migration and credentials, account isolation/token expiry and revocation checks, second-device restore, live reconnect testing, production TLS/WSS deployment, and approved monster progression/economy rules.
