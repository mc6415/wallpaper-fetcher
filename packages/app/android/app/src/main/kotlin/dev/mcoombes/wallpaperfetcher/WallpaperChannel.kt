package dev.mcoombes.wallpaperfetcher

import android.app.WallpaperManager
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Rect
import android.hardware.display.DisplayManager
import android.net.Uri
import android.os.Build
import android.view.Display
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.FileInputStream
import java.io.InputStream

/**
 * Sets wallpapers and describes the device's screens. The decisions (which
 * screens to offer, where to crop) are made in Dart; this only does what the
 * platform has to.
 *
 * Samsung foldables keep a separate wallpaper per screen. One UI reads extra
 * bits in `which`: 16 for the cover ("sub") screen and 4 for the main screen.
 * Without either bit it picks whichever screen is in use, so a plain
 * FLAG_SYSTEM only changes the screen you're looking at. The public
 * `setStream(stream, crop, allowBackup, which)` passes the bits through
 * untouched (checked on an SM-F976B with One UI 9 / Android 17).
 */
class WallpaperChannel private constructor(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val NAME = "dev.mcoombes.wallpaperfetcher/wallpaper"

        /** One UI's FLAG_DISPLAY_PHONE. Hidden, so not readable by reflection. */
        const val SAMSUNG_MAIN_DISPLAY = 4

        /** Added in Android 16 QPR2; Flutter compiles against an earlier SDK. */
        private const val CATEGORY_BUILT_IN = "android.hardware.display.category.BUILT_IN_DISPLAYS"

        fun register(messenger: BinaryMessenger, context: Context) {
            MethodChannel(messenger, NAME).setMethodCallHandler(WallpaperChannel(context.applicationContext))
        }
    }

    private val wallpapers: WallpaperManager = WallpaperManager.getInstance(context)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "device" -> result.success(device())
            "apply" -> Background.run(result) {
                @Suppress("UNCHECKED_CAST")
                apply(call.argument<List<Map<String, Any?>>>("assignments") ?: emptyList())
            }
            "accentColor" -> result.success(accentColor())
            else -> result.notImplemented()
        }
    }

    private fun device(): Map<String, Any?> {
        val current = currentSize()
        return mapOf(
            "sdk" to Build.VERSION.SDK_INT,
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "canSet" to (wallpapers.isWallpaperSupported && wallpapers.isSetWallpaperAllowed),
            "hasHinge" to context.packageManager.hasSystemFeature(PackageManager.FEATURE_SENSOR_HINGE_ANGLE),
            "samsungSubDisplayFlag" to samsungSubDisplayFlag(),
            "samsungMainDisplayFlag" to SAMSUNG_MAIN_DISPLAY,
            "current" to mapOf("width" to current.first, "height" to current.second),
            "displays" to builtInDisplays().map { d ->
                // The panel's own size, in its natural (portrait) orientation.
                val mode = d.mode
                mapOf(
                    "id" to d.displayId,
                    "name" to d.name,
                    "width" to minOf(mode.physicalWidth, mode.physicalHeight),
                    "height" to maxOf(mode.physicalWidth, mode.physicalHeight),
                    "on" to (d.state == Display.STATE_ON),
                )
            },
        )
    }

    /** Samsung exposes this one to apps (it's on the SDK list); null elsewhere. */
    private fun samsungSubDisplayFlag(): Int? = try {
        WallpaperManager::class.java.getField("SEM_FLAG_SUB_DISPLAY").getInt(null)
    } catch (e: ReflectiveOperationException) {
        null
    } catch (e: SecurityException) {
        null
    }

    private fun builtInDisplays(): List<Display> {
        val manager = context.getSystemService(DisplayManager::class.java) ?: return emptyList()
        val builtIn = if (Build.VERSION.SDK_INT >= 36) {
            try {
                manager.getDisplays(CATEGORY_BUILT_IN).toList()
            } catch (e: RuntimeException) {
                emptyList()
            }
        } else {
            emptyList()
        }
        return builtIn.ifEmpty { listOfNotNull(manager.getDisplay(Display.DEFAULT_DISPLAY)) }
    }

    /** The screen in use now, portrait, in physical pixels. */
    private fun currentSize(): Pair<Int, Int> {
        val manager = context.getSystemService(DisplayManager::class.java)
        val mode = manager?.getDisplay(Display.DEFAULT_DISPLAY)?.mode ?: return 1080 to 1920
        return minOf(mode.physicalWidth, mode.physicalHeight) to maxOf(mode.physicalWidth, mode.physicalHeight)
    }

    /** Each assignment: path (file path or content:// URI), which, crop [l, t, r, b]. */
    private fun apply(assignments: List<Map<String, Any?>>): List<Int> {
        if (!wallpapers.isWallpaperSupported) throw PlatformFailure("unsupported", "This device doesn't support wallpapers.")
        if (!wallpapers.isSetWallpaperAllowed) {
            throw PlatformFailure("not_allowed", "Changing the wallpaper is blocked on this device (by a work profile or device policy).")
        }
        return assignments.map { a ->
            val path = a["path"] as String
            val which = (a["which"] as Number).toInt()
            val crop = (a["crop"] as List<*>?)?.map { (it as Number).toInt() }?.let { Rect(it[0], it[1], it[2], it[3]) }
            open(path).use { stream -> wallpapers.setStream(stream, crop, true, which) }
        }
    }

    private fun open(path: String): InputStream = when {
        path.startsWith("content://") && path.contains('#') -> Trees.open(context, path)
        path.startsWith("content://") -> context.contentResolver.openInputStream(Uri.parse(path))
            ?: throw PlatformFailure("not_found", "Couldn't open the image.")
        else -> FileInputStream(path)
    }

    /** Material You's accent (Android 12+), as 0xAARRGGBB. */
    private fun accentColor(): Long? =
        if (Build.VERSION.SDK_INT >= 31) {
            context.getColor(android.R.color.system_accent1_500).toLong() and 0xFFFFFFFFL
        } else {
            null
        }
}
