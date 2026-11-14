package com.softify.softify

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.view.KeyEvent
import android.widget.RemoteViews

class SoftifyTurntableWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        const val ACTION_PLAY_PAUSE = "com.softify.softify.widget.turntable.PLAY_PAUSE"
        const val ACTION_NEXT = "com.softify.softify.widget.turntable.NEXT"
        const val ACTION_PREVIOUS = "com.softify.softify.widget.turntable.PREVIOUS"

        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_softify_turntable)

            // Launch MainActivity when clicking outer turntable container
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingLaunch = PendingIntent.getActivity(
                context,
                0,
                launchIntent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            )
            views.setOnClickPendingIntent(R.id.widget_turntable_container, pendingLaunch)

            // Play/Pause pending intent
            val playPauseIntent = Intent(context, SoftifyTurntableWidgetProvider::class.java).apply {
                action = ACTION_PLAY_PAUSE
            }
            val pendingPlayPause = PendingIntent.getBroadcast(
                context,
                10,
                playPauseIntent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            )
            views.setOnClickPendingIntent(R.id.widget_turntable_play_container, pendingPlayPause)

            // Previous track pending intent
            val prevIntent = Intent(context, SoftifyTurntableWidgetProvider::class.java).apply {
                action = ACTION_PREVIOUS
            }
            val pendingPrev = PendingIntent.getBroadcast(
                context,
                11,
                prevIntent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            )
            views.setOnClickPendingIntent(R.id.widget_turntable_prev, pendingPrev)

            // Next track pending intent
            val nextIntent = Intent(context, SoftifyTurntableWidgetProvider::class.java).apply {
                action = ACTION_NEXT
            }
            val pendingNext = PendingIntent.getBroadcast(
                context,
                12,
                nextIntent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            )
            views.setOnClickPendingIntent(R.id.widget_turntable_next, pendingNext)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun updateAllWidgets(context: Context, isPlaying: Boolean) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, SoftifyTurntableWidgetProvider::class.java)
            val allWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)

            for (widgetId in allWidgetIds) {
                val views = RemoteViews(context.packageName, R.layout.widget_softify_turntable)
                views.setImageViewResource(
                    R.id.widget_turntable_play_pause,
                    if (isPlaying) R.drawable.audio_service_pause else R.drawable.audio_service_play_arrow
                )
                appWidgetManager.updateAppWidget(widgetId, views)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_PLAY_PAUSE -> dispatchMediaKey(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
            ACTION_NEXT -> dispatchMediaKey(context, KeyEvent.KEYCODE_MEDIA_NEXT)
            ACTION_PREVIOUS -> dispatchMediaKey(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS)
        }
    }

    private fun dispatchMediaKey(context: Context, keyCode: Int) {
        val downIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            setPackage(context.packageName)
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
        }
        context.sendBroadcast(downIntent)

        val upIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            setPackage(context.packageName)
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_UP, keyCode))
        }
        context.sendBroadcast(upIntent)
    }
}
