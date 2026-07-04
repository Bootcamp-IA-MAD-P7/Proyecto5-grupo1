import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Keystore ──────────────────────────────────────────────────────────────────
//
// En LOCAL: lee key.properties (no commiteado en git).
// En CI/CD: el workflow escribe key.properties desde secrets antes de ejecutar
//           el build, así que el mismo código funciona en ambos entornos.
//
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

android {
    namespace = "com.jzelada.proyecto_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // ── Signing configs ───────────────────────────────────────────────────────
    signingConfigs {
        create("release") {
            keyAlias     = keyProperties["keyAlias"]     as String? ?: ""
            keyPassword  = keyProperties["keyPassword"]  as String? ?: ""
            storeFile    = keyProperties["storeFile"]?.let { file(it as String) }
            storePassword = keyProperties["storePassword"] as String? ?: ""
        }
    }

    defaultConfig {
        applicationId = "com.jzelada.proyecto_flutter"
        minSdk        = flutter.minSdkVersion
        targetSdk     = flutter.targetSdkVersion

        // versionCode y versionName vienen de pubspec.yaml vía Flutter Gradle Plugin.
        // En CI/CD el workflow sobreescribe versionCode con --build-number=$GITHUB_RUN_NUMBER.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Firma con el keystore fijo en lugar del debug key por defecto.
            signingConfig = signingConfigs.getByName("release")

            // Minificación deshabilitada por defecto para no romper plugins.
            // Habilita cuando tengas un proguard-rules.pro configurado.
            isMinifyEnabled = false
            isShrinkResources = false
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
