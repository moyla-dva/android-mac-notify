package com.vainve.androidmacnotify.data

import org.json.JSONArray
import org.json.JSONObject

internal object AppConfigCodecs {
    fun decodeMacReachabilityStatus(raw: String?): MacReachabilityStatus {
        return runCatching {
            MacReachabilityStatus.valueOf(raw.orEmpty())
        }.getOrDefault(MacReachabilityStatus.Unknown)
    }

    fun encodePendingNotificationEvents(events: List<PendingNotificationEvent>): String {
        val array = JSONArray()
        events.forEach { event ->
            array.put(
                JSONObject()
                    .put("eventId", event.eventId)
                    .put("deviceId", event.deviceId)
                    .put("appPackage", event.appPackage)
                    .put("appName", event.appName)
                    .put("title", event.title)
                    .put("text", event.text)
                    .put("postedAt", event.postedAt)
                    .put("notificationKey", event.notificationKey)
            )
        }
        return array.toString()
    }

    fun decodePendingNotificationEvents(rawJson: String): List<PendingNotificationEvent> {
        if (rawJson.isBlank()) return emptyList()

        return runCatching {
            val array = JSONArray(rawJson)
            val events = mutableListOf<PendingNotificationEvent>()
            for (index in 0 until array.length()) {
                val item = array.optJSONObject(index) ?: continue
                val event = PendingNotificationEvent(
                    eventId = item.optString("eventId"),
                    deviceId = item.optString("deviceId"),
                    appPackage = item.optString("appPackage"),
                    appName = item.optString("appName"),
                    title = item.optString("title"),
                    text = item.optString("text"),
                    postedAt = item.optLong("postedAt"),
                    notificationKey = item.optString("notificationKey"),
                )
                if (event.eventId.isNotBlank() && event.deviceId.isNotBlank()) {
                    events.add(event)
                }
            }
            events
        }.getOrDefault(emptyList())
    }

    fun encodeRelayActivityRecords(records: List<RelayActivityRecord>): String {
        val array = JSONArray()
        records.forEach { record ->
            array.put(
                JSONObject()
                    .put("eventId", record.eventId)
                    .put("appPackage", record.appPackage)
                    .put("appName", record.appName)
                    .put("title", record.title)
                    .put("text", record.text)
                    .put("postedAt", record.postedAt)
                    .put("relayedAt", record.relayedAt)
            )
        }
        return array.toString()
    }

    fun decodeRelayActivityRecords(rawJson: String): List<RelayActivityRecord> {
        if (rawJson.isBlank()) return emptyList()

        return runCatching {
            val array = JSONArray(rawJson)
            val records = mutableListOf<RelayActivityRecord>()
            for (index in 0 until array.length()) {
                val item = array.optJSONObject(index) ?: continue
                val record = RelayActivityRecord(
                    eventId = item.optString("eventId"),
                    appPackage = item.optString("appPackage"),
                    appName = item.optString("appName"),
                    title = item.optString("title"),
                    text = item.optString("text"),
                    postedAt = item.optLong("postedAt"),
                    relayedAt = item.optLong("relayedAt"),
                )
                if (record.eventId.isNotBlank() && record.appName.isNotBlank()) {
                    records.add(record)
                }
            }
            records
        }.getOrDefault(emptyList())
    }

    fun encodeSharedFileDeliveryRecords(records: List<SharedFileDeliveryRecord>): String {
        val array = JSONArray()
        records.forEach { record ->
            array.put(
                JSONObject()
                    .put("recordId", record.recordId)
                    .put("fileName", record.fileName)
                    .put("fileCount", record.fileCount)
                    .put("completedCount", record.completedCount)
                    .put("sourceUris", JSONArray(record.sourceUris))
                    .put("targetName", record.targetName.orEmpty())
                    .put("status", record.status.name)
                    .put("message", record.message)
                    .put("canRetry", record.canRetry)
                    .put("finishedAt", record.finishedAt)
                    .apply {
                        record.totalBytes?.let { put("totalBytes", it) }
                    }
            )
        }
        return array.toString()
    }

