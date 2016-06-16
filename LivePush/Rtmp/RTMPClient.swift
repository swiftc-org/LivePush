//
//  RTMPClient.swift
//  LivePush
//
//  Created by 成杰 on 16/6/2.
//  Copyright © 2016年 swiftc.org. All rights reserved.
//

import UIKit

class RTMPClient {
    
    private let rtmp = RTMP_Alloc()
    private var startTimeV: Double!
    private var startTimeA: Double!
    
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
    func connect(urlStr: String) -> Bool {
        
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
            return false
        }
        
        RTMP_EnableWrite(rtmp)
        
        let connectResult = RTMP_Connect(rtmp, nil)
        guard connectResult != 0 else {
            print("RTMP_Connect failed")
            return false
        }
        
        // Prevent SIGPIPE signals
        var nosigpipe = 1
        let nosigpipeLen = UInt32(sizeof(nosigpipe.dynamicType))
        setsockopt(rtmp.memory.m_sb.sb_socket,
                   SOL_SOCKET,
                   SO_NOSIGPIPE,
                   &nosigpipe,
                   nosigpipeLen)
        
        
        let streamResult = RTMP_ConnectStream(rtmp, 0)
        guard streamResult != 0 else {
            print("RTMP_ConnectStream failed")
            return false
        }
        
