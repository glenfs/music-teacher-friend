# Android Online Testing Options

You can test the Android APK online without owning an Android phone.

## Recommended Options

### Appetize.io

Best for quick browser testing. Upload the APK and run it in a browser-based Android emulator.

Good for:
- Layout checks
- Touch flow
- Basic UX
- Crash checks
- Quick demos

Appetize runs Android apps in the browser using Android emulators.

Links:
- https://docs.appetize.io/
- https://support.appetize.io/does-appetize.io-use-emulators-or-physical-devices

### BrowserStack App Live

Best for testing on real Android devices online. Upload the APK or AAB and interact with actual phones through the browser.

Good for:
- Real-device behavior
- Screen-size checks
- Performance checks
- Touch behavior
- Audio/device quirks

Link:
- https://www.browserstack.com/docs/app-live/app-source/upload-apps

### Firebase Test Lab

Best for automated testing, not manual playing. Upload the APK and run Robo or instrumented tests across Android devices and configurations.

Good for:
- Crash discovery
- Compatibility checks
- Automated regression testing

Link:
- https://firebase.google.com/docs/test-lab

## Suggested Clefira Workflow

Use Appetize.io first for quick manual testing and demos.

Use BrowserStack when real Android device behavior matters.

Use Firebase Test Lab later for automated regression testing.

Current student APK path:

```text
builds/android/student/ClefiraStudent.apk
```

## Important Note

Clefira uses audio, touch-heavy UI, and possibly mic/MIDI-style interaction. Emulator-only testing is useful for layout and basic flow, but it should not be treated as final release validation. Before release, test on at least one real Android device or use a BrowserStack real-device session.
