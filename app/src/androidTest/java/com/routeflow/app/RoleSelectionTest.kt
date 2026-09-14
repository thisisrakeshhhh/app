package com.routeflow.app

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.routeflow.app.app.MainActivity
import com.routeflow.app.domain.model.EmployeeRole
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class RoleSelectionTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()

    @Test
    fun allFourRolesOpenCorrectHomeAndCanChangeRole() {
        val expectedTitles = mapOf(
            EmployeeRole.OWNER to "Business overview",
            EmployeeRole.SALESPERSON to "Your sales day",
            EmployeeRole.WAREHOUSE_MANAGER to "Warehouse desk",
            EmployeeRole.DELIVERY_EXECUTIVE to "Your delivery day",
        )
        expectedTitles.forEach { (role, title) ->
            compose.onNodeWithTag("open_workspace").assertIsNotEnabled()
            compose.onNodeWithTag("role_${role.name}").performScrollTo().performClick()
            compose.onNodeWithTag("open_workspace").performClick()
            compose.onNodeWithTag("home_${role.name}").assertIsDisplayed()
            compose.onNodeWithText(title).assertIsDisplayed()
            compose.onNodeWithTag("change_role").performClick()
            compose.onNodeWithTag("role_picker").assertIsDisplayed()
        }
    }

    @Test
    fun backFromHomeClearsRoleEvenAfterActivityRecreation() {
        compose.onNodeWithTag("role_OWNER").performScrollTo().performClick()
        compose.onNodeWithTag("open_workspace").performClick()
        compose.onNodeWithTag("home_OWNER").assertIsDisplayed()
        compose.activityRule.scenario.recreate()
        compose.onNodeWithTag("home_OWNER").assertIsDisplayed()
        compose.activityRule.scenario.onActivity { it.onBackPressedDispatcher.onBackPressed() }
        compose.onNodeWithTag("role_picker").assertIsDisplayed()
        compose.onNodeWithTag("open_workspace").assertIsNotEnabled()
    }
}
