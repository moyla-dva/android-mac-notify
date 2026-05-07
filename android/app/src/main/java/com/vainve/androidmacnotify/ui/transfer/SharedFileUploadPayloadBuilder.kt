package com.vainve.androidmacnotify.ui.transfer

import android.content.Context
import android.net.Uri
import com.vainve.androidmacnotify.network.SharedFileRelayPayload
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.asRequestBody
import okio.BufferedSink
import okio.ForwardingSink
import okio.buffer
import java.io.File
import java.io.IOException

private const val SHARED_FILE_TRANSFER_BUFFER_SIZE = 256 * 1024
private const val SHARED_FILE_UPLOAD_CACHE_PREFIX = "share-"
private const val SHARED_FILE_UPLOAD_CACHE_SUFFIX = ".upload"
private const val STALE_SHARED_FILE_UPLOAD_CACHE_AGE_MILLIS = 6 * 60 * 60 * 1000L
private const val MIN_SHARED_FILE_UPLOAD_CACHE_HEADROOM_BYTES = 8L * 1024L * 1024L

class SharedFileUploadPayloadBuilder(
    private val context: Context,
) {
    private val metadataReader = SharedFileMetadataReader(context)

    fun buildPayload(
        uri: Uri,
        deviceId: String,
        shareId: String,
        batchId: String? = null,
        batchIndex: Int? = null,
        batchTotal: Int? = null,
        cancelToken: SharedFileTransferCancelToken,
        onProgress: (sentBytes: Long, totalBytes: Long) -> Unit = { _, _ -> },
    ): SharedFileRelayPayload {
        val metadata = metadataReader.metadataFor(uri)
        val fileName = metadata.fileName
        val declaredSize = metadata.sizeBytes
        cancelToken.throwIfCancelled()
        val mimeType = metadata.mimeType
        val uploadBody = if (shouldCacheBeforeUpload(declaredSize, mimeType, fileName)) {
            cacheUnknownLengthFile(uri, mimeType, cancelToken)
        } else {
            val knownSize = declaredSize!!
            SharedFileBody(
                size = knownSize,
                body = ContentUriRequestBody(
                    context = context,
                    uri = uri,
                    mediaType = mimeType,
                    size = knownSize,
                    cancelToken = cancelToken,
                ),
            )
        }

        return SharedFileRelayPayload(
            deviceId = deviceId,
            shareId = shareId,
            batchId = batchId,
            batchIndex = batchIndex,
            batchTotal = batchTotal,
            fileName = fileName,
            mimeType = mimeType,
            size = uploadBody.size,
            sharedAt = System.currentTimeMillis(),
            fileBody = ProgressRequestBody(
                delegate = uploadBody.body,
                totalBytes = uploadBody.size,
                cancelToken = cancelToken,
                onProgress = onProgress,
            ),
            onCallCreated = cancelToken::attachCall,
            cleanup = uploadBody.cleanup,
        )
    }

    private fun cacheUnknownLengthFile(
        uri: Uri,
        mimeType: String?,
        cancelToken: SharedFileTransferCancelToken,
    ): SharedFileBody {
        val cacheDirectory = File(context.cacheDir, "shared-file-uploads").apply {
            mkdirs()
        }
        cleanupStaleSharedFileUploadCache(cacheDirectory)
        val tempFile = File.createTempFile(
            SHARED_FILE_UPLOAD_CACHE_PREFIX,
            SHARED_FILE_UPLOAD_CACHE_SUFFIX,
            cacheDirectory,
        )
        var totalBytes = 0L
        try {
            context.contentResolver.openInputStream(uri)?.use { input ->
                tempFile.outputStream().use { output ->
                    val buffer = ByteArray(SHARED_FILE_TRANSFER_BUFFER_SIZE)
                    while (true) {
                        cancelToken.throwIfCancelled()
                        val read = input.read(buffer)
                        if (read == -1) break
                        ensureUploadCacheCanAcceptChunk(cacheDirectory, read)
                        totalBytes += read
                        output.write(buffer, 0, read)
                    }
                }
            } ?: error("无法读取文件内容")
        } catch (error: Throwable) {
            tempFile.delete()
            throw error
        }

        return SharedFileBody(
            size = totalBytes,
            body = tempFile.asRequestBody(mimeType.safeMediaType()),
            cleanup = { tempFile.delete() },
        )
    }

    private data class SharedFileBody(
        val size: Long,
        val body: RequestBody,
        val cleanup: () -> Unit = {},
    )
}

