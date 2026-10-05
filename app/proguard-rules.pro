# RouteFlow Production ProGuard / R8 Rules

# Preserve Kotlin / Reflection annotations & signatures
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod,Exceptions

# ==============================================================================
# Kotlinx Serialization Rules
# ==============================================================================
-keepclassmembers class * {
    @kotlinx.serialization.Serializable <fields>;
}
-keepclassmembers class * {
    @kotlinx.serialization.SerialName <fields>;
}
-keepclassmembers class * implements kotlinx.serialization.KSerializer {
    <methods>;
}
-keepclassmembers class * extends kotlinx.serialization.internal.GeneratedSerializer {
    <methods>;
}
-keepclasseswithmembers class * {
    companion object;
}
-keepclassmembers class **$Companion {
    public kotlinx.serialization.KSerializer serializer(...);
}

# Keep RouteFlow Network DTOs and Domain Models
-keep class com.routeflow.app.core.network.dto.** { *; }
-keep class com.routeflow.app.domain.model.** { *; }

# ==============================================================================
# Retrofit & OkHttp Rules
# ==============================================================================
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }
-keepclasseswithmembers interface * {
    @retrofit2.http.* <methods>;
}
-keep interface com.routeflow.app.core.network.api.** { *; }

# ==============================================================================
# Room Persistence Rules
# ==============================================================================
-keep class * extends androidx.room.RoomDatabase
-keep @androidx.room.Entity class * { *; }
-keep @androidx.room.Dao interface * { *; }
-keep class * extends androidx.room.RoomOpenHelper
-keep class com.routeflow.app.data.local.entity.** { *; }
-keep class com.routeflow.app.data.local.dao.** { *; }
-dontwarn androidx.room.paging.**

# ==============================================================================
# Hilt / Dagger Rules
# ==============================================================================
-dontwarn dagger.hilt.**
-keep class * extends dagger.hilt.android.internal.managers.ViewComponentManager$FragmentContextWrapper

# ==============================================================================
# AndroidX Security / EncryptedSharedPreferences Rules
# ==============================================================================
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**
-dontwarn com.google.crypto.tink.**
-dontwarn com.google.errorprone.annotations.**
