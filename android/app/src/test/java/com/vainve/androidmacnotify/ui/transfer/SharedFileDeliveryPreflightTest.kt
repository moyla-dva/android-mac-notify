package com.vainve.androidmacnotify.ui.transfer

import com.vainve.androidmacnotify.ui.PairingUiState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SharedFileDeliveryPreflightTest {
    @Test
    fun pausedRelayFailsWithRetryableMessage() {
        val result = SharedFileDeliveryPreflight.check(
            PairingUiState(relayEnabled = false)
        ) as SharedFileDeliveryPreflightResult.Failed

        assertTrue(result.canRetry)
        assertEquals("手机端已暂停接力，恢复后再投递文件", result.message)
    }

    @Test
    fun missingPairingFailsWithoutRetry() {
        val result = SharedFileDeliveryPreflight.check(
            PairingUiState(host = "", port = "38471", deviceToken = "")
        ) as SharedFileDeliveryPreflightResult.Failed

        assertFalse(result.canRetry)
        assertEquals("请先连接并配对 Mac 后再投递文件", result.message)
    }

    @Test
    fun validConfigBuildsDeliveryTarget() {
        val result = SharedFileDeliveryPreflight.check(
            PairingUiState(
                host = " 192.168.1.2 ",
                port = "38471",
                deviceToken = "device-token",
                deviceId = "android-device",
            )
        ) as SharedFileDeliveryPreflightResult.Ready

        assertEquals("192.168.1.2", result.target.host)
        assertEquals(38471, result.target.port)
        assertEquals("device-token", result.target.deviceToken)
        assertEquals("android-device", result.target.deviceId)
    }
}
