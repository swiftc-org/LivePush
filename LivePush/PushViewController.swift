//
//  PushViewController.swift
//  LivePush
//
//  Created by 成杰 on 16/5/25.
//  Copyright © 2016年 swiftc.org. All rights reserved.
//

import UIKit
import CoreMedia

class PushViewController: UIViewController {

    private let vCapture = VideoCapture()
    private let aCapture = AudioCapture()
    
    private let vEncode = VideoEncoder()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.whiteColor()
        
        vCapture.previewLayer.frame = view.layer.bounds
        view.layer.addSublayer(vCapture.previewLayer)
        
        vCapture.startSession()
        
        // CVPixelBuffer == CVImageBuffer == CVBuffer
        
        vCapture.output { (sampleBuffer) in
            
            self.handleSampleBuffer(sampleBuffer)
        }
        
        aCapture.startSession()
        
//        performSelector(#selector(stopCapture),
//                        withObject: nil,
//                        afterDelay: 5.0)
    }
    
    private func handleSampleBuffer(sampleBuffer: CMSampleBuffer) {
        // TODO: some effect on here
        
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        guard imageBuffer != nil else { return }
        let timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let duration = CMSampleBufferGetDuration(sampleBuffer)
        
        vEncode.encode(imageBuffer: imageBuffer!,
                       presentationTimeStamp: timeStamp,
                       presentationDuration: duration)
    }
    
    dynamic func stopCapture() {
        vCapture.stopSession()
        aCapture.stopSession()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
}
