package com.vainve.androidmacnotify.network

internal fun hostForUrl(host: String): String {
    val trimmed = host.trim()
    if (!trimmed.contains(":")) return trimmed
    return "[${trimmed.replace("%", "%25")}]"
}
