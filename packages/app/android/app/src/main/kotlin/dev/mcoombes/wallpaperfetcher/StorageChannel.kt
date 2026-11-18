package dev.mcoombes.wallpaperfetcher

import android.content.Context
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.InputStream

/** Picked folders by URI, shared by every engine in the process. */
object Trees {
    private val trees = HashMap<String, SafTree>()

    fun get(context: Context, uri: String): SafTree = synchronized(trees) {
        trees.getOrPut(uri) { SafTree(context.applicationContext, Uri.parse(uri)) }
    }

    /**
     * Opens a library file. A picked folder's files are written
     * `<tree uri>#<relative path>` (see `saf_storage.dart`).
     */
    fun open(context: Context, location: String): InputStream {
        val hash = location.indexOf('#')
        if (location.startsWith("content://") && hash > 0) {
            return get(context, location.substring(0, hash)).open(location.substring(hash + 1))
        }
        throw IllegalArgumentException("Not a library location: $location")
    }
}

/**
 * The library folder when it's one the user picked (no file paths): the
 * operations `LibraryStorage` needs, done through the Storage Access
 * Framework. The picker itself needs an activity, so it's only available to
 * the app's own engine.
 */
class StorageChannel private constructor(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val NAME = "dev.mcoombes.wallpaperfetcher/storage"

        fun register(messenger: BinaryMessenger, context: Context): StorageChannel =
            StorageChannel(context.applicationContext).also { MethodChannel(messenger, NAME).setMethodCallHandler(it) }
    }

    /** Opens the system folder picker; set while the app's activity exists. */
    var picker: ((persist: Boolean, result: MethodChannel.Result) -> Unit)? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val treeUri = call.argument<String>("tree")
        val path = call.argument<String>("path") ?: ""
        fun tree() = Trees.get(context, treeUri ?: throw PlatformFailure("bad_args", "No folder given."))
        when (call.method) {
            "pick" -> picker?.invoke(call.argument<Boolean>("persist") ?: true, result)
                ?: result.error("no_activity", "The folder picker needs the app to be open.", null)
            "release" -> {
                try {
                    context.contentResolver.releasePersistableUriPermission(
                        Uri.parse(treeUri),
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
                    )
                } catch (e: SecurityException) {
                    // Not held (any more); nothing to release.
                }
                result.success(null)
            }
            "persisted" -> result.success(context.contentResolver.persistedUriPermissions.map { it.uri.toString() })
            "available" -> Background.run(result) { tree().available() }
            "describe" -> Background.run(result) { tree().describe() }
            "list" -> Background.run(result) { tree().list() }
            "exists" -> Background.run(result) { tree().exists(path) }
            "length" -> Background.run(result) { tree().length(path) }
            "sha256" -> Background.run(result) { tree().sha256(path) }
            "imageSize" -> Background.run(result) { tree().imageSize(path) }
            "read" -> Background.run(result) { tree().read(path) }
            "write" -> Background.run(result) { tree().write(path, call.argument<ByteArray>("bytes")!!) }
            "putFile" -> Background.run(result) {
                tree().putFile(path, File(call.argument<String>("source")!!), call.argument<Boolean>("move") ?: false)
            }
            "getFile" -> Background.run(result) { tree().getFile(path, File(call.argument<String>("destination")!!)) }
            "delete" -> Background.run(result) { tree().delete(path) }
            else -> result.notImplemented()
        }
    }
}
