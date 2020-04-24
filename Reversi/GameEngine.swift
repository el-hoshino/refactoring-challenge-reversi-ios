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
    
    private(set) var turn: Disk? = .dark // `nil` if the current game is over
    
    private var playerForTurn: [Disk: Player] = [:]
    
    func player(for turn: Disk) -> Player {
        return playerForTurn[turn] ?? .manual
    }
    func setPlayer(_ player: Player, for turn: Disk) {
        playerForTurn[turn] = player
    }
    
}

extension GameEngine {
    
    // TODO: private typealise Coordinate = (x: Int, y: Int)
    private func flippedDiskCoordinatesByPlacingDisk(_ disk: Disk, atX x: Int, y: Int) -> [(Int, Int)] {
        let directions = [
            (x: -1, y: -1),
            (x:  0, y: -1),
            (x:  1, y: -1),
            (x:  1, y:  0),
            (x:  1, y:  1),
            (x:  0, y:  1),
            (x: -1, y:  0),
            (x: -1, y:  1),
        ]
        
        guard board[x: x, y: y] == nil else {
            return []
        }
        
        var diskCoordinates: [(Int, Int)] = []
        
        for direction in directions {
            var x = x
            var y = y
            
            var diskCoordinatesInLine: [(Int, Int)] = []
            flipping: while true {
                x += direction.x
                y += direction.y
                
                switch (disk, board[x: x, y: y]) { // Uses tuples to make patterns exhaustive
                case (.dark, .some(.dark)), (.light, .some(.light)):
                    diskCoordinates.append(contentsOf: diskCoordinatesInLine)
                    break flipping
                case (.dark, .some(.light)), (.light, .some(.dark)):
                    diskCoordinatesInLine.append((x, y))
                case (_, .none):
                    break flipping
                }
            }
        }
        
        return diskCoordinates
    }
    
    func canPlaceDisk(_ disk: Disk, atX x: Int, y: Int) -> Bool {
        !flippedDiskCoordinatesByPlacingDisk(disk, atX: x, y: y).isEmpty
    }
    
}

extension GameEngine {
    
    private func nextTurn() {
        guard var turn = self.turn else { return }

        turn.flip()
        
        if validMoves(for: turn).isEmpty {
            if validMoves(for: turn.flipped).isEmpty {
                self.turn = nil
            }
        } else {
            self.turn = turn
        }
    }
    
}

extension GameEngine: GameEngineProtocol {
    
    var gameBoardWidth: Int {
        width
    }
    
    var gameBoardHeight: Int {
        height
    }
    
    /// `x`, `y` で指定されたセルの状態を返します。
    /// セルにディスクが置かれていない場合、 `nil` が返されます。
    /// - Parameter x: セルの列です。
    /// - Parameter y: セルの行です。
    /// - Returns: セルにディスクが置かれている場合はそのディスクの値を、置かれていない場合は `nil` を返します。
    func diskAt(x: Int, y: Int) -> Disk? {
        return board[x: x, y: y]
    }
    
    /// - Throws: `DiskPlacementError` if the `disk` cannot be placed at (`x`, `y`).
    func placeDiskAt(x: Int, y: Int) throws {
        
        guard let disk = turn else { return }
        guard player(for: disk) == .manual else { return }
        
        let diskCoordinates = flippedDiskCoordinatesByPlacingDisk(disk, atX: x, y: y)
        if diskCoordinates.isEmpty {
            throw DiskPlacementError(disk: disk, x: x, y: y)
        }
        
        board[x: x, y: y] = disk
        
        for coordinate in diskCoordinates {
            board[x: coordinate.0, y: coordinate.1]?.flip()
        }
        
        nextTurn()
        
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
        var coordinates: [(Int, Int)] = []
        
        for y in boardYRange {
            for x in boardXRange {
                if canPlaceDisk(side, atX: x, y: y) {
                    coordinates.append((x, y))
                }
            }
        }
        
        return coordinates
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
