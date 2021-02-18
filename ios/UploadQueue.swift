//
//  UploadQueue.swift
//  RNUploadManager
//
//  Created by Mostafa Taghipour on 2/17/21.
//  Copyright © 2021 Mostafa Taghipour. All rights reserved.
//

import Foundation

typealias UploadItem = [AnyHashable:Any]

protocol UploadQueue {
    func push(item: UploadItem)
    func pop(removeIt: Bool) -> UploadItem?
    func remove(id: String)
    func clear()
    func isEmpty() -> Bool
}


class UploadQueueImp: UploadQueue {
    
    static let shared = UploadQueueImp()
    
    private static let QUEUE_KEY = "UPLOAD_MANAGER_QUEUE_KEY"
    
    private lazy var userDefaults : UserDefaults = {
        return UserDefaults.standard
    }()
    
    var queue : [UploadItem] = [[:]]
    
    
    private init(){
        load()
    }
    
    
    private func load(){
        self.queue = userDefaults.object(forKey: UploadQueueImp.QUEUE_KEY) as? [UploadItem] ?? [[:]]
    }
    
    func push(item: UploadItem) {
        self.queue.append(item)
        sync()
    }
    
    
    func pop(removeIt: Bool) -> UploadItem? {
        let first =  self.queue.first
        
        if removeIt , first != nil {
            self.queue.remove(at: 0)
            sync()
        }
        
        return first
    }
    
    
    func remove(id: String) {
        let index = self.queue.firstIndex{$0["customUploadId"] as? String == id}
        
        if let index = index {
            self.queue.remove(at: index)
            sync()
        }
    }
    
    private func sync() {
        userDefaults.set(self.queue, forKey: UploadQueueImp.QUEUE_KEY)
    }
    
    func clear() {
        self.queue = []
        sync()
    }
    
    func isEmpty() -> Bool {
        return self.queue.isEmpty
    }
}
