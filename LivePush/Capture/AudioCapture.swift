//
//  AudioCapture.swift
//  LivePush
//
//  Created by 成杰 on 16/5/25.
//  Copyright © 2016年 swiftc.org. All rights reserved.
//

import UIKit
import CoreMedia
import AVFoundation

final class AudioCapture: AVCapture {
    
    private var audioQueue: dispatch_queue_t! {
        let queue = dispatch_queue_create("org.swiftc.capture.audio", DISPATCH_QUEUE_SERIAL)
        dispatch_set_target_queue(queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0))
        return queue
    }
    
    private var outputHandler: OutputHandler!

    override init() {
        super.init()
        
        let captureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio)
        
        let audioInput = try! AVCaptureDeviceInput(device: captureDevice)
        
        if session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }
        
        let audioOutput = AVCaptureAudioDataOutput()
        audioOutput.setSampleBufferDelegate(self, queue: audioQueue)
        
        if session.canAddOutput(audioOutput) {
            session.addOutput(audioOutput)
        }
    }
    
    /// CMSampleBuffer data call back
    func output(outputHandler: OutputHandler) {
        
        // the real call back must be on didOutputSampleBuffer
        self.outputHandler = outputHandler
    }
    
}

extension AudioCapture: AVCaptureProtocol {
    
    typealias OutputHandler = (sampleBuffer: CMSampleBuffer) -> Void
    
    func startSession() {
        dispatch_sync(audioQueue) {
            self.session.startRunning()
        }
    }
    
    func stopSession() {
        dispatch_sync(audioQueue) {
            self.session.stopRunning()
        }
    }
}

extension AudioCapture: AVCaptureAudioDataOutputSampleBufferDelegate {
    
    func captureOutput(captureOutput:AVCaptureOutput!, didOutputSampleBuffer
        sampleBuffer:CMSampleBuffer!, fromConnection connection:AVCaptureConnection!) {
        
        guard outputHandler != nil else { return }
        self.outputHandler(sampleBuffer: sampleBuffer!)
    }
}