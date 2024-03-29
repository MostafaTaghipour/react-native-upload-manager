//
//  RNUploadManager.swift
//  RNUploadManager
//
//  Copyright © 2021 Mostafa Taghipour. All rights reserved.
//

import Foundation
import MobileCoreServices
import Photos


private let eventPrefix = "RNUploadManager-"

@objc(RNUploadManager)
class RNUploadManager: RCTEventEmitter {
    
    private var responsesData :[AnyHashable : Any]
    private static var staticEventEmitter: RCTEventEmitter? = nil
    private var BACKGROUND_SESSION_ID = "ReactNativeUploadManager"
    var _urlSession: URLSession? = nil
    
    private lazy var queue: UploadQueue = {
        return UploadQueueImp.shared
    }()
    
    override init() {
        responsesData = [AnyHashable : Any]()
        super.init()
        RNUploadManager.staticEventEmitter = self
    }
    
    @objc
    override static func requiresMainQueueSetup() -> Bool {
        return false
    }
    
    // we need to override this method and
    // return an array of event names that we can listen to
    override func supportedEvents() -> [String]! {
        return ["\(eventPrefix)progress","\(eventPrefix)error","\(eventPrefix)cancelled","\(eventPrefix)completed"]
    }
    
    /*
     * Get file info using path
     * return some info of file like
     * name
     * size
     * mimeType
     * extension
     * exists
     */
    @objc
    func getFileInfo(
        _ path:String,
        resolver resolve: RCTPromiseResolveBlock,
        rejecter reject: RCTPromiseRejectBlock
    ) -> Void {
        
        
        let fileUri =  URL(string: path)
        let pathWithoutProtocol = fileUri?.path
        let name = fileUri?.lastPathComponent
        let `extension` = URL(fileURLWithPath: name ?? "").pathExtension
        let exists = FileManager.default.fileExists(atPath: pathWithoutProtocol ?? "")
        var params : [AnyHashable : Any] = [
            "name" : name ?? ""
        ]
        params["extension"] = `extension`
        params["exists"] = exists
        
        if exists {
            params["mimeType"] = guessMIMEType(fromFileName: name)
            var error: Error? = nil
            var attributes: [FileAttributeKey : Any]? = nil
            do {
                attributes = try FileManager.default.attributesOfItem(atPath: pathWithoutProtocol ?? "")
            } catch let ex {
                error = ex
            }
            if error == nil {
                let fileSize = attributes?[FileAttributeKey.size] as? UInt64 ?? 0
                params["size"] = Int(fileSize)
            }
        }
        resolve(params)
    }
    
    
    
