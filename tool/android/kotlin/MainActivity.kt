package com.hatimkardesim.hatim_kardesim

import android.content.Context
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.SystemClock
import android.view.Surface
import android.view.WindowManager
import java.util.concurrent.Executor
import com.google.android.gms.location.DeviceOrientation
import com.google.android.gms.location.DeviceOrientationListener
import com.google.android.gms.location.DeviceOrientationRequest
import com.google.android.gms.location.FusedOrientationProviderClient
import com.google.android.gms.location.LocationServices
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import kotlin.math.atan2
import kotlin.math.hypot

/**
 * Kıble pusulası için yön kaynağı (EventChannel "hatim/kible").
 *
 * - Mutlak yön ivme ölçer + manyetik alan algılayıcısından hesaplanır; jiroskop varsa onunla
 *   birleştirilip sabitlenir. İkisi yoksa döndürme vektörü algılayıcısı kullanılır.
 * - Yön, telefonun üst kenarının baktığı yöndür; telefon dik tutulursa (ekran size dönük) arka
 *   kameranın baktığı yöne geçilir. Böylece telefon eğilince yön zıplamaz (gimbal kilidi yok).
 * - Ekranın döndürülmesi hesaba katılır.
 * - Manyetik sapma, seçilen ilin koordinatına göre GeomagneticField ile hesaplanır; çıkan değer
 *   gerçek (coğrafi) kuzeye göredir.
 * Birincil kaynak Google Play hizmetlerinin birleşik yön servisidir (Fused Orientation
 * Provider; Google Haritalar'ın yön konisinin kullandığı servis: ivme + jiroskop + manyetik,
 * kendi kalibrasyonu ve manyetik sapma düzeltmesiyle, coğrafi kuzeye göre). Play hizmetleri
 * yoksa ya da yanıt vermezse telefonun algılayıcılarıyla yapılan hesaba düşülür.
 * Olay: [yön (derece), doğruluk (0-3), sapma (derece), kaynak ("google"/"sensor"), hata payı (derece)]
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "hatim/kible")
            .setStreamHandler(KibleStream(applicationContext, this))
        // Pil kısıtlaması: ekran kapalıyken ezan bildiriminin zamanında gelmesi için.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hatim/pil").setMethodCallHandler { call, result ->
            when (call.method) {
                "kisitsizMi" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                    result.success(Build.VERSION.SDK_INT < 23 || pm.isIgnoringBatteryOptimizations(packageName))
                }
                "ayariAc" -> {
                    val tries = listOf(
                        Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")),
                    )
                    var ok = false
                    for (i in tries) {
                        try {
                            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(i)
                            ok = true
                            break
                        } catch (_: Throwable) {}
                    }
                    result.success(ok)
                }
                "uygulamaAyari" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(true)
                    } catch (_: Throwable) { result.success(false) }
                }
                else -> result.notImplemented()
            }
        }
    }
}

private class KibleStream(private val ctx: Context, private val activity: FlutterActivity) :
    EventChannel.StreamHandler, SensorEventListener {

    private val sm = ctx.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private var sink: EventChannel.EventSink? = null
    private var declination = 0f
    private var accuracy = SensorManager.SENSOR_STATUS_ACCURACY_MEDIUM
    private var magAccuracy = -1
    private var lastEmit = 0L

    // Manyetik (mutlak) yön: ivme + manyetik alan
    private val rotMag = FloatArray(9)
    private var grav: FloatArray? = null
    private var geo: FloatArray? = null
    private var magAz: Float? = null
    // Jiroskoplu göreli yön (manyetik alandan etkilenmez, titremez ama sıfırı rastgeledir)
    private val rotGame = FloatArray(9)
    private var hasGame = false
    private var offset: Float? = null
    private var upright = false

    // Google birleşik yön servisi
    private var fop: FusedOrientationProviderClient? = null
    private var fopListener: DeviceOrientationListener? = null
    private var fopGot = false
    private var sensorsOn = false
    private val main = Handler(Looper.getMainLooper())
    private val fopTimeout = Runnable { if (!fopGot) { stopFop(); startSensors() } }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        val args = arguments as? Map<*, *>
        val lat = (args?.get("lat") as? Number)?.toFloat()
        val lon = (args?.get("lon") as? Number)?.toFloat()
        declination = if (lat != null && lon != null) {
            GeomagneticField(lat, lon, 0f, System.currentTimeMillis()).declination
        } else 0f

        fopGot = false
        try {
            val client = LocationServices.getFusedOrientationProviderClient(ctx)
            val l = DeviceOrientationListener { o -> onFop(o) }
            fop = client
            fopListener = l
            val req = DeviceOrientationRequest.Builder(DeviceOrientationRequest.OUTPUT_PERIOD_DEFAULT).build()
            client.requestOrientationUpdates(req, Executor { r -> main.post(r) }, l)
                .addOnFailureListener { main.post { stopFop(); startSensors() } }
            main.postDelayed(fopTimeout, 2500)
        } catch (_: Throwable) {
            stopFop()
            startSensors()
        }
    }

    private fun stopFop() {
        val c = fop; val l = fopListener
        if (c != null && l != null) try { c.removeOrientationUpdates(l) } catch (_: Throwable) {}
        fop = null
        fopListener = null
        main.removeCallbacks(fopTimeout)
    }

    private val rotFop = FloatArray(9)

    private fun onFop(o: DeviceOrientation) {
        if (sensorsOn) return
        fopGot = true
        val now = SystemClock.elapsedRealtime()
        if (now - lastEmit < 33) return
        lastEmit = now
        // Tutum: cihaz → doğu-kuzey-yukarı (kuzey: sapma biliniyorsa coğrafi kuzey).
        SensorManager.getRotationMatrixFromVector(rotFop, o.attitude)
        updateUpright(rotFop)
        var az = yaw(rotFop) + displayRotation()
        az = ((az % 360f) + 360f) % 360f
        val err = o.headingErrorDegrees
        val acc = when {
            err >= 179f -> 0
            err <= 12f -> 3
            err <= 25f -> 2
            err <= 45f -> 1
            else -> 0
        }
        sink?.success(listOf(az.toDouble(), acc, declination.toDouble(), "google", err.toDouble()))
    }

    private fun startSensors() {
        if (sensorsOn || sink == null) return
        sensorsOn = true
        // Mutlak yön ivme + manyetik alandan (pusula uygulamalarının yaptığı gibi); jiroskop varsa
        // yön jiroskopun göreli yönüyle birleştirilir (tamamlayıcı süzgeç): kısa süreli manyetik
        // parazit ve titreme jiroskopla bastırılır, uzun vadede yön manyetik kuzeye oturur.
        val acc = sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        val mag = sm.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
        if (acc != null && mag != null) {
            sm.registerListener(this, acc, SensorManager.SENSOR_DELAY_GAME)
            sm.registerListener(this, mag, SensorManager.SENSOR_DELAY_GAME)
            sm.getDefaultSensor(Sensor.TYPE_GAME_ROTATION_VECTOR)?.let {
                sm.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
            }
        } else {
            val rv = sm.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
                ?: sm.getDefaultSensor(Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR)
            if (rv == null) {
                sink?.error("no_sensor", "Pusula algılayıcısı yok", null)
                return
            }
            sm.registerListener(this, rv, SensorManager.SENSOR_DELAY_GAME)
        }
    }

    override fun onCancel(arguments: Any?) {
        stopFop()
        sensorsOn = false
        fopGot = false
        sm.unregisterListener(this)
        sink = null
        grav = null
        geo = null
        magAz = null
        hasGame = false
        offset = null
    }

    override fun onAccuracyChanged(sensor: Sensor?, acc: Int) {
        when (sensor?.type) {
            Sensor.TYPE_MAGNETIC_FIELD -> magAccuracy = acc
            Sensor.TYPE_ROTATION_VECTOR, Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR -> accuracy = acc
        }
    }

    override fun onSensorChanged(e: SensorEvent) {
        when (e.sensor.type) {
            Sensor.TYPE_GAME_ROTATION_VECTOR -> {
                SensorManager.getRotationMatrixFromVector(rotGame, e.values)
                hasGame = true
                emit()
            }
            Sensor.TYPE_ROTATION_VECTOR, Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR -> {
                SensorManager.getRotationMatrixFromVector(rotMag, e.values)
                updateUpright(rotMag)
                magAz = yaw(rotMag) + declination
                emit()
            }
            Sensor.TYPE_ACCELEROMETER -> {
                grav = lowPass(e.values, grav, 0.15f)
                computeMag()
            }
            Sensor.TYPE_MAGNETIC_FIELD -> {
                magAccuracy = e.accuracy
                geo = lowPass(e.values, geo, if (hasGame) 0.25f else 0.12f)
                computeMag()
            }
        }
    }

    private fun computeMag() {
        val g = grav ?: return
        val m = geo ?: return
        if (!SensorManager.getRotationMatrix(rotMag, null, g, m)) return
        if (!hasGame) updateUpright(rotMag)
        magAz = yaw(rotMag) + declination
        if (!hasGame) emit()
    }

    private fun lowPass(v: FloatArray, prev: FloatArray?, k: Float): FloatArray {
        if (prev == null) return v.copyOf(3)
        for (i in 0..2) prev[i] = prev[i] + k * (v[i] - prev[i])
        return prev
    }

    /** Telefon yatıkken üst kenar, dikken (ekran size dönük) arka kamera yönü kullanılır. */
    private fun updateUpright(r: FloatArray) {
        val topLen = hypot(r[1], r[4])
        val backLen = hypot(r[2], r[5])
        if (upright && topLen > backLen * 1.3f) upright = false
        else if (!upright && backLen > topLen * 1.3f) upright = true
    }

    /** r: cihaz → dünya (x: doğu, y: kuzey, z: yukarı). Sütun 1 = üst kenar, -sütun 2 = arka kamera. */
    private fun yaw(r: FloatArray): Float {
        val e = if (upright) -r[2] else r[1]
        val n = if (upright) -r[5] else r[4]
        return Math.toDegrees(atan2(e.toDouble(), n.toDouble())).toFloat()
    }

    private fun wrap(a: Float): Float = ((a % 360f) + 540f) % 360f - 180f

    private fun emit() {
        val now = SystemClock.elapsedRealtime()
        if (now - lastEmit < 33) return // en fazla ~30 olay/sn
        val m = magAz ?: return
        lastEmit = now
        var az: Float
        if (hasGame) {
            updateUpright(rotGame)
            val g = yaw(rotGame)
            val target = wrap(m - g)
            val o = offset
            // Jiroskop yönü ile manyetik yön arasındaki fark yavaşça izlenir (~1-2 sn).
            offset = if (o == null || kotlin.math.abs(wrap(target - o)) > 45f) target else o + wrap(target - o) * 0.03f
            az = g + offset!!
        } else {
            az = m
        }
        az += displayRotation()
        az = ((az % 360f) + 360f) % 360f
        val acc = if (magAccuracy >= 0) magAccuracy else accuracy
        sink?.success(listOf(az.toDouble(), acc, declination.toDouble(), "sensor", -1.0))
    }

    @Suppress("DEPRECATION")
    private fun displayRotation(): Float {
        val r = try {
            if (Build.VERSION.SDK_INT >= 30) activity.display?.rotation ?: Surface.ROTATION_0
            else (ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager).defaultDisplay.rotation
        } catch (_: Throwable) { Surface.ROTATION_0 }
        return when (r) {
            Surface.ROTATION_90 -> 90f
            Surface.ROTATION_180 -> 180f
            Surface.ROTATION_270 -> 270f
            else -> 0f
        }
    }
}
