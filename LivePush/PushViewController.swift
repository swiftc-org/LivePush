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
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.whiteColor()
        
        vCapture.previewLayer.frame = view.layer.bounds
        view.layer.addSublayer(vCapture.previewLayer)
        
        vCapture.startSession()
        
        vCapture.output { (sampleBuffer) in
            print("sampleBuffer:\(sampleBuffer)")
        }
        
        aCapture.startSession()
        
//        performSelector(#selector(stopCapture),
//                        withObject: nil,
//                        afterDelay: 5.0)
    }
    
    dynamic func stopCapture() {
        vCapture.stopSession()
        aCapture.stopSession()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
}