    /*
     * Starts a file upload.
     * Options are passed in as the first argument as a js hash:
     * {
     *   url: string.  url to post to.
     *   path: string.  path to the file on the device
     *   headers: hash of name/value header pairs
     * }
     *
     * Returns a promise with the string ID of the upload.
     */
    @objc
    func startUpload(_ options: [AnyHashable : Any],  resolver resolve: RCTPromiseResolveBlock,
                     rejecter  reject: @escaping RCTPromiseRejectBlock){
        
        guard let uploadUrl = options["url"] as? String else {
            reject("RN Uploade Manager", "Missing url field", nil)
            return
        }
        guard var fileURI = options["path"] as? String else {
            reject("RN Uploade Manager", "Missing path field", nil)
            return
        }
        let method = options["method"] as? String ?? "POST"
        let uploadType = options["type"] as? String ?? "raw"
        let fieldName = options["field"] as? String
        let uploadId = options["customUploadId"] as? String ?? UUID().uuidString
        let appGroup = options["appGroup"] as? String
        let headers : NSDictionary?  = options["headers"] as? NSDictionary
        let parameters = options["parameters"] as? [AnyHashable : Any]
        let readTimeout = options["readTimeout"] as? Int ?? 60
        let writeTimeout = options["writeTimeout"] as? Int ?? (5 * 60)
        
        
        guard let requestUrl = URL(string: uploadUrl) else{
            reject("RN Uploade Manager", "URL not compliant with RFC 2396", nil)
            return
        }
        
        var request: URLRequest =  URLRequest(url: requestUrl)
        request.httpMethod = method
        
        headers?.enumerateKeysAndObjects({ key, value, stop in
            
            if let value = value as? String , let key = key as? String {
                request.setValue(value , forHTTPHeaderField: key)
            }
        })
        
        if fileURI.hasPrefix("assets-library") {
            let group = DispatchGroup()
            group.enter()
            copyAsset(toFile: fileURI, completionHandler: { tempFileUrl, error in
                if error != nil {
                    group.leave()
                    reject("RN Upload Manager", "Asset could not be copied to temp file.", nil)
                    return
                }
                fileURI = tempFileUrl ??  ""
                group.leave()
            })
            _ = group.wait(timeout: DispatchTime.distantFuture)
        }
        
        
        
        var uploadTask: URLSessionDataTask?
        
        if uploadType == "multipart" {
            let uuidStr = UUID().uuidString
            request.setValue("multipart/form-data; boundary=\(uuidStr)", forHTTPHeaderField: "Content-Type")
            
            guard  (fieldName != nil)  else {
                reject("RN Upload Manager", "field is required field for multipart type.",nil)
                return
                
            }
            
            let httpBody = createBody(withBoundary:uuidStr, path: fileURI, parameters: parameters, fieldName: fieldName)
            request.httpBody = httpBody
            
            uploadTask = urlSession(withReadTimeout : readTimeout, writeTimeOut: writeTimeout, groupId: appGroup)?.uploadTask(withStreamedRequest: request)
        } else {
            if (parameters != nil) , parameters!.count > 0 {
                reject("RN Uploade Manager", "Parameters supported only in multipart type", nil)
                return
            }
            
            if let url = URL(string: fileURI) {
                uploadTask = urlSession(withReadTimeout : readTimeout, writeTimeOut: writeTimeout, groupId: appGroup)?.uploadTask(with: request, fromFile: url)
            }
        }
        
        uploadTask?.taskDescription = uploadId
        
        uploadTask?.resume()
        
        resolve(uploadId)
    }
    
    
    /*
     * Cancels file upload
     * Accepts upload ID as a first argument, this upload will be cancelled
     * Event "cancelled" will be fired when upload is cancelled.
     */
    @objc
    func cancelUpload(_ cancelUploadId: String,  resolver resolve: RCTPromiseResolveBlock,
                      rejecter  reject: @escaping RCTPromiseRejectBlock){
        _urlSession?.getTasksWithCompletionHandler({ dataTasks, uploadTasks, downloadTasks in
            for uploadTask in uploadTasks {
                //                guard let uploadTask = uploadTask as? URLSessionTask else {
                //                    continue
                //                }
                if uploadTask.taskDescription == cancelUploadId {
                    // == checks if references are equal, while isEqualToString checks the string value
                    uploadTask.cancel()
                }
            }
        })
        resolve(NSNumber(value: true))
    }
    
    
    /*
     * Add file to upload queue
     * Options are passed in as the first argument as a js hash:
     * {
     *   url: string.  url to post to.
     *   path: string.  path to the file on the device
     *   headers: hash of name/value header pairs
     * }
     *
     * Returns a promise with the string ID of the upload.
     */
    @objc
    func addToUploadQueue(_ options: [AnyHashable : Any],  resolver resolve: RCTPromiseResolveBlock,
                          rejecter  reject: @escaping RCTPromiseRejectBlock){
        
        //        self.queue.clear()
        let empty = self.queue.isEmpty()
        
        var opt = options
        let uploadId = opt["customUploadId"] as? String ?? UUID().uuidString
        opt["customUploadId"] = uploadId
        
        self.queue.push(item: opt)
        
        if (empty) {
            uploadNextItemInQueue()
        }
        resolve(uploadId)
    }
    
    
    
    
    /*
     * Clear Upload Queue
     */
    @objc
    func clearUploadQueue(_  resolve: RCTPromiseResolveBlock,
                          rejecter  reject: @escaping RCTPromiseRejectBlock){
        
        self.queue.clear()
        resolve(true)
    }
    
}


// Util methods
extension RNUploadManager {
    