private class ContentUriRequestBody(
    private val context: Context,
    private val uri: Uri,
    private val mediaType: String?,
    private val size: Long,
    private val cancelToken: SharedFileTransferCancelToken,
) : RequestBody() {
    override fun contentType() = mediaType.safeMediaType()

    override fun contentLength() = size

    override fun writeTo(sink: BufferedSink) {
        var writtenBytes = 0L
        context.contentResolver.openInputStream(uri)?.use { input ->
            val buffer = ByteArray(SHARED_FILE_TRANSFER_BUFFER_SIZE)
            while (true) {
                cancelToken.throwIfCancelled()
                val read = input.read(buffer)
                if (read == -1) break
                writtenBytes += read
                sink.write(buffer, 0, read)
                cancelToken.throwIfCancelled()
            }
        } ?: throw IOException("无法读取文件内容")

        if (writtenBytes != size) {
            throw IOException("文件大小发生变化，请重新投递")
        }
    }
}

private class ProgressRequestBody(
    private val delegate: RequestBody,
    private val totalBytes: Long,
    private val cancelToken: SharedFileTransferCancelToken,
    private val onProgress: (sentBytes: Long, totalBytes: Long) -> Unit,
) : RequestBody() {
    override fun contentType() = delegate.contentType()

    override fun contentLength() = delegate.contentLength()

    override fun writeTo(sink: BufferedSink) {
        var sentBytes = 0L
        val countingSink = object : ForwardingSink(sink) {
            override fun write(source: okio.Buffer, byteCount: Long) {
                cancelToken.throwIfCancelled()
                super.write(source, byteCount)
                sentBytes += byteCount
                onProgress(sentBytes, totalBytes)
                cancelToken.throwIfCancelled()
            }
        }
        val bufferedSink = countingSink.buffer()
        cancelToken.throwIfCancelled()
        delegate.writeTo(bufferedSink)
        bufferedSink.flush()
        cancelToken.throwIfCancelled()
    }
}

internal fun cleanupStaleSharedFileUploadCache(
    cacheDirectory: File,
    nowMillis: Long = System.currentTimeMillis(),
    maxAgeMillis: Long = STALE_SHARED_FILE_UPLOAD_CACHE_AGE_MILLIS,
) {
    if (!cacheDirectory.isDirectory) return
    val cutoffMillis = nowMillis - maxAgeMillis.coerceAtLeast(0L)
    cacheDirectory.listFiles().orEmpty()
        .asSequence()
        .filter { file ->
            file.isFile &&
                file.name.startsWith(SHARED_FILE_UPLOAD_CACHE_PREFIX) &&
                file.name.endsWith(SHARED_FILE_UPLOAD_CACHE_SUFFIX) &&
                file.lastModified() < cutoffMillis
        }
        .forEach { file ->
            runCatching { file.delete() }
        }
}

internal fun ensureUploadCacheCanAcceptChunk(
    cacheDirectory: File,
    nextChunkBytes: Int,
    minHeadroomBytes: Long = MIN_SHARED_FILE_UPLOAD_CACHE_HEADROOM_BYTES,
) {
    val requiredBytes = safeUploadCacheRequiredBytes(
        nextChunkBytes = nextChunkBytes,
        minHeadroomBytes = minHeadroomBytes,
    )
    if (cacheDirectory.usableSpace < requiredBytes) {
        throw IOException("手机临时空间不足，无法准备这个文件；请清理空间后重新投递。")
    }
}

internal fun safeUploadCacheRequiredBytes(
    nextChunkBytes: Int,
    minHeadroomBytes: Long,
): Long {
    val chunkBytes = nextChunkBytes.toLong().coerceAtLeast(0L)
    val headroomBytes = minHeadroomBytes.coerceAtLeast(0L)
    return if (Long.MAX_VALUE - headroomBytes < chunkBytes) {
        Long.MAX_VALUE
    } else {
        chunkBytes + headroomBytes
    }
}

internal fun shouldCacheBeforeUpload(
    declaredSize: Long?,
    mimeType: String? = null,
    fileName: String? = null,
): Boolean {
    return declaredSize == null ||
        declaredSize <= 0L ||
        isTextLikeSharedFile(mimeType, fileName)
}

private fun isTextLikeSharedFile(mimeType: String?, fileName: String?): Boolean {
    val normalizedMimeType = mimeType.orEmpty().lowercase()
    if (normalizedMimeType.startsWith("text/")) {
        return true
    }
    if (normalizedMimeType in textLikeMimeTypes) {
        return true
    }

    val normalizedFileName = fileName.orEmpty().lowercase()
    return textLikeExtensions.any { normalizedFileName.endsWith(it) }
}

private val textLikeMimeTypes = setOf(
    "application/json",
    "application/xml",
    "application/javascript",
    "application/x-javascript",
    "application/x-sh",
    "application/x-yaml",
    "application/yaml",
)

private val textLikeExtensions = listOf(
    ".txt",
    ".md",
    ".json",
    ".xml",
    ".csv",
    ".tsv",
    ".log",
    ".yaml",
    ".yml",
    ".ini",
    ".conf",
    ".sh",
    ".js",
    ".ts",
    ".kt",
    ".swift",
    ".java",
    ".py",
)

private fun String?.safeMediaType() = this
    ?.takeIf { it.isNotBlank() }
    ?.toMediaTypeOrNull()
    ?: "application/octet-stream".toMediaTypeOrNull()
