/// The AdMob APP ids — one per platform, and not to be confused with the unit
/// ids in `ad_units.dart`.
///
/// **These belong in the native manifests, not in Dart**, and they are here so
/// that one file states them and the two manifests can be checked against it.
/// The SDK reads them from `AndroidManifest.xml` and `Info.plist` at
/// initialisation; an app whose manifest is missing or wrong CRASHES on start
/// on Android rather than quietly serving nothing, which is why a test pins
/// them.
///
/// Taken from the shipped app's own `capacitor.config.ts`, so they are the ids
/// an already-published listing is serving against.
library;

const String admobAppIdAndroid = 'ca-app-pub-0386196346828968~9406473537';
const String admobAppIdIos = 'ca-app-pub-0386196346828968~3098217491';
