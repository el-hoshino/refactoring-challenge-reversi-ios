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
    
    private let board: CurrentValueSubject<[Disk?], Never> = .init(.initialize())
    
    private let turn: CurrentValueSubject<Turn, Never> = .init(.validTurn(.dark))
    
    private var playerForTurn: [Disk: Player] = [:]
    private var thinkingCanceller: [Disk: Canceller] = [:]
    
    private let thinking: PassthroughSubject<(turn: Disk, thinking: Bool), Never> = .init()
    private let changed: PassthroughSubject<(diskType: Disk, coordinates: [(x: Int, y: Int)]), Never> = .init()
    
    private func initialize() {
        board.send(.initialize())
        turn.send(.validTurn(.dark))
        playerForTurn = [:]
        thinkingCanceller = [:]
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
        
        guard board.value[x: x, y: y] == nil else {
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
                
                switch (disk, board.value[x: x, y: y]) { // Uses tuples to make patterns exhaustive
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
    
    private func toggleTurn() {
        guard var turn = self.turn.value.availableTurn else { return }

        turn.flip()
        
        if validMoves(for: turn).isEmpty {
            if validMoves(for: turn.flipped).isEmpty {
                self.turn.send(.finished(winner: winner))
            } else {
                self.turn.send(.skippingTurn(turn))
            }
        } else {
            self.turn.send(.validTurn(turn))
        }
    }
    
    private func placeDisk(_ disk: Disk, at coordinate: (x: Int, y: Int)) throws {
        
        let diskCoordinates = flippedDiskCoordinatesByPlacingDisk(disk, at: coordinate)
        if diskCoordinates.isEmpty {
            throw DiskPlacementError(disk: disk, x: coordinate.x, y: coordinate.y)
        }
        
        board.value[x: coordinate.x, y: coordinate.y] = disk
        
        for coordinate in diskCoordinates {
            board.value[x: coordinate.0, y: coordinate.1]?.flip()
        }
        
        toggleTurn()
        
        let changedDisks: (diskType: Disk, coordinates: [(x: Int, y: Int)]) = (disk, [coordinate] + diskCoordinates)
        changed.send(changedDisks)
        
    }
    
    private func placeDiskAutomatically(as side: Disk) {
        
        let (x, y) = validMoves(for: side).randomElement()!
        
        thinking.send((side, true))
        
        let cleanUp: () -> Void = { [weak self] in
            guard let self = self else { return }
            self.thinking.send((side, false))
            self.thinkingCanceller[side] = nil
        }
        let canceller = Canceller(cleanUp)
        thinkingCanceller[side] = canceller
        
        Thread.sleep(forTimeInterval: 0.1)
//        Thread.sleep(forTimeInterval: 2)

        if canceller.isCancelled { return }
        cleanUp()
        
        try! placeDisk(side, at: (x, y))
        
    }
    
}

extension GameEngine: GameEngineProtocol {
    
    var gameBoardWidth: Int {
        width
    }
    
    var gameBoardHeight: Int {
        height
    }
    
    func reset() {
        initialize()
    }
    
    func setPlayer(_ player: Player, for turn: Disk) {
        thinkingCanceller[turn]?.cancel()
        playerForTurn[turn] = player
        nextMove()
    }
    
    func getPlayer(for turn: Disk) -> Player {
        playerForTurn[turn] ?? .manual
    }
    
    /// `x`, `y` で指定されたセルの状態を返します。
    /// セルにディスクが置かれていない場合、 `nil` が返されます。
    /// - Parameter x: セルの列です。
    /// - Parameter y: セルの行です。
    /// - Returns: セルにディスクが置かれている場合はそのディスクの値を、置かれていない場合は `nil` を返します。
    func diskAt(x: Int, y: Int) -> Disk? {
        return board.value[x: x, y: y]
    }
    
    /// - Throws: `DiskPlacementError` if the `disk` cannot be placed at (`x`, `y`).
    func placeDiskAt(x: Int, y: Int) throws {
        
        guard case .validTurn(let disk) = turn.value else { return }
        guard getPlayer(for: disk) == .manual else { return }
        
        try placeDisk(disk, at: (x, y))
        
    }
    
    /// 次のターンがコンピューターなら自動で次のセルを置く
    func nextMove() {
        
        switch turn.value {
        case .validTurn(let side):
            if getPlayer(for: side) == .computer {
                placeDiskAutomatically(as: side)
            }
            
        case .skippingTurn:
            toggleTurn()
            
        case .finished:
            break
            
        }
        
    }
    
    var isThinking: AnyPublisher<(turn: Disk, thinking: Bool), Never> {
        return thinking.eraseToAnyPublisher()
    }
    
    var changedDisks: AnyPublisher<(diskType: Disk, coordinates: [(x: Int, y: Int)]), Never> {
        changed.eraseToAnyPublisher()
    }
    
    var winner: Disk? {
        
        let darkCount = board.value.count(of: .dark)
        let lightCount = board.value.count(of: .light)
        if darkCount == lightCount {
            return nil
        } else {
            return darkCount > lightCount ? .dark : .light
        }
        
    }
    
    var currentTurn: AnyPublisher<Turn, Never> {
        turn.eraseToAnyPublisher()
    }
    
    func currentCount(of disk: Disk) -> AnyPublisher<Int, Never> {
        board.map {
            $0.count(of: disk)
        }.eraseToAnyPublisher()
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
    
    func count(of disk: Disk) -> Int {
        
        reduce(0) {
            if $1 == disk {
                return $0 + 1
            } else {
                return $0
            }
        }
        
    }
    
}

private extension Turn {
    
    var availableTurn: Disk? {
        switch self {
        case .validTurn(let turn), .skippingTurn(let turn):
            return turn
            
        case .finished:
            return nil
        }
    }
    
}
