package com.vainve.androidmacnotify.ui.transfer

import android.content.ContentResolver
import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.provider.OpenableColumns

internal data class SharedFileMetadata(
    val fileName: String,
    val sizeBytes: Long?,
    val mimeType: String?,
)

internal class SharedFileMetadataReader(
    private val context: Context,
) {
    fun metadataFor(uri: Uri): SharedFileMetadata {
        val resolver = context.contentResolver
        return SharedFileMetadata(
            fileName = resolver.displayName(uri).ifBlank { "shared-file" },
            sizeBytes = resolver.fileSize(uri),
            mimeType = resolver.getType(uri),
        )
    }
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
