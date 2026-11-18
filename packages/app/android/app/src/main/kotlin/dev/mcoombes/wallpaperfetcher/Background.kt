package dev.mcoombes.wallpaperfetcher

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import java.io.FileNotFoundException
import java.util.concurrent.Executors

/** A failure with a message meant for the user. */
class PlatformFailure(val code: String, message: String) : Exception(message)

/** Runs channel work off the main thread and replies on it. */
object Background {
    private val pool = Executors.newFixedThreadPool(3)
    private val main = Handler(Looper.getMainLooper())

    fun run(result: MethodChannel.Result, work: () -> Any?) {
        pool.execute {
            val reply: () -> Unit = try {
                // Unit isn't something the codec can send; it means "no value".
                val value = work().takeUnless { it == Unit }
                ({ result.success(value) })
            } catch (e: PlatformFailure) {
                ({ result.error(e.code, e.message, null) })
            } catch (e: FileNotFoundException) {
                ({ result.error("not_found", e.message ?: "File not found.", null) })
            } catch (e: SecurityException) {
                Log.w("WallpaperFetcher", "Not allowed", e)
                ({ result.error("not_allowed", e.message ?: "Not allowed.", null) })
            } catch (e: Exception) {
                Log.w("WallpaperFetcher", "Platform call failed", e)
                ({ result.error("failed", e.message ?: e.javaClass.simpleName, null) })
            }
            main.post(reply)
        }
    }
}
