//
//  PushViewController.swift
//  LivePush
//
//  Created by 成杰 on 16/5/25.
//  Copyright © 2016年 swiftc.org. All rights reserved.
//

import UIKit
import CoreMedia

class PushViewController: UIViewController, VideoEncoderDelegate {

    private let vCapture = VideoCapture()
    private let aCapture = AudioCapture()
    
    private let vEncoder = VideoEncoder()
    private let aEncoder = AudioEncoder()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.whiteColor()
        
        vCapture.previewLayer.frame = view.layer.bounds
        view.layer.addSublayer(vCapture.previewLayer)
        
        vCapture.startSession()
        
        vCapture.output { (sampleBuffer) in
            
            self.handleVideoSampleBuffer(sampleBuffer)
        }
        
        aCapture.startSession()
        
        aCapture.output { (sampleBuffer) in
            
            self.handleAudioSampleBuffer(sampleBuffer)
        }
    }
    
    private func handleVideoSampleBuffer(sampleBuffer: CMSampleBuffer) {
        // TODO: some effect on here
        
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        guard imageBuffer != nil else { return }
        
        let timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let duration = CMSampleBufferGetDuration(sampleBuffer)
        
        vEncoder.delegate = self
        vEncoder.encode(imageBuffer: imageBuffer!,
                        presentationTimeStamp: timeStamp,
                        presentationDuration: duration)
    }
    
    private func handleAudioSampleBuffer(sampleBuffer: CMSampleBuffer) {
        
        aEncoder.encode(sampleBuffer: sampleBuffer)
    }
    
    dynamic func stopCapture() {
        vCapture.stopSession()
        aCapture.stopSession()
    }
    
    // MARK: - VideoEncoderDelegate
    func onVideoEncoderGet(sps sps: NSData, pps: NSData) {
        
    }
    
    func onVideoEncoderGet(video video: NSData, timeStamp: Double, isKeyFrame: Bool) {
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
}
