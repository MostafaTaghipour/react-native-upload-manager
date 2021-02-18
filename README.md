# react-native-upload-manager [![npm version](https://badge.fury.io/js/react-native-upload-manager.svg)](https://badge.fury.io/js/react-native-upload-manager)

A React Native Library to manage your http post file uploads with android and iOS background support.  If you are uploading large files like videos, use this so your users can background your app during a long upload. This library support both Serial (Queue) and Parallel upload.
<img width="290" alt="screenshots" src="https://raw.githubusercontent.com/MostafaTaghipour/react-native-upload-manager/main/screenshots/1.png"><img width="290" alt="screenshots" src="https://raw.githubusercontent.com/MostafaTaghipour/react-native-upload-manager/main/screenshots/2.png">
# Installation

## 1. Install package

`npm install --save react-native-upload-manager`

or

`yarn add react-native-upload-manager`

## 2. Link Native Code

### Autolinking (React Native >= 0.60)

##### iOS

`cd ./ios && pod install && cd ../`

##### Android

No further actions required.

### Automatic Native Library Linking (React Native < 0.60)

`react-native link react-native-background-upload`

### Or, Manually Link It

#### iOS

1. In the XCode's "Project navigator", right click on your project's Libraries folder ➜ `Add Files to <...>`
2. Go to `node_modules` ➜ `react-native-upload-manager` ➜ `ios` ➜ select `RNUploadManager.xcodeproj`
3. Add `RNUploadManager.a` to `Build Phases -> Link Binary With Libraries`

#### Android
1. Add the following lines to `android/settings.gradle`:

    ```gradle
    include ':react-native-upload-manager'
    project(':react-native-upload-manager').projectDir = new File(settingsDir, '../node_modules/react-native-upload-manager/android')
    ```
2. Add the compile and resolutionStrategy line to the dependencies in `android/app/build.gradle`:

    ```gradle
    dependencies {
        compile project(':react-native-upload-manager')
    }
    ```


3. Add the import and link the package in `MainApplication.java`:

    ```java
    import com.mostafataghipour.reactnativeuploadmanager;  <-- add this import

    public class MainApplication extends Application implements ReactApplication {
        @Override
        protected List<ReactPackage> getPackages() {
            return Arrays.<ReactPackage>asList(
                new MainReactPackage(),
                new RNUploadManagerPackage() // <-- add this line
            );
        }
    }
    ```


## 3. Expo

