# Keep Flutter & AppWidgetProviders
-keep class io.flutter.** { *; }
-keep class id.tafseer.app.** { *; }
-keep class es.antonborri.home_widget.** { *; }
-keep public class * extends android.appwidget.AppWidgetProvider { *; }

# WebView JS bridge
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }

# Supabase / OkHttp / Gson reflection
-keep class io.github.jan.supabase.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# Flutter deferred components reference Play Core — not used, suppress missing class errors
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn com.google.android.play.core.**
