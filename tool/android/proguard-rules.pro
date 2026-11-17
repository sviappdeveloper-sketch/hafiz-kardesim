# WorkManager / Room (home_widget, in_app_update): R8 veritabanı sınıflarını silmesin.
-keep class androidx.work.** { *; }
-keep class androidx.room.** { *; }
-keep class * extends androidx.room.RoomDatabase { <init>(); *; }
-keep class androidx.startup.** { *; }
-keep class * implements androidx.startup.Initializer { <init>(); }
-keep class es.antonborri.home_widget.** { *; }
-keep class com.sviapp.hafiz_kardesim.** { *; }
-dontwarn androidx.work.**
-dontwarn androidx.room.**

# flutter_local_notifications: zamanlanmış bildirimler Gson ile saklanır. R8 tür bilgisini
# silerse zonedSchedule "Missing type parameter" hatasıyla düşer ve ezan/cüz bildirimleri hiç
# planlanmaz (eklentinin belgelediği kurallar).
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-dontwarn com.google.gson.**
