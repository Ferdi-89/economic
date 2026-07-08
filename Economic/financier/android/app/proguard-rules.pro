# Flutter specific
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Supabase
-keep class com.supabase.** { *; }

# Keep freezed models
-keep class com.financier.** { *; }

# Ignore warnings for Play Core libraries
-dontwarn com.google.android.play.core.**
