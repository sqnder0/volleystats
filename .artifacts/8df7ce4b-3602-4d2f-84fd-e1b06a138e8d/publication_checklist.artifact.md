# Publication Checklist: Volleystats

We have completed the core technical preparations. Here is what is left to officially publish the app to the Google Play Store or distribute it for testing.

## 1. Technical Finalization

> [!IMPORTANT]
> **Generate Signing Key**: You must generate a production `.jks` file.
> 1. Run: `keytool -genkey -v -keystore android/app/key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
> 2. Fill the passwords in [key.properties](file:///home/sander/StudioProjects/volleystats/android/key.properties).

- [ ] **Final Build Test**: Run `flutter build appbundle`. This generates the `.aab` file required by Google Play.
- [ ] **Version Bump**: In `pubspec.yaml`, increment the version (e.g., `1.0.1+2`) before every new store upload.
- [ ] **ProGuard/R8 Check**: Verify if any plugins (like `flutter_local_notifications`) require specific keep rules to prevent crashes in the minified release build.

## 2. Store Preparation (Non-Technical)

- [ ] **Privacy Policy**: Since the app accesses the internet, Google Play requires a Privacy Policy URL. You can host a simple one on GitHub Pages or a site like [privacypolicygenerator.info](https://www.privacypolicygenerator.info/).
- [ ] **Store Assets**:
    - [ ] **Short Description** (up to 80 chars).
    - [ ] **Full Description** explaining features.
    - [ ] **Feature Graphic** (1024x500 PNG).
    - [ ] **Screenshots** (Phone, 7" tablet, 10" tablet).
- [ ] **Developer Account**: If not already done, you need to pay the one-time $25 fee for a Google Play Developer account.

## 3. Recommended Additions (Optional but Useful)

- [ ] **Error Reporting**: Integrate [Firebase Crashlytics](https://firebase.google.com/docs/crashlytics/get-started?platform=flutter) to see crashes that happen on users' devices.
- [ ] **Analytics**: Integrate [Google Analytics for Firebase](https://firebase.google.com/docs/analytics/get-started?platform=flutter) to see how many people are using the app.
- [ ] **App Rating Prompt**: Add a prompt to ask users to rate the app after they've used it a few times.
- [ ] **Contact Email**: Ensure there is a way for users to report bugs or ask questions (e.g., a "Contact" button in the More tab).

## 4. Final Review

- [ ] **Asset Check**: Ensure the new "Splash Icon" and "Adaptive Icon" look perfect on multiple physical devices.
- [ ] **API Load Test**: Ensure your server at `volleyapi.sqnder.dev` is ready for a surge of new users.
