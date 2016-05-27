//
//  AVCapture.swift
//  LivePush
//
//  Created by 成杰 on 16/5/25.
//  Copyright © 2016年 swiftc.org. All rights reserved.
//

import AVFoundation

protocol AVCaptureProtocol {
    
    associatedtype OutputHandler
    
    func startSession()
    
    func stopSession()
}

/// base class for video and andio capture
class AVCapture: NSObject {
    
    // input和output的桥梁
    var session: AVCaptureSession!
    
    override init() {
        super.init()
        session = AVCaptureSession()
    }
    
}
