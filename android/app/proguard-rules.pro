# Flutter and plugin ProGuard / R8 rules for Pantry Pal

# Keep Flutter local notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Keep SQLite bindings
-keep class com.tekartik.sqflite.** { *; }

# Keep ML Kit Text Recognition
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.vision.** { *; }
-dontwarn com.google.mlkit.vision.text.**

# Keep Mobile Scanner
-keep class dev.steenbakker.mobile_scanner.** { *; }

# Keep Flutter Engine & Core
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-dontwarn io.flutter.embedding.**
