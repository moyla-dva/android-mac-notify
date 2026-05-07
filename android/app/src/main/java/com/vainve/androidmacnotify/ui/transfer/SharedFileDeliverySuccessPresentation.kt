package com.vainve.androidmacnotify.ui.transfer

import com.vainve.androidmacnotify.network.SharedFileRelayResponse

internal data class SharedFileDeliverySuccessSummary(
    val message: String,
    val displayFileName: String?,
)

internal data class SharedFileDeliverySuccessSource(
    val fileName: String,
    val sizeLabel: String?,
)

internal data class SharedFileDeliverySuccessPresentation(
    val totalCount: Int,
    val savedFileName: String,
    val renamedCount: Int,
    val recordMessage: String,
    val transferFileName: String,
    val transferSizeLabel: String?,
    val displayFileName: String?,
) {
    fun transferMessage(targetName: String?): String {
        val target = targetName ?: "Mac"
        return if (totalCount == 1) {
            if (renamedCount > 0) {
                "已发送到 $target，Mac 已保存为 $savedFileName。"
            } else {
                "已发送到 $target，可在 Mac 上打开或定位。"
            }
        } else if (renamedCount > 0) {
            "已发送 $totalCount 个文件到 $target，其中 $renamedCount 个已自动改名。"
        } else {
            "已发送 $totalCount 个文件到 $target。"
        }
    }

    fun toSummary(): SharedFileDeliverySuccessSummary {
        return SharedFileDeliverySuccessSummary(
            message = recordMessage,
            displayFileName = displayFileName,
        )
    }
}

internal object SharedFileDeliverySuccessPresenter {
    fun build(
        selections: List<SharedFileSelection>,
        responses: List<SharedFileRelayResponse>,
        formatFileSize: (Long) -> String,
    ): SharedFileDeliverySuccessPresentation {
        return buildFromSources(
            sources = selections.map {
                SharedFileDeliverySuccessSource(
                    fileName = it.fileName,
                    sizeLabel = it.sizeLabel,
                )
            },
            responses = responses,
            formatFileSize = formatFileSize,
        )
    }

    fun buildFromSources(
        sources: List<SharedFileDeliverySuccessSource>,
        responses: List<SharedFileRelayResponse>,
        formatFileSize: (Long) -> String,
    ): SharedFileDeliverySuccessPresentation {
        val totalCount = sources.size
        val firstSource = sources.first()
        val firstResponse = responses.firstOrNull()
        val savedFileName = firstResponse?.fileName?.takeIf { it.isNotBlank() } ?: firstSource.fileName
        val renamedCount = responses.zip(sources).count { (response, source) ->
            response.fileName.isNotBlank() && response.fileName != source.fileName
        }
        val recordMessage = when {
            totalCount == 1 && renamedCount > 0 -> "Mac 已保存为 $savedFileName"
            totalCount == 1 -> "已发送 $savedFileName 到 Mac"
            renamedCount > 0 -> "已发送 $totalCount 个文件到 Mac，其中 $renamedCount 个已自动改名"
            else -> "已发送 $totalCount 个文件到 Mac"
        }

        return SharedFileDeliverySuccessPresentation(
            totalCount = totalCount,
            savedFileName = savedFileName,
            renamedCount = renamedCount,
            recordMessage = recordMessage,
            transferFileName = if (totalCount == 1) savedFileName else "$totalCount 个文件",
            transferSizeLabel = if (totalCount == 1) {
                firstResponse?.size?.let(formatFileSize) ?: firstSource.sizeLabel
            } else {
                "$totalCount 个文件"
            },
            displayFileName = if (totalCount == 1) savedFileName else null,
        )
    }
}
