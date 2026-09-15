pluginManagement {
    val flutterSdkPath =
        run {
            // Prefer the project-bundled SDK (ASCII path). Avoid OneDrive/Masaüstü
            // paths that get mojibake and break includeBuild on Windows.
            val bundled = rootDir.resolve("../.tools/flutter").canonicalFile
            if (bundled.resolve("packages/flutter_tools/gradle").isDirectory) {
                return@run bundled.invariantSeparatorsPath
            }
            val properties = java.util.Properties()
            val localPropertiesFile = file("local.properties")
            if (localPropertiesFile.exists()) {
                localPropertiesFile.inputStream().use { properties.load(it) }
            }
            val configured = properties.getProperty("flutter.sdk") ?: System.getenv("FLUTTER_ROOT")
            require(configured != null) {
                "flutter.sdk not set in local.properties nor FLUTTER_ROOT environment variable"
            }
            configured
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
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

include(":app")
