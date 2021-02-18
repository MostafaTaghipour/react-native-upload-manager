//
//  RNUploadManager.m
//  RNUploadManager
//
//  Copyright © 2021 Mostafa Taghipour. All rights reserved.
//

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface RCT_EXTERN_MODULE(RNUploadManager, RCTEventEmitter)

RCT_EXTERN_METHOD(getFileInfo: (NSString *)path resolver: (RCTPromiseResolveBlock)resolve rejecter: (RCTPromiseRejectBlock)reject
                  )

RCT_EXTERN_METHOD(startUpload: (NSDictionary *)options resolver: (RCTPromiseResolveBlock)resolve rejecter: (RCTPromiseRejectBlock)reject
                  )

RCT_EXTERN_METHOD(cancelUpload: (NSString *)cancelUploadId resolver: (RCTPromiseResolveBlock)resolve rejecter: (RCTPromiseRejectBlock)reject
                  )

RCT_EXTERN_METHOD(addToUploadQueue: (NSDictionary *)options resolver: (RCTPromiseResolveBlock)resolve rejecter: (RCTPromiseRejectBlock)reject
                  )


RCT_EXTERN_METHOD(clearUploadQueue: (RCTPromiseResolveBlock)resolve rejecter: (RCTPromiseRejectBlock)reject
                  )

@end
