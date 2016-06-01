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
