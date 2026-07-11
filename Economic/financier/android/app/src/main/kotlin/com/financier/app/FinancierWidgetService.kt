package com.financier.app

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import java.text.NumberFormat
import java.util.Locale

class FinancierWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return FinancierWidgetFactory(applicationContext)
    }
}

class FinancierWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var itemList: List<TransactionItem> = ArrayList()

    data class TransactionItem(
        val title: String,
        val amount: Long,
        val type: String,
        val category: String
    )

    override fun onCreate() {}

    override fun onDataSetChanged() {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val jsonStr = prefs.getString("flutter.recent_transactions", "[]") ?: "[]"
        val newList = ArrayList<TransactionItem>()
        try {
            val jsonArray = JSONArray(jsonStr)
            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.getJSONObject(i)
                newList.add(
                    TransactionItem(
                        title = obj.optString("title", "Transaksi"),
                        amount = obj.optLong("amount", 0L),
                        type = obj.optString("type", "expense"),
                        category = obj.optString("category", "Lainnya")
                    )
                )
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        itemList = newList
    }

    override fun onDestroy() {}

    override fun getCount(): Int = itemList.size

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.financier_list_item)
        if (position >= itemList.size) return views

        val item = itemList[position]
        
        views.setTextViewText(R.id.item_title, item.title)
        views.setTextViewText(R.id.item_category, item.category)

        val formatter = NumberFormat.getCurrencyInstance(Locale("id", "ID")).apply {
            maximumFractionDigits = 0
        }
        val formattedAmount = formatter.format(item.amount).replace("Rp", "Rp ")

        if (item.type == "income") {
            views.setTextViewText(R.id.item_amount, "+$formattedAmount")
            views.setTextColor(R.id.item_amount, android.graphics.Color.parseColor("#10B981"))
        } else if (item.type == "expense") {
            views.setTextViewText(R.id.item_amount, "-$formattedAmount")
            views.setTextColor(R.id.item_amount, android.graphics.Color.parseColor("#EF4444"))
        } else {
            views.setTextViewText(R.id.item_amount, formattedAmount)
            views.setTextColor(R.id.item_amount, android.graphics.Color.parseColor("#8F94FB"))
        }

        // Fill-in Intent to pass back through the template
        val fillInIntent = Intent()
        views.setOnClickFillInIntent(R.id.list_item_container, fillInIntent)

        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true
}
