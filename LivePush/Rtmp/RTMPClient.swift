//
//  RTMPClient.swift
//  LivePush
//
//  Created by 成杰 on 16/6/2.
//  Copyright © 2016年 swiftc.org. All rights reserved.
//

import UIKit

class RTMPClient {
    
    //private var urlStr: String!
    private let rtmp = RTMP_Alloc()
    
    var isConnected: Bool {
        
        return RTMP_IsConnected(rtmp) != 0
    }
    
    var setLogLevel: RTMP_LogLevel! {
        willSet {
            RTMP_LogSetLevel(newValue)
        }
    }
    
    init() {
        
        // Allocate rtmp context object
        RTMP_Init(rtmp)
        
    }
    
    /// Open rtmp connection to the given URL
    func connect(urlStr: String) {
        
        /*
         * It will failed at first handshaked RTMP_Connect1
         * the follow is error (RTMP_LogSetLevel(RTMP_LOGALL))
         DEBUG2: RTMP_SendPacket: fd=4, size=86
         DEBUG2:   0000:  03 00 00 00 00 00 56 14  00 00 00 00               ......V.....
         DEBUG2:   0000:  02 00 07 63 6f 6e 6e 65  63 74 00 3f f0 00 00 00   ...connect.?....
         DEBUG2:   0010:  00 00 00 03 00 03 61 70  70 02 00 04 00 00 00 00   ......app.......
         DEBUG2:   0020:  00 04 74 79 70 65 02 00  0a 6e 6f 6e 70 72 69 76   ..type...nonpriv
         DEBUG2:   0030:  61 74 65 00 05 74 63 55  72 6c 02 00 16 20 67 e3   ate..tcUrl... g.
         DEBUG2:   0040:  3c 01 00 00 00 20 73 e3  3c 01 00 00 00 00 00 00   <.... s.<.......
         DEBUG2:   0050:  00 00 00 00 00 09                                  ......
         ERROR: RTMP_ReadPacket, failed to read RTMP packet header
         * because the RTMP packet header has no url info
         * the reason is: swift' cann't not convert the swift String type to the real ascii string
         * which c language needs, so I convert the swift string to the NSString first (asciiString)
         */
        let setupUrlResult = RTMP_SetupURL(rtmp, urlStr.asciiString)
        guard setupUrlResult != 0 else { // 0 means failed
            print("RTMP_SetupURL failed")
            return
        }
        
        RTMP_EnableWrite(rtmp)
        
        let connectResult = RTMP_Connect(rtmp, nil)
        guard connectResult != 0 else {
            print("RTMP_Connect failed")
            return
        }
        
        let streamResult = RTMP_ConnectStream(rtmp, 0)
        guard streamResult != 0 else {
            print("RTMP_ConnectStream failed")
            return
        }
        
        print("is connect:\(isConnected)")
    }
    
    func push(data: NSData) {
        
        guard isConnected else {
            print("rtmp is not connected")
            return
        }
        
        let length = RTMP_Write(rtmp,
                                UnsafePointer<Int8>(data.bytes),
                                Int32(data.length))
        print("length:\(length)")
    }
    
    func close() {
        
        guard isConnected else {
            print("rtmp is not connected")
            return
        }
        
        RTMP_Close(rtmp)
        RTMP_Free(rtmp)
    }
    
}

extension String {
    
    var pointer: UnsafePointer<Int8> {
        return withCString { (ptr) -> UnsafePointer<Int8> in
            return ptr
        }
    }
    
    var mutablePointer: UnsafeMutablePointer<Int8> {
        return withCString({ (ptr) -> UnsafeMutablePointer<Int8> in
            return UnsafeMutablePointer(ptr)
        })
    }

    // It's right
    var asciiString: UnsafePointer<Int8> {
        return (self as NSString).cStringUsingEncoding(NSASCIIStringEncoding)
    }
    
    /// It's wrong
    var asciiStringII: UnsafePointer<Int8>? {
        
        guard canBeConvertedToEncoding(NSASCIIStringEncoding) else {
            print("the string can not be converted by NSASCIIStringEncoding")
            return nil
        }
        
        let ccharArr = cStringUsingEncoding(NSASCIIStringEncoding)
        guard ccharArr != nil else {
            print("convert To NSASCIIStringEncoding failed")
            return nil
        }
        
        let ptr = UnsafePointer<Int8>.init(ccharArr!)
        return ptr
    }
}

