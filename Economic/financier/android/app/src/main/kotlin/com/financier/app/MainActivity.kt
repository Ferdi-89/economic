package com.financier.app

import io.flutter.embedding.android.FlutterActivity
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.financier.app/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "updateWidget") {
                val appWidgetManager = AppWidgetManager.getInstance(applicationContext)

                // 1. Notify Summary Widget
                val summaryIntent = Intent(applicationContext, FinancierWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    val ids = appWidgetManager.getAppWidgetIds(ComponentName(applicationContext, FinancierWidgetProvider::class.java))
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                }
                sendBroadcast(summaryIntent)

                // 2. Notify Transactions List Widget
                val listIds = appWidgetManager.getAppWidgetIds(ComponentName(applicationContext, FinancierListWidgetProvider::class.java))
                appWidgetManager.notifyAppWidgetViewDataChanged(listIds, R.id.transactions_list)

                val listIntent = Intent(applicationContext, FinancierListWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, listIds)
                }
                sendBroadcast(listIntent)

                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }
}
