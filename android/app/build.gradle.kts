import org.gradle.api.tasks.Exec
import java.io.File

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.figmamake"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.figmamake"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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

// Debug 安装时自动 adb reverse，真机 127.0.0.1:3000 才能打到电脑后端。
val adbSdkHome = System.getenv("ANDROID_HOME")
    ?: System.getenv("ANDROID_SDK_ROOT")
    ?: "D:\\Software\\Android_Studio\\SDK"
val adbPath = "$adbSdkHome${File.separator}platform-tools${File.separator}adb.exe"

tasks.register<Exec>("adbReverseApiPort") {
    isIgnoreExitValue = true
    commandLine(adbPath, "reverse", "tcp:3000", "tcp:3000")
    onlyIf { File(adbPath).exists() }
}

afterEvaluate {
    tasks.matching { it.name.startsWith("install") }.configureEach {
        dependsOn("adbReverseApiPort")
    }
}
