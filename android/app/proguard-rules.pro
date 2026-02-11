# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Google ML Kit
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.vision.** { *; }

# Play Core (Deferred Components)
-dontwarn com.google.android.play.core.**

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.firebase.iid.**

# Prevent warnings for common missing classes in Flutter plugins
-dontwarn android.hardware.**
-dontwarn java.nio.file.**
-dontwarn javax.annotation.**
-dontwarn org.codehaus.mojo.animal_sniffer.IgnoreJRERequirement

# Gson (often used by ML dependencies)
-keep class com.google.gson.** { *; }

# ML Kit specific for Object Detection
-keep class com.google.mlkit.vision.objects.** { *; }

# WebView
-keep class android.webkit.** { *; }
-dontwarn android.webkit.**
