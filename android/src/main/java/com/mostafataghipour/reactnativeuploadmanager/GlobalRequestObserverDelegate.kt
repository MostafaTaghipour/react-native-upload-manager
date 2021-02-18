package com.mostafataghipour.reactnativeuploadmanager

import android.content.Context
import android.util.Log
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.WritableMap
import com.facebook.react.modules.core.DeviceEventManagerModule.RCTDeviceEventEmitter
import net.gotev.uploadservice.data.UploadInfo
import net.gotev.uploadservice.network.ServerResponse
import net.gotev.uploadservice.observer.request.RequestObserverDelegate
import java.lang.ref.WeakReference

class GlobalRequestObserverDelegate(module: RNUploadManagerModule, reactApplicationContext: ReactApplicationContext) : RequestObserverDelegate {
    private val TAG = "UploadReceiver"

    private var weakModule: WeakReference<RNUploadManagerModule> = WeakReference(module)
    private var weakContext: WeakReference<ReactApplicationContext> = WeakReference(reactApplicationContext)

    override fun onCompleted(context: Context, uploadInfo: UploadInfo) {
        uploadNext(uploadInfo.uploadId)
    }

    override fun onCompletedWhileNotObserving() {
    }

    override fun onError(context: Context, uploadInfo: UploadInfo, exception: Throwable) {

        val params = Arguments.createMap()
        params.putString("id", uploadInfo.uploadId)

        // Make sure we do not try to call getMessage() on a null object
        params.putString("error", exception.message)

        sendEvent("error", params, context)

    }

    override fun onProgress(context: Context, uploadInfo: UploadInfo) {
        val params = Arguments.createMap()
        params.putString("id", uploadInfo.uploadId)
        params.putInt("progress", uploadInfo.progressPercent) //0-100

        sendEvent("progress", params, context)
    }

    override fun onSuccess(context: Context, uploadInfo: UploadInfo, serverResponse: ServerResponse) {
        val params = Arguments.createMap()
        params.putString("id", uploadInfo.uploadId)
        params.putInt("responseCode", serverResponse.code)
        params.putString("responseBody", serverResponse.bodyString)
        sendEvent("completed", params, context)

    }

    /**
     * Sends an event to the JS module.
     */
    private fun sendEvent(eventName: String, params: WritableMap?, context: Context) {
        weakContext.get()?.getJSModule(RCTDeviceEventEmitter::class.java)?.emit("RNUploadManager-$eventName", params)
                ?: Log.e(TAG, "sendEvent() failed due reactContext == null!")
    }

    private fun uploadNext(uploadId: String) {
        val uploadId = uploadId
        weakModule.get()?.removeFromQueue(uploadId)
        weakModule.get()?.uploadNextItemInQueue()
    }
}