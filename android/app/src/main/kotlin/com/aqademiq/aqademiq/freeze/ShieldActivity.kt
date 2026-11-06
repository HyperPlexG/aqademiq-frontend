package com.aqademiq.aqademiq.freeze

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.Shader
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.TextView
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher
import androidx.annotation.RequiresApi
import androidx.core.content.ContextCompat
import androidx.core.view.AccessibilityDelegateCompat
import androidx.core.view.ViewCompat
import androidx.core.view.accessibility.AccessibilityNodeInfoCompat
import com.aqademiq.aqademiq.MainActivity
import com.aqademiq.aqademiq.R
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

/**
 * The frost shield (APP_FREEZE.md §4): what a frozen app turns into when it
 * is opened. [FreezeMonitorService] starts it over the app and has already
 * worked out every word, so this only draws.
 *
 * Two ways out, and neither is the frozen app:
 *
 *  * **Back to focus** goes to the home screen — and so does Back, so the
 *    gesture a thumb makes without thinking does the same thing.
 *  * **Thaw · 10s** queues a `thaw_request` and opens Aqademiq at
 *    `aqademiq://freeze/thaw?target=<package>`, where the breath happens.
 *    The shield never thaws anything itself: the breath, the length and the
 *    refreeze all live in one place, in Dart.
 *
 * Never open has no Thaw; a Deep freeze says when thawing opens again instead.
 * Its own task (`singleInstance`, no affinity, out of recents) so it never
 * joins the frozen app's task or Aqademiq's.
 */
class ShieldActivity : Activity() {

    companion object {
        const val EXTRA_PACKAGE = "package"
        const val EXTRA_LABEL = "label"

        /** 1–3: how many times today the shield has covered this app (§4). */
        const val EXTRA_STAGE = "stage"
        const val EXTRA_LINE = "line"
        const val EXTRA_BREATH = "breath"
        const val EXTRA_DEEP = "deep"

        /** "Deep freeze until 1:00 PM", shown in place of Thaw. */
        const val EXTRA_DEEP_NOTE = "deep_note"
        const val EXTRA_NEVER = "never"

        /** CSS `linear-gradient(170deg, …)`, as the design draws the ground. */
        private const val GROUND_ANGLE = 170.0
    }