        return isConnected
    }
    
    /// send sps and pps before send H264 stream
    func send(sps sps: NSData, pps: NSData) -> Bool {
        
        guard isConnected else {
            print("rtmp is not connected")
            close()
            return false
        }
        
        let spsLen = sps.length
        let ppsLen = pps.length
        
        print("sps:\(sps)")
        print("pps:\(pps)")
        
        let result = rtmp_send_sps_pps(rtmp,
                                       UnsafePointer<UInt8>(sps.bytes),
                                       UInt32(spsLen),
                                       UnsafePointer<UInt8>(pps.bytes),
                                       UInt32(ppsLen))
        
        startTimeV = NSDate().timeIntervalSince1970
        
        // 0 means failed, 1 means success
        if result == 0 {
            return false
        } else {
            return true
        }
        /*var body = [UInt8]()
        
        // The following refers to Video File Format Specification Version 10
        // and http://billhoo.blog.51cto.com/2337751/1557646
        
        // FrameType = 1(key frame)(4Bit), CodecID = 7(avc)(4Bit)
        // FLV files store multibyte integers in big-endian byte order, so it is 0x17
        body.append(0x17)
        
        // if CodecID == 7 then VideoData = AVCVIDEOPACKET, so let's see AVCVIDEOPACKET
        // AVCPacketType == 0x00(because we need AVCDecoderConfigurationRecord)，
        // so CompositionTime == 0x000000，Data == AVCDecoderConfigurationRecord
        body.append(0x00) // 0: AVC sequence header
        body.append(0x00) // if AVCPacketType == 1 Composition time offset else 0
        body.append(0x00) // CompositionTime needs 24 Bits
        body.append(0x00) // CompositionTime needs 24 Bits
        
        // AVCDecoderConfigurationRecord
        // http://www.cnblogs.com/haibindev/archive/2011/12/29/2305712.html
        // ISO/IEC JTC1/SC29/WG11/N14837 5.3.3.1.2.Syntax
        body.append(0x01)   // configurationVersion
        body.append(sps[1]) // AVCProfileIndication
        body.append(sps[2]) // profile_compatibility
        body.append(sps[3]) // AVCLevelIndication
        body.append(0xff)   // 6 bits is reserved (111111b) and 2 bits lengthSizeMinusOne(0x03)
        body.append(0xe1)   // 3 bits reserved = ‘111’b and 5 bits numOfSequenceParameterSets()
        // so it is 0b11100001 == 0xe1, don't forget flv is big-endian
        
        // sps data length
        // spit the 32 or 64 bit Int to two 8 bits
        body.append(UInt8(spsLen >> 8)) // sequenceParameterSetNALUnit, [spsLen, sps]
        body.append(UInt8(spsLen & 0xff))
        
        // sps data
        for i in 0..<spsLen {
            body.append(sps[i])
        }
        
        // number of pps
        body.append(UInt8(ppsLen >> 8))
        body.append(UInt8(ppsLen & 0xff))
        
        // pps data length
        // body.append(0x01)
        
        // pps data
        for i in 0..<ppsLen {
            body.append(pps[i])
        }
        
        let data = NSData(bytes: &body, length: body.count)
        let bodyPtr = UnsafeMutablePointer<Int8>(data.bytes)
        
//        var packet = RTMPPacket(m_headerType: UInt8(RTMP_PACKET_SIZE_MEDIUM),
//                                m_packetType: UInt8(RTMP_PACKET_TYPE_VIDEO),
//                                m_hasAbsTimestamp: 0,
//                                m_nChannel: 0x04,
//                                m_nTimeStamp: 0,
//                                m_nInfoField2: rtmp.memory.m_stream_id,
//                                m_nBodySize: UInt32(body.count),
//                                m_nBytesRead: 0,
//                                m_chunk: nil,
//                                m_body: bodyPtr)
        
        var packet: RTMPPacket?
        RTMPPacket_Reset(&packet!)
        RTMPPacket_Alloc(&packet!, <#T##nSize: UInt32##UInt32#>)
        
        let result = RTMP_SendPacket(rtmp, &packet, 1) // 1 means add to a queue, 0 == don't
        
        if result == 0 { // 0 means failed
            print(#function, "RTMP_SendPacket failed")
            return
        } else {
            startTime = NSDate().timeIntervalSince1970
            print("startTime:\(startTime)")
        }*/
    }
    
    func send(video video: NSData, timeStamp: Double, isKeyFrame: Bool) -> Bool {
        
        guard isConnected else {
            print("rtmp is not connected")
            close()
            return false
        }
        
        guard startTimeV != nil else {
            print("sps and pps has not been send succeed")
            return false
        }
        
        //print("video length:\(video.length)")
        //print("timeStamp:\(timeStamp)")
        //print("isKeyFrame:\(isKeyFrame)")
        
        let timeOffset = NSDate().timeIntervalSince1970 - startTimeV
        //print("timeOffset:\(UInt32(timeOffset))")
        
        let result = rtmp_send_video(rtmp,
                                     UnsafePointer<UInt8>(video.bytes),
                                     UInt32(video.length),
                                     isKeyFrame,
                                     UInt32(timeOffset))
        
        // 0 means failed, 1 means success
        if result == 0 {
            return false
        } else {
            return true
        }
        // the current time - start push time
        /*let timeOffset = NSDate().timeIntervalSince1970 - startTime

        let len = video.length

        var body = [UInt8]()
        print("isKeyFrame:\(isKeyFrame)")
        if isKeyFrame {
            body.append(0x17) // key frame
        } else {
            body.append(0x27) // inter frame
        }

        body.append(0x01) // nal unit
        body.append(0x00)
        body.append(0x00)
        body.append(0x00)

        let low8 = (len >> 24) & 0xff
        let mid8 = (len >> 16) & 0xff
        let high8 = (len >> 8) & 0xff
        let last8 = (len >> 0) & 0xff

        // len data, spit len to 4 Bytes
        body.append(UInt8(low8))
        body.append(UInt8(mid8))
        body.append(UInt8(high8))
        body.append(UInt8(last8))

        for i in 0..<len {
            body.append(video[i])
        }
        print("body:\(body)")

        let data = NSData(bytes: &body, length: body.count)
        let bodyPtr = UnsafeMutablePointer<Int8>(data.bytes)

        //print("data:\(data)")
        //print("bodyPtr:")
        //printHexOfPointer(bodyPtr, length: body.count)

        var packet = RTMPPacket(m_headerType: UInt8(RTMP_PACKET_SIZE_LARGE),
                                m_packetType: UInt8(RTMP_PACKET_TYPE_VIDEO),
                                m_hasAbsTimestamp: 0,
                                m_nChannel: 0x04,
                                m_nTimeStamp: UInt32(timeOffset),
                                m_nInfoField2: rtmp.memory.m_stream_id,
                                m_nBodySize: UInt32(body.count),
                                m_nBytesRead: 0,
                                m_chunk: nil,
                                m_body: bodyPtr)
        
        print("packet:\(packet)")
        
        withUnsafePointer(&packet) { (ptr) -> Void in
            print("packetPtr:\(ptr)")
        }
        let result = RTMP_SendPacket(rtmp, &packet, 1) // 1 means add to a queue, 0 == don't
        if result == 0 { // 0 means failed
            print(#function, "RTMP_SendPacket failed")
            return
        } else {
            print(#function, "RTMP_SendPacket success")
        }*/
    }

    func sendAACHead() {
        
        let audioHead: [UInt8] = [0x12, 0x10]
        let audioHeadData = NSData(bytes: audioHead, length: audioHead.count)
        
        rtmp_send_audio_head(rtmp,
                             UnsafePointer<UInt8>(audioHeadData.bytes),
                             UInt32(audioHeadData.length))
        startTimeA = NSDate().timeIntervalSince1970 * 1000
    }
    
    func send(audio audio: NSData) {
        
        guard isConnected else {
            print("rtmp is not connected")
            return
        }
        
        guard startTimeA != nil else {
            print("sps and pps has not been send succeed")
            return
        }
        
        let timeOffset = (NSDate().timeIntervalSince1970 - startTimeA) * 1000
        
        rtmp_send_audio(rtmp,
                        UnsafePointer<UInt8>(audio.bytes),
                        UInt32(audio.length),
                        UInt32(timeOffset))
    }
    
    /// just for push flv file, can't used for H264 and AAC stream
    func push(data: NSData) {
        
        guard isConnected else {
            print("rtmp is not connected")
            close()
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
