group = "uz.vis.sdk.flutter"
version = "1.0.2"

// Native SDK version this plugin is built and tested against.
val visSdkAndroidVersion: String =
    (rootProject.findProperty("visSdkAndroidVersion") as String?) ?: "1.0.2"

buildscript {
    val kotlinVersion = "2.3.20"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.0.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

// The native SDK (uz.vis:vis-sdk-android) is on Maven Central, which Flutter
// apps already list. For internal testing before a release, point the build at
// a local repository: `visSdkMavenRepo=/abs/path` in android/gradle.properties.
(rootProject.findProperty("visSdkMavenRepo") as String?)?.let { localRepo ->
    rootProject.allprojects {
        repositories {
            maven { url = uri(localRepo) }
        }
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "uz.vis.sdk.flutter"

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
        // The native SDK requires Android 7.0.
        minSdk = 24
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("uz.vis:vis-sdk-android:$visSdkAndroidVersion")
}
