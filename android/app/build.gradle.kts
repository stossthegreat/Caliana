plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.caliana.app"
    compileSdk = maxOf(flutter.compileSdkVersion, 35)
    // Pin NDK to a known-good locally installed version
    // (the auto-selected 26.3.11579264 is corrupt on this machine).
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    signingConfigs {
        create("release") {
            storeFile = file("upload-keystore.jks")
            storePassword = System.getenv("STORE_PASSWORD") ?: "skeletalpt123"
            keyAlias = System.getenv("KEY_ALIAS") ?: "skeletalpt"
            keyPassword = System.getenv("KEY_PASSWORD") ?: "skeletalpt123"
        }
    }

    defaultConfig {
        applicationId = "com.caliana.app"
        // record_android requires API 23+, image_picker prefers 21+
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = maxOf(flutter.targetSdkVersion, 35)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
