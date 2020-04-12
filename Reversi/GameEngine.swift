//
//  GameEngine.swift
//  Reversi
//
//  Created by 史 翔新 on 2020/04/12.
//  Copyright © 2020 Yuta Koshizawa. All rights reserved.
//

import Foundation

final class GameEngine {
    
    /// 盤の幅（ `8` ）を表します。
    static let width = 8
    /// 盤の高さ（ `8` ）を返します。
    static let height = 8
    
    /// 盤のセルの `x` の範囲（ `0 ..< 8` ）を返します。
    static var boardXRange: Range<Int> { 0 ..< width }
    /// 盤のセルの `y` の範囲（ `0 ..< 8` ）を返します。
    static var boardYRange: Range<Int> { 0 ..< height }
    
    static var midXLeft: Int { midXRight - 1 }
    static var midXRight: Int { width / 2 }
    static var midYUpper: Int { midYLower - 1 }
    static var midYLower: Int { height / 2 }
    
    static var totalNumberOnBoard: Int { width * height }
    
    private(set) var board: [Disk?] = .initialize()
    
}

private extension Array where Element == Disk? {
    
    private typealias GE = GameEngine
    
    static func initialize() -> [Element] {
        var board: [Element] = .init(repeating: nil, count: GE.totalNumberOnBoard)
        board[x: GE.midXLeft, y: GE.midYUpper] = .light
        board[x: GE.midXRight, y: GE.midYUpper] = .dark
        board[x: GE.midXLeft, y: GE.midYLower] = .dark
        board[x: GE.midXRight, y: GE.midYLower] = .light
        return board
    }
    
    private func indexExists(x: Int, y: Int) -> Bool {
        GE.boardXRange.contains(x) && GE.boardYRange.contains(y)
    }
    
    private func index(atX x: Int, y: Int) -> Int? {
        guard indexExists(x: x, y: y) else { return nil }
        return y * GE.boardXRange.count + x
    }
    
    subscript(x x: Int, y y: Int) -> Element {
        get {
            guard let targetIndex = index(atX: x, y: y) else {
                return nil
            }
            return self[targetIndex]
        }
        set {
            guard let targetIndex = index(atX: x, y: y) else {
                preconditionFailure()
            }
            self[targetIndex] = newValue
        }
    }
    
}