To use this library with [Expo](https://expo.io) one must first detach (eject) the project and follow [step 2](#2-link-native-code) instructions.

# Usage

```js
import UploadManager from 'react-native-upload-manager'

useEffect(() => {
    const progressSubscription = UploadManager.addListener('progress', (data) => {
        console.log(`Progress: ${data.progress}%`)
    })
    
    const completeSubscription = UploadManager.addListener('completed', (data) => {
        // data includes responseCode: number and responseBody: Object
        console.log('Completed!')
    })
    
    const errorSubscription = UploadManager.addListener('error', (data) => {
        console.log(`Error: ${data.error}%`)
    })
    
    const cancelSubscription = UploadManager.addListener('cancelled', (data) => {
        console.log(`Cancelled!`)
    })
    
    return () => {
      progressSubscription.remove()
      completeSubscription.remove()
      errorSubscription.remove()
      cancelSubscription.remove()
    }
  }, [])
  
const uploadfile = async () => {
    const options = {
      url: 'https://myservice.com/path/to/post',
      path: 'file://path/to/file/on/device',
      method: 'POST',
      type: 'raw',
      maxRetries: 0, // set retry count (Android only). Default 0
      headers: {
        'content-type': 'application/octet-stream', // Customize content-type
        'my-custom-header': 's3headervalueorwhateveryouneed'
      },
      // Below are options only supported on Android
      notification: {
        enabled: true,
        onErrorMessage: 'upload failed',
        onCompleteMessage: 'upload success',
        onProgressMessage: 'uploading...  ([[PROGRESS]])',
        autoClear: true
      }
    }

    const uploadId = await UploadManager.startUpload(options)
}
```

## Multipart Uploads

Just set the `type` option to `multipart` and set the `field` option.  Example:

```
const options = {
  url: 'https://myservice.com/path/to/post',
  path: 'file://path/to/file%20on%20device.png',
  method: 'POST',
  field: 'uploaded_media',
  type: 'multipart'
}
```

Note the `field` property is required for multipart uploads.

# API

## Top Level Functions

All top-level methods are available as named exports or methods on the default export.

### startUpload(options)

The primary method you will use, this starts the upload process.

Returns a promise with the string ID of the upload.  Will reject if there is a connection problem, the file doesn't exist, or there is some other problem.

`options` is an object with following values:

*Note: You must provide valid URIs. react-native-background-upload does not escape the values you provide.*

|Name|Type|Required|Default|Description|Example|
|---|---|---|---|---|---|
|`url`|string|Required||URL to upload to|`https://myservice.com/path/to/post`|
|`path`|string|Required||File path on device|`file://something/coming/from%20the%20device.png`|
|`type`|'raw' or 'multipart'|Optional|`raw`|Primary upload type.||
|`method`|string|Optional|`POST`|HTTP method||
|`customUploadId`|string|Optional||`startUpload` returns a Promise that includes the upload ID, which can be used for future status checks.  By default, the upload ID is automatically generated.  This parameter allows a custom ID to use instead of the default.||
|`headers`|object|Optional||HTTP headers|`{ 'Accept': 'application/json' }`|
|`field`|string|Required if `type: 'multipart'`||The form field name for the file.  Only used when `type: 'multipart`|`uploaded-file`|
|`parameters`|object|Optional||Additional form fields to include in the HTTP request. Only used when `type: 'multipart`||
|`notification`|Notification object (see below)|Optional||Android only.  |`{ enabled: true, onProgressTitle: "Uploading...", autoClear: true }`|

### Notification Object (Android Only)
|Name|Type|Required|Description|Example|
|---|---|---|---|---|
|`enabled`|boolean|Optional|Enable or diasable notifications. Works only on Android version < 8.0 Oreo. On Android versions >= 8.0 Oreo is required by Google's policy to display a notification when a background service run|`{ enabled: true }`|
|`autoClear`|boolean|Optional|Autoclear notification on complete|`{ autoclear: true }`|
|`notificationChannel`|string|Optional|Sets android notificaion channel|`{ notificationChannel: "My-Upload-Service" }`|
|`enableRingTone`|boolean|Optional|Sets whether or not to enable the notification sound when the upload gets completed with success or error|`{ enableRingTone: true }`|
|`onProgressTitle`|string|Optional|Sets notification progress title|`{ onProgressTitle: "Uploading" }`|
|`onProgressMessage`|string|Optional|Sets notification progress message|`{ onProgressMessage: "Uploading new video" }`|
|`onCompleteTitle`|string|Optional|Sets notification complete title|`{ onCompleteTitle: "Upload finished" }`|
|`onCompleteMessage`|string|Optional|Sets notification complete message|`{ onCompleteMessage: "Your video has been uploaded" }`|
|`onErrorTitle`|string|Optional|Sets notification error title|`{ onErrorTitle: "Upload error" }`|
|`onErrorMessage`|string|Optional|Sets notification error message|`{ onErrorMessage: "An error occured while uploading a video" }`|
|`onCancelledTitle`|string|Optional|Sets notification cancelled title|`{ onCancelledTitle: "Upload cancelled" }`|
|`onCancelledMessage`|string|Optional|Sets notification cancelled message|`{ onCancelledMessage: "Video upload was cancelled" }`|


### getFileInfo(path)

Returns some useful information about the file in question.  Useful if you want to set a MIME type header.

`path` is a string, such as `file://path.to.the.file.png`

Returns a Promise that resolves to an object containing:

|Name|Type|Required|Description|Example|
|---|---|---|---|---|
|`name`|string|Required|The file name within its directory.|`image2.png`|
|`exists`|boolean|Required|Is there a file matching this path?||
|`size`|number|If `exists`|File size, in bytes||
|`extension`|string|If `exists`|File extension|`mov`|
|`mimeType`|string|If `exists`|The MIME type for the file.|`video/mp4`|

### cancelUpload(uploadId)

Cancels an upload.

`uploadId` is the result of the Promise returned from `startUpload`

Returns a Promise that resolves to an boolean indicating whether the upload was cancelled.

### addToUploadQueue(options)

The primary method you will use to add your filr to upload queue. your upload queue will be continue even after your app going to background mode.

Returns a promise with the string ID of the upload. Will reject if there is a connection problem, the file doesn’t exist, or there is some other problem.

All Options are similar to startUpload function.

### clearUploadQueue()

Clear all files in upload queue.


### addListener(eventType, listener)

Adds an event listener to listen to upload events.

`eventType` Event to listen for. Values: 'progress' | 'error' | 'completed' | 'cancelled'

`listener` Function to call when the event occurs.

Returns an [EventSubscription](https://github.com/facebook/react-native/blob/master/Libraries/vendor/emitter/EmitterSubscription.js). To remove the listener, call `remove()` on the `EventSubscription`.

## Events

### progress

Event Data

|Name|Type|Required|Description|
|---|---|---|---|
|`id`|string|Required|The ID of the upload.|
|`progress`|0-100|Required|Percentage completed.|

### error

Event Data

|Name|Type|Required|Description|
|---|---|---|---|
|`id`|string|Required|The ID of the upload.|
|`error`|string|Required|Error message.|

### completed

Event Data

|Name|Type|Required|Description|
|---|---|---|---|
|`id`|string|Required|The ID of the upload.|
|`responseCode`|string|Required|HTTP status code received|
|`responseBody`|string|Required|HTTP response body|

### cancelled

Event Data

|Name|Type|Required|Description|
|---|---|---|---|
|`id`|string|Required|The ID of the upload.|

# FAQs

Is there an example/sandbox app to test out this package?

> Yes, there is a simple react native app that you can find  [here](https://github.com/MostafaTaghipour/react-native-upload-manager/tree/main/example).



Does it support iOS camera roll assets?

> Yes, as of version 4.3.0.

Does it support multiple file uploads?

> Yes and No.  It supports multiple concurrent uploads, but only a single upload per request.  That should be fine for 90%+ of cases.

Why should I use this file uploader instead of others that I've Googled like [react-native-uploader](https://github.com/aroth/react-native-uploader)?

> This package has two killer features not found anywhere else (as of 12/16/2016).  First, it works on both iOS and Android.  Others are iOS only.  Second, it supports background uploading.  This means that users can background your app and the upload will continue.  This does not happen with other uploaders.

What is the difference between this package and  [react-native-background-upload](https://github.com/Vydia/react-native-background-upload)?

> This package heavily inspired by react-native-background-upload and base on that.
But this package has a some of features that do not exist in react-native-background-uploa, such as Upload queue and etc.

## Inspiration
This project is heavily inspired by [react-native-background-upload](https://github.com/Vydia/react-native-background-upload). Kudos to [@Vydia](https://github.com/Vydia). :thumbsup:

## Gratitude

Thanks to [android-upload-service](https://github.com/gotev/android-upload-service)  It made Android dead simple to support.


## Author

Mostafa Taghipour, mostafa@taghipour.me

## License

react-native-upload-manager is available under the MIT license. See the LICENSE file for more info.