package dev.mcoombes.wallpaperfetcher

import android.content.Context
import android.graphics.BitmapFactory
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
import android.webkit.MimeTypeMap
import java.io.File
import java.io.FileNotFoundException
import java.io.InputStream
import java.security.MessageDigest

/**
 * A folder picked through the system file picker (ACTION_OPEN_DOCUMENT_TREE),
 * used like a plain folder: paths are relative to it, with `/` separators.
 *
 * Document ids are provider-specific, so paths are resolved by looking names
 * up folder by folder. Folder listings are cached until something in them
 * changes or [list] walks the whole tree again.
 */
class SafTree(private val context: Context, val uri: Uri) {
    private data class Entry(val id: String, val isDir: Boolean)

    private val resolver = context.contentResolver
    private val rootId: String = DocumentsContract.getTreeDocumentId(uri)
    private val cache = HashMap<String, HashMap<String, Entry>>() // folder path -> name -> entry

    private fun docUri(id: String): Uri = DocumentsContract.buildDocumentUriUsingTree(uri, id)

    /** Whether the folder is still there and we may still use it. */
    fun available(): Boolean = try {
        resolver.query(docUri(rootId), arrayOf(Document.COLUMN_DOCUMENT_ID), null, null, null)?.use { it.moveToFirst() } ?: false
    } catch (e: SecurityException) {
        false
    } catch (e: IllegalArgumentException) {
        false
    }

    /** A name for the folder: `Pictures/Wallpapers` for phone storage. */
    fun describe(): String {
        if (uri.authority == "com.android.externalstorage.documents") {
            val (volume, path) = rootId.split(':', limit = 2).let { it[0] to it.getOrElse(1) { "" } }
            val where = if (volume == "primary") "" else "SD card: "
            return where + path.ifEmpty { if (volume == "primary") "Phone storage" else volume }
        }
        return resolver.query(docUri(rootId), arrayOf(Document.COLUMN_DISPLAY_NAME), null, null, null)?.use {
            if (it.moveToFirst()) it.getString(0) else null
        } ?: uri.lastPathSegment ?: "Picked folder"
    }

    /** Every file below the folder, re-reading everything. */
    fun list(): List<String> {
        synchronized(cache) { cache.clear() }
        val files = ArrayList<String>()
        fun walk(dir: String, id: String) {
            for ((name, entry) in children(dir, id)) {
                val path = if (dir.isEmpty()) name else "$dir/$name"
                if (entry.isDir) walk(path, entry.id) else files.add(path)
            }
        }
        walk("", rootId)
        return files
    }

    fun exists(path: String): Boolean = find(path) != null

    fun length(path: String): Long =
        resolver.query(docUri(require(path).id), arrayOf(Document.COLUMN_SIZE), null, null, null)?.use {
            if (it.moveToFirst()) it.getLong(0) else 0L
        } ?: 0L

    fun sha256(path: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        open(path).use { input ->
            val buffer = ByteArray(1 shl 16)
            while (true) {
                val n = input.read(buffer)
                if (n < 0) break
                digest.update(buffer, 0, n)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    /** Width and height, without decoding the pixels. Null if unreadable. */
    fun imageSize(path: String): List<Int>? {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        open(path).use { BitmapFactory.decodeStream(it, null, options) }
        return if (options.outWidth > 0 && options.outHeight > 0) listOf(options.outWidth, options.outHeight) else null
    }

    fun read(path: String): ByteArray = open(path).use { it.readBytes() }

    fun write(path: String, bytes: ByteArray) {
        val target = createOrFind(path)
        (resolver.openOutputStream(target, "wt") ?: throw FileNotFoundException(path)).use { it.write(bytes) }
    }

    /** Copies a local file in (and deletes it when [move]). */
    fun putFile(path: String, source: File, move: Boolean) {
        val target = createOrFind(path)
        source.inputStream().use { input ->
            (resolver.openOutputStream(target, "wt") ?: throw FileNotFoundException(path)).use { input.copyTo(it) }
        }
        if (move) source.delete()
    }

    fun getFile(path: String, destination: File) {
        destination.parentFile?.mkdirs()
        open(path).use { input -> destination.outputStream().use { input.copyTo(it) } }
    }

    fun delete(path: String) {
        val entry = find(path) ?: return
        DocumentsContract.deleteDocument(resolver, docUri(entry.id))
        val (dir, name) = split(path)
        synchronized(cache) { cache[dir]?.remove(name) }
    }

    /** An input stream for [path]. */
    fun open(path: String): InputStream =
        resolver.openInputStream(docUri(require(path).id)) ?: throw FileNotFoundException(path)

    // --- Resolving paths -------------------------------------------------------

    private fun split(path: String): Pair<String, String> {
        val i = path.lastIndexOf('/')
        return if (i < 0) "" to path else path.substring(0, i) to path.substring(i + 1)
    }

    private fun require(path: String): Entry = find(path) ?: throw FileNotFoundException("$path isn't in the library folder.")

    private fun find(path: String): Entry? {
        var dir = ""
        var id = rootId
        val parts = path.split('/').filter { it.isNotEmpty() }
        for ((i, part) in parts.withIndex()) {
            val entry = children(dir, id)[part] ?: return null
            if (i == parts.lastIndex) return entry
            if (!entry.isDir) return null
            dir = if (dir.isEmpty()) part else "$dir/$part"
            id = entry.id
        }
        return Entry(rootId, true)
    }

    /** The document for [path], creating it (and its folders) if needed. */
    private fun createOrFind(path: String): Uri {
        find(path)?.let { return docUri(it.id) }
        val (dir, name) = split(path)
        val parentId = ensureDir(dir)
        val created = DocumentsContract.createDocument(resolver, docUri(parentId), mimeOf(name), name)
            ?: throw FileNotFoundException("Couldn't create $path in the library folder.")
        val id = DocumentsContract.getDocumentId(created)
        synchronized(cache) { cache[dir]?.put(name, Entry(id, false)) }
        return created
    }

    private fun ensureDir(dir: String): String {
        var path = ""
        var id = rootId
        for (part in dir.split('/').filter { it.isNotEmpty() }) {
            val existing = children(path, id)[part]
            val childId = if (existing != null && existing.isDir) {
                existing.id
            } else {
                val created = DocumentsContract.createDocument(resolver, docUri(id), Document.MIME_TYPE_DIR, part)
                    ?: throw FileNotFoundException("Couldn't create the folder $part.")
                DocumentsContract.getDocumentId(created).also { newId ->
                    synchronized(cache) { cache[path]?.put(part, Entry(newId, true)) }
                }
            }
            path = if (path.isEmpty()) part else "$path/$part"
            id = childId
        }
        return id
    }

    private fun children(dir: String, id: String): Map<String, Entry> {
        synchronized(cache) { cache[dir]?.let { return HashMap(it) } }
        val found = HashMap<String, Entry>()
        val columns = arrayOf(Document.COLUMN_DOCUMENT_ID, Document.COLUMN_DISPLAY_NAME, Document.COLUMN_MIME_TYPE)
        resolver.query(DocumentsContract.buildChildDocumentsUriUsingTree(uri, id), columns, null, null, null)?.use { c ->
            while (c.moveToNext()) {
                val name = c.getString(1) ?: continue
                found[name] = Entry(c.getString(0), c.getString(2) == Document.MIME_TYPE_DIR)
            }
        }
        synchronized(cache) { cache[dir] = found }
        return HashMap(found)
    }

    private fun mimeOf(name: String): String =
        MimeTypeMap.getSingleton().getMimeTypeFromExtension(name.substringAfterLast('.', "").lowercase())
            ?: "application/octet-stream"
}
