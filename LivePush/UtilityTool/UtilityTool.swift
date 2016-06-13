//
//  UtilityTool.swift
//  AWiFi
//
//  Created by 成杰 on 16/2/16.
//  Copyright © 2016年 A. All rights reserved.
//

import Foundation

func isRunningOniOSDevice() -> Bool {
    
    #if (arch(arm) && os(iOS)) || (arch(arm64) && os(iOS))
        return true
    #else
        return false
    #endif
}

func printHexOfPointer(ptr: UnsafePointer<Void>, length: Int) {
    
    for i in 0..<length {
        
        let uint8Ptr = UnsafePointer<UInt8>(ptr)
        let m = uint8Ptr.advancedBy(i).memory
        
        var hexStr = String(m, radix: 16)
        
        if hexStr.characters.count == 1 {
            hexStr = "0\(hexStr)"
        }
        
        print(hexStr, terminator: "")
        
        if i != 0 && (i+1) % 4 == 0 {
            print(" ", terminator: "")
        }
        
        if i == length - 1 {
            print("\n")
        }
    }
}

func Log(items: Any...,
         fileName: String = #file,
         funcName: String = #function,
         lineNum: Int = #line) {
    
    if items.count == 0 {
        print(funcName, lineNum)
        //print(fileName, funcName, lineNum)
    } else {
        print(funcName, lineNum, items)
        //print(fileName, funcName, lineNum, items)
    }
}

extension NSData {
    
    subscript(index: Int) -> UInt8 {
        
        let bytePtr = UnsafePointer<UInt8>(bytes)
        let byte = bytePtr.advancedBy(index)
        return byte.memory
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
