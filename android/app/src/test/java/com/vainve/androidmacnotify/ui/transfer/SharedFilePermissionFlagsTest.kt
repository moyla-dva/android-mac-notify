package com.vainve.androidmacnotify.ui.transfer

import android.content.Intent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SharedFilePermissionFlagsTest {
    @Test
    fun persistableReadPermissionRequiresReadAndPersistableGrants() {
        val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
            Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION

        assertEquals(
            Intent.FLAG_GRANT_READ_URI_PERMISSION,
            persistableReadPermissionModeFlags(flags),
        )
    }

    @Test
    fun persistableReadPermissionSkipsTemporaryReadGrant() {
        assertNull(persistableReadPermissionModeFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
    }

    @Test
    fun persistableReadPermissionSkipsPersistableWithoutReadGrant() {
        assertNull(persistableReadPermissionModeFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION))
    }
}
