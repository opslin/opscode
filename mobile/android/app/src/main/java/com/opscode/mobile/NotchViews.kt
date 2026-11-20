package com.opscode.mobile

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.roundToInt

internal class NotchViews(private val context: Context) {
    val paper = 0xff_f5f5f7.toInt()
    val secondary = 0xff_b2adb3.toInt()
    val red = 0xff_ff9388.toInt()

    fun approvalCard(session: Session, approval: Approval, busy: Boolean, selectable: Boolean = true,
        onDeny: () -> Unit, onReview: () -> Unit): View {
        val card = ApprovalCard(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(px(11), px(9), px(11), px(10))
            background = base(0xff_1b0e10.toInt(), 13, 0xff_6b3632.toInt(), 0xff_100c0e.toInt())
            clipToOutline = true
        }
        val title = LinearLayout(context).apply { gravity = Gravity.CENTER_VERTICAL }
        title.addView(mark(session.engine, "needs"), LinearLayout.LayoutParams(px(31), px(31)).apply { marginEnd = px(8) })
        val names = vertical()
        names.addView(label(session.title, 14, paper, true))
        names.addView(label(session.project, 11, secondary))
        title.addView(names, LinearLayout.LayoutParams(0, -2, 1f))
        title.addView(label("Approval", 11, red, true).apply { setPadding(px(4), 0, 0, 0) })
        card.addView(title)
        val summary = listOf(approval.tool.replace('_', ' '), approval.summary).filter(String::isNotBlank).joinToString("  ·  ")
        if (summary.isNotBlank()) card.addView(label(summary, 13, paper), row(top = 9, bottom = 4))
        if (approval.detail.isNotBlank()) {
            card.addView(label(approval.detail, 12, 0xff_efebf0.toInt()).apply {
                typeface = Typeface.MONOSPACE
                setTextIsSelectable(selectable)
                background = base(0xff_090809.toInt(), 8, 0xff_372529.toInt())
                setPadding(px(9), px(7), px(9), px(7))
            }, row(top = 3, bottom = 3))
        }
        if (!approval.canAllow) card.addView(label("Review the full request on your Mac.", 12, secondary), row(top = 5))
        val actions = LinearLayout(context).apply { gravity = Gravity.CENTER_VERTICAL }
        val deny = button("Deny", false, action = onDeny).apply {
            isEnabled = !busy
            filterTouchesWhenObscured = true
        }
        val allow = button(if (approval.choices.isEmpty()) "Allow once" else "Review options", true, action = onReview).apply {
            isEnabled = !busy && approval.canAllow
            filterTouchesWhenObscured = true
        }
        actions.addView(deny, LinearLayout.LayoutParams(0, -2, 1f).apply { marginEnd = px(6) })
        actions.addView(allow, LinearLayout.LayoutParams(0, -2, 1.25f))
        card.addView(actions, row(top = 8))
        return card
    }

    fun mark(engine: String, status: String): View = android.widget.FrameLayout(context).apply {
        val color = when {
            status == "needs" || status == "failed" -> 0xff_ff4c42.toInt()
            status == "working" -> 0xff_ffb48a.toInt()
            status == "done" -> Color.WHITE
            else -> 0xff_737075.toInt()
        }
        importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
        background = base(0xff_242326.toInt(), 9, 0xff_3d383b.toInt(), 0xff_141315.toInt())
        val mark = ImageView(context).apply {
            setImageResource(when (engine.lowercase()) {
                "codex" -> R.drawable.notch_codex
                "claude-code", "claude code" -> R.drawable.notch_claude
                "antigravity" -> R.drawable.notch_antigravity
                "qoder" -> R.drawable.notch_qoder
                else -> R.drawable.notch_opscode
            })
            scaleType = ImageView.ScaleType.FIT_CENTER
        }
        addView(mark, FrameLayout.LayoutParams(px(16), px(16), Gravity.CENTER))
        val dot = View(context).apply { background = base(color, 2, 0xff_151012.toInt()) }
        addView(dot, android.widget.FrameLayout.LayoutParams(px(8), px(8), Gravity.BOTTOM or Gravity.END))
    }

    fun button(text: String, primary: Boolean, compact: Boolean = false, action: () -> Unit) =
        android.widget.Button(context).apply {
            this.text = text
            textSize = if (compact) 12f else 13f
            isAllCaps = false
            setTextColor(if (primary) Color.BLACK else paper)
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            minHeight = px(48)
            minimumHeight = px(48)
            minWidth = px(48)
            minimumWidth = px(48)
            stateListAnimator = null
            setPadding(px(9), px(4), px(9), px(4))
            val fill = if (primary) paper else 0xff_242024.toInt()
            background = RippleDrawable(ColorStateList.valueOf(if (primary) 0x33000000 else 0x33ffffff),
                base(fill, 9, if (primary) fill else 0xff_47393f.toInt()), null)
            setOnFocusChangeListener { _, focused -> alpha = if (focused) .84f else 1f }
            setOnClickListener { action() }
        }

    fun base(color: Int, r: Int, stroke: Int, bottom: Int = color) =
        GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM, intArrayOf(color, bottom)).apply {
            cornerRadius = px(r).toFloat()
            setStroke(px(1), stroke)
        }

    fun label(value: String, sp: Int, ink: Int, bold: Boolean = false) = TextView(context).apply {
        text = value
        textSize = sp.toFloat()
        setTextColor(ink)
        includeFontPadding = false
        if (bold) typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
    }

    fun vertical() = LinearLayout(context).apply { orientation = LinearLayout.VERTICAL }
    fun row(top: Int = 0, bottom: Int = 0) = LinearLayout.LayoutParams(-1, -2).apply {
        topMargin = px(top)
        bottomMargin = px(bottom)
    }
    fun px(dp: Int) = (dp * context.resources.displayMetrics.density).roundToInt()
    private class ApprovalCard(context: android.content.Context) : LinearLayout(context) {
        private val ink = Paint(Paint.ANTI_ALIAS_FLAG)
        private val top = RectF()

        override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
            super.onSizeChanged(w, h, oldw, oldh)
            if (w <= 0) return
            val center = w * .34f
            val spread = (w * .29f).coerceAtLeast(1f)
            ink.shader = LinearGradient(center - spread, 0f, center + spread, 0f,
                intArrayOf(0x00_ff8c78, 0x88_ff8c78.toInt(), 0x00_ff8c78), null, Shader.TileMode.CLAMP)
            top.set(8f, 0f, w - 8f, resources.displayMetrics.density)
        }

        override fun dispatchDraw(canvas: Canvas) {
            super.dispatchDraw(canvas)
            canvas.drawRect(top, ink)
        }
    }
}
