package com.vainve.androidmacnotify.ui.transfer

import android.content.Intent
import android.net.Uri
import com.vainve.androidmacnotify.data.SharedFileDeliveryRecord
import com.vainve.androidmacnotify.data.MacReachabilityStatus
import com.vainve.androidmacnotify.ui.PairingUiState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

class SharedFileDeliveryCoordinator(
    private val transferManager: SharedFileTransferManager,
    private val scope: CoroutineScope,
    private val readState: () -> PairingUiState,
    private val updateState: ((PairingUiState) -> PairingUiState) -> Unit,
    private val targetName: (PairingUiState) -> String?,
    private val onRecordDelivery: (SharedFileDeliveryRecord) -> Unit = {},
    private val onMacReachabilityChanged: (MacReachabilityStatus, String?) -> Unit = { _, _ -> },
) {
    private var pendingSelections: List<SharedFileSelection> = emptyList()
    private var retrySelections: List<SharedFileSelection> = emptyList()
    private var activeCancelToken: SharedFileTransferCancelToken? = null
    private var hasLoadedConfig = false
    private val deliveryRecorder = SharedFileDeliveryRecorder(
        targetName = { targetName(readState()) },
        onRecordDelivery = onRecordDelivery,
    )
    private val uiUpdater = SharedFileDeliveryUiUpdater(
        updateState = updateState,
        targetName = targetName,
        formatFileSize = transferManager::formatFileSize,
    )
    private val transferClient = SharedFileTransferManagerClient(transferManager)
    private val sessionRunner = SharedFileDeliverySessionRunner(
        transferClient = transferClient,
        readState = readState,
        updateState = updateState,
        uiUpdater = uiUpdater,
        deliveryRecorder = deliveryRecorder,
        onMacReachabilityChanged = onMacReachabilityChanged,
    )

    fun markConfigLoaded() {
        hasLoadedConfig = true
        sendPendingSharedFileIfReady()
    }

    fun handleShareIntent(intent: Intent) {
        if (intent.action != Intent.ACTION_SEND && intent.action != Intent.ACTION_SEND_MULTIPLE) return

        val selections = runCatching {
            transferManager.selectionsFrom(intent)
        }.getOrElse {
            showFileSelectionAccessFailure()
            return
        }
        handleSelections(selections)
    }

    fun handleSelectedFiles(uris: List<Uri>) {
        if (uris.isEmpty()) {
            return
        }

        val selections = runCatching {
            transferManager.selectionsFrom(uris)
        }.getOrElse {
            showFileSelectionAccessFailure()
            return
        }
        handleSelections(selections)
    }

    private fun showFileSelectionAccessFailure() {
        pendingSelections = emptyList()
        retrySelections = emptyList()
        uiUpdater.showFileSelectionAccessFailure()
    }

    private fun handleSelections(selections: List<SharedFileSelection>) {
        if (selections.isEmpty()) {
            uiUpdater.showNoFilesFound()
            return
        }

        pendingSelections = selections
        retrySelections = selections
        uiUpdater.showReadingConfig(selections)
        sendPendingSharedFileIfReady()
    }

    fun cancelSharedFileTransfer() {
        val cancelToken = activeCancelToken ?: return
        if (!readState().isSendingSharedFile) return

        cancelToken.cancel()
        uiUpdater.showCancelling()
    }

    fun retrySharedFileTransfer() {
        if (readState().isSendingSharedFile) return
        if (retrySelections.isEmpty()) return

        pendingSelections = retrySelections
        uiUpdater.showRetrying(retrySelections)
        sendPendingSharedFileIfReady()
    }

    fun retrySharedFileDeliveryRecord(record: SharedFileDeliveryRecord) {
        if (readState().isSendingSharedFile) return
        if (record.sourceUris.isEmpty()) return

        val uris = record.sourceUris.map(Uri::parse)
        handleSelectedFiles(uris)
    }

    private fun sendSharedFiles(selections: List<SharedFileSelection>) {
        val cancelToken = SharedFileTransferCancelToken()
        val batchId = transferClient.createTransferId()
        activeCancelToken = cancelToken

        scope.launch {
            val result = sessionRunner.run(
                batchId = batchId,
                selections = selections,
                cancelToken = cancelToken,
            )
            pendingSelections = emptyList()
            retrySelections = result.retrySelections
            clearActiveTransfer(cancelToken)
        }
    }

    private fun sendPendingSharedFileIfReady() {
        if (!hasLoadedConfig || readState().isSendingSharedFile) return
        val selections = pendingSelections
        if (selections.isEmpty()) return
        sendSharedFiles(selections)
    }

    private fun clearActiveTransfer(cancelToken: SharedFileTransferCancelToken) {
        if (activeCancelToken == cancelToken) {
            activeCancelToken = null
        }
    }

}
