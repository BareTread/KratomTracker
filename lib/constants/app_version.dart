/// The user-visible release version.
///
/// Must match `version:` in pubspec.yaml — `test/app_version_test.dart`
/// fails the build if they drift, which is how this got stuck at 1.0.0
/// through nine releases.
const String kAppVersion = '2.15.0';
