package com.softify.app.ui.diagnostics

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Share
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

@Composable
fun DiagnosticsScreen(
    viewModel: PlaybackViewModel,
    onClose: () -> Unit,
    modifier: Modifier = Modifier
) {
    val logs by PlaybackLogger.logsFlow.collectAsState()
    val clipboardManager = LocalClipboardManager.current
    val listState = rememberLazyListState()

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
                    text = "Playback Diagnostics",
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

            IconButton(
                onClick = onClose,
                modifier = Modifier.size(48.dp)
            ) {
                Icon(
                    imageVector = Icons.Filled.Close,
                    contentDescription = "Close Diagnostics",
                    tint = Color.White
                )
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
                val activeStream = viewModel.activeStream.collectAsState().value
                if (activeStream != null) {
                    val isFallback = !activeStream.isRequestedQuality || activeStream.provider.contains("fallback", ignoreCase = true) || activeStream.provider.contains("youtube", ignoreCase = true)
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("Stream: ${activeStream.provider} (${activeStream.bitrateKbps} kbps, ${activeStream.codec})", fontSize = 11.sp, color = Color(0xFF60A5FA), fontWeight = FontWeight.SemiBold)
                        Text(if (isFallback) "FALLBACK" else "DIRECT", fontSize = 11.sp, color = if (isFallback) Color(0xFFFBBF24) else Color(0xFF34D399), fontWeight = FontWeight.Bold)
                    }
                }
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    val jankColor = if (viewModel.jankPercentage < 5f) Color(0xFF34D399) else Color(0xFFFBBF24)
                    val formattedJank = ((viewModel.jankPercentage * 10).toInt() / 10f).toString()
                    Text(
                        "JankStats: ${viewModel.jankFramesCount}/${viewModel.jankTotalFrames} ($formattedJank% jank, max ${viewModel.maxFrameDurationMs}ms)",
                        fontSize = 10.sp,
                        color = jankColor,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }
        }

        // Section 1.5: Cover Art Telemetry Card
        Card(
            modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp),
            colors = CardDefaults.cardColors(containerColor = Color(0xFF181528)),
            shape = RoundedCornerShape(12.dp)
        ) {
            Column(modifier = Modifier.padding(12.dp)) {
                Text("Cover Art Telemetry", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = Color(0xFF38BDF8))
                Spacer(modifier = Modifier.height(6.dp))
                val screens = listOf(
                    com.softify.app.ui.components.ScreenType.HOME,
                    com.softify.app.ui.components.ScreenType.SEARCH,
                    com.softify.app.ui.components.ScreenType.LIBRARY,
                    com.softify.app.ui.components.ScreenType.QUEUE
                )
                for (sc in screens) {
                    val (ok, failed, noUrl) = com.softify.app.ui.components.CoverTelemetry.getStats(sc)
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text("${sc.displayName}:", fontSize = 11.sp, color = Color.LightGray, fontWeight = FontWeight.Medium)
                        Text(
                            "OK: $ok | Failed: $failed | No URL: $noUrl",
                            fontSize = 11.sp,
                            color = if (failed > 0) Color(0xFFF87171) else Color(0xFF34D399),
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }

                val recentFails = com.softify.app.ui.components.CoverTelemetry.recentFailures
                if (recentFails.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(6.dp))
                    Text("Recent Failures (last 5):", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = Color(0xFFF87171))
                    for (fail in recentFails.take(5)) {
                        Text(
                            "• [${fail.host}] status=${fail.httpStatus ?: "err"}: ${fail.url.take(50)}...",
                            fontSize = 10.sp,
                            color = Color(0xFFFCA5A5),
                            maxLines = 1,
                            overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis
                        )
                    }
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
                        modifier = Modifier.weight(1f).defaultMinSize(minHeight = 48.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2563EB)),
                        contentPadding = PaddingValues(horizontal = 6.dp, vertical = 8.dp),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text("Play Test URL", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                    }

                    Button(
                        onClick = { viewModel.resolveOnlyTestTrack() },
                        modifier = Modifier.weight(1f).defaultMinSize(minHeight = 48.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF7C3AED)),
                        contentPadding = PaddingValues(horizontal = 6.dp, vertical = 8.dp),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text("Resolve Only", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                    }

                    Button(
                        onClick = { viewModel.resolveAndPlayTestTrack() },
                        modifier = Modifier.weight(1f).defaultMinSize(minHeight = 48.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF059669)),
                        contentPadding = PaddingValues(horizontal = 6.dp, vertical = 8.dp),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text("Resolve + Play", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                    }
                }

                Spacer(modifier = Modifier.height(8.dp))

                Button(
                    onClick = { viewModel.probeLastYouTubeUrl() },
                    modifier = Modifier.fillMaxWidth().defaultMinSize(minHeight = 48.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFD97706)),
                    contentPadding = PaddingValues(horizontal = 8.dp, vertical = 8.dp),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text("Probe last YouTube URL (OkHttp Matrix)", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                }

                Spacer(modifier = Modifier.height(6.dp))

                Button(
                    onClick = { viewModel.openComponentGallery() },
                    modifier = Modifier.fillMaxWidth().defaultMinSize(minHeight = 48.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF4F46E5)),
                    contentPadding = PaddingValues(horizontal = 8.dp, vertical = 8.dp),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text("Open M3 Expressive Component Gallery", fontSize = 11.sp, fontWeight = FontWeight.Bold)
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
                    modifier = Modifier.defaultMinSize(minHeight = 48.dp),
                    contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Icon(Icons.Filled.ContentCopy, contentDescription = "Copy", modifier = Modifier.size(14.dp), tint = Color.White)
                    Spacer(Modifier.width(4.dp))
                    Text("Copy", fontSize = 11.sp, color = Color.White)
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
                    modifier = Modifier.defaultMinSize(minHeight = 48.dp),
                    contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Icon(Icons.Filled.Share, contentDescription = "Share", modifier = Modifier.size(14.dp), tint = Color.White)
                    Spacer(Modifier.width(4.dp))
                    Text("Share", fontSize = 11.sp, color = Color.White)
                }

                OutlinedButton(
                    onClick = { PlaybackLogger.clear() },
                    modifier = Modifier.defaultMinSize(minHeight = 48.dp),
                    contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Icon(Icons.Filled.Delete, contentDescription = "Clear", modifier = Modifier.size(14.dp), tint = Color(0xFFF87171))
                    Spacer(Modifier.width(4.dp))
                    Text("Clear", fontSize = 11.sp, color = Color(0xFFF87171))
                }
            }
        }

        // Section 4: Scrollable Console Log View
        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .background(Color(0xFF07060B), RoundedCornerShape(8.dp))
                .border(1.dp, Color(0xFF27273A), RoundedCornerShape(8.dp))
                .padding(8.dp)
        ) {
            if (logs.isEmpty()) {
                Text(
                    text = "No logs captured yet. Tap actions above to record playback telemetry.",
                    color = Color.DarkGray,
                    fontSize = 11.sp,
                    fontFamily = FontFamily.Monospace,
                    modifier = Modifier.align(Alignment.Center)
                )
            } else {
                LazyColumn(state = listState, modifier = Modifier.fillMaxSize()) {
                    items(logs) { entry ->
                        val logColor = when {
                            entry.contains("ERROR") || entry.contains("failed") || entry.contains("FAIL") || entry.contains("Exception") -> Color(0xFFF87171)
                            entry.contains("READY") || entry.contains("Playing") || entry.contains("320 kbps") -> Color(0xFF34D399)
                            entry.contains("BUFFERING") || entry.contains("Connecting") -> Color(0xFFFBBF24)
                            entry.contains("WARN") || entry.contains("fallback") -> Color(0xFFF97316)
                            else -> Color(0xFFD1D5DB)
                        }
                        Text(
                            text = entry,
                            color = logColor,
                            fontSize = 10.sp,
                            fontFamily = FontFamily.Monospace,
                            lineHeight = 14.sp
                        )
                    }
                }
            }
        }
    }
}
