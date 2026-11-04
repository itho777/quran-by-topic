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