    /*
     Borrowed from http://stackoverflow.com/questions/2439020/wheres-the-iphone-mime-type-database
     */
    private func guessMIMEType(fromFileName fileName: String?) -> String? {
        var UTI: CFString? = nil
        if let name = fileName , let path = URL(fileURLWithPath: name).pathExtension as CFString? {
            UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, path, nil)?.takeRetainedValue()
        }
        var MIMEType: CFString? = nil
        if let UTI = UTI {
            MIMEType = UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType)?.takeRetainedValue()
        }
        if MIMEType == nil {
            return "application/octet-stream"
        }
        return MIMEType as String?
    }
    
    
    
    /*
     Utility method to copy a PHAsset file into a local temp file, which can then be uploaded.
     */
    private func copyAsset(toFile assetUrl: String?, completionHandler: @escaping (_ tempFileUrl: String?, _ error: Error?) -> Void) {
        let url = URL(string: assetUrl ?? "")
        let asset = PHAsset.fetchAssets(withALAssetURLs: [url].compactMap { $0 }, options: nil).lastObject
        if asset == nil {
            var details: [AnyHashable : Any] = [:]
            details[NSLocalizedDescriptionKey] = "Asset could not be fetched.  Are you missing permissions?"
            completionHandler(nil, NSError(domain: "RNUploadManager", code: 5, userInfo: details as? [String : Any]))
            return
        }
        var assetResource: PHAssetResource? = nil
        if let asset = asset {
            assetResource = PHAssetResource.assetResources(for: asset).first
        }
        let pathToWrite = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).path
        let pathUrl = URL(fileURLWithPath: pathToWrite)
        let fileURI = pathUrl.absoluteString
        
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        
        if let assetResource = assetResource {
            PHAssetResourceManager.default().writeData(for: assetResource, toFile: pathUrl, options: options, completionHandler: { e in
                if e == nil {
                    completionHandler(fileURI, nil)
                } else {
                    completionHandler(nil, e!)
                }
            })
        }
    }
    
    
    
    
    private func createBody(
        withBoundary boundary: String?,
        path: String?,
        parameters: [AnyHashable : Any]?,
        fieldName: String?
    ) -> Data? {
        
        let crlf = "\r\n"
        
        var httpBody = Data()
        
        // resolve path
        let fileUri = URL(string: path ?? "")
        let pathWithoutProtocol = fileUri?.path
        
        let data = FileManager.default.contents(atPath: pathWithoutProtocol ?? "")
        let filename : String = fileUri?.lastPathComponent ?? ""
        let mimetype : String = path?.mimeType() ?? DEFAULT_MIME_TYPE
        
        
        httpBody.append(BoundaryGenerator.boundaryData(boundaryType: .initial, boundaryKey: boundary ?? ""))
        
        httpBody.append(Data((
                                "Content-Disposition: form-data; name=\"\(fieldName ?? "")\"; filename=\"\(filename)\"\(crlf)" +
                                    "Content-Type: \(mimetype)\(crlf)\(crlf)").utf8
        )
        )
        
        if let data = data {
            httpBody.append(data)
        }
        
        httpBody.append(BoundaryGenerator.boundaryData(boundaryType: .final, boundaryKey: boundary ?? ""))
        
        //        (parameters as NSDictionary?)?.enumerateKeysAndObjects({ parameterKey, parameterValue, stop in
        //            if let data1 = "--\(boundary ?? "")\r\n".data(using: .utf8) {
        //                httpBody.append(data1)
        //            }
        //            if let data1 = "Content-Disposition: form-data; name=\"\(parameterKey )\"\r\n\r\n".data(using: .utf8) {
        //                httpBody.append(data1)
        //            }
        //            if let data1 = "\(parameterValue )\r\n".data(using: .utf8) {
        //                httpBody.append(data1)
        //            }
        //        })
        
        
        
        
        //        if let data1 = "--\(boundary ?? "")\r\n".data(using: .utf8) {
        //            httpBody.append(data1)
        //        }
        //        if  let data1 = "Content-Disposition: form-data; name=\"\(String(describing: fieldName))\"; filename=\"\(String(describing: filename))\"\r\n".data(using: .utf8) {
        //            httpBody.append(data1)
        //        }
        //        if  let data1 = "Content-Type: \(String(describing: mimetype))\r\n\r\n".data(using: .utf8) {
        //            httpBody.append(data1)
        //        }
//        if let data = data {
//            httpBody.append(data)
//        }
        
//        if let data1 = "\r\n".data(using: .utf8) {
//            httpBody.append(data1)
//        }
//
//        if let data1 = "--\(boundary ?? "")--\r\n".data(using: .utf8) {
//            httpBody.append(data1)
//        }
        
        return httpBody
    }
    
    
    
    private func urlSession(withReadTimeout  readTimeout: Int , writeTimeOut : Int , groupId: String?  ) -> URLSession? {
        if _urlSession == nil {
            let sessionConfiguration = URLSessionConfiguration.background(withIdentifier: BACKGROUND_SESSION_ID)
            
            sessionConfiguration.timeoutIntervalForResource = TimeInterval(readTimeout)
            sessionConfiguration.timeoutIntervalForRequest = TimeInterval(writeTimeOut)
            if groupId != nil && (groupId != "") {
                sessionConfiguration.sharedContainerIdentifier = groupId
            }
            _urlSession = URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: nil)
        }
        
        return _urlSession
    }
    
    
    
    private func _sendEvent(withName eventName: String?, body: Any?) {
        if RNUploadManager.staticEventEmitter == nil {
            return
        }
        RNUploadManager.staticEventEmitter?.sendEvent(withName: eventName, body: body)
    }
    
    
    private func uploadFinished(uploadId:String?)  {
        guard let id = uploadId else { return  }
        removeFromQueue(uploadId: id)
        uploadNextItemInQueue()
    }
    
    private func removeFromQueue(uploadId:String?)  {
        guard let id = uploadId else { return  }
        self.queue.remove(id: id)
    }
    
    
    private func uploadNextItemInQueue() {
        if let item = self.queue.pop(removeIt: false){
            self.startUpload(item) { _ in } rejecter: { (_, _, _) in }
        }
    }
}



