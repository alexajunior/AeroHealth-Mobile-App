plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")  // Standard Kotlin plugin ID
    id("com.google.gms.google-services") // Firebase plugin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.aerohealth"
    compileSdk = flutter.compileSdkVersion.toInt()  // Ensure conversion to Int

    // Modern NDK version (match with Flutter's requirements)
    ndkVersion = "27.0.12077973"  // Updated to stable version

    defaultConfig {
        applicationId = "com.example.aerohealth"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion.toInt()  // Ensure conversion to Int
        versionCode = flutter.versionCode.toInt()  // Ensure conversion
        versionName = flutter.versionName
        multiDexEnabled = true  // Important for Firebase
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17  // Updated to Java 17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"  // Updated to match Java 17
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug") // Temporary for development
            isMinifyEnabled = true  // Enable code shrinking
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            isMinifyEnabled = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Import the Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:32.7.4"))

    // Firebase dependencies (automatically gets versions from BoM)
    // Firebase dependencies (automatically gets versions from BoM)
    implementation("com.google.firebase:firebase-analytics-ktx")
    implementation("com.google.firebase:firebase-auth-ktx")
    implementation("com.google.firebase:firebase-firestore-ktx")
    implementation("com.google.firebase:firebase-messaging-ktx")
    implementation ("com.google.firebase:firebase-auth")
// Optional for FCM
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") // ✅ ADD THIS

    // Add these if needed
    implementation("androidx.multidex:multidex:2.0.1") // For multidex support
    implementation("androidx.core:core-ktx:1.12.0") // Recommended for modern apps
}


