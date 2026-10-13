package com.softify.softify

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews

class SoftifyAppWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        const val ACTION_PLAY_PAUSE = "com.softify.softify.widget.PLAY_PAUSE"

        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_softify_compact)

            // Intent to launch main application when tapping widget
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingLaunch = PendingIntent.getActivity(
                context,
                0,
                launchIntent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            )
            views.setOnClickPendingIntent(R.id.widget_container, pendingLaunch)

            // Intent for Play/Pause toggle
            val playPauseIntent = Intent(context, SoftifyAppWidgetProvider::class.java).apply {
                action = ACTION_PLAY_PAUSE
            }
            val pendingPlayPause = PendingIntent.getBroadcast(
                context,
                1,
                playPauseIntent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            )
            views.setOnClickPendingIntent(R.id.widget_play_pause, pendingPlayPause)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun updateAllWidgets(context: Context, title: String, artist: String, isPlaying: Boolean) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, SoftifyAppWidgetProvider::class.java)
            val allWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)

            for (widgetId in allWidgetIds) {
                val views = RemoteViews(context.packageName, R.layout.widget_softify_compact)
                views.setTextViewText(R.id.widget_title, title)
                views.setTextViewText(R.id.widget_artist, artist)
                views.setImageViewResource(
                    R.id.widget_play_pause,
                    if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
                )
                appWidgetManager.updateAppWidget(widgetId, views)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_PLAY_PAUSE) {
            // Forward media button event to AudioService
            val mediaIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
                setPackage(context.packageName)
            }
            context.sendBroadcast(mediaIntent)
        }
    }
}
