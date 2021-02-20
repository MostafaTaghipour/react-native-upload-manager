package com.mostafataghipour.reactnativeuploadmanager;

import android.content.Context;
import androidx.annotation.Nullable;
import android.util.Log;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;

import net.gotev.uploadservice.ServerResponse;
import net.gotev.uploadservice.UploadInfo;
import net.gotev.uploadservice.UploadServiceBroadcastReceiver;

import java.lang.ref.WeakReference;

/**
 * This implementation is empty on purpose, just to show how it's possible to intercept
 * all the upload events app-wise with a global broadcast receiver registered in the manifest.
 *
 * @author Aleksandar Gotev
 */

public class UploadReceiver extends UploadServiceBroadcastReceiver {
    private static final String TAG = "UploadReceiver";


    private ReactApplicationContext reactContext;
    private WeakReference<RNUploadManagerModule> nativeModuleWeak;

    UploadReceiver(RNUploadManagerModule nativeModule ){
        this.nativeModuleWeak = new WeakReference<RNUploadManagerModule>(nativeModule);
    }

    @Override
    public void onProgress(Context context, UploadInfo uploadInfo) {
        super.onProgress(context, uploadInfo);

        WritableMap params = Arguments.createMap();
        params.putString("id", uploadInfo.getUploadId());
        params.putInt("progress", uploadInfo.getProgressPercent()); //0-100
        sendEvent("progress", params, context);
    }

    @Override
    public void onError(Context context, UploadInfo uploadInfo, ServerResponse serverResponse, Exception exception) {
        super.onError(context, uploadInfo, serverResponse, exception);

        WritableMap params = Arguments.createMap();
        params.putString("id", uploadInfo.getUploadId());
        if (serverResponse != null) {
            params.putInt("responseCode", serverResponse.getHttpCode());
            params.putString("responseBody", serverResponse.getBodyAsString());
        }

        // Make sure we do not try to call getMessage() on a null object
        if (exception != null){
            params.putString("error", exception.getMessage());
        } else {
            params.putString("error", "Unknown exception");
        }

        sendEvent("error", params, context);
        uploadNext(uploadInfo.getUploadId());
    }

    @Override
    public void onCompleted(Context context, UploadInfo uploadInfo, ServerResponse serverResponse) {
        super.onCompleted(context, uploadInfo, serverResponse);

        WritableMap params = Arguments.createMap();
        params.putString("id", uploadInfo.getUploadId());
        params.putInt("responseCode", serverResponse.getHttpCode());
        params.putString("responseBody", serverResponse.getBodyAsString());
        sendEvent("completed", params, context);
        uploadNext(uploadInfo.getUploadId());
    }

    @Override
    public void onCancelled(Context context, UploadInfo uploadInfo) {
        super.onCancelled(context, uploadInfo);

        WritableMap params = Arguments.createMap();
        params.putString("id", uploadInfo.getUploadId());
        sendEvent("cancelled", params, context);
        uploadNext(uploadInfo.getUploadId());
    }

    /**
     * Sends an event to the JS module.
     */
    private void sendEvent(String eventName, @Nullable WritableMap params, Context context) {
        if (this.reactContext != null) {
            this.reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class).emit("RNUploadManager-" + eventName, params);
        } else {
            Log.e(TAG, "sendEvent() failed due reactContext == null!");
        }
    }

    @Override
    public void register(final Context context) {
        super.register(context);

        this.reactContext = (ReactApplicationContext) context;
    }

    @Override
    public void unregister(final Context context) {
        super.unregister(context);

        this.reactContext = null;
    }


    private void uploadNext(String uploadId) {
        nativeModuleWeak.get().removeFromQueue(uploadId);
        nativeModuleWeak.get().uploadNextItemInQueue();
    }
}