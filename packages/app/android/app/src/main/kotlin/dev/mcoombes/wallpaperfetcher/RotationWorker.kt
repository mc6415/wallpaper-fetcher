package dev.mcoombes.wallpaperfetcher

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkInfo
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.util.concurrent.TimeUnit

/**
 * Changes the wallpaper in the background. WorkManager wakes this every so
 * often (15 minutes at the least); it starts a Flutter engine without UI,
 * runs `rotationWorkerMain` in Dart (which changes the wallpaper if it's due)
 * and shuts the engine down again.
 *
 * Our own channels are registered here as well as in MainActivity: engines
 * created this way only get pub plugins automatically.
 */
class RotationWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    companion object {
        private const val TAG = "WallpaperFetcher"
        private const val WORK_NAME = "rotation"
        const val CHANNEL = "dev.mcoombes.wallpaperfetcher/rotation"
        private const val ENTRYPOINT = "rotationWorkerMain"

        fun register(messenger: BinaryMessenger, context: Context) {
            val app = context.applicationContext
            MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
                val work = WorkManager.getInstance(app)
                when (call.method) {
                    "schedule" -> {
                        val minutes = (call.argument<Int>("minutes") ?: 60).toLong().coerceAtLeast(15)
                        val request = PeriodicWorkRequestBuilder<RotationWorker>(minutes, TimeUnit.MINUTES).build()
                        work.enqueueUniquePeriodicWork(WORK_NAME, ExistingPeriodicWorkPolicy.UPDATE, request)
                        result.success(null)
                    }
                    "cancel" -> {
                        work.cancelUniqueWork(WORK_NAME)
                        result.success(null)
                    }
                    "status" -> Background.run(result) {
                        val info = work.getWorkInfosForUniqueWork(WORK_NAME).get()
                            .firstOrNull { it.state != WorkInfo.State.CANCELLED }
                        info?.let {
                            mapOf(
                                "state" to it.state.name,
                                "nextRun" to it.nextScheduleTimeMillis.takeIf { t -> t != Long.MAX_VALUE },
                                "everyMinutes" to it.periodicityInfo?.repeatIntervalMillis?.div(60_000),
                            )
                        }
                    }
                    // The background Dart code reports back on the same channel.
                    else -> result.notImplemented()
                }
            }
        }
    }

    override suspend fun doWork(): Result {
        val finished = withContext(Dispatchers.Main) { runDart() }
        Log.i(TAG, "Background rotation check ${if (finished) "finished" else "timed out"}")
        // A failed change is logged by the Dart side; the next check tries again.
        return Result.success()
    }

    private suspend fun runDart(): Boolean {
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(applicationContext)
        loader.ensureInitializationComplete(applicationContext, null)
        val engine = FlutterEngine(applicationContext)
        try {
            val messenger = engine.dartExecutor.binaryMessenger
            WallpaperChannel.register(messenger, applicationContext)
            StorageChannel.register(messenger, applicationContext)
            val done = CompletableDeferred<Unit>()
            MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
                if (call.method == "done") {
                    done.complete(Unit)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(loader.findAppBundlePath(), ENTRYPOINT),
            )
            // WorkManager allows ten minutes; downloading a daily picture fits easily.
            return withTimeoutOrNull(TimeUnit.MINUTES.toMillis(8)) { done.await() } != null
        } finally {
            engine.destroy()
        }
    }
}
