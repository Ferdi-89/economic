package com.financier.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import java.text.NumberFormat
import java.util.Locale

class FinancierWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val views = RemoteViews(context.packageName, R.layout.financier_widget)

        // Read data from SharedPreferences
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val netWorth = prefs.getLong("flutter.net_worth", 0L)
        val income = prefs.getLong("flutter.monthly_income", 0L)
        val expense = prefs.getLong("flutter.monthly_expense", 0L)

        // Format currency
        val formatter = NumberFormat.getCurrencyInstance(Locale("id", "ID")).apply {
            maximumFractionDigits = 0
        }
        val formattedNetWorth = formatter.format(netWorth).replace("Rp", "Rp ")
        val formattedIncome = formatter.format(income).replace("Rp", "Rp ")
        val formattedExpense = formatter.format(expense).replace("Rp", "Rp ")

        // Update views
        views.setTextViewText(R.id.widget_net_worth, formattedNetWorth)
        views.setTextViewText(R.id.widget_income, formattedIncome)
        views.setTextViewText(R.id.widget_expense, formattedExpense)

        // Quick Actions Deep Links
        views.setOnClickPendingIntent(R.id.btn_widget_expense, getDeepLinkPendingIntent(context, "expense", 101))
        views.setOnClickPendingIntent(R.id.btn_widget_income, getDeepLinkPendingIntent(context, "income", 102))
        views.setOnClickPendingIntent(R.id.btn_widget_transfer, getDeepLinkPendingIntent(context, "transfer", 103))

        // Tap widget body to open app home
        val mainIntent = Intent(context, MainActivity::class.java)
        val mainPendingIntent = PendingIntent.getActivity(
            context, 0, mainIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_container, mainPendingIntent)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun getDeepLinkPendingIntent(context: Context, type: String, requestCode: Int): PendingIntent {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("financier://transactions/add?type=$type")).apply {
            `package` = context.packageName
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        return PendingIntent.getActivity(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
