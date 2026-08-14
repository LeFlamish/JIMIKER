import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 업로드 키 정보. 저장소에 올리지 않는 android/key.properties에서 읽는다.
//
// 플레이스토어는 디버그 키로 서명된 파일을 받지 않는다. 이 파일을 만들어두면
// 릴리스 빌드가 자동으로 그 키로 서명된다. 없으면(개발 중이거나 남의 PC라면)
// 예전처럼 디버그 키를 쓰므로 빌드가 깨지지 않는다.
//
// 만드는 방법은 docs/play-store.md 참고.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasUploadKey = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.jimiker.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications가 요구한다.
        // (알림 예약 기능을 옛 안드로이드에서도 쓰기 위해 desugaring을 쓴다)
        isCoreLibraryDesugaringEnabled = true
        // 이 플러그인이 Java 17로 빌드돼 있어 앱도 17로 맞춘다.
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // 스토어에 한 번 올리면 영원히 못 바꾸는 값이다. 손대지 말 것.
        // 바꿔야 한다면 Firebase 앱 등록과 Maps 키 제한도 같이 손봐야 한다.
        applicationId = "com.jimiker.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // desugaring으로 메서드 수가 늘어나 64K 한도를 넘을 수 있다.
        multiDexEnabled = true
    }

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // key.properties가 있으면 업로드 키로, 없으면 디버그 키로 서명한다.
            // 스토어에 올릴 파일은 반드시 업로드 키로 서명돼야 한다.
            signingConfig = if (hasUploadKey) {
                signingConfigs.getByName("upload")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
