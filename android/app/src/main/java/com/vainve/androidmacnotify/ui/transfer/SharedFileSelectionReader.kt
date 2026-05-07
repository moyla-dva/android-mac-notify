package com.vainve.androidmacnotify.ui.transfer

import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.OpenableColumns
import android.text.format.Formatter

class SharedFileSelectionReader(
    private val context: Context,
) {
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
        val resolver = context.contentResolver
        val sizeBytes = resolver.fileSize(uri)
        return SharedFileSelection(
            uri = uri,
            fileName = resolver.displayName(uri).ifBlank { "shared-file" },
            sizeLabel = sizeBytes?.let { Formatter.formatFileSize(context, it) },
            sizeBytes = sizeBytes,
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

private fun ContentResolver.displayName(uri: Uri): String {
    return query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
        ?.useFirstString(OpenableColumns.DISPLAY_NAME)
        .orEmpty()
}

private fun ContentResolver.fileSize(uri: Uri): Long? {
    return query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)
        ?.useFirstLong(OpenableColumns.SIZE)
}

private fun Cursor.useFirstString(columnName: String): String? {
    use { cursor ->
        if (!cursor.moveToFirst()) return null
        val columnIndex = cursor.getColumnIndex(columnName)
        return if (columnIndex >= 0) cursor.getString(columnIndex) else null
    }
}

private fun Cursor.useFirstLong(columnName: String): Long? {
    use { cursor ->
        if (!cursor.moveToFirst()) return null
        val columnIndex = cursor.getColumnIndex(columnName)
        if (columnIndex < 0 || cursor.isNull(columnIndex)) return null
        return cursor.getLong(columnIndex)
    }
}
