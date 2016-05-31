//
//  AppDelegate.swift
//  LivePush
//
//  Created by 成杰 on 16/5/25.
//  Copyright © 2016年 swiftc.org. All rights reserved.
//

// TODO: todo list
// 无摄像头权限的错误处理
// 无麦克风权限的错误处理
// 设置视频参数的类（e.g:视频方向，视频大小，帧率...）
// 设置音频参数的类（也许用不上）
// 跟踪这个错误：VTCompressionSessionCreate failed: Error Domain=VideoToolboxPlusError Code=-12912 "-12912" UserInfo={NSLocalizedDescription=-12912}

import UIKit
import MachO

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        
        let vc = PushViewController()
        let nav = UINavigationController(rootViewController: vc)
        nav.setNavigationBarHidden(true, animated: true)
        window = UIWindow(frame: UIScreen.mainScreen().bounds)
        window?.makeKeyAndVisible()
        window?.rootViewController = nav
        return true
    }
}

