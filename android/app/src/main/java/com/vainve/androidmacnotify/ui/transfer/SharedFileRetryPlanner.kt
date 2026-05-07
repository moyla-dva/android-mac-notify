package com.vainve.androidmacnotify.ui.transfer

internal fun <T> remainingItemsForRetry(
    items: List<T>,
    currentIndex: Int,
    includeCurrent: Boolean,
): List<T> {
    if (items.isEmpty()) return emptyList()
    val startIndex = currentIndex + if (includeCurrent) 0 else 1
    return items.drop(startIndex.coerceIn(0, items.size))
}
