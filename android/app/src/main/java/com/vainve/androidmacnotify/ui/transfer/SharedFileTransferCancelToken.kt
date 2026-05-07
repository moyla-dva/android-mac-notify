package com.vainve.androidmacnotify.ui.transfer

import okhttp3.Call
import java.io.IOException
import java.util.concurrent.atomic.AtomicBoolean

class SharedFileTransferCancelToken {
    private val isCancelledValue = AtomicBoolean(false)

    @Volatile
    private var activeCall: Call? = null

    val isCancelled: Boolean
        get() = isCancelledValue.get()

    fun attachCall(call: Call) {
        activeCall = call
        if (isCancelled) {
            call.cancel()
        }
    }

    fun cancel() {
        isCancelledValue.set(true)
        activeCall?.cancel()
    }

    fun throwIfCancelled() {
        if (isCancelled) {
            throw IOException("文件投递已取消")
        }
    }
}
