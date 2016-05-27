//
//  VideoCapture.swift
//  LivePush
//
//  Created by 成杰 on 16/5/25.
//  Copyright © 2016年 swiftc.org. All rights reserved.
//

import UIKit
import CoreMedia
import AVFoundation

final class VideoCapture: AVCapture {
    
    private var videoQueue: dispatch_queue_t {
        let queue = dispatch_queue_create("org.swiftc.capture.video", DISPATCH_QUEUE_SERIAL)
        dispatch_set_target_queue(queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0))
        return queue
    }
    
    private var outputHandler: OutputHandler!
    
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    override init() {
        
        super.init()
        
        let captureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        
        if session.canSetSessionPreset(AVCaptureSessionPreset640x480) {
            session.sessionPreset = AVCaptureSessionPreset640x480
        }
        
        let videoInput = try! AVCaptureDeviceInput(device: captureDevice)
        
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        let bgra = NSNumber(int: Int32(kCVPixelFormatType_32BGRA))
        let captureSettings = [String(kCVPixelBufferPixelFormatTypeKey) : bgra]
        videoOutput.videoSettings = captureSettings
        videoOutput.alwaysDiscardsLateVideoFrames = false
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        
        videoOutput.connectionWithMediaType(AVMediaTypeVideo)
        
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        previewLayer.connection.videoOrientation = .Portrait
    }
    
    /// CMSampleBuffer data call back
    func output(outputHandler: OutputHandler) {
        
        // the real call back must be on didOutputSampleBuffer
        self.outputHandler = outputHandler
    }
}

extension VideoCapture: AVCaptureProtocol {
    
    typealias OutputHandler = (sampleBuffer: CMSampleBuffer) -> Void
    
    /// Let's start
    func startSession() {
        dispatch_sync(videoQueue) {
            self.session.startRunning()
        }
    }
    
    func stopSession() {
        dispatch_sync(videoQueue) {
            self.session.stopRunning()
        }
    }
}

extension VideoCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer
        sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        
        guard outputHandler != nil else { return }
        self.outputHandler(sampleBuffer: sampleBuffer!)
    }
}