// URLSession delegates
extension RNUploadManager : URLSessionDataDelegate , URLSessionTaskDelegate {
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        
        var data : [AnyHashable:Any] = [
            "id" : task.taskDescription ?? ""
        ]
        let uploadTask = task as? URLSessionDataTask
        let response = uploadTask?.response as? HTTPURLResponse
        if let response = response {
            data["responseCode"] = Int(response.statusCode)
        }
        //Add data that was collected earlier by the didReceiveData method
        let responseData = responsesData[NSNumber(value: task.taskIdentifier)]
        if let responseData = responseData {
            responsesData.removeValue(forKey: NSNumber(value: task.taskIdentifier))
            let response = String(data: responseData as! Data, encoding: .utf8)
            data["responseBody"] = response
        } else {
            data["responseBody"] = NSNull()
        }
        
        if error == nil {
            _sendEvent(withName: "\(eventPrefix)completed", body: data)
            uploadFinished(uploadId: task.taskDescription)
        } else {
            data["error"] = error?.localizedDescription
            if (error as NSError?)?.code == Int(NSURLErrorCancelled) {
                _sendEvent(withName: "\(eventPrefix)cancelled", body: data)
                uploadFinished(uploadId: task.taskDescription)
            } else {
                _sendEvent(withName: "\(eventPrefix)error", body: data)
                uploadFinished(uploadId: task.taskDescription)
            }
        }
    }
    
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        
        var progress: Int = -1
        if totalBytesExpectedToSend > 0 {
            progress = Int(100 * totalBytesSent / totalBytesExpectedToSend)
        }
        _sendEvent(withName: "\(eventPrefix)progress", body: [
            "id": task.taskDescription ?? "",
            "progress": NSNumber(value: progress)
        ])
    }
    
    
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        
        if data.count == 0 {
            return
        }
        //Hold returned data so it can be picked up by the didCompleteWithError method later
        var responseData = responsesData[NSNumber(value: dataTask.taskIdentifier)]
        if responseData == nil {
            responseData = Data(data)
            responsesData[NSNumber(value: dataTask.taskIdentifier)] = responseData
        } else {
            responsesData[NSNumber(value: dataTask.taskIdentifier)] = data
        }
    }
}




struct EncodingCharacters {
    static let crlf = "\r\n"
}

enum BoundaryGenerator {
    enum BoundaryType {
        case initial, encapsulated, final
    }
    
    static func boundary(forBoundaryType boundaryType: BoundaryType, boundaryKey: String) -> String {
        let boundary: String
        
        switch boundaryType {
        case .initial:
            boundary = "--\(boundaryKey)\(EncodingCharacters.crlf)"
        case .encapsulated:
            boundary = "\(EncodingCharacters.crlf)--\(boundaryKey)\(EncodingCharacters.crlf)"
        case .final:
            boundary = "\(EncodingCharacters.crlf)--\(boundaryKey)--\(EncodingCharacters.crlf)"
        }
        
        return boundary
    }
    
    static func boundaryData(boundaryType: BoundaryType, boundaryKey: String) -> Data {
        Data(BoundaryGenerator.boundary(forBoundaryType: boundaryType,
                                        boundaryKey: boundaryKey).utf8)
    }
}



internal let DEFAULT_MIME_TYPE = "application/octet-stream"

