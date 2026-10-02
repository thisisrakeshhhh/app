package com.routeflow.app.feature.auth

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Business
import androidx.compose.material.icons.filled.CloudDone
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.routeflow.app.R
import com.routeflow.app.core.design.RFColors

@Composable
fun LoginScreen(
    state: LoginState,
    onUsernameChange: (String) -> Unit,
    onPasswordChange: (String) -> Unit,
    onLogin: () -> Unit,
    onSwitchToDemo: (() -> Unit)? = null,
    currentLanguage: String = "en",
    onLanguageChange: (String) -> Unit = {}
) {
    var passwordVisible by remember { mutableStateOf(false) }

    Surface(
        modifier = Modifier.fillMaxSize(),
        color = Color(0xFFF8FAFC)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .imePadding()
                .navigationBarsPadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            // Language selector top bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 12.dp),
                horizontalArrangement = Arrangement.End,
                verticalAlignment = Alignment.CenterVertically
            ) {
                OutlinedButton(
                    onClick = {
                        onLanguageChange(if (currentLanguage == "en") "hi" else "en")
                    },
                    shape = RoundedCornerShape(20.dp),
                    border = BorderStroke(1.dp, RFColors.Accent.copy(alpha = 0.5f)),
                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp),
                    colors = ButtonDefaults.outlinedButtonColors(
                        containerColor = Color.White,
                        contentColor = RFColors.Primary
                    )
                ) {
                    Icon(
                        imageVector = Icons.Default.Language,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp),
                        tint = RFColors.Accent
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = if (currentLanguage == "en") "हिन्दी (Hindi)" else "English",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold
                    )
                }
            }

            // Branding Icon
            Card(
                modifier = Modifier.size(68.dp),
                shape = RoundedCornerShape(18.dp),
                colors = CardDefaults.cardColors(containerColor = RFColors.Primary),
                elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
            ) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = Icons.Default.Business,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(36.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(14.dp))

            Text(
                text = stringResource(R.string.app_name),
                style = MaterialTheme.typography.headlineLarge.copy(fontSize = 30.sp),
                fontWeight = FontWeight.Black,
                color = RFColors.Primary
            )

            Text(
                text = stringResource(R.string.app_tagline),
                style = MaterialTheme.typography.bodyMedium,
                color = RFColors.Secondary,
                fontWeight = FontWeight.Medium
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Main Credential Card
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(20.dp),
                colors = CardDefaults.cardColors(containerColor = Color.White),
                elevation = CardDefaults.cardElevation(defaultElevation = 3.dp)
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(22.dp)
                ) {
                    Text(
                        text = stringResource(R.string.login_title),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = RFColors.TextPrimary
                    )

                    Spacer(modifier = Modifier.height(18.dp))

                    OutlinedTextField(
                        value = state.username,
                        onValueChange = onUsernameChange,
                        label = { Text(stringResource(R.string.username)) },
                        leadingIcon = {
                            Icon(Icons.Default.Person, contentDescription = null, tint = RFColors.Accent)
                        },
                        modifier = Modifier.fillMaxWidth().testTag("username_field"),
                        singleLine = true,
                        enabled = !state.isLoading,
                        shape = RoundedCornerShape(12.dp)
                    )

                    Spacer(modifier = Modifier.height(14.dp))

                    OutlinedTextField(
                        value = state.password,
                        onValueChange = onPasswordChange,
                        label = { Text(stringResource(R.string.password)) },
                        leadingIcon = {
                            Icon(Icons.Default.Lock, contentDescription = null, tint = RFColors.Accent)
                        },
                        modifier = Modifier.fillMaxWidth().testTag("password_field"),
                        singleLine = true,
                        enabled = !state.isLoading,
                        visualTransformation = if (passwordVisible) VisualTransformation.None else PasswordVisualTransformation(),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                        trailingIcon = {
                            val image = if (passwordVisible) Icons.Filled.Visibility else Icons.Filled.VisibilityOff
                            IconButton(onClick = { passwordVisible = !passwordVisible }) {
                                Icon(imageVector = image, contentDescription = null, tint = RFColors.Secondary)
                            }
                        },
                        shape = RoundedCornerShape(12.dp)
                    )

                    if (state.errorMessage != null) {
                        Spacer(modifier = Modifier.height(12.dp))
                        Surface(
                            shape = RoundedCornerShape(8.dp),
                            color = Color(0xFFFEF2F2),
                            border = BorderStroke(1.dp, Color(0xFFFCA5A5)),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(
                                modifier = Modifier.padding(10.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    imageVector = Icons.Default.ErrorOutline,
                                    contentDescription = null,
                                    tint = RFColors.Error,
                                    modifier = Modifier.size(18.dp)
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = state.errorMessage,
                                    color = RFColors.Error,
                                    style = MaterialTheme.typography.bodySmall,
                                    fontWeight = FontWeight.Medium
                                )
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(20.dp))

                    Button(
                        onClick = onLogin,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(54.dp)
                            .testTag("login_button"),
                        enabled = !state.isLoading && state.username.isNotBlank() && state.password.isNotBlank(),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = RFColors.Primary,
                            contentColor = Color.White,
                            disabledContainerColor = RFColors.Primary.copy(alpha = 0.4f),
                            disabledContentColor = Color.White.copy(alpha = 0.7f)
                        ),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        if (state.isLoading) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(24.dp),
                                color = Color.White,
                                strokeWidth = 2.dp
                            )
                            Spacer(modifier = Modifier.width(10.dp))
                            Text(
                                text = stringResource(R.string.logging_in),
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold,
                                color = Color.White
                            )
                        } else {
                            Text(
                                text = stringResource(R.string.login_button),
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold,
                                color = Color.White
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(20.dp))

            // Quick Jaipur Field Accounts Autofill (2 comfortable rows)
            Text(
                text = "Jaipur Operations Accounts (Click to Fill):",
                style = MaterialTheme.typography.labelSmall,
                color = RFColors.Secondary,
                fontWeight = FontWeight.SemiBold
            )

            Spacer(modifier = Modifier.height(8.dp))

            // Row 1: Management & Sales
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally)
            ) {
                listOf(
                    "owner" to "Owner",
                    "admin" to "Admin",
                    "sales" to "Sales"
                ).forEach { (user, label) ->
                    val isSelected = state.username == user
                    OutlinedButton(
                        onClick = {
                            onUsernameChange(user)
                            onPasswordChange("password123")
                        },
                        colors = ButtonDefaults.outlinedButtonColors(
                            containerColor = if (isSelected) RFColors.Primary else Color.White,
                            contentColor = if (isSelected) Color.White else RFColors.Primary
                        ),
                        border = BorderStroke(
                            1.dp,
                            if (isSelected) RFColors.Primary else RFColors.Outline
                        ),
                        contentPadding = PaddingValues(horizontal = 14.dp, vertical = 6.dp),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text(
                            text = label,
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(6.dp))

            // Row 2: Warehouse & Delivery
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally)
            ) {
                listOf(
                    "warehouse" to "Warehouse Manager",
                    "delivery" to "Delivery Executive"
                ).forEach { (user, label) ->
                    val isSelected = state.username == user
                    OutlinedButton(
                        onClick = {
                            onUsernameChange(user)
                            onPasswordChange("password123")
                        },
                        colors = ButtonDefaults.outlinedButtonColors(
                            containerColor = if (isSelected) RFColors.Primary else Color.White,
                            contentColor = if (isSelected) Color.White else RFColors.Primary
                        ),
                        border = BorderStroke(
                            1.dp,
                            if (isSelected) RFColors.Primary else RFColors.Outline
                        ),
                        contentPadding = PaddingValues(horizontal = 14.dp, vertical = 6.dp),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text(
                            text = label,
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Cloud Status Badge
            Surface(
                shape = RoundedCornerShape(16.dp),
                color = Color(0xFFF1F5F9),
                border = BorderStroke(1.dp, Color(0xFFE2E8F0))
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.CloudDone,
                        contentDescription = null,
                        tint = RFColors.Success,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = "Cloudflare Edge & Local Live Sync",
                        style = MaterialTheme.typography.labelSmall,
                        color = RFColors.Secondary,
                        fontWeight = FontWeight.Medium
                    )
                }
            }

            if (onSwitchToDemo != null) {
                Spacer(modifier = Modifier.height(10.dp))
                TextButton(onClick = onSwitchToDemo) {
                    Text(
                        text = "Switch to Offline Workspace",
                        color = RFColors.Accent,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }
        }
    }
}
