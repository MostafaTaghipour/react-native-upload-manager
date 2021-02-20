package com.mostafataghipour.reactnativeuploadmanager

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.util.Log
import android.webkit.MimeTypeMap
import com.facebook.react.bridge.*
import net.gotev.uploadservice.BinaryUploadRequest
import net.gotev.uploadservice.MultipartUploadRequest
import net.gotev.uploadservice.UploadNotificationConfig
import net.gotev.uploadservice.UploadService
import net.gotev.uploadservice.okhttp.OkHttpStack
import okhttp3.OkHttpClient
import java.io.File
import java.util.*
import java.util.concurrent.TimeUnit


class RNUploadManagerModule(reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext), LifecycleEventListener {

    override fun getName() = "RNUploadManager"
    private val TAG = "UploaderBridge"
    internal var notificationChannelID = "BackgroundUploadChannel"
    internal val queue: UploadQueue by lazy {
        return@lazy UploadQueueImp.getInstance(this.reactApplicationContext)
    }

    private var uploadReceiver: UploadReceiver? = null

    init {
        reactContext.addLifecycleEventListener(this)
        if (uploadReceiver == null) {
            uploadReceiver = UploadReceiver(this)
            uploadReceiver?.register(reactContext)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.DONUT) {
            UploadService.NAMESPACE = reactContext.applicationInfo.packageName
        }
//        UploadService.HTTP_STACK = OkHttpStack()
    }


