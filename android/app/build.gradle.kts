plugins {
    id("com.android.application")
    id("com.google.gms.google-services") // Firebase
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

android {
    namespace = "com.example.parking_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.parking_app"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ---------------------------------------------------------------------
    // 🛡️ BULLETPROOF KEYSTORE LOADING (NO NULLS ALLOWED)
    // ---------------------------------------------------------------------

    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")

    if (!keystorePropertiesFile.exists()) {
        throw GradleException("FATAL ERROR: key.properties NOT found at android/key.properties")
    }

    keystoreProperties.load(FileInputStream(keystorePropertiesFile))

    val keyAliasValue = keystoreProperties["keyAlias"]
        ?: throw GradleException("Missing keyAlias in key.properties")

    val keyPasswordValue = keystoreProperties["keyPassword"]
        ?: throw GradleException("Missing keyPassword in key.properties")

    val storePasswordValue = keystoreProperties["storePassword"]
        ?: throw GradleException("Missing storePassword in key.properties")

    val storeFileName = keystoreProperties["storeFile"]
        ?: throw GradleException("Missing storeFile in key.properties")

   val storeFilePath = file(storeFileName)

    if (!storeFilePath.exists()) {
        throw GradleException("Keystore file NOT FOUND at: android/app/$storeFileName")
    }

    signingConfigs {
        create("release") {
            keyAlias = keyAliasValue.toString()
            keyPassword = keyPasswordValue.toString()
            storePassword = storePasswordValue.toString()
            storeFile = storeFilePath
        }
    }

    // ---------------------------------------------------------------------

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
