package com.vainve.androidmacnotify.ui.transfer

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.text.format.Formatter

class SharedFileSelectionReader(
    private val context: Context,
) {
    private val metadataReader = SharedFileMetadataReader(context)

    fun selectionsFrom(intent: Intent): List<SharedFileSelection> {
        val streamUris = when (intent.action) {
            Intent.ACTION_SEND -> intent.sharedStreamUri()?.let(::listOf).orEmpty()
            Intent.ACTION_SEND_MULTIPLE -> intent.sharedStreamUris()
            else -> emptyList()
        }
        persistSharedReadPermissions(streamUris, intent.flags)

        return streamUris
            .distinct()
            .map(::selectionFrom)
    }

    fun selectionsFrom(uris: List<Uri>): List<SharedFileSelection> {
        return uris
            .distinct()
            .map(::selectionFrom)
    }

    private fun selectionFrom(uri: Uri): SharedFileSelection {
        val metadata = metadataReader.metadataFor(uri)
        return SharedFileSelection(
            uri = uri,
            fileName = metadata.fileName,
            sizeLabel = metadata.sizeBytes?.let { Formatter.formatFileSize(context, it) },
            sizeBytes = metadata.sizeBytes,
        )
    }

    private fun persistSharedReadPermissions(uris: List<Uri>, intentFlags: Int) {
        val modeFlags = persistableReadPermissionModeFlags(intentFlags) ?: return
        uris.distinct().forEach { uri ->
            runCatching {
                context.contentResolver.takePersistableUriPermission(uri, modeFlags)
            }
        }
    }
}

internal fun persistableReadPermissionModeFlags(intentFlags: Int): Int? {
    val hasReadGrant = intentFlags and Intent.FLAG_GRANT_READ_URI_PERMISSION != 0
    val hasPersistableGrant = intentFlags and Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION != 0
    return if (hasReadGrant && hasPersistableGrant) {
        Intent.FLAG_GRANT_READ_URI_PERMISSION
    } else {
        null
    }
}

private fun Intent.sharedStreamUri(): Uri? {
    @Suppress("DEPRECATION")
    return getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
        ?: clipData?.takeIf { it.itemCount == 1 }?.getItemAt(0)?.uri
}

private fun Intent.sharedStreamUris(): List<Uri> {
    @Suppress("DEPRECATION")
    val extraStreams = getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM).orEmpty()
    val clipStreams = buildList {
        val clipData = clipData ?: return@buildList
        for (index in 0 until clipData.itemCount) {
            clipData.getItemAt(index)?.uri?.let(::add)
        }
    }

    return (extraStreams + clipStreams).distinct()
}
