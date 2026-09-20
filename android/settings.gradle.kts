pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    // 2.1.0 -> 2.2.20 il 22/08: la CI di GitHub Actions usa Flutter stable
    // 3.47.1, che richiede Kotlin >=2.2.20 per il proprio Gradle plugin
    // ("Your project's Kotlin version (2.1.0) is lower than Flutter's
    // minimum supported version of 2.2.20").
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
