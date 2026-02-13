# Flutter and plugin keep rules for release builds with minification.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.patrimonium.** { *; }

# Suppress Play Core split-install warnings (not used, referenced by Flutter engine)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
