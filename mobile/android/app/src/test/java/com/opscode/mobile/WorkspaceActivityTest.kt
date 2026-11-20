package com.opscode.mobile

import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "w320dp-h640dp")
class WorkspaceActivityTest {
    @Test fun workspaceOpensOnSmallPhoneAndRequiresPairingForRemoteActions() {
        val controller = Robolectric.buildActivity(WorkspaceActivity::class.java).setup()
        try {
            val workspace = controller.get()
            val views = children(workspace.window.decorView).toList()
            assertTrue(views.filterIsInstance<TextView>().any { it.text == "New chat" })
            assertTrue(views.filterIsInstance<TextView>().any { it.text.contains("Pair your Mac") })
            assertFalse(views.filterIsInstance<Button>().first { it.contentDescription == "Send message" }.isEnabled)
            assertTrue(views.filterIsInstance<Button>().first { it.contentDescription == "Settings" }.isEnabled)
            assertFalse(views.filterIsInstance<EditText>().first { it.hint == "Describe a task, or add files…" }.isEnabled)
        } finally { controller.pause().stop().destroy() }
    }

    private fun children(root: View): Sequence<View> = sequence {
        yield(root)
        if (root is ViewGroup) for (index in 0 until root.childCount) yieldAll(children(root.getChildAt(index)))
    }
}
