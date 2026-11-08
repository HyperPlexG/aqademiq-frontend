package com.aqademiq.aqademiq

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.PowerManager
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.HapticFeedbackConstants
import android.view.View
import io.flutter.plugin.common.MethodChannel

/**
 * Plays the haptic lexicon (`lib/services/haptics/haptic_lexicon.dart`) on
 * the phone's vibrator.
 *
 * Dart sends one pattern per call — `{id, prims, constant, wave, preferWave,
 * waveOnly, fallback, faceDownAlt}` — and this picks the best rendering the
 * phone can play (spec §6, "Android"):
 *
 *  1. the amplitude **waveform** first, for the patterns that are a shape over
 *     time (the thaw breath, the drill's rumble, wind-down), where the motor
 *     can vary its strength;
 *  2. **composition primitives** where the phone supports every one the
 *     pattern uses (`areAllPrimitivesSupported`), with the spec's stand-in
 *     where it names one ("LOW_TICK if THUD unsupported");
 *  3. the pattern's **`performHapticFeedback` constant** or predefined effect
 *     — tuned by the phone maker, and better than a waveform on a budget
 *     phone with no primitives;
 *  4. the **waveform** on any motor with amplitude control;
 *  5. a plain on/off rhythm, or nothing for a pattern that is waveform-only
 *     (an on/off buzz for ten seconds is the opposite of a breath).
 *
 * Every vibration is tagged as touch feedback, so the phone's own touch
 * vibration setting applies (performHapticFeedback honours it by itself).
 */
object HapticsBridge {
    const val CHANNEL = "aqademiq/haptics"

    private var vibrator: Vibrator? = null
    private var powerManager: PowerManager? = null
    private var sensorManager: SensorManager? = null
    private var viewProvider: () -> View? = { null }

    /** The pattern playing now — Android plays one vibration at a time. */
    private var currentId = 0

    @Volatile private var faceDown = false
    private var faceDownListener: SensorEventListener? = null

