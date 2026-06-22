//
//  DanmakuClock.swift
//  DanmakuKit
//
//  Created by 显卡的香气 on 2026/6/22.
//
import QuartzCore

public class DanmakuClock {
    
    public var offset: Double = 0
    
    public var currentTime: Double {
        CACurrentMediaTime() + offset
    }
}
