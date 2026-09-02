package com.example.blockx.channel

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import java.io.ByteArrayOutputStream

/**
 * Reads installed-app metadata (list, label, launcher icon) for the Flutter UI.
 * Extracted from [MainActivity] — pure, read-only, no state.
 */
object AppInfoReader {

    /** All launchable apps on the device, as maps for the Flutter side. */
    fun getInstalledApps(ctx: Context): List<Map<String, String>> {
        val pm = ctx.packageManager
        val launchable = Intent(Intent.ACTION_MAIN, null)
            .addCategory(Intent.CATEGORY_LAUNCHER)

        val resolved = pm.queryIntentActivities(launchable, 0)
        val seen = HashSet<String>()
        val apps = ArrayList<Map<String, String>>()

        for (info in resolved) {
            val pkg = info.activityInfo.packageName
            if (pkg == ctx.packageName) continue // don't list ourselves
            if (!seen.add(pkg)) continue
            val label = info.loadLabel(pm)?.toString() ?: pkg
            apps.add(mapOf("appName" to label, "packageName" to pkg))
        }
        return apps
    }

    /** An app's display label, or the package name if it can't be resolved. */
    fun getAppLabel(ctx: Context, pkg: String): String {
        if (pkg.isEmpty()) return pkg
        return try {
            ctx.packageManager.getApplicationLabel(
                ctx.packageManager.getApplicationInfo(pkg, 0),
            ).toString()
        } catch (e: Exception) {
            pkg
        }
    }

    /** An app's launcher icon as PNG bytes (~96px), or null. Read-only. */
    fun getAppIcon(ctx: Context, pkg: String): ByteArray? {
        if (pkg.isEmpty()) return null
        return try {
            val drawable = ctx.packageManager.getApplicationIcon(pkg)
            val bmp = drawableToBitmap(ctx, drawable)
            ByteArrayOutputStream().use { out ->
                bmp.compress(Bitmap.CompressFormat.PNG, 100, out)
                out.toByteArray()
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun drawableToBitmap(ctx: Context, drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable && drawable.bitmap != null) return drawable.bitmap
        val size = (96 * ctx.resources.displayMetrics.density).toInt().coerceAtLeast(96)
        val w = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else size
        val h = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else size
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bmp
    }
}
