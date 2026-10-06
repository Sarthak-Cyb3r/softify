# Flutter Proguard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# AndroidX WorkManager & Room
# Prevents R8 from stripping WorkDatabase and Worker classes in background_downloader
-keep class androidx.work.** { *; }
-keep class androidx.work.impl.** { *; }
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class * extends androidx.work.Worker { *; }
-keep class * extends androidx.work.ListenableWorker { *; }
-keep class androidx.room.** { *; }
-keep class * extends androidx.room.RoomDatabase { *; }
-keep class androidx.startup.** { *; }

# Background Downloader
-keep class com.bbflight.background_downloader.** { *; }

# Audio Service & Just Audio
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.just_audio.** { *; }

# SQLite
-keep class org.sqlite.** { *; }
-keep class com.tekartik.sqflite.** { *; }

# Google Play Core
-dontwarn com.google.android.play.core.**