internal let mimeTypes = [
    "html": "text/html",
    "htm": "text/html",
    "shtml": "text/html",
    "css": "text/css",
    "xml": "text/xml",
    "gif": "image/gif",
    "jpeg": "image/jpeg",
    "jpg": "image/jpeg",
    "js": "application/javascript",
    "atom": "application/atom+xml",
    "rss": "application/rss+xml",
    "mml": "text/mathml",
    "txt": "text/plain",
    "jad": "text/vnd.sun.j2me.app-descriptor",
    "wml": "text/vnd.wap.wml",
    "htc": "text/x-component",
    "png": "image/png",
    "tif": "image/tiff",
    "tiff": "image/tiff",
    "wbmp": "image/vnd.wap.wbmp",
    "ico": "image/x-icon",
    "jng": "image/x-jng",
    "bmp": "image/x-ms-bmp",
    "svg": "image/svg+xml",
    "svgz": "image/svg+xml",
    "webp": "image/webp",
    "woff": "application/font-woff",
    "jar": "application/java-archive",
    "war": "application/java-archive",
    "ear": "application/java-archive",
    "json": "application/json",
    "hqx": "application/mac-binhex40",
    "doc": "application/msword",
    "pdf": "application/pdf",
    "ps": "application/postscript",
    "eps": "application/postscript",
    "ai": "application/postscript",
    "rtf": "application/rtf",
    "m3u8": "application/vnd.apple.mpegurl",
    "xls": "application/vnd.ms-excel",
    "eot": "application/vnd.ms-fontobject",
    "ppt": "application/vnd.ms-powerpoint",
    "wmlc": "application/vnd.wap.wmlc",
    "kml": "application/vnd.google-earth.kml+xml",
    "kmz": "application/vnd.google-earth.kmz",
    "7z": "application/x-7z-compressed",
    "cco": "application/x-cocoa",
    "jardiff": "application/x-java-archive-diff",
    "jnlp": "application/x-java-jnlp-file",
    "run": "application/x-makeself",
    "pl": "application/x-perl",
    "pm": "application/x-perl",
    "prc": "application/x-pilot",
    "pdb": "application/x-pilot",
    "rar": "application/x-rar-compressed",
    "rpm": "application/x-redhat-package-manager",
    "sea": "application/x-sea",
    "swf": "application/x-shockwave-flash",
    "sit": "application/x-stuffit",
    "tcl": "application/x-tcl",
    "tk": "application/x-tcl",
    "der": "application/x-x509-ca-cert",
    "pem": "application/x-x509-ca-cert",
    "crt": "application/x-x509-ca-cert",
    "xpi": "application/x-xpinstall",
    "xhtml": "application/xhtml+xml",
    "xspf": "application/xspf+xml",
    "zip": "application/zip",
    "bin": "application/octet-stream",
    "exe": "application/octet-stream",
    "dll": "application/octet-stream",
    "deb": "application/octet-stream",
    "dmg": "application/octet-stream",
    "iso": "application/octet-stream",
    "img": "application/octet-stream",
    "msi": "application/octet-stream",
    "msp": "application/octet-stream",
    "msm": "application/octet-stream",
    "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    "pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    "mid": "audio/midi",
    "midi": "audio/midi",
    "kar": "audio/midi",
    "mp3": "audio/mpeg",
    "ogg": "audio/ogg",
    "m4a": "audio/x-m4a",
    "ra": "audio/x-realaudio",
    "3gpp": "video/3gpp",
    "3gp": "video/3gpp",
    "ts": "video/mp2t",
    "mp4": "video/mp4",
    "mpeg": "video/mpeg",
    "mpg": "video/mpeg",
    "mov": "video/quicktime",
    "webm": "video/webm",
    "flv": "video/x-flv",
    "m4v": "video/x-m4v",
    "mng": "video/x-mng",
    "asx": "video/x-ms-asf",
    "asf": "video/x-ms-asf",
    "wmv": "video/x-ms-wmv",
    "avi": "video/x-msvideo"
]

internal func MimeType(ext: String?) -> String {
    if ext != nil && mimeTypes.contains(where: { $0.0 == ext!.lowercased() }) {
        return mimeTypes[ext!.lowercased()]!
    }
    return DEFAULT_MIME_TYPE
}

extension NSURL {
    public func mimeType() -> String {
        return MimeType(ext: self.pathExtension)
    }
}


extension NSString {
    public func mimeType() -> String {
        return MimeType(ext: self.pathExtension)
    }
}

extension String {
    public func mimeType() -> String {
        return (self as NSString).mimeType()
    }
}
