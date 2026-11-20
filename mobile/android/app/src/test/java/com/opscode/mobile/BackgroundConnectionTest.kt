package com.opscode.mobile

import android.Manifest
import android.app.Application
import android.content.Intent
import android.content.pm.PackageManager
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class BackgroundConnectionTest {
    private lateinit var app: Application

    @Before fun setUp() {
        app = RuntimeEnvironment.getApplication()
        app.getSharedPreferences("mac-connection", Application.MODE_PRIVATE).edit().clear().commit()
        CompanionConnection.setActivityVisible(this, false)
    }

    @After fun resetVisibility() {
        CompanionConnection.setActivityVisible(this, false)
    }

    @Test fun pairingRequestsBackgroundServiceEvenWhenNotificationPermissionIsDenied() {
        val shadow = shadowOf(app)
        shadow.denyPermissions(Manifest.permission.POST_NOTIFICATIONS)
        assertEquals(PackageManager.PERMISSION_DENIED, app.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS))
        assertFalse(CompanionConnection.canNotify(app))
        assertTrue(CompanionConnection.enabled(app))

        CompanionConnection.setActivityVisible(this, true)
        CompanionConnection.start(app)

        assertEquals(Intent(app, CompanionConnection::class.java).component, shadow.nextStartedService.component)
    }

    @Test fun explicitOptOutStaysOffAfterReopening() {
        val shadow = shadowOf(app)
        CompanionConnection.setActivityVisible(this, true)
        CompanionConnection.setEnabled(app, false)
        CompanionConnection.setActivityVisible(this, false)
        CompanionConnection.setActivityVisible(this, true)
        CompanionConnection.start(app)

        assertFalse(CompanionConnection.enabled(app))
        assertNull(shadow.nextStartedService)
    }

    @Test fun leavingNotchWhileProjectsIsVisibleDoesNotBackgroundTheService() {
        val workspace = Any()
        CompanionConnection.setActivityVisible(this, true)
        CompanionConnection.setActivityVisible(workspace, true)
        CompanionConnection.setActivityVisible(this, false)
        assertTrue(CompanionConnection.activityVisible)
        CompanionConnection.setActivityVisible(workspace, false)
        assertFalse(CompanionConnection.activityVisible)
    }

    @Test fun serviceStartIsDeferredUntilTheActivityIsVisible() {
        val shadow = shadowOf(app)
        CompanionConnection.setEnabled(app, true)
        assertNull(shadow.nextStartedService)
        CompanionConnection.setActivityVisible(this, true)
        CompanionConnection.start(app)
        assertEquals(Intent(app, CompanionConnection::class.java).component, shadow.nextStartedService.component)
    }
}
