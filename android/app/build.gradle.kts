import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Reads `google-services.json`. Without it the native Firebase SDKs have no
    // project to talk to and analytics is silently empty — which is the failure
    // the JS's own comment records, on the other platform.
    id("com.google.gms.google-services")
    // AFTER google-services, which is the order its own docs require.
    id("com.google.firebase.crashlytics")
}

// **THE RELEASE BUILD WAS SIGNED WITH THE DEBUG KEYS.**
//
// `flutter create` leaves a TODO there and the port shipped with it, which is
// not a console task waiting to be done — it is a build that Play REFUSES.
// A debug-signed artifact is rejected at upload, and on the store's side it
// would be a different signing identity from the live app in any case, which
// is the one thing that cannot be corrected after the fact.
//
// The keystore itself stays out of the repository, where a signing key belongs:
// this reads `android/key.properties`, which is git-ignored, and falls back to
// the debug config when there is no such file so `flutter run --release` still
// works on a machine that has never seen the key. That fallback is deliberate
// and it is also the only risk here, so it is LOUD — the build prints a warning
// naming the file it wanted, rather than quietly producing an unshippable
// artifact the way the TODO did.
//
// `key.properties` carries `storeFile`, `storePassword`, `keyAlias` and
// `keyPassword`; it is in the old Capacitor repo and is not committed here.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasKeystore = keystorePropertiesFile.exists()
if (hasKeystore) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.mergeempirefc.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications needs java.time on old API levels, and the
        // build fails outright without it rather than degrading.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mergeempirefc.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // The real key when there is one, and a NOISY fallback when there
            // is not — see the note above. Signing a release with the debug key
            // produces an artifact Play rejects, and doing it silently is how
            // that reaches the upload step rather than the build.
            signingConfig = if (hasKeystore) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "WARNING: no android/key.properties — signing the release " +
                        "build with the DEBUG key. This artifact cannot be " +
                        "uploaded to Play.",
                )
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
