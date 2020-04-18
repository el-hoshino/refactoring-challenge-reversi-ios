//
//  GameEngine.swift
//  Reversi
//
//  Created by 史 翔新 on 2020/04/12.
//  Copyright © 2020 Yuta Koshizawa. All rights reserved.
//

import Foundation

/// 盤の幅（ `8` ）を表します。
private let width = 8
/// 盤の高さ（ `8` ）を返します。
private let height = 8

private var boardXRange: Range<Int> { 0 ..< width }
private var boardYRange: Range<Int> { 0 ..< height }

private var midXLeft: Int { midXRight - 1 }
private var midXRight: Int { width / 2 }
private var midYUpper: Int { midYLower - 1 }
private var midYLower: Int { height / 2 }

private var totalNumberOnBoard: Int { width * height }

final class GameEngine {
    
    private(set) var board: [Disk?] = .initialize()
    
}

extension GameEngine: GameEngineProtocol {
    
    var gameBoardWidth: Int {
        width
    }
    
    var gameBoardHeight: Int {
        height
    }
    
    func count(of disk: Disk) -> Int {
        board.reduce(0) {
            if $1 == disk {
                return $0 + 1
            } else {
                return $0
            }
        }
    }
    
    func validMoves(for side: Disk) -> [(x: Int, y: Int)] {
        // TODO
        return []
    }
    
    func saveGame() throws {
        // TODO
    }
    
    func loadGame() throws {
        // TODO
    }
    
}

private extension Array where Element == Disk? {
    
    static func initialize() -> [Element] {
        var board: [Element] = .init(repeating: nil, count: totalNumberOnBoard)
        board[x: midXLeft, y: midYUpper] = .light
        board[x: midXRight, y: midYUpper] = .dark
        board[x: midXLeft, y: midYLower] = .dark
        board[x: midXRight, y: midYLower] = .light
        return board
    }
    
    private func indexExists(x: Int, y: Int) -> Bool {
        boardXRange.contains(x) && boardYRange.contains(y)
    }
    
    private func index(atX x: Int, y: Int) -> Int? {
        guard indexExists(x: x, y: y) else { return nil }
        return y * width + x
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
