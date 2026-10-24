package com.aqademiq.aqademiq

import android.content.Context
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.plugin.common.MethodChannel

/**
 * Renders the app's haptic patterns on the phone's vibrator.
 *
 * Dart sends beats — `{shape, at, ms, intensity, sharpness}` — and this turns
 * them into a [VibrationEffect] waveform of alternating gaps and pulses. That
 * is the only Android API that expresses what the vocabulary needs: a duration
 * per beat and an amplitude per beat.
 *
 * ## Why `ms` matters more here than on iOS
 *
 * An iOS transient has no duration; strength is intensity alone. An Android
 * LRA has to spin up before anything is felt at all, so a ~20 ms pulse is
 * imperceptible however high its amplitude — which is why the app's detents
 * previously read as "nothing happened" on device. Dart therefore gives every
 * tap an explicit pulse length (50 ms for detents, 90 ms for a long-press) and
 * this plays it verbatim. Do not shorten these here; the floors are the fix.
 *
 * `sharpness` has no Android equivalent and is deliberately dropped rather
 * than faked.
 *
 * Three rungs: an amplitude waveform where the motor supports amplitude
 * control, a timings-only waveform where it does not (on/off is still a
 * pattern), and a single one-shot on anything older.
 */
object HapticsBridge {
    const val CHANNEL = "aqademiq/haptics"

    private var vibrator: Vibrator? = null

    fun attach(channel: MethodChannel, context: Context) {
        vibrator = resolveVibrator(context)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    @Suppress("UNCHECKED_CAST")
                    val beats = call.argument<List<Map<String, Any>>>("beats") ?: emptyList()
                    play(beats)
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
        vibrator = null
    }

    private fun resolveVibrator(context: Context): Vibrator? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)
                ?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }

    private fun hasAmplitudeControl(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && vibrator?.hasAmplitudeControl() == true

    private fun play(beats: List<Map<String, Any>>) {
        val device = vibrator ?: return
        if (!device.hasVibrator() || beats.isEmpty()) return

        // Build alternating [gap, pulse, gap, pulse, …] from the beats' offsets.
        // A waveform's first entry is always a wait, which is exactly what the
        // first beat's `at` is.
        val timings = ArrayList<Long>()
        val amplitudes = ArrayList<Int>()
        var cursor = 0L

        for (beat in beats.sortedBy { intOf(it, "at") }) {
            val at = intOf(beat, "at").toLong()
            val ms = intOf(beat, "ms").toLong()
            if (ms <= 0) continue
            val gap = (at - cursor).coerceAtLeast(0L)
            timings.add(gap)
            amplitudes.add(0)
            timings.add(ms)
            amplitudes.add(amplitude(beat))
            cursor = at + ms
        }
        if (timings.isEmpty()) return

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val effect = if (hasAmplitudeControl()) {
                    VibrationEffect.createWaveform(
                        timings.toLongArray(),
                        amplitudes.toIntArray(),
                        -1,
                    )
                } else {
                    // No amplitude control: on/off timing still carries the
                    // rhythm, which is most of what distinguishes a double-tap
                    // warning from a single confirmation.
                    VibrationEffect.createWaveform(timings.toLongArray(), -1)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    // Marked as touch feedback so Android's own "Touch feedback"
                    // switch and intensity apply, as they did for Flutter's
                    // HapticFeedback before this bridge. Someone who turned
                    // system haptics off should not feel the app anyway.
                    device.vibrate(
                        effect,
                        VibrationAttributes.createForUsage(VibrationAttributes.USAGE_TOUCH),
                    )
                } else {
                    device.vibrate(effect)
                }
            } else {
                @Suppress("DEPRECATION")
                device.vibrate(timings.toLongArray(), -1)
            }
        } catch (_: Exception) {
            // A motor busy with a system haptic, or an OEM that refuses a
            // waveform. Haptics is enrichment; never surface this.
        }
    }

    /** 1–255. Scaled from the beat's 0–1 intensity, never zero for a real beat. */
    private fun amplitude(beat: Map<String, Any>): Int {
        val intensity = (beat["intensity"] as? Number)?.toDouble() ?: 0.0
        return (intensity * 255).toInt().coerceIn(1, 255)
    }

    /**
     * Reads one millisecond field off a beat.
     *
     * Named `intOf` rather than `beat` so it cannot be confused with the loop
     * variable above: a helper called `beat` taking a `beat` resolved to the
     * function inside `sortedBy`'s lambda, where the loop variable is not yet
     * in scope, and the compiler passed the function itself as the argument.
     */
    private fun intOf(beat: Map<String, Any>, key: String): Int =
        (beat[key] as? Number)?.toInt() ?: 0
}