    fun attach(channel: MethodChannel, context: Context, view: () -> View?) {
        vibrator = resolveVibrator(context)
        powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        viewProvider = view
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    @Suppress("UNCHECKED_CAST")
                    play(call.arguments as? Map<String, Any?> ?: emptyMap())
                    result.success(null)
                }
                "stop" -> {
                    stop(
                        call.argument<Int>("id") ?: 0,
                        call.argument<Int>("fadeMs") ?: 0,
                        call.argument<Double>("level") ?: 0.0,
                    )
                    result.success(null)
                }
                "deviceState" -> result.success(
                    mapOf("lowPower" to (powerManager?.isPowerSaveMode == true), "hot" to isHot()),
                )
                "watchFaceDown" -> {
                    watchFaceDown(call.argument<Boolean>("on") == true)
                    result.success(null)
                }
                "capabilities" -> result.success(
                    mapOf(
                        "hasVibrator" to (vibrator?.hasVibrator() ?: false),
                        "amplitudeControl" to hasAmplitudeControl(),
                    ),
                )
                else -> result.notImplemented()
            }
        }
    }

    fun detach() {
        watchFaceDown(false)
        vibrator = null
        viewProvider = { null }
    }

    private fun resolveVibrator(context: Context): Vibrator? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }

    private fun hasAmplitudeControl(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && vibrator?.hasAmplitudeControl() == true

    /** A phone running hot drops Full down to Essential (spec §3). */
    private fun isHot(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            (powerManager?.currentThermalStatus ?: 0) >= PowerManager.THERMAL_STATUS_SEVERE

    // ─── play ──────────────────────────────────────────────────────────────

    private fun play(args: Map<String, Any?>) {
        val device = vibrator ?: return
        if (!device.hasVibrator()) return

        @Suppress("UNCHECKED_CAST")
        val pattern = if (faceDown) (args["faceDownAlt"] as? Map<String, Any?>) ?: args else args
        val id = (args["id"] as? Number)?.toInt() ?: 0

        @Suppress("UNCHECKED_CAST")
        val prims = pattern["prims"] as? List<Map<String, Any?>> ?: emptyList()
        @Suppress("UNCHECKED_CAST")
        val wave = pattern["wave"] as? Map<String, Any?>
        val constant = pattern["constant"] as? String
        val preferWave = pattern["preferWave"] == true
        val waveOnly = pattern["waveOnly"] == true

        val amplitude = hasAmplitudeControl()
        try {
            if (preferWave && amplitude && wave != null && vibrateWave(wave, id)) return
            if (prims.isNotEmpty() && vibrateComposition(prims, id)) return
            if (constant != null && playConstant(constant, id)) return
            if (amplitude && wave != null && vibrateWave(wave, id)) return
            if (waveOnly) return
            if (wave != null) vibrateRhythm(wave, id) else oneShot(pattern["fallback"] as? String, id)
        } catch (_: Exception) {
            // A motor busy with a system haptic, or an OEM that refuses an
            // effect. Haptics is enrichment; never surface this.
        }
    }

    private fun primitiveId(name: String?): Int? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return null
        return when (name) {
            "click" -> VibrationEffect.Composition.PRIMITIVE_CLICK
            "tick" -> VibrationEffect.Composition.PRIMITIVE_TICK
            "slowRise" -> VibrationEffect.Composition.PRIMITIVE_SLOW_RISE
            "quickFall" -> VibrationEffect.Composition.PRIMITIVE_QUICK_FALL
            "lowTick" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) VibrationEffect.Composition.PRIMITIVE_LOW_TICK else null
            "thud" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) VibrationEffect.Composition.PRIMITIVE_THUD else null
            "spin" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) VibrationEffect.Composition.PRIMITIVE_SPIN else null
            else -> null
        }
    }

    private fun supported(id: Int?): Boolean =
        id != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && vibrator?.areAllPrimitivesSupported(id) == true

    /** Rung 2. False when any primitive (and its stand-in) is missing. */
    private fun vibrateComposition(prims: List<Map<String, Any?>>, id: Int): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return false
        val composition = VibrationEffect.startComposition()
        for (p in prims) {
            var prim = primitiveId(p["p"] as? String)
            if (!supported(prim)) prim = primitiveId(p["alt"] as? String)
            if (!supported(prim)) return false
            val scale = ((p["scale"] as? Number)?.toFloat() ?: 1f).coerceIn(0f, 1f)
            val delay = ((p["delay"] as? Number)?.toInt() ?: 0).coerceAtLeast(0)
            composition.addPrimitive(prim!!, scale, delay)
        }
        vibrate(composition.compose(), id)
        return true
    }

    /** Rung 3: `fb:NAME` is a performHapticFeedback constant, `fx:NAME` a predefined effect. */
    private fun playConstant(constant: String, id: Int): Boolean {
        val (kind, name) = constant.split(":", limit = 2).let { it[0] to it.getOrElse(1) { "" } }
        if (kind == "fx") {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
            val effect = when (name) {
                "HEAVY_CLICK" -> VibrationEffect.EFFECT_HEAVY_CLICK
                "CLICK" -> VibrationEffect.EFFECT_CLICK
                "TICK" -> VibrationEffect.EFFECT_TICK
                "DOUBLE_CLICK" -> VibrationEffect.EFFECT_DOUBLE_CLICK
                else -> return false
            }
            vibrate(VibrationEffect.createPredefined(effect), id)
            return true
        }
        val code = feedbackConstant(name) ?: return false
        val view = viewProvider() ?: return false
        currentId = id
        return view.performHapticFeedback(code)
    }

    private fun feedbackConstant(name: String): Int? {
        val sdk = Build.VERSION.SDK_INT
        return when (name) {
            "CONFIRM" -> if (sdk >= Build.VERSION_CODES.R) HapticFeedbackConstants.CONFIRM else null
            "REJECT" -> if (sdk >= Build.VERSION_CODES.R) HapticFeedbackConstants.REJECT else null
            "SEGMENT_TICK" -> if (sdk >= 34) HapticFeedbackConstants.SEGMENT_TICK else HapticFeedbackConstants.CLOCK_TICK
            "TOGGLE_ON" -> if (sdk >= 34) HapticFeedbackConstants.TOGGLE_ON else HapticFeedbackConstants.VIRTUAL_KEY
            "TOGGLE_OFF" -> if (sdk >= 34) HapticFeedbackConstants.TOGGLE_OFF else null
            "DRAG_START" -> if (sdk >= 34) HapticFeedbackConstants.DRAG_START else HapticFeedbackConstants.LONG_PRESS
            "GESTURE_THRESHOLD_ACTIVATE" -> if (sdk >= 34) HapticFeedbackConstants.GESTURE_THRESHOLD_ACTIVATE else null
            "GESTURE_THRESHOLD_DEACTIVATE" -> if (sdk >= 34) HapticFeedbackConstants.GESTURE_THRESHOLD_DEACTIVATE else null
            else -> null
        }
    }

    private fun timingsOf(wave: Map<String, Any?>): LongArray =
        ((wave["t"] as? List<*>) ?: emptyList<Any>()).map { (it as? Number)?.toLong() ?: 0L }.toLongArray()

    private fun amplitudesOf(wave: Map<String, Any?>): IntArray =
        ((wave["a"] as? List<*>) ?: emptyList<Any>()).map { ((it as? Number)?.toInt() ?: 0).coerceIn(0, 255) }.toIntArray()

    /** Rungs 1 and 4: the waveform with its amplitudes. */
    private fun vibrateWave(wave: Map<String, Any?>, id: Int): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val timings = timingsOf(wave)
        val amplitudes = amplitudesOf(wave)
        if (timings.isEmpty() || timings.size != amplitudes.size || amplitudes.all { it == 0 }) return false
        vibrate(VibrationEffect.createWaveform(timings, amplitudes, -1), id)
        return true
    }

    /** Rung 5: no amplitude control, so the rhythm alone — on wherever the wave is. */
    private fun vibrateRhythm(wave: Map<String, Any?>, id: Int) {
        val timings = timingsOf(wave)
        val amplitudes = amplitudesOf(wave)
        if (timings.isEmpty() || timings.size != amplitudes.size) return
        // Collapse to alternating off/on durations, starting with an off.
        val merged = ArrayList<Long>()
        var on = false
        var run = 0L
        for (i in timings.indices) {
            val isOn = amplitudes[i] > 40
            if (isOn != on) {
                merged.add(run)
                run = 0L
                on = isOn
            }
            run += timings[i]
        }
        merged.add(run)
        if (merged.size < 2) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrate(VibrationEffect.createWaveform(merged.toLongArray(), -1), id)
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(merged.toLongArray(), -1)
            currentId = id
        }
    }

    private fun oneShot(fallback: String?, id: Int) {
        val ms = when (fallback) {
            "none" -> return
            "selection", "light" -> 30L
            "medium", "success" -> 45L
            else -> 70L
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrate(VibrationEffect.createOneShot(ms, VibrationEffect.DEFAULT_AMPLITUDE), id)
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(ms)
            currentId = id
        }
    }

    private fun vibrate(effect: VibrationEffect, id: Int) {
        val device = vibrator ?: return
        currentId = id
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            device.vibrate(effect, VibrationAttributes.createForUsage(VibrationAttributes.USAGE_TOUCH))
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            device.vibrate(effect)
        }
    }

    // ─── stop ──────────────────────────────────────────────────────────────

    /**
     * Stop pattern [id] if it is the one playing. With a fade and a motor that
     * can vary its strength, a short ramp from [level] to nothing takes over:
     * the breath fades out over 150 ms, a ratchet lifted early falls softly.
     */
    private fun stop(id: Int, fadeMs: Int, level: Double) {
        val device = vibrator ?: return
        if (id != currentId) return
        device.cancel()
        currentId = 0
        if (fadeMs <= 0 || level <= 0.01 || !hasAmplitudeControl()) return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val steps = 5
        val start = (level * 255).toInt().coerceIn(1, 255)
        val timings = LongArray(steps) { (fadeMs / steps).toLong().coerceAtLeast(10) }
        val amplitudes = IntArray(steps) { i -> (start * (steps - i) / (steps + 1)).coerceIn(1, 255) }
        try {
            vibrate(VibrationEffect.createWaveform(timings, amplitudes, -1), 0)
        } catch (_: Exception) {
        }
    }

    // ─── face down ─────────────────────────────────────────────────────────

    /**
     * While the timer is on screen, watch gravity. Face down (z below
     * −0.9 g; the screen towards the desk) switches bloom to its desk-safe
     * version, which hums instead of rattling.
     */
    private fun watchFaceDown(on: Boolean) {
        val sensors = sensorManager ?: return
        if (!on) {
            faceDownListener?.let { sensors.unregisterListener(it) }
            faceDownListener = null
            faceDown = false
            return
        }
        if (faceDownListener != null) return
        val sensor = sensors.getDefaultSensor(Sensor.TYPE_GRAVITY)
            ?: sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
            ?: return
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                faceDown = event.values[2] < -0.9f * SensorManager.GRAVITY_EARTH
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }
        sensors.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_NORMAL)
        faceDownListener = listener
    }
}
