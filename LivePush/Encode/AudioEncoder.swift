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
    
    // in means input, out means output audio stream
    private var inSourceFormat: AudioStreamBasicDescription!
    private var currentBufferList: AudioBufferList?
    private var formatDescription: CMFormatDescription?
    
    private var audioQueue: dispatch_queue_t {
        let queue = dispatch_queue_create("org.swiftc.encode.audio", DISPATCH_QUEUE_SERIAL)
        dispatch_set_target_queue(queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0))
        return queue
    } // TODO: not used
    
    private var requestedDescps: [AudioClassDescription] = [
        
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
        return encoder.copeWith(ioNumberDataPackets,
                                ioData: ioData,
                                outDataPacketDescription: outDataPacketDescription)
    }
    
    private var inTargetFormat: AudioStreamBasicDescription {
        
        get {
            var format = AudioStreamBasicDescription(mSampleRate: self.inSourceFormat.mSampleRate,
                                                     mFormatID: kAudioFormatMPEG4AAC,
                                                     mFormatFlags: UInt32(MPEG4ObjectID.AAC_Main.rawValue),
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
        
        var aconverter: AudioConverterRef = nil
        let result = AudioConverterNewSpecific(&self.inSourceFormat!,
                                               &self.inTargetFormat,
                                               UInt32(self.requestedDescps.count),
                                               &self.requestedDescps,
                                               &aconverter)
        if result == noErr {
            
            print("AudioConverterNewSpecific success")
            AudioConverterSetProperty(aconverter,
                                      kAudioConverterEncodeBitRate,
                                      UInt32(sizeof(UInt32)),
                                      &self.bitrate)
            return aconverter
        } else {
            print("AudioConverterNewSpecific Error")
            return nil
        }
        }() // to ensure set only once
    
    private func copeWith(ioNumberDataPackets: UnsafeMutablePointer<UInt32>,
                          ioData: UnsafeMutablePointer<AudioBufferList>,
                          outDataPacketDescription:
        UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>>)
        -> OSStatus {
            
            // inSourceFormat may fail set in init
            if currentBufferList == nil || inSourceFormat == nil {
                ioNumberDataPackets.memory = 0
                return 1024 // 100 means something wrong, just different from noErr (value is 0)
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
    
    var bitrate = Int()
    weak var delegate: AudioEncoderDelegate?
    
    private var audioTimestamp = kCMTimeZero
    
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
                                                                &blockBuffer) // can't be nil, or the audioData will empty
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
        
        var outPacketDescription = AudioStreamPacketDescription()
        
        let result = AudioConverterFillComplexBuffer(converter!,
                                                     inputDataProc,
                                                     unsafeBitCast(self, UnsafeMutablePointer<Void>.self),
                                                     &ioOutputDataPacketSize,
                                                     &audioBufferList,
                                                     &outPacketDescription)
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
            
            let audioDataLen = audioBufferList.mBuffers.mDataByteSize
            let audioData = NSData(bytes: audioBufferList.mBuffers.mData, length: Int(audioDataLen))
            //print("audioData:\(audioData)")
            
            delegate?.onAudioEncoderGet(audioData)
            
            //print("outPacketDescription:\(outPacketDescription)")
            
            CMSampleBufferSetDataBufferFromAudioBufferList(sbuf!,
                                                           kCFAllocatorDefault,
                                                           kCFAllocatorDefault,
                                                           0,
                                                           &audioBufferList)
            
            let presentTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            
            //let durationTimeStamp = CMSampleBufferGetDuration(sampleBuffer)
            
            //let delta = CMTimeGetSeconds(presentTimeStamp) - CMTimeGetSeconds(audioTimestamp)
            //let timeStamp: Double = (audioTimestamp == kCMTimeZero ? 0 : delta) * 1000
            //let timeStamp: Double = audioTimestamp == kCMTimeZero ? 0 : delta
            
            //print("\(NSDate())--presentTimeStamp:\(CMTimeGetSeconds(presentTimeStamp))")
            //print("\(NSDate())--delta           :\(delta)")
            
            //print("\(NSDate())--durationTimeStam:\(CMTimeGetSeconds(durationTimeStamp))")
            
            audioTimestamp = presentTimeStamp
            //print("\(NSDate())--timestamep:\(CMTimeGetSeconds(presentTimeStamp))")
            
        } else {
            print("AudioConverterFillComplexBuffer Failed")
        }
        
        let list = UnsafeMutableAudioBufferListPointer(&audioBufferList)
        for buffer in list {
            free(buffer.mData)
        }
    }
}
