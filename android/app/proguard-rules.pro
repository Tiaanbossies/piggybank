# R8/ProGuard keep rules for the release build (isMinifyEnabled/isShrinkResources, see
# build.gradle.kts). Flutter's own Gradle plugin already contributes consumer rules for the
# io.flutter.* embedding classes automatically — these cover the plugins in pubspec.yaml that
# touch platform APIs via reflection or JNI, where R8's static analysis can't see the real
# call site and would otherwise strip a class/method a plugin needs at runtime.

# local_auth: androidx.biometric's BiometricPrompt callback classes are invoked via reflection
# from the platform BiometricManager, not a visible Kotlin/Java call site.
-keep class androidx.biometric.** { *; }

# flutter_secure_storage: AndroidX Security Crypto's key generation/keystore classes.
-keep class androidx.security.crypto.** { *; }

# dio: uses okhttp3 internally, which ships its own consumer rules, but keep response/request
# model reflection-safe in case any interceptor introspects them.
-dontwarn okhttp3.**
-dontwarn okio.**

# file_picker / image_picker: platform-channel result classes are constructed by the Android
# embedding via reflection from the plugin's own package.
-keep class io.flutter.plugins.file_picker.** { *; }
-keep class io.flutter.plugins.imagepicker.** { *; }

# Keep line numbers in stack traces for crash reports, without keeping full source file names.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
