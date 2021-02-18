package com.mostafataghipour.reactnativeuploadmanager

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

interface UploadQueue {
    fun clear()
    fun push(json: JSONObject)
    fun pop(removeIt: Boolean): JSONObject?
    fun isEmpty(): Boolean
    fun remove(id: String)
}


class UploadQueueImp private constructor(context: Context) : UploadQueue {

    companion object {
        private const val PREF_KEY = "RN-UPLOAD_KEY"
        private const val QUEUE_KEY = "RN-UPLOAD-QUEUE_KEY"


        @Volatile private var INSTANCE: UploadQueueImp? = null

        fun getInstance(context: Context): UploadQueueImp =
                INSTANCE ?: synchronized(this) {
                    INSTANCE ?: buildInstance(context).also { INSTANCE = it }
                }

        private fun buildInstance(context: Context) =
                UploadQueueImp(context)
    }



    private val pref: SharedPreferences by lazy {
        return@lazy context.getSharedPreferences(PREF_KEY, Context.MODE_PRIVATE)
    }


    private lateinit var queue: JSONArray

    init {
        load()
    }

    private fun load() {
        val str = pref.getString(QUEUE_KEY, null)
        val jsonArray: JSONArray = if (str.isNullOrEmpty())
            JSONArray()
        else
            JSONArray(str)

        this.queue = jsonArray
    }

    override fun push(json: JSONObject) {
        this.queue.put(json)
        sync()
    }


    override fun pop(removeIt: Boolean): JSONObject? = try {
        val json = this.queue.getJSONObject(0)
        if (removeIt) {
            this.queue.remove(0)
            sync()
        }
        json
    } catch (e: Exception) {
        null
    }


    override fun remove(id: String) {
        try {
            for (i in 0 until this.queue.length()) {
                val item = this.queue.getJSONObject(i)
                if (item.getString("customUploadId") == id) {
                    this.queue.remove(i)
                    sync()
                    break
                }
            }
        } catch (e: Exception) {

        }
    }


    private fun sync() {
        val editor = pref.edit()
        val str = this.queue.toString()
        editor.putString(QUEUE_KEY, str)
        editor.apply()
    }

    override fun clear() {
        this.queue = JSONArray()
        sync()
    }

    override fun isEmpty(): Boolean {
        return this.queue.length() == 0
    }
}