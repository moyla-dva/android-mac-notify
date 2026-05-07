package com.vainve.androidmacnotify.ui.transfer

import org.junit.Assert.assertEquals
import org.junit.Test

class SharedFileRetrySelectionTest {
    @Test
    fun failedCurrentFileRetriesFromCurrentItem() {
        val files = listOf("first", "second", "third", "fourth")

        val retryItems = remainingItemsForRetry(
            items = files,
            currentIndex = 2,
            includeCurrent = true,
        )

        assertEquals(listOf("third", "fourth"), retryItems)
    }

    @Test
    fun cancellationAfterCompletedCurrentFileRetriesOnlyFutureItems() {
        val files = listOf("first", "second", "third", "fourth")

        val retryItems = remainingItemsForRetry(
            items = files,
            currentIndex = 2,
            includeCurrent = false,
        )

        assertEquals(listOf("fourth"), retryItems)
    }

    @Test
    fun retrySelectionHandlesOutOfRangeIndex() {
        val files = listOf("first", "second")

        assertEquals(files, remainingItemsForRetry(files, currentIndex = -10, includeCurrent = true))
        assertEquals(emptyList<String>(), remainingItemsForRetry(files, currentIndex = 10, includeCurrent = true))
    }
}
