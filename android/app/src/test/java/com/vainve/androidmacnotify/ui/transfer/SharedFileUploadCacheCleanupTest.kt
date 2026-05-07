package com.vainve.androidmacnotify.ui.transfer

import org.junit.Assert.assertFalse
import org.junit.Assert.assertEquals
import org.junit.Assert.fail
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException
import java.nio.file.Files

class SharedFileUploadCacheCleanupTest {
    @Test
    fun cleanupRemovesOnlyStaleUploadCacheFiles() {
        val cacheDirectory = Files.createTempDirectory("amn-upload-cache-test").toFile()
        try {
            val nowMillis = 1_777_900_000_000L
            val staleUpload = cacheDirectory.resolve("share-stale.upload").apply {
                writeText("stale")
                setLastModified(nowMillis - 7 * 60 * 60 * 1000L)
            }
            val freshUpload = cacheDirectory.resolve("share-fresh.upload").apply {
                writeText("fresh")
                setLastModified(nowMillis - 1_000L)
            }
            val unrelatedUpload = cacheDirectory.resolve("other-stale.upload").apply {
                writeText("unrelated")
                setLastModified(nowMillis - 7 * 60 * 60 * 1000L)
            }

            cleanupStaleSharedFileUploadCache(cacheDirectory, nowMillis = nowMillis)

            assertFalse(staleUpload.exists())
            assertTrue(freshUpload.exists())
            assertTrue(unrelatedUpload.exists())
        } finally {
            cacheDirectory.deleteRecursively()
        }
    }

    @Test
    fun cleanupIgnoresMissingDirectory() {
        val missingDirectory = Files.createTempDirectory("amn-upload-cache-test").toFile()
            .resolve("missing")

        cleanupStaleSharedFileUploadCache(missingDirectory)

        assertFalse(missingDirectory.exists())
    }

    @Test
    fun uploadCacheSpaceCheckFailsWithClearErrorWhenHeadroomCannotFit() {
        val cacheDirectory = Files.createTempDirectory("amn-upload-cache-test").toFile()
        try {
            try {
                ensureUploadCacheCanAcceptChunk(
                    cacheDirectory = cacheDirectory,
                    nextChunkBytes = 1,
                    minHeadroomBytes = Long.MAX_VALUE,
                )
                fail("Expected upload cache space check to fail")
            } catch (error: IOException) {
                assertEquals(
                    "手机临时空间不足，无法准备这个文件；请清理空间后重新投递。",
                    error.message,
                )
            }
        } finally {
            cacheDirectory.deleteRecursively()
        }
    }

    @Test
    fun uploadCacheRequiredBytesSaturatesInsteadOfOverflowing() {
        assertEquals(
            Long.MAX_VALUE,
            safeUploadCacheRequiredBytes(
                nextChunkBytes = 1,
                minHeadroomBytes = Long.MAX_VALUE,
            ),
        )
        assertEquals(
            0L,
            safeUploadCacheRequiredBytes(
                nextChunkBytes = -1,
                minHeadroomBytes = -1,
            ),
        )
    }

    @Test
    fun nonPositiveDeclaredSizeUsesCachePath() {
        assertTrue(shouldCacheBeforeUpload(null))
        assertTrue(shouldCacheBeforeUpload(-1L))
        assertTrue(shouldCacheBeforeUpload(0L))
        assertFalse(shouldCacheBeforeUpload(1L))
    }

    @Test
    fun textLikeFilesUseCachePathEvenWhenDeclaredSizeIsPositive() {
        assertTrue(shouldCacheBeforeUpload(632_403L, mimeType = "text/plain", fileName = "idacrypt.txt"))
        assertTrue(shouldCacheBeforeUpload(632_403L, mimeType = null, fileName = "idacrypt.txt"))
        assertTrue(shouldCacheBeforeUpload(632_403L, mimeType = "application/json", fileName = "payload.bin"))
        assertFalse(shouldCacheBeforeUpload(632_403L, mimeType = "image/jpeg", fileName = "photo.jpg"))
        assertFalse(shouldCacheBeforeUpload(274_000_000L, mimeType = "application/vnd.android.package-archive", fileName = "app.apk"))
    }
}
