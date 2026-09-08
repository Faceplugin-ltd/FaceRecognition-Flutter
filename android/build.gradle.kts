group = "com.faceplugin.face_recognition_sdk"
version = "1.0-SNAPSHOT"

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // AGP only — do not apply Kotlin Gradle Plugin (Built-in Kotlin / AGP 9+).
        classpath("com.android.tools.build:gradle:8.9.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "com.faceplugin.face_recognition_sdk"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
    }
}

// Built-in Kotlin (AGP 9+ / Flutter consumer) — no org.jetbrains.kotlin.android apply.
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("androidx.exifinterface:exifinterface:1.3.7")

    // AGP forbids implementation(files("…aar")) on an Android library (plugin) module —
    // :face_recognition_sdk:bundleDebugAar would fail. Always consume the runtime via a
    // flat :libfacesdk artifact module (see example/android/libfacesdk).
    val libfacesdk = findProject(":libfacesdk")
    val bundledAar = file("libs/facerecognitionsdk.aar")
    when {
        libfacesdk != null -> implementation(project(":libfacesdk"))
        bundledAar.exists() ->
            throw GradleException(
                """
                Found android/libs/facerecognitionsdk.aar, but Flutter/AGP cannot link a
                local .aar with implementation(files(…)) from a plugin library module.

                Demo app: put the AAR in example/android/libfacesdk/facerecognitionsdk.aar
                (settings.gradle.kts already includes :libfacesdk).

                Your own app: copy example/android/libfacesdk/ into your Android project,
                place facerecognitionsdk.aar there, and add include(":libfacesdk") to
                settings.gradle — then depend on this plugin as usual.
                """.trimIndent()
            )
        else ->
            throw GradleException(
                """
                Missing Face Recognition Android runtime (facerecognitionsdk.aar).

                Demo: copy from Drive → example/android/libfacesdk/facerecognitionsdk.aar
                Own app: use a :libfacesdk module (see example/android/libfacesdk/README.md).
                """.trimIndent()
            )
    }
}