    private var target: String? = null
    private var label: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.freeze_shield)
        // The theme's ground is the closest of Android's eight gradient
        // directions, for the frame before this one; this is the real angle.
        window.setBackgroundDrawable(
            FrostGround(
                intArrayOf(
                    ContextCompat.getColor(this, R.color.freeze_ground_top),
                    ContextCompat.getColor(this, R.color.freeze_ground_mid),
                    ContextCompat.getColor(this, R.color.freeze_ground_bottom),
                ),
                GROUND_ANGLE,
            ),
        )
        val backButton = findViewById<Button>(R.id.shield_back)
        val thawButton = findViewById<View>(R.id.shield_thaw)
        backButton.setOnClickListener { goHome() }
        thawButton.setOnClickListener { requestThaw() }
        announceAsButton(thawButton)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) registerBack()
        render(intent)
    }

    /** singleInstance: a second frozen app reuses this one with new words. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        render(intent)
    }

    /**
     * A shield can outlive its freeze: left up with the screen off while the
     * window ended, or brought back from wherever it was while a thaw ran.
     * Coming back to a shield over an app that is no longer frozen, step
     * aside — the app underneath is the student's again. The monitor puts it
     * back within a second if that was wrong.
     */
    override fun onResume() {
        super.onResume()
        val pkg = target ?: return
        val policy = FreezeStore.policy(this)
        if (policy == null || !FreezeRules.isFrozen(policy, pkg, System.currentTimeMillis())) finish()
    }

    private fun render(intent: Intent) {
        target = intent.getStringExtra(EXTRA_PACKAGE)
        label = intent.getStringExtra(EXTRA_LABEL)
        val never = intent.getBooleanExtra(EXTRA_NEVER, false)
        val deep = intent.getBooleanExtra(EXTRA_DEEP, false)
        val stage = intent.getIntExtra(EXTRA_STAGE, 1).coerceIn(1, 3)
        val breath = intent.getIntExtra(EXTRA_BREATH, FreezeRules.BREATH_SECONDS)

        findViewById<TextView>(R.id.shield_title).text = when {
            never -> "Never open."
            stage == 1 -> "Ada's sitting on this one."
            stage == 2 -> "Still on ice."
            else -> "Frozen."
        }
        findViewById<TextView>(R.id.shield_line).text = intent.getStringExtra(EXTRA_LINE) ?: ""

        val thawButton = findViewById<View>(R.id.shield_thaw)
        val deepNote = findViewById<TextView>(R.id.shield_deep)
        val canThaw = !never && !deep && target != null
        thawButton.visibility = if (canThaw) View.VISIBLE else View.GONE
        findViewById<TextView>(R.id.shield_thaw_label).text = "Thaw · ${breath}s"
        thawButton.contentDescription = "Thaw, after a $breath second breath"
        if (!never && deep) {
            deepNote.text = intent.getStringExtra(EXTRA_DEEP_NOTE) ?: "Deep freeze"
            deepNote.visibility = View.VISIBLE
        } else {
            deepNote.visibility = View.GONE
        }
    }

    /** Back to focus: the home screen, never the app underneath. */
    private fun goHome() {
        val home = Intent(Intent.ACTION_MAIN)
            .addCategory(Intent.CATEGORY_HOME)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            startActivity(home)
        } catch (e: ActivityNotFoundException) {
            // No home app is not a state a phone gets into; finishing is enough.
        }
        finish()
    }

    /**
     * The event and the link land together (§1.2): the event survives an
     * engine that is not running yet, the link brings the app up. Dart
     * de-duplicates by target.
     */
    private fun requestThaw() {
        val pkg = target ?: return goHome()
        FreezeStore.queueEvent(this, FreezeStore.EVENT_THAW_REQUEST, pkg, label, System.currentTimeMillis())
        val open = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("aqademiq://freeze/thaw?target=" + Uri.encode(pkg)),
            this,
            MainActivity::class.java,
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        try {
            startActivity(open)
        } catch (e: ActivityNotFoundException) {
            // MainActivity is ours; it cannot be missing.
        }
        finish()
    }

    @Deprecated("Deprecated in Java")
    @Suppress("OVERRIDE_DEPRECATION")
    override fun onBackPressed() {
        goHome()
    }

    /**
     * Android 13+ with predictive back (and every Android 16 app that targets
     * it) never calls onBackPressed; this is the same exit for them.
     */
    @RequiresApi(Build.VERSION_CODES.TIRAMISU)
    private fun registerBack() {
        onBackInvokedDispatcher.registerOnBackInvokedCallback(
            OnBackInvokedDispatcher.PRIORITY_DEFAULT,
            OnBackInvokedCallback { goHome() },
        )
    }

    /** The thaw pill is a row (glyph + words); TalkBack should still call it a button. */
    private fun announceAsButton(view: View) {
        ViewCompat.setAccessibilityDelegate(
            view,
            object : AccessibilityDelegateCompat() {
                override fun onInitializeAccessibilityNodeInfo(host: View, info: AccessibilityNodeInfoCompat) {
                    super.onInitializeAccessibilityNodeInfo(host, info)
                    info.className = Button::class.java.name
                }
            },
        )
    }

    /**
     * The shield's ground at the design's own angle. Android's gradient XML
     * only goes in steps of 45°, and 170° is not one of them; CSS's gradient
     * line is reproduced here — through the centre, long enough that the
     * corners see the first and last stop.
     */
    private class FrostGround(private val colors: IntArray, angleDegrees: Double) : Drawable() {
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        private val dx = sin(Math.toRadians(angleDegrees)).toFloat()
        private val dy = (-cos(Math.toRadians(angleDegrees))).toFloat()

        override fun onBoundsChange(bounds: Rect) {
            super.onBoundsChange(bounds)
            val w = bounds.width().toFloat()
            val h = bounds.height().toFloat()
            val half = (abs(w * dx) + abs(h * dy)) / 2f
            val cx = bounds.exactCenterX()
            val cy = bounds.exactCenterY()
            paint.shader = LinearGradient(
                cx - dx * half,
                cy - dy * half,
                cx + dx * half,
                cy + dy * half,
                colors,
                floatArrayOf(0f, 0.5f, 1f),
                Shader.TileMode.CLAMP,
            )
        }

        override fun draw(canvas: Canvas) {
            canvas.drawRect(bounds, paint)
        }

        override fun setAlpha(alpha: Int) {
            paint.alpha = alpha
            invalidateSelf()
        }

        override fun setColorFilter(colorFilter: ColorFilter?) {
            paint.colorFilter = colorFilter
            invalidateSelf()
        }

        @Deprecated("Deprecated in Java")
        @Suppress("OVERRIDE_DEPRECATION")
        override fun getOpacity(): Int = PixelFormat.OPAQUE
    }
}
