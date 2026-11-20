plugins {
    id("com.android.application") version "8.11.1"
    id("org.jetbrains.kotlin.android") version "2.2.20"
}

android {
    namespace = "com.opscode.mobile"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.opscode.mobile"
        minSdk = 26
        targetSdk = 35
        versionCode = 18
        versionName = "0.1.17"
        val firebase = mapOf(
            "google_app_id" to providers.environmentVariable("OPSCODE_ANDROID_FIREBASE_APP_ID").orNull,
            "google_api_key" to providers.environmentVariable("OPSCODE_ANDROID_FIREBASE_API_KEY").orNull,
            "gcm_defaultSenderId" to providers.environmentVariable("OPSCODE_ANDROID_FIREBASE_SENDER_ID").orNull,
            "project_id" to providers.environmentVariable("OPSCODE_ANDROID_FIREBASE_PROJECT_ID").orNull,
        )
        if (firebase.values.any { it != null }) {
            firebase.forEach { (name, value) -> resValue("string", name, checkNotNull(value) { "Missing Firebase resource $name" }) }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    testOptions {
        unitTests.isIncludeAndroidResources = true
    }

    // Optional signing for the private preview. Keep the keystore and passwords outside the repo.
    val previewKeystore = providers.environmentVariable("OPSCODE_ANDROID_KEYSTORE").orNull
    if (previewKeystore != null) {
        signingConfigs.create("privatePreview") {
            storeFile = file(previewKeystore)
            storePassword = providers.environmentVariable("OPSCODE_ANDROID_STORE_PASSWORD").get()
            keyAlias = providers.environmentVariable("OPSCODE_ANDROID_KEY_ALIAS").get()
            keyPassword = providers.environmentVariable("OPSCODE_ANDROID_KEY_PASSWORD").get()
        }
        buildTypes.getByName("release").signingConfig = signingConfigs.getByName("privatePreview")
    }
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("androidx.activity:activity:1.13.0")
    implementation("androidx.camera:camera-camera2:1.6.1")
    implementation("androidx.camera:camera-lifecycle:1.6.1")
    implementation("androidx.camera:camera-view:1.6.1")
    implementation("com.google.mlkit:barcode-scanning:17.3.0")
    implementation("com.google.firebase:firebase-messaging:24.1.2")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.14.1")
}
