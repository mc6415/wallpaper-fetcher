package dev.mcoombes.wallpaperfetcher

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private companion object {
        const val PICK_FOLDER = 4100
    }

    private var pendingPick: MethodChannel.Result? = null
    private var persistPick = true

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        WallpaperChannel.register(messenger, this)
        RotationWorker.register(messenger, this)
        StorageChannel.register(messenger, this).picker = ::pickFolder
    }

    /** ACTION_OPEN_DOCUMENT_TREE; replies with the folder's URI, or null. */
    private fun pickFolder(persist: Boolean, result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.error("busy", "The folder picker is already open.", null)
            return
        }
        pendingPick = result
        persistPick = persist
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                Intent.FLAG_GRANT_PREFIX_URI_PERMISSION,
        )
        @Suppress("DEPRECATION")
        startActivityForResult(intent, PICK_FOLDER)
    }

    @Deprecated("Flutter's embedding still delivers results here")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != PICK_FOLDER) {
            @Suppress("DEPRECATION")
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingPick ?: return
        pendingPick = null
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        if (persistPick) {
            try {
                contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
                )
            } catch (e: SecurityException) {
                result.error("not_allowed", "Android didn't let the app keep access to that folder.", null)
                return
            }
        }
        result.success(uri.toString())
    }
}
