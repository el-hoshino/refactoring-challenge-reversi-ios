//
//  GameEngine.swift
//  Reversi
//
//  Created by 史 翔新 on 2020/04/12.
//  Copyright © 2020 Yuta Koshizawa. All rights reserved.
//

import Foundation
import Combine

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
    private var thinkingCanceller: [Disk: Canceller] = [:]
    
    private let thinking: PassthroughSubject<(turn: Disk, thinking: Bool), Never> = .init()
    private let changed: PassthroughSubject<(diskType: Disk, coordinates: [(x: Int, y: Int)]), Never> = .init()
    
    func player(for turn: Disk) -> Player {
        return playerForTurn[turn] ?? .manual
    }
    
    func setPlayer(_ player: Player, for turn: Disk) {
        playerForTurn[turn] = player
        thinkingCanceller[turn]?.cancel()
        nextMove()
    }
        
}

extension GameEngine {
    
    // TODO: private typealise Coordinate = (x: Int, y: Int)
    private func flippedDiskCoordinatesByPlacingDisk(_ disk: Disk, at coordinate: (x: Int, y: Int)) -> [(Int, Int)] {
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
        let x = coordinate.x
        let y = coordinate.y
        
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
    
    func canPlaceDisk(_ disk: Disk, at coordinate: (x: Int, y: Int)) -> Bool {
        !flippedDiskCoordinatesByPlacingDisk(disk, at: coordinate).isEmpty
    }
    
}

extension GameEngine {
    
    private func placeDisk(_ disk: Disk, at coordinate: (x: Int, y: Int)) throws {
        
        let diskCoordinates = flippedDiskCoordinatesByPlacingDisk(disk, at: coordinate)
        if diskCoordinates.isEmpty {
            throw DiskPlacementError(disk: disk, x: coordinate.x, y: coordinate.y)
        }
        
        board[x: coordinate.x, y: coordinate.y] = disk
        
        for coordinate in diskCoordinates {
            board[x: coordinate.0, y: coordinate.1]?.flip()
        }
        
        nextTurn()
        
        let changedDisks: (diskType: Disk, coordinates: [(x: Int, y: Int)]) = (disk, [coordinate] + diskCoordinates)
        changed.send(changedDisks)
        
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
    
    func set(_ turn: Disk, to player: Player) {
        setPlayer(player, for: turn)
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
        
        try placeDisk(disk, at: (x, y))
        
    }
    
    /// 次のターンがコンピューターなら自動で次のセルを置く
    func nextMove() {
        
        guard let turn = self.turn else { preconditionFailure() }
        guard player(for: turn) == .computer else { return }
        
        let (x, y) = validMoves(for: turn).randomElement()!
        
        thinking.send((turn, true))
        
        let cleanUp: () -> Void = { [weak self] in
            guard let self = self else { return }
            self.thinking.send((turn, false))
            self.thinkingCanceller[turn] = nil
        }
        let canceller = Canceller(cleanUp)
        thinkingCanceller[turn] = canceller
        
        Thread.sleep(forTimeInterval: 2)

        if canceller.isCancelled { return }
        cleanUp()
        
        try! placeDisk(turn, at: (x, y))
        
    }
    
    var isThinking: AnyPublisher<(turn: Disk, thinking: Bool), Never> {
        return thinking.eraseToAnyPublisher()
    }
    
    var changedDisks: AnyPublisher<(diskType: Disk, coordinates: [(x: Int, y: Int)]), Never> {
        changed.eraseToAnyPublisher()
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
                if canPlaceDisk(side, at: (x, y)) {
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
