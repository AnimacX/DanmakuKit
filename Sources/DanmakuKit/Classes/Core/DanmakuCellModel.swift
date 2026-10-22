//
//  DanmakuCellModel.swift
//  DanmakuKit
//
//  Created by Q YiZhong on 2020/8/16.
//

import Foundation
import CoreGraphics

public enum DanmakuCellType {
    case floating
    case top
    case bottom
}

public protocol DanmakuCellModel {
    
    var cellClass: DanmakuCell.Type { get }
    
    var size: CGSize { get }
    
    /// Track for danmaku
    var track: UInt? { get set }
    
    var displayTime: Double { get }
    
    var type: DanmakuCellType { get }
    
    /// unique identifier
    var identifier: String { get }
    
    /// Used to determine if two cellmodels are equal
    /// - Parameter cellModel: other cellModel
    func isEqual(to cellModel: DanmakuCellModel) -> Bool
    
}

/// Adopt this protocol for text models whose measured size depends on a font.
/// Keep the base font unchanged. Measure and draw using the base font multiplied
/// by `fontScale`, and recalculate `size` when the scale changes.
public protocol DanmakuFontScalable: DanmakuCellModel {
    var fontScale: CGFloat { get set }
}

extension DanmakuCellModel {
    func applyingFontScale(_ scale: CGFloat) -> DanmakuCellModel {
        guard var model = self as? DanmakuFontScalable else { return self }
        model.fontScale = scale
        return model
    }
}
