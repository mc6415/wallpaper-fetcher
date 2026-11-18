import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing. CI passes the key in environment variables; locally,
// android/key.properties (git-ignored) holds storeFile, storePassword,
// keyAlias and keyPassword. Without either, release builds fall back to the
// debug key so `flutter run --release` works anywhere, unless
// REQUIRE_RELEASE_SIGNING=true (CI), which makes a missing key an error.
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

fun signingValue(environment: String, property: String): String? =
    System.getenv(environment)?.takeIf { it.isNotEmpty() } ?: keyProperties.getProperty(property)

android {
    namespace = "dev.mcoombes.wallpaperfetcher"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "dev.mcoombes.wallpaperfetcher"
        // Android 8.0+ (PROJECT_BRIEF.md).
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            signingValue("ANDROID_KEYSTORE_FILE", "storeFile")?.let { store ->
                storeFile = file(store)
                storePassword = signingValue("ANDROID_KEYSTORE_PASSWORD", "storePassword")
                keyAlias = signingValue("ANDROID_KEY_ALIAS", "keyAlias")
                keyPassword = signingValue("ANDROID_KEY_PASSWORD", "keyPassword")
            }
        }
    }

    buildTypes {
        release {
            val release = signingConfigs.getByName("release")
            signingConfig = when {
                release.storeFile != null -> release
                System.getenv("REQUIRE_RELEASE_SIGNING") == "true" ->
                    throw GradleException("No release signing key: set ANDROID_KEYSTORE_FILE and friends, or android/key.properties.")
                else -> signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Background rotation (RotationWorker).
    implementation("androidx.work:work-runtime-ktx:2.11.2")
}
