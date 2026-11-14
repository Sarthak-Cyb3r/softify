package com.softify.app.ui.diagnostics

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.softify.app.util.PlaybackLogger
import com.softify.app.viewmodel.PlaybackViewModel
import kotlinx.coroutines.launch

@Composable
fun DiagnosticsScreen(
    viewModel: PlaybackViewModel,
    onClose: () -> Unit,
    modifier: Modifier = Modifier
) {
    val logs by PlaybackLogger.logsFlow.collectAsState()
    val clipboardManager = LocalClipboardManager.current
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()

    // Auto-scroll to bottom when new logs arrive
    LaunchedEffect(logs.size) {
        if (logs.isNotEmpty()) {
            listState.animateScrollToItem(logs.size - 1)
        }
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(Color(0xFF0D0C15))
            .statusBarsPadding()
            .padding(16.dp)
    ) {
        // Header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text(
                    text = "🛠 Playback Diagnostics",
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
                Text(
                    text = "Live telemetry & direct Media3 audio testing",
                    fontSize = 12.sp,
                    color = Color.Gray
                )
            }

            IconButton(onClick = onClose) {
                Text("✕", fontSize = 22.sp, color = Color.White)
            }
        }

        // Section 1: System Info Card
        Card(
            modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp),
            colors = CardDefaults.cardColors(containerColor = Color(0xFF181528)),
            shape = RoundedCornerShape(12.dp)
        ) {
            Column(modifier = Modifier.padding(12.dp)) {
                Text("System & Native Engine", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = Color(0xFF6EE7B7))
                Spacer(modifier = Modifier.height(4.dp))
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("App: ${viewModel.appVersion}", fontSize = 11.sp, color = Color.LightGray)
                    Text("ABI: ${viewModel.abi}", fontSize = 11.sp, color = Color.LightGray)
                }
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("OS: ${viewModel.osVersion}", fontSize = 11.sp, color = Color.LightGray)
                    val nativeColor = if (viewModel.isNativeLibLoaded) Color(0xFF34D399) else Color(0xFFF87171)
                    Text("libsoftify_core: ${if (viewModel.isNativeLibLoaded) "LOADED" else "NOT LOADED"}", fontSize = 11.sp, color = nativeColor, fontWeight = FontWeight.Bold)
                }
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    val mcColor = if (viewModel.isMediaControllerConnected) Color(0xFF34D399) else Color(0xFFFBBF24)
                    Text("MediaController: ${if (viewModel.isMediaControllerConnected) "CONNECTED" else "CONNECTING/IDLE"}", fontSize = 11.sp, color = mcColor, fontWeight = FontWeight.SemiBold)
                    Text("Preset: ${viewModel.qualityPreset.collectAsState().value.name}", fontSize = 11.sp, color = Color.LightGray)
                }
            }
        }

        // Section 2: Test Action Buttons Card
        Card(
            modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp),
            colors = CardDefaults.cardColors(containerColor = Color(0xFF181528)),
            shape = RoundedCornerShape(12.dp)
        ) {
            Column(modifier = Modifier.padding(12.dp)) {
                Text("Pipeline Isolation Tests", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = Color(0xFFA78BFA))
                Spacer(modifier = Modifier.height(8.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Button(
                        onClick = { viewModel.playTestDirectUrl() },
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2563EB)),
                        contentPadding = PaddingValues(horizontal = 6.dp, vertical = 8.dp),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text("▶ Play Test URL", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                    }

                    Button(
                        onClick = { viewModel.resolveOnlyTestTrack() },
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF7C3AED)),
                        contentPadding = PaddingValues(horizontal = 6.dp, vertical = 8.dp),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text("🔍 Resolve Only", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                    }

                    Button(
                        onClick = { viewModel.resolveAndPlayTestTrack() },
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF059669)),
                        contentPadding = PaddingValues(horizontal = 6.dp, vertical = 8.dp),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text("⚡ Resolve+Play", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                    }
                }

                Spacer(modifier = Modifier.height(8.dp))

                Button(
                    onClick = { viewModel.probeLastYouTubeUrl() },
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFD97706)),
                    contentPadding = PaddingValues(horizontal = 8.dp, vertical = 8.dp),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text("🔬 Probe last YouTube URL (OkHttp Matrix)", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                }
            }
        }

        // Section 3: Log Toolbar
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 4.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Live Log (${logs.size}/300)",
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                color = Color.LightGray
            )

            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                OutlinedButton(
                    onClick = {
                        val fullLog = PlaybackLogger.getAllLogs()
                        clipboardManager.setText(AnnotatedString(fullLog))
                        viewModel.showSnackbar("Logs copied to clipboard (${logs.size} lines)")
                    },
                    contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text("📋 Copy", fontSize = 11.sp, color = Color.White)
                }

                OutlinedButton(
                    onClick = {
                        val fullLog = PlaybackLogger.getAllLogs()
                        val shareHandler = viewModel.onShareText
                        if (shareHandler != null) {
                            shareHandler.invoke(fullLog)
                        } else {
                            clipboardManager.setText(AnnotatedString(fullLog))
                            viewModel.showSnackbar("Share unavailable; copied to clipboard")
                        }
                    },
                    contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text("📤 Share", fontSize = 11.sp, color = Color.White)
                }

                OutlinedButton(
                    onClick = { PlaybackLogger.clear() },
                    contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text("🗑 Clear", fontSize = 11.sp, color = Color(0xFFF87171))
                }
            }
        }

        // Section 4: Scrollable Console Log View
        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .background(Color(0xFF07060A), RoundedCornerShape(8.dp))
                .border(1.dp, Color(0xFF222030), RoundedCornerShape(8.dp))
                .padding(8.dp)
        ) {
            if (logs.isEmpty()) {
                Text(
                    text = "No playback logs captured yet. Tap a song or use test buttons above.",
                    fontSize = 12.sp,
                    color = Color.DarkGray,
                    modifier = Modifier.align(Alignment.Center)
                )
            } else {
                LazyColumn(
                    state = listState,
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.spacedBy(3.dp)
                ) {
                    items(logs) { line ->
                        val lineColor = when {
                            line.contains("error", ignoreCase = true) || line.contains("FAILED", ignoreCase = true) -> Color(0xFFF87171)
                            line.contains("Resolve end", ignoreCase = true) || line.contains("READY", ignoreCase = true) || line.contains("CONNECTED", ignoreCase = true) -> Color(0xFF34D399)
                            line.contains("Resolve start", ignoreCase = true) || line.contains("BUFFERING", ignoreCase = true) -> Color(0xFFFBBF24)
                            line.contains("Tap:", ignoreCase = true) || line.contains("Test button", ignoreCase = true) -> Color(0xFF60A5FA)
                            else -> Color(0xFFD1D5DB)
                        }
                        Text(
                            text = line,
                            fontFamily = FontFamily.Monospace,
                            fontSize = 10.sp,
                            color = lineColor,
                            lineHeight = 14.sp
                        )
                    }
                }
            }
        }
    }
}
