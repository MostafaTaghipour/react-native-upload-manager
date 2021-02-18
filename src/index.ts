import {
  NativeEventEmitter,
  NativeModules,
} from 'react-native'

export type UploadEvent = 'progress' | 'error' | 'completed' | 'cancelled'

export type NotificationArgs = {
  enabled: boolean
  enableRingTone?: boolean
  onProgressTitle?: string
  onProgressMessage?: string
  onCompleteTitle?: string
  onCompleteMessage?: string
  autoClear?: boolean
  onErrorTitle?: string
  onErrorMessage?: string
  onCancelledTitle?: string
  onCancelledMessage?: string
  notificationChannel?: string
}

export type StartUploadArgs = {
  url: string
  path: string
  method?: 'PUT' | 'POST'
  // Optional, because raw is default
  type?: 'raw' | 'multipart'
  // This option is needed for multipart type
  field?: string
  customUploadId?: string
  // parameters are supported only in multipart type
  parameters?: Object
  headers?: Object
  writeTimeout?: number
  readTimeout?: number

  // android only
  notification?: NotificationArgs
  // android only
  maxRetries?: number
  // android only
  followRedirects?: boolean
  // android only
  followSslRedirects?: boolean
  // android only
  retryOnConnectionFailure?: boolean
  // android only
  connectTimeout?: number
}

const NativeModule = NativeModules.RNUploadManager
const eventPrefix = 'RNUploadManager-'
const UploadEvents = new NativeEventEmitter(NativeModule)

/*
Gets file information for the path specified.
Example valid path is:
  Android: '/storage/extSdCard/DCIM/Camera/20161116_074726.mp4'
  iOS: 'file:///var/mobile/Containers/Data/Application/3C8A0EFB-A316-45C0-A30A-761BF8CCF2F8/tmp/trim.A5F76017-14E9-4890-907E-36A045AF9436.MOV;
Returns an object:
  If the file exists: {extension: "mp4", size: "3804316", exists: true, mimeType: "video/mp4", name: "20161116_074726.mp4"}
  If the file doesn't exist: {exists: false} and might possibly include name or extension
The promise should never be rejected.
*/
const getFileInfo = (path: string): Promise<Object> => {
  return NativeModule.getFileInfo(path).then((data: any) => {
    if (data.size) {
      // size comes back as a string on android so we convert it here.  if it's already a number this won't hurt anything
      data.size = +data.size
    }
    return data
  })
}

/*
Starts uploading a file to an HTTP endpoint.
Options object:
{
  url: string.  url to post to.
  path: string.  path to the file on the device
  headers: hash of name/value header pairs
  method: HTTP method to use.  Default is "POST"
  notification: hash for customizing tray notifiaction
    enabled: boolean to enable/disabled notifications, true by default.
}

Returns a promise with the string ID of the upload.  Will reject if there is a connection problem, the file doesn't exist, or there is some other problem.

It is recommended to add listeners in the .then of this promise.

*/
const startUpload = (options: StartUploadArgs): Promise<string> =>
  NativeModule.startUpload(options)



/*
Add file to upload queue to be uploading to an HTTP endpoint.
Options object:
{
  url: string.  url to post to.
  path: string.  path to the file on the device
  headers: hash of name/value header pairs
  method: HTTP method to use.  Default is "POST"
  notification: hash for customizing tray notifiaction
    enabled: boolean to enable/disabled notifications, true by default.
}

Returns a promise with the string ID of the upload.  Will reject if there is a connection problem, the file doesn't exist, or there is some other problem.

It is recommended to add listeners in the .then of this promise.
*/
const addToUploadQueue = (options: StartUploadArgs): Promise<string> =>
  NativeModule.addToUploadQueue(options)


/*
Clear upload queue
and remove all file that pending to be upload
*/
const clearUploadQueue = (): Promise<boolean> => NativeModule.clearUploadQueue()

/*
Cancels active upload by string ID of the upload.
Upload ID is returned in a promise after a call to startUpload method,
use it to cancel started upload.
Event "cancelled" will be fired when upload is cancelled.
Returns a promise with boolean true if operation was successfully completed.
Will reject if there was an internal error or ID format is invalid.
*/
const cancelUpload = (cancelUploadId: string): Promise<boolean> => {
  if (typeof cancelUploadId !== 'string') {
    return Promise.reject(new Error('Upload ID must be a string'))
  }
  return NativeModule.cancelUpload(cancelUploadId)
}
/*
Listens for the given event on the given upload ID (resolved from startUpload).
If you don't supply a value for uploadId, the event will fire for all uploads.
Events (id is always the upload ID):
  progress - { id: string, progress: int (0-100) }
  error - { id: string, error: string }
  cancelled - { id: string, error: string }
  completed - { id: string }
*/
function addListener(eventType: UploadEvent, listener: (data: any) => any) {
  return UploadEvents.addListener(eventPrefix + eventType, (data) => {
    listener(data)
  })
}

export default {
  startUpload,
  cancelUpload,
  addToUploadQueue,
  clearUploadQueue,
  addListener,
  getFileInfo,
}
