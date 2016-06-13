//
//  VideoEncoder.swift
//  LivePush
//
//  Created by 成杰 on 16/5/27.
//  Copyright © 2016年 swiftc.org. All rights reserved.
//

import UIKit
import CoreMedia
import VideoToolbox

final class VideoEncoder: NSObject {
    
    private var encodeSession: VTCompressionSession?
    
    private func configCompressionSession() {
        
        let result: OSStatus = VTCompressionSessionCreate(kCFAllocatorDefault,
                                                          width,
                                                          height,
                                                          kCMVideoCodecType_H264,
                                                          nil,
                                                          attributes,
                                                          nil,
                                                          callback,
                                                          unsafeBitCast(self, UnsafeMutablePointer<Void>.self),
                                                          &encodeSession)
        
        guard encodeSession != nil else { return }
        
        VTSessionSetProperty(encodeSession!, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue)
        VTSessionSetProperty(encodeSession!, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse)
        VTSessionSetProperty(encodeSession!, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_High_AutoLevel)
        VTSessionSetProperty(encodeSession!, kVTCompressionPropertyKey_AverageBitRate, NSNumber(integer: defaultBitrate))
        VTSessionSetProperty(encodeSession!, kVTCompressionPropertyKey_MaxKeyFrameInterval, NSNumber(integer: defaultFPS))
        
        VTCompressionSessionPrepareToEncodeFrames(encodeSession!)
        
        if result != noErr {
            let error = NSError(domain: "VideoToolboxError",
                                code: Int(result),
                                userInfo: [NSLocalizedDescriptionKey : NSNumber(int: result)])
            print("VTCompressionSessionCreate failed: \(error)")
        } else {
            print("VTCompressionSessionCreate success")
        }
    }
    
    private var formatDescription: CMFormatDescription!
    
    private var width = Int32(480)
    private var height = Int32(640)
    
