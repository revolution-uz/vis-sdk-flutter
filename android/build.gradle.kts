group = "uz.vis.sdk.flutter"
version = "1.0.0"

// Native SDK version this plugin is built and tested against.
val visSdkAndroidVersion: String =
    (rootProject.findProperty("visSdkAndroidVersion") as String?) ?: "1.0.0"

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

// The native Vis Android SDK is published on JitPack. Add the repository to
// the whole build so host apps need no manual step. (Builds that forbid
// project repositories must add it in settings.gradle.kts themselves.)
rootProject.allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
        // Optional local repository for internal testing before a release:
        // `visSdkMavenRepo=/abs/path` in the app's android/gradle.properties.
        (rootProject.findProperty("visSdkMavenRepo") as String?)?.let { maven { url = uri(it) } }
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
        // The native SDK requires Android 8.0.
        minSdk = 26
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("com.github.revolution-uz:vis-sdk-android:$visSdkAndroidVersion")
}
