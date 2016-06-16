//
//  AVEncoder.swift
//  LivePush
//
//  Created by 成杰 on 16/5/30.
//  Copyright © 2016年 swiftc.org. All rights reserved.
//  copy from https://github.com/shogo4405/lf.swift/blob/650ce9b8d8c8248322a618583911565c63afa221/Sources/Core/CoreMedia%2BExtension.swift

import UIKit
import CoreMedia

protocol AudioEncoderDelegate: class {
    func onAudioEncoderGet(audio: NSData)
}

protocol VideoEncoderDelegate: class {
    func onVideoEncoderGet(sps sps: NSData, pps: NSData)
    func onVideoEncoderGet(video video: NSData, timeStamp: Double, isKeyFrame: Bool)
}

extension CMSampleBuffer {
    
    var isKeyFrame: Bool? {
        let attachments = CMSampleBufferGetSampleAttachmentsArray(self, true)
        guard attachments != nil else { return nil }
        
        let unsafePointer = CFArrayGetValueAtIndex(attachments, 0)
        let nsDic = unsafeBitCast(unsafePointer, NSDictionary.self)
        guard let dic = nsDic as? Dictionary<String, AnyObject> else { return nil }
        
        guard let dependsOnOthersOptinal = dic["DependsOnOthers"],
            let dependsOnOthers = dependsOnOthersOptinal as? Bool
            else { return nil }
        
        let keyFrame = !dependsOnOthers
        return keyFrame
    }
    
    var dependsOnOthers: Bool {
        guard let
            attachments = CMSampleBufferGetSampleAttachmentsArray(self, false),
            attachment = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), CFDictionaryRef.self) as Dictionary?
        else { return false }
        
        return attachment["DependsOnOthers"] as! Bool
    }
    
    var dataBuffer: CMBlockBuffer? {
        get {
            return CMSampleBufferGetDataBuffer(self)
        }
        set {
            guard let dataBuffer = newValue else {
                return
            }
            CMSampleBufferSetDataBuffer(self, dataBuffer)
        }
    }
    
    var duration: CMTime {
        return CMSampleBufferGetDuration(self)
    }
    
    var formatDescription: CMFormatDescription? {
        return CMSampleBufferGetFormatDescription(self)
    }
    
    var decodeTimeStamp: CMTime {
        let decodeTimestamp = CMSampleBufferGetDecodeTimeStamp(self)
        return decodeTimestamp == kCMTimeInvalid ? presentationTimeStamp : decodeTimestamp
    }
    
    var presentationTimeStamp: CMTime {
        return CMSampleBufferGetPresentationTimeStamp(self)
    }
}

extension Mirror {
    var description: String {
        var data: [String] = []
        if let superclassMirror = superclassMirror() {
            for child in superclassMirror.children {
                guard let label = child.label else {
                    continue
                }
                data.append("\(label):\(child.value)")
            }
        }
        for child in children {
            guard let label = child.label else {
                continue
            }
            data.append("\(label):\(child.value)")
        }
        return "\(subjectType){\(data.joinWithSeparator(","))}"
    }
}

extension IntegerLiteralConvertible {
    var bytes: [UInt8] {
        var value: Self = self
        return withUnsafePointer(&value) {
            Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>($0), count: sizeof(Self.self)))
        }
    }
    
    init(bytes: [UInt8]) {
        self = bytes.withUnsafeBufferPointer {
            return UnsafePointer<`Self`>($0.baseAddress).memory
        }
    }
}
