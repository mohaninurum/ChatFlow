# Google ML Kit Text Recognition rules
-keep class com.google.mlkit.** { *; }
-keep interface com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Vision text and internal bindings
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-keep class com.google.mlkit.vision.text.latin.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_** { *; }
-keep class com.google.android.gms.vision.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-dontwarn com.google.android.gms.**

# Firebase Component Registrars used by ML Kit for runtime dependency injection
-keep class * implements com.google.firebase.components.ComponentRegistrar { *; }

# Suppress missing Play Core warnings caused by Flutter engine's optional deferred components
-dontwarn com.google.android.play.core.**