    /*
    Gets file information for the path specified.  Example valid path is: /storage/extSdCard/DCIM/Camera/20161116_074726.mp4
    Returns an object such as: {extension: "mp4", size: "3804316", exists: true, mimeType: "video/mp4", name: "20161116_074726.mp4"}
     */
    @ReactMethod
    fun getFileInfo(path: String?, promise: Promise) {
        try {
            val params = Arguments.createMap()
            val fileInfo = File(path)
            params.putString("name", fileInfo.name)
            if (!fileInfo.exists() || !fileInfo.isFile) {
                params.putBoolean("exists", false)
            } else {
                params.putBoolean("exists", true)
                params.putString("size", fileInfo.length().toString()) //use string form of long because there is no putLong and converting to int results in a max size of 17.2 gb, which could happen.  Javascript will need to convert it to a number
                val extension = MimeTypeMap.getFileExtensionFromUrl(path)
                params.putString("extension", extension)
                val mimeType = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension.toLowerCase())
                params.putString("mimeType", mimeType)
            }
            promise.resolve(params)
        } catch (exc: Exception) {
            exc.printStackTrace()
            Log.e(TAG, exc.message, exc)
            promise.reject(exc)
        }
    }


    /*
     * Starts a file upload.
     * Returns a promise with the string ID of the upload.
     */
    @ReactMethod
    fun startUpload(options: ReadableMap, promise: Promise?) {

        for (key in arrayOf("url", "path")) {
            if (!options.hasKey(key)) {
                promise?.reject(java.lang.IllegalArgumentException("Missing '$key' field."))
                return
            }
            if (options.getType(key) != ReadableType.String) {
                promise?.reject(java.lang.IllegalArgumentException("$key must be a string."))
                return
            }
        }
        if (options.hasKey("headers") && options.getType("headers") != ReadableType.Map) {
            promise?.reject(java.lang.IllegalArgumentException("headers must be a hash."))
            return
        }
        if (options.hasKey("notification") && options.getType("notification") != ReadableType.Map) {
            promise?.reject(java.lang.IllegalArgumentException("notification must be a hash."))
            return
        }

        var requestType: String? = "raw"
        if (options.hasKey("type")) {
            requestType = options.getString("type")
            if (requestType == null) {
                promise?.reject(java.lang.IllegalArgumentException("type must be string."))
                return
            }
            if (requestType != "raw" && requestType != "multipart") {
                promise?.reject(java.lang.IllegalArgumentException("type should be string: raw or multipart."))
                return
            }
        }
        val notification: WritableMap = WritableNativeMap()
        notification.putBoolean("enabled", true)
        if (options.hasKey("notification")) {
            notification.merge(options.getMap("notification")!!)
        }

//        val application = reactApplicationContext.applicationContext as Application

        reactApplicationContext.addLifecycleEventListener(this)

        if (notification.hasKey("notificationChannel")) {
            notificationChannelID = notification.getString("notificationChannel")!!
        }

        createNotificationChannel(reactApplicationContext)

        configureUploadServiceHTTPStack(options, promise)

        val url = options.getString("url")
        val filePath = options.getString("path")
        val method = if (options.hasKey("method") && options.getType("method") == ReadableType.String) options.getString("method") else "POST"
        val maxRetries = if (options.hasKey("maxRetries") && options.getType("maxRetries") == ReadableType.Number) options.getInt("maxRetries") else 2
        val customUploadId = if (options.hasKey("customUploadId") && options.getType("method") == ReadableType.String) options.getString("customUploadId") else null
        try {

            val request = if (requestType == "raw") {
                BinaryUploadRequest(this.reactApplicationContext, customUploadId, url)
                        .setFileToUpload(filePath)
            } else {
                if (!options.hasKey("field")) {
                    promise?.reject(java.lang.IllegalArgumentException("field is required field for multipart type."))
                    return
                }
                if (options.getType("field") != ReadableType.String) {
                    promise?.reject(java.lang.IllegalArgumentException("field must be string."))
                    return
                }
                MultipartUploadRequest(this.reactApplicationContext, customUploadId, url!!)
                        .addFileToUpload(filePath!!, options.getString("field")!!)
            }
            request.setMethod(method!!)
                    .setMaxRetries(maxRetries)
                    .setDelegate(null);

            if (notification.getBoolean("enabled")) {
                val notificationConfig = UploadNotificationConfig()
                if (notification.hasKey("notificationChannel")) {
                    notificationConfig.setNotificationChannelId(notification.getString("notificationChannel")!!)
                }
                if (notification.hasKey("autoClear") && notification.getBoolean("autoClear")) {
                    notificationConfig.completed.autoClear = true
                    notificationConfig.cancelled.autoClear = true
                    notificationConfig.error.autoClear = true
                }
                if (notification.hasKey("enableRingTone") && notification.getBoolean("enableRingTone")) {
                    notificationConfig.setRingToneEnabled(true)
                }
                if (notification.hasKey("onCompleteTitle")) {
                    notificationConfig.completed.title = notification.getString("onCompleteTitle")
                }
                if (notification.hasKey("onCompleteMessage")) {
                    notificationConfig.completed.message = notification.getString("onCompleteMessage")
                }
                if (notification.hasKey("onErrorTitle")) {
                    notificationConfig.error.title = notification.getString("onErrorTitle")
                }
                if (notification.hasKey("onErrorMessage")) {
                    notificationConfig.error.message = notification.getString("onErrorMessage")
                }
                if (notification.hasKey("onProgressTitle")) {
                    notificationConfig.progress.title = notification.getString("onProgressTitle")
                }
                if (notification.hasKey("onProgressMessage")) {
                    notificationConfig.progress.message = notification.getString("onProgressMessage")
                }
                if (notification.hasKey("onCancelledTitle")) {
                    notificationConfig.cancelled.title = notification.getString("onCancelledTitle")
                }
                if (notification.hasKey("onCancelledMessage")) {
                    notificationConfig.cancelled.message = notification.getString("onCancelledMessage")
                }
                request.setNotificationConfig(notificationConfig)
            }
            if (options.hasKey("parameters")) {
                if (requestType == "raw") {
                    promise?.reject(java.lang.IllegalArgumentException("Parameters supported only in multipart type"))
                    return
                }
                val parameters = options.getMap("parameters")
                val keys = parameters!!.keySetIterator()
                while (keys.hasNextKey()) {
                    val key = keys.nextKey()
                    if (parameters.getType(key) != ReadableType.String) {
                        promise?.reject(java.lang.IllegalArgumentException("Parameters must be string key/values. Value was invalid for '$key'"))
                        return
                    }
                    request.addParameter(key, parameters.getString(key)!!)
                }
            }
            if (options.hasKey("headers")) {
                val headers = options.getMap("headers")
                val keys = headers!!.keySetIterator()
                while (keys.hasNextKey()) {
                    val key = keys.nextKey()
                    if (headers.getType(key) != ReadableType.String) {
                        promise?.reject(java.lang.IllegalArgumentException("Headers must be string key/values.  Value was invalid for '$key'"))
                        return
                    }
                    request.addHeader(key, headers.getString(key)!!)
                }
            }

            val uploadId = request.startUpload()
            promise?.resolve(uploadId)
        } catch (exc: java.lang.Exception) {
            exc.printStackTrace()
            Log.e(TAG, exc.message, exc)
            promise?.reject(exc)
        }
    }

    /*
     * Cancels file upload
     * Accepts upload ID as a first argument, this upload will be cancelled
     * Event "cancelled" will be fired when upload is cancelled.
     */
    @ReactMethod
    fun cancelUpload(cancelUploadId: String?, promise: Promise) {
        if (cancelUploadId !is String) {
            promise.reject(java.lang.IllegalArgumentException("Upload ID must be a string"))
            return
        }
        try {
            UploadService.stopUpload(cancelUploadId)
            promise.resolve(true)
        } catch (exc: java.lang.Exception) {
            exc.printStackTrace()
            Log.e(TAG, exc.message, exc)
            promise.reject(exc)
        }
    }

    /*
     * Cancels all file uploads
     */
    @ReactMethod
    fun cancelAllUploads(promise: Promise) {
        try {
            UploadService.stopAllUploads()
            promise.resolve(true)
        } catch (exc: java.lang.Exception) {
            exc.printStackTrace()
            Log.e(TAG, exc.message, exc)
            promise.reject(exc)
        }
    }




    @ReactMethod
    fun addToUploadQueue(options: ReadableMap, promise: Promise) {

//        this.queue?.clear()

        val empty = this.queue!!.isEmpty()

        val jsonObject = convertMapToJson(options)
        if (jsonObject == null) {
            promise.reject(java.lang.IllegalArgumentException("upload failed"))
            return
        }

        var uploadId = UUID.randomUUID().toString()
        if (!options.hasKey("customUploadId")) {
            jsonObject.put("customUploadId", uploadId)
        } else {
            uploadId = options.getString("customUploadId")!!
        }

        this.queue?.push(jsonObject)

        if (empty) {
            uploadNextItemInQueue()
        }
        promise.resolve(uploadId)
    }


    @ReactMethod
    fun clearUploadQueue(promise: Promise?) {
        this.queue?.clear()
        promise?.resolve(true)
    }




    override fun onHostResume() {
        uploadReceiver?.register(reactApplicationContext)
    }

    override fun onHostPause() {
    }

    override fun onHostDestroy() {
        try {
            uploadReceiver!!.unregister(reactApplicationContext)
        } catch (e: java.lang.Exception) {
            e.printStackTrace()
        }
    }



    private fun configureUploadServiceHTTPStack(options: ReadableMap, promise: Promise?) {
        var followRedirects = true
        var followSslRedirects = true
        var retryOnConnectionFailure = true
        var connectTimeout = 30
        var writeTimeout = 60
        var readTimeout = 60
        //TODO: make 'cache' customizable
        if (options.hasKey("followRedirects")) {
            if (options.getType("followRedirects") != ReadableType.Boolean) {
                promise?.reject(IllegalArgumentException("followRedirects must be a boolean."))
                return
            }
            followRedirects = options.getBoolean("followRedirects")
        }
        if (options.hasKey("followSslRedirects")) {
            if (options.getType("followSslRedirects") != ReadableType.Boolean) {
                promise?.reject(IllegalArgumentException("followSslRedirects must be a boolean."))
                return
            }
            followSslRedirects = options.getBoolean("followSslRedirects")
        }
        if (options.hasKey("retryOnConnectionFailure")) {
            if (options.getType("retryOnConnectionFailure") != ReadableType.Boolean) {
                promise?.reject(IllegalArgumentException("retryOnConnectionFailure must be a boolean."))
                return
            }
            retryOnConnectionFailure = options.getBoolean("retryOnConnectionFailure")
        }
        if (options.hasKey("connectTimeout")) {
            if (options.getType("connectTimeout") != ReadableType.Number) {
                promise?.reject(IllegalArgumentException("connectTimeout must be a number."))
                return
            }
            connectTimeout = options.getInt("connectTimeout")
        }
        if (options.hasKey("writeTimeout")) {
            if (options.getType("writeTimeout") != ReadableType.Number) {
                promise?.reject(IllegalArgumentException("writeTimeout must be a number."))
                return
            }
            writeTimeout = options.getInt("writeTimeout")
        }
        if (options.hasKey("readTimeout")) {
            if (options.getType("readTimeout") != ReadableType.Number) {
                promise?.reject(IllegalArgumentException("readTimeout must be a number."))
                return
            }
            readTimeout = options.getInt("readTimeout")
        }
        UploadService.HTTP_STACK = OkHttpStack(OkHttpClient().newBuilder()
                .followRedirects(followRedirects)
                .followSslRedirects(followSslRedirects)
                .retryOnConnectionFailure(retryOnConnectionFailure)
                .connectTimeout(connectTimeout.toLong(), TimeUnit.SECONDS)
                .writeTimeout(writeTimeout.toLong(), TimeUnit.SECONDS)
                .readTimeout(readTimeout.toLong(), TimeUnit.SECONDS)
                .cache(null)
                .build())

    }


    // Customize the notification channel as you wish. This is only for a bare minimum example
    private fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= 26) {
            val channel = NotificationChannel(
                    notificationChannelID,
                    "Background Upload Channel",
                    NotificationManager.IMPORTANCE_LOW
            )
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    fun removeFromQueue(uploadId: String) {
        this.queue?.remove(uploadId)
    }

    fun uploadNextItemInQueue() {
        val jsonObject = this.queue?.pop(false)
        val item = if (jsonObject != null) convertJsonToMap(jsonObject) else null
        if (item != null)
            startUpload(item, null)
    }

}


