//
//  AudioEncoder.swift
//  LivePush
//
//  Created by 成杰 on 16/5/31.
//  Copyright © 2016年 swiftc.org. All rights reserved.
//

import CoreMedia
import AudioToolbox

/// encode to AAC (Advanced Audio Coding)
final class AudioEncoder: NSObject {
    
    //private var audioQueue: AudioQueueRef!
    
    // in means input, out means output audio stream
    private var inSourceFormat: AudioStreamBasicDescription!
//    private var inTargetFormat: AudioStreamBasicDescription!
    private var currentBufferList: AudioBufferList?
    //private var converter: AudioConverterRef?
    private var formatDescription: CMFormatDescription?
    
    private var audioQueue: dispatch_queue_t {
        let queue = dispatch_queue_create("org.swiftc.encode.audio", DISPATCH_QUEUE_SERIAL)
        dispatch_set_target_queue(queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0))
        return queue
    } // TODO: not used
    
    private var inClasseDescps: [AudioClassDescription] = [
        
        AudioClassDescription(mType: kAudioEncoderComponentType,
                              mSubType: kAudioFormatMPEG4AAC,
                              mManufacturer: kAppleHardwareAudioCodecManufacturer),
        AudioClassDescription(mType: kAudioEncoderComponentType,
                              mSubType: kAudioFormatMPEG4AAC,
                              mManufacturer: kAppleHardwareAudioCodecManufacturer)
    ]
    
    private let inputDataProc: AudioConverterComplexInputDataProc = {(
        inAudioConverter: AudioConverterRef,
        ioNumberDataPackets: UnsafeMutablePointer<UInt32>,
        ioData: UnsafeMutablePointer<AudioBufferList>,
        outDataPacketDescription: UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>>,
        inUserData: UnsafeMutablePointer<Void>) in
        
        let encoder = unsafeBitCast(inUserData, AudioEncoder.self)
        return encoder.copeWith(ioNumberDataPackets, ioData, outDataPacketDescription)
    }
    
    private var inTargetFormat: AudioStreamBasicDescription {
        
        get {
            var format = AudioStreamBasicDescription(mSampleRate: self.inSourceFormat.mSampleRate,
                                                     mFormatID: kAudioFormatMPEG4AAC,
                                                     mFormatFlags: UInt32(MPEG4ObjectID.AAC_LC.rawValue),
                                                     mBytesPerPacket: 0,
                                                     mFramesPerPacket: 1024,
                                                     mBytesPerFrame: 0,
                                                     mChannelsPerFrame: self.inSourceFormat!.mChannelsPerFrame,
                                                     mBitsPerChannel: 0,
                                                     mReserved: 0)
            
            CMAudioFormatDescriptionCreate(kCFAllocatorDefault,
                                           &format,
                                           0,
                                           nil,
                                           0,
                                           nil,
                                           nil,
                                           &formatDescription)
            
            return format
        }
        
        set {
            // nothing to do, just let inTargetFormat write able writeable
            // because AudioConverterNewSpecific need it writeable
        }
    }
    
    // audio converter，use AudioConverterNewSpecific create
    private lazy var converter: AudioConverterRef? = {[unowned self] in
        
        // inSourceFormat must be from input sampleBuffer
        guard self.inSourceFormat != nil else { return nil }
        
        var cvr: AudioConverterRef = nil
        let result = AudioConverterNewSpecific(&self.inSourceFormat!,
                                               &self.inTargetFormat,
                                               UInt32(self.inClasseDescps.count),
                                               &self.inClasseDescps,
                                               &cvr)
        if result == noErr {
            print("AudioConverterNewSpecific success")
            return cvr
        } else {
            print("AudioConverterNewSpecific Error")
            return nil
        }
    }() // to ensure set only once
    
    private func copeWith(ioNumberDataPackets: UnsafeMutablePointer<UInt32>,
                          _ ioData: UnsafeMutablePointer<AudioBufferList>,
                          _ outDataPacketDescription:
        UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>>) -> OSStatus {
        
        // inSourceFormat may fail set in init
        if currentBufferList == nil || inSourceFormat == nil {
            ioNumberDataPackets.memory = 0
            return 100 // TODO: what is 100 means
        }
        
        let numBytes: UInt32 = min(ioNumberDataPackets.memory * inSourceFormat!.mBytesPerPacket,
                                   currentBufferList!.mBuffers.mDataByteSize)
        
        ioData.memory.mBuffers.mData = currentBufferList!.mBuffers.mData
        ioData.memory.mBuffers.mDataByteSize = numBytes
        ioNumberDataPackets.memory = numBytes / inSourceFormat!.mBytesPerPacket
        currentBufferList = nil
        
        return noErr
    }
    
    override init() {
        super.init()
        
    }
    
    func encode(sampleBuffer sampleBuffer: CMSampleBuffer) {
        
        let format = CMSampleBufferGetFormatDescription(sampleBuffer)
        guard format != nil else { return }
        
        // converter's init depends inSourceFormat
        inSourceFormat = CMAudioFormatDescriptionGetStreamBasicDescription(format!).memory
        
        var blockBuffer: CMBlockBuffer?
        currentBufferList = AudioBufferList()
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer,
                                                                nil,
                                                                &currentBufferList!,
                                                                sizeof(AudioBufferList.self),
                                                                nil,
                                                                nil,
                                                                0,
                                                                &blockBuffer) // TODO: 释放
        var ioOutputDataPacketSize = UInt32(1)
        
        guard converter != nil else { return }
        
        let frameSize = UInt32(1024)
        let channels = inSourceFormat.mChannelsPerFrame
        let dataPtr = UnsafeMutablePointer<Void>.alloc(Int(frameSize))
        
        let audioBuffer = AudioBuffer(mNumberChannels: channels,
                                      mDataByteSize: frameSize,
                                      mData: dataPtr)
        // free the object which dataPtr reference to
        dataPtr.destroy()
        
        var audioBufferList = AudioBufferList(mNumberBuffers: 1,
                                              mBuffers: audioBuffer)
        
        let result = AudioConverterFillComplexBuffer(converter!,
                                                     inputDataProc,
                                                     unsafeBitCast(self, UnsafeMutablePointer<Void>.self),
                                                     &ioOutputDataPacketSize,
                                                     &audioBufferList,
                                                     nil)
        if result == noErr {
            var sbuf: CMSampleBuffer?
            var timming = CMSampleTimingInfo()
            let numSamples: CMItemCount = CMSampleBufferGetNumSamples(sampleBuffer)
            
            CMSampleBufferCreate(kCFAllocatorDefault,
                                 nil,
                                 false,
                                 nil,
                                 nil,
                                 formatDescription,
                                 numSamples,
                                 1,
                                 &timming,
                                 0,
                                 nil,
                                 &sbuf)
            
            CMSampleBufferSetDataBufferFromAudioBufferList(sbuf!,
                                                           kCFAllocatorDefault,
                                                           kCFAllocatorDefault,
                                                           0,
                                                           &audioBufferList)
            
            //print("sampleb:\(sbuf!)")
        } else {
            print("AudioConverterFillComplexBuffer Failed")
        }
        
        let list = UnsafeMutableAudioBufferListPointer(&audioBufferList)
        for buffer in list {
            free(buffer.mData)
        }
    }
}
