import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Il keystore di release non sta in git: il percorso e la password
// arrivano da android/key.properties, che e' ignorato. Senza quel file
// si compila con la chiave di debug, come prima.
val chiaviRelease = Properties()
val fileChiavi = rootProject.file("key.properties")
if (fileChiavi.exists()) {
    chiaviRelease.load(FileInputStream(fileChiavi))
}

android {
    namespace = "me.ismail.nutriapp"
    
    compileSdk = 36 // <-- CAMBIATO DA 34 A 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "me.ismail.nutriapp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion // <-- CAMBIATO DA flutter.minSdkVersion A 21 (Serve per il Barcode Scanner!)
        targetSdk = 36 // <-- CAMBIATO DA 34 A 36
        versionCode = flutter.versionCode.toInt()
        versionName = flutter.versionName
    }

    signingConfigs {
        if (fileChiavi.exists()) {
            create("release") {
                storeFile = file(chiaviRelease["storeFile"] as String)
                storePassword = chiaviRelease["storePassword"] as String
                keyAlias = chiaviRelease["keyAlias"] as String
                keyPassword = chiaviRelease["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // La chiave di release serve anche a Google Sign-In: la sua
            // SHA-1 e' quella registrata su Firebase. Con la chiave di
            // debug l'accesso con Google viene rifiutato.
            signingConfig = if (fileChiavi.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.9.0"))
    implementation("com.google.firebase:firebase-analytics")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
