package com.hatimkardesim.hatim_kardesim

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.EventChannel
import java.lang.reflect.InvocationHandler
import java.lang.reflect.Proxy
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * WebRTC yerel mikrofon izinin ham sesini (flutter_webrtc LocalAudioTrack.addSink) alır,
 * tek kanala ve 16 kHz'e indirip ~100 ms'lik 16 bit PCM parçaları hâlinde Dart'a gönderir.
 *
 * flutter_webrtc'nin sınıfları yansıma (reflection) ile çağrılır: WebRTC kütüphanesi eklentide
 * "implementation" olarak durduğu için uygulamanın derlemesinde görünmez; böylece eklenti sürümü
 * değişse de derleme bozulmaz. Bir şey bulunamazsa false döner, Dart tarafı ses tanımasız sürer.
 */
class WebrtcSesKoprusu : EventChannel.StreamHandler {
    private val ana = Handler(Looper.getMainLooper())
    private var olay: EventChannel.EventSink? = null
    private var iz: Any? = null
    private var sink: Any? = null
    private var sinkSinifi: Class<*>? = null

    // Örnek indirme durumu
    private var oran = 1.0
    private var konum = 0.0
    private var tampon = ShortArray(3200)
    private var dolu = 0

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { olay = events }
    override fun onCancel(arguments: Any?) { olay = null }

    fun dinle(izId: String): Boolean {
        birak()
        return try {
            val eklentiSinifi = Class.forName("com.cloudwebrtc.webrtc.FlutterWebRTCPlugin")
            val eklenti = eklentiSinifi.getField("sharedSingleton").get(null) ?: return false
            val t = eklentiSinifi.getMethod("getLocalTrack", String::class.java).invoke(eklenti, izId) ?: return false
            val ss = Class.forName("org.webrtc.AudioTrackSink")
            val h = InvocationHandler { _, m, a ->
                if (m.name == "onData" && a != null && a.size >= 4) {
                    try {
                        veri(a[0] as ByteBuffer, a[1] as Int, a[2] as Int, a[3] as Int)
                    } catch (e: Throwable) {
                        Log.w("WebrtcSes", "onData: $e")
                    }
                }
                when (m.name) {
                    "hashCode" -> System.identityHashCode(this)
                    "equals" -> a?.getOrNull(0) === this
                    "toString" -> "WebrtcSesKoprusu"
                    else -> null
                }
            }
            val s = Proxy.newProxyInstance(ss.classLoader, arrayOf(ss), h)
            t.javaClass.getMethod("addSink", ss).invoke(t, s)
            iz = t
            sink = s
            sinkSinifi = ss
            konum = 0.0
            dolu = 0
            true
        } catch (e: Throwable) {
            Log.w("WebrtcSes", "dinle: $e")
            false
        }
    }

    fun birak() {
        val t = iz
        val s = sink
        val ss = sinkSinifi
        iz = null
        sink = null
        if (t != null && s != null && ss != null) {
            try { t.javaClass.getMethod("removeSink", ss).invoke(t, s) } catch (_: Throwable) {}
        }
        dolu = 0
    }

    /** Ses iş parçacığında çağrılır. */
    private fun veri(b: ByteBuffer, bit: Int, hz: Int, kanal: Int) {
        if (bit != 16 || hz <= 0 || kanal <= 0) return
        val sb = b.duplicate().order(ByteOrder.LITTLE_ENDIAN)
        sb.rewind()
        val n = sb.remaining() / 2 / kanal
        oran = hz / 16000.0
        // Tek kanala indir, sonra 16 kHz'e (aradaki örneklerin ortalaması: basit alçak geçiren).
        var i = 0
        while (i < n) {
            var t = 0
            for (k in 0 until kanal) t += sb.getShort((i * kanal + k) * 2).toInt()
            val v = t / kanal
            if (oran <= 1.0) {
                ekle(v)
            } else {
                konum += 1.0
                topla += v
                adet++
                if (konum >= oran) {
                    konum -= oran
                    ekle(topla / adet)
                    topla = 0
                    adet = 0
                }
            }
            i++
        }
    }

    private var topla = 0
    private var adet = 0

    private fun ekle(v: Int) {
        tampon[dolu++] = v.coerceIn(-32768, 32767).toShort()
        if (dolu >= 1600) {
            val out = ByteArray(dolu * 2)
            val bb = ByteBuffer.wrap(out).order(ByteOrder.LITTLE_ENDIAN)
            for (k in 0 until dolu) bb.putShort(tampon[k])
            dolu = 0
            ana.post { olay?.success(out) }
        }
    }
}