    private let defaultFPS: Int = 30
    private let defaultBitrate: Int = 160 * 1024
    private let defaultAttributes: [NSString: AnyObject] = [
        kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA),
        kCVPixelBufferIOSurfacePropertiesKey: [:],
        kCVPixelBufferOpenGLESCompatibilityKey: true]
    
    private var videoTimeStamp = kCMTimeZero
    
    private var attributes: [NSString: AnyObject] {
        var attrs: [NSString: AnyObject] = defaultAttributes
        attrs[kCVPixelBufferWidthKey] = NSNumber(int: width)
        attrs[kCVPixelBufferHeightKey] = NSNumber(int: height)
        return attrs
    }
    
    private var callback: VTCompressionOutputCallback = {(
        outputCallbackRefCon: UnsafeMutablePointer<Void>,
        sourceFrameRefCon: UnsafeMutablePointer<Void>,
        status: OSStatus, infoFlags: VTEncodeInfoFlags,
        sampleBuffer: CMSampleBuffer?) in // parameters
        
        guard sampleBuffer != nil else { return }
        guard CMSampleBufferDataIsReady(sampleBuffer!) else { return }
        guard status == noErr else { return }
        
        let encoder = unsafeBitCast(outputCallbackRefCon, VideoEncoder.self)
        encoder.handleEncodedSampleBuffer(sampleBuffer!)
    }
    
    private var has_send_sps_pps = false
    
    private func handleEncodedSampleBuffer(sampleBuffer: CMSampleBuffer) {
        
        let keyFrame = sampleBuffer.isKeyFrame
        guard keyFrame != nil else { return }
        
        if keyFrame! {
            
            sps = get_sps_or_pps(by: true, sampleBuffer: sampleBuffer)
            pps = get_sps_or_pps(by: false, sampleBuffer: sampleBuffer)
            
            if !has_send_sps_pps { // ensure send once
                guard sps != nil && pps != nil else {
                    print("sps or pps is nil")
                    return
                }
                delegate?.onVideoEncoderGet(sps: sps!, pps: pps!)
                has_send_sps_pps = true
            }
        }
        
        getEncodedData(sampleBuffer)
    }
    
    // choice: true means sps. false means pps
    private func get_sps_or_pps(by choice: Bool, sampleBuffer: CMSampleBuffer) -> NSData! {
        
        let format = CMSampleBufferGetFormatDescription(sampleBuffer)
        guard format != nil else { return nil }
        
        var paramSet = UInt8()
        var paramSetPtr = withUnsafePointer(&paramSet, {
            (ptr) -> UnsafePointer<UInt8> in
            return ptr
        })
        
        var paraSetSize = Int()
        var paraSetCount = Int()
        var naluHeadLen = Int32()
        var paraSetIndex = Int()
        if choice {
            paraSetIndex = 0
        } else {
            paraSetIndex = 1
        }
        
        let status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format!,
                                                                        paraSetIndex,
                                                                        &paramSetPtr,
                                                                        &paraSetSize,
                                                                        &paraSetCount,
                                                                        &naluHeadLen)
        if status == noErr {
            // choice: true means sps. false means pps
            let paraData = NSData(bytes: paramSetPtr, length: paraSetSize)
            return paraData
        } else {
            print("CMVideoFormatDescriptionGetH264ParameterSetAtIndex error:\(status)")
            return nil
        }
    }
    
    private func getEncodedData(sampleBuffer: CMSampleBuffer) {
        
        let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer)
        guard blockBuffer != nil else { return }
        
        var totalLen = Int()
        var dataPointer: UnsafeMutablePointer<Int8> = nil
        
        let status = CMBlockBufferGetDataPointer(blockBuffer!,
                                                 0,
                                                 nil,
                                                 &totalLen,
                                                 &dataPointer)
        
        if status == noErr {
            
            var cto = Int32(0)
            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            var dts = CMSampleBufferGetDecodeTimeStamp(sampleBuffer)
            
            if dts == kCMTimeInvalid {
                dts = pts
            } else {
                cto = Int32(CMTimeGetSeconds(pts) - CMTimeGetSeconds(dts)*1000)
            }
            
            let dis = CMTimeGetSeconds(dts) - CMTimeGetSeconds(videoTimeStamp)
            let delta = (videoTimeStamp == kCMTimeZero ? 0 : dis) * 1000
            
            guard sampleBuffer.isKeyFrame != nil else { return }
            // TODO: don't know why
            let tmp: UInt8 = ((sampleBuffer.isKeyFrame! ? 0x01 : 0x02) << 0x04) | 0x07
            
            var data = [UInt8](count: 5, repeatedValue: 0x00)
            data[0] = tmp
            data[1] = 0x01
            data[2..<5] = cto.bigEndian.bytes[1..<4]
            
            let buffer = NSMutableData()
            buffer.appendBytes(&data, length: data.count)
            buffer.appendBytes(dataPointer, length: totalLen)
            
            let keyFrame = sampleBuffer.isKeyFrame
            guard keyFrame != nil else {
                print("keyFrame is nil")
                return
            }
            
            delegate?.onVideoEncoderGet(video: buffer, timeStamp: delta, isKeyFrame: keyFrame!)
            videoTimeStamp = dts
            
        } else {
            print(#function, "CMBlockBufferGetDataPointer failed")
            return
        }
    }
    
    // MARK: - Out interface
    
    override init() {
        super.init()
        
        var onceToken = 0
        dispatch_once(&onceToken) {
            // may init again in callback
            self.configCompressionSession()
        }
    }
    
    // CVPixelBuffer == CVImageBuffer == CVBuffer
    func encode(imageBuffer imageBuffer: CVImageBuffer,
                            presentationTimeStamp: CMTime,
                            presentationDuration: CMTime) {
        
        // encodeSession will not be nil
        // because init called configCompressionSession()
        // so feel free to force unwap it
        
        var flags: VTEncodeInfoFlags = VTEncodeInfoFlags()
        
        VTCompressionSessionEncodeFrame(encodeSession!,
                                        imageBuffer,
                                        presentationTimeStamp,
                                        presentationDuration,
                                        nil,
                                        nil,
                                        &flags)
    }
    
    weak var delegate: VideoEncoderDelegate?
    var sps: NSData?
    var pps: NSData?
}