    fun decodeSharedFileDeliveryRecords(rawJson: String): List<SharedFileDeliveryRecord> {
        if (rawJson.isBlank()) return emptyList()

        return runCatching {
            val array = JSONArray(rawJson)
            val records = mutableListOf<SharedFileDeliveryRecord>()
            for (index in 0 until array.length()) {
                val item = array.optJSONObject(index) ?: continue
                val status = runCatching {
                    SharedFileDeliveryRecordStatus.valueOf(item.optString("status"))
                }.getOrDefault(SharedFileDeliveryRecordStatus.Failed)
                val record = SharedFileDeliveryRecord(
                    recordId = item.optString("recordId"),
                    fileName = item.optString("fileName"),
                    fileCount = item.optInt("fileCount", 1).coerceAtLeast(1),
                    completedCount = item.optInt("completedCount", 0).coerceAtLeast(0),
                    totalBytes = if (item.has("totalBytes") && !item.isNull("totalBytes")) {
                        item.optLong("totalBytes")
                    } else {
                        null
                    },
                    sourceUris = item.optJSONArray("sourceUris")?.let { uriArray ->
                        buildList {
                            for (uriIndex in 0 until uriArray.length()) {
                                uriArray.optString(uriIndex).takeIf { it.isNotBlank() }?.let(::add)
                            }
                        }
                    }.orEmpty(),
                    targetName = item.optString("targetName").takeIf { it.isNotBlank() },
                    status = status,
                    message = item.optString("message"),
                    canRetry = if (item.has("canRetry")) {
                        item.optBoolean("canRetry", true)
                    } else {
                        status == SharedFileDeliveryRecordStatus.Failed ||
                            status == SharedFileDeliveryRecordStatus.Cancelled
                    },
                    finishedAt = item.optLong("finishedAt"),
                )
                if (record.recordId.isNotBlank() && record.fileName.isNotBlank()) {
                    records.add(record)
                }
            }
            records
        }.getOrDefault(emptyList())
    }

    fun nextSharedFileDeliveryRecords(
        current: List<SharedFileDeliveryRecord>,
        record: SharedFileDeliveryRecord,
        maxSize: Int,
        maxSuccessSize: Int,
    ): List<SharedFileDeliveryRecord> {
        val currentWithoutResolvedFailures = if (record.status == SharedFileDeliveryRecordStatus.Success) {
            current.filterNot { existing ->
                existing.recordId != record.recordId &&
                    existing.status != SharedFileDeliveryRecordStatus.Success &&
                    existing.sharesSourceWith(record)
            }
        } else {
            current
        }
        return trimSharedFileDeliveryRecords(
            records = listOf(record) + currentWithoutResolvedFailures.filterNot { it.recordId == record.recordId },
            maxSize = maxSize,
            maxSuccessSize = maxSuccessSize,
        )
    }

    fun trimSharedFileDeliveryRecords(
        records: List<SharedFileDeliveryRecord>,
        maxSize: Int,
        maxSuccessSize: Int,
    ): List<SharedFileDeliveryRecord> {
        val safeMaxSize = maxSize.coerceAtLeast(1)
        val safeMaxSuccessSize = maxSuccessSize.coerceIn(0, safeMaxSize)
        val sortedRecords = records.sortedByDescending { it.finishedAt }
        val attentionRecords = sortedRecords
            .filterNot { it.status == SharedFileDeliveryRecordStatus.Success }
            .take(safeMaxSize)
        val remainingSize = (safeMaxSize - attentionRecords.size).coerceAtLeast(0)
        val successes = sortedRecords
            .filter { it.status == SharedFileDeliveryRecordStatus.Success }
            .take(minOf(safeMaxSuccessSize, remainingSize))
        return (successes + attentionRecords)
            .sortedByDescending { it.finishedAt }
            .take(safeMaxSize)
    }

    private fun SharedFileDeliveryRecord.sharesSourceWith(other: SharedFileDeliveryRecord): Boolean {
        if (sourceUris.isEmpty() || other.sourceUris.isEmpty()) return false
        val sourceSet = sourceUris.toSet()
        return other.sourceUris.any(sourceSet::contains)
    }
}
