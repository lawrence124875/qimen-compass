// Wear OS 手錶羅盤（HANDOFF §12 1.3.0）。CI 由 scripts/patch_wear.sh 複製到 android/wear/，
// 並把 __PLUGINS__ 換成與 app 模組相同的 Android／Kotlin 外掛（不含 Flutter 外掛）。
import java.io.FileInputStream
import java.util.Properties

plugins {
__PLUGINS__
}

val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(FileInputStream(f))
}

android {
    namespace = "com.lclab.qimen_compass.wear"
    compileSdk = 36

    defaultConfig {
        // 必須與手機 App 相同（Data Layer 只連同套件名稱、同簽章的 App）；私人版以 -PqmAppId 傳入
        applicationId = (project.findProperty("qmAppId") as String?) ?: "com.lclab.qimen"
        minSdk = 30
        targetSdk = 36
        versionCode = ((project.findProperty("qmVersionCode") as String?) ?: "1").toInt()
        versionName = (project.findProperty("qmVersionName") as String?) ?: "1.0"
    }

    signingConfigs {
        if (keystoreProperties.containsKey("storeFile")) {
            create("release") {
                storeFile = rootProject.file("app/" + keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }

    lint {
        checkReleaseBuilds = false
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

// Java 與 Kotlin 目標版本要一致（否則 Kotlin 預設用 JDK 版本 25，與 Java 不符）
tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    implementation("com.google.android.gms:play-services-wearable:19.0.0")
}
