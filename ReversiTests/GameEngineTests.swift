//
//  GameEngineTests.swift
//  ReversiTests
//
//  Created by 史 翔新 on 2020/04/12.
//  Copyright © 2020 Yuta Koshizawa. All rights reserved.
//

import XCTest
import Combine
@testable import Reversi

class GameEngineTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testInitialBoard() {
        
        let engine = GameEngine()
        XCTAssertEqual(engine.gameBoardWidth, 8)
        XCTAssertEqual(engine.gameBoardHeight, 8)
        XCTAssertEqual(engine.count(of: .light), 2)
        XCTAssertEqual(engine.count(of: .dark), 2)
        XCTAssertEqual(engine.validMoves(for: .dark).toCoordinates(), [
            .init(x: 3, y: 2),
            .init(x: 2, y: 3),
            .init(x: 5, y: 4),
            .init(x: 4, y: 5),
        ])
        XCTAssertEqual(engine.validMoves(for: .light).toCoordinates(), [
            .init(x: 4, y: 2),
            .init(x: 5, y: 3),
            .init(x: 2, y: 4),
            .init(x: 3, y: 5),
        ])
        XCTAssertEqual(engine.boardStandardOutput, """
            --------
            --------
            --------
            ---ox---
            ---xo---
            --------
            --------
            --------
            """
        )
        
    }
    
    func testPlaceDisk() {
        
        let engine = GameEngine()
        var changedDisks: DiskCoordinates?
        var observations: Set<AnyCancellable> = []
        engine.changedDisks.sink {
            changedDisks = DiskCoordinates($0)
        }.store(in: &observations)
        
        XCTAssertThrowsError(try engine.placeDiskAt(x: 3, y: 4)) { error in
            guard let error = error as? DiskPlacementError else { XCTFail(); return }
            XCTAssertEqual(error.disk, .dark)
            XCTAssertEqual(error.x, 3)
            XCTAssertEqual(error.y, 4)
        }
        XCTAssertEqual(engine.boardStandardOutput, """
            --------
            --------
            --------
            ---ox---
            ---xo---
            --------
            --------
            --------
            """
        )
        XCTAssertEqual(changedDisks, nil)
        
        XCTAssertNoThrow(try engine.placeDiskAt(x: 2, y: 3))
        XCTAssertEqual(engine.boardStandardOutput, """
            --------
            --------
            --------
            --xxx---
            ---xo---
            --------
            --------
            --------
            """
        )
        XCTAssertEqual(changedDisks, DiskCoordinates(disk: .dark, coordinates: [
            (x: 2, y: 3),
            (x: 3, y: 3),
        ]))
        
        XCTAssertNoThrow(try engine.placeDiskAt(x: 2, y: 4))
        XCTAssertEqual(engine.boardStandardOutput, """
            --------
            --------
            --------
            --xxx---
            --ooo---
            --------
            --------
            --------
            """
        )
        XCTAssertEqual(changedDisks, DiskCoordinates(disk: .light, coordinates: [
            (x: 2, y: 4),
            (x: 3, y: 4),
        ]))
        
    }
    
}

private extension GameEngine {
    
    var boardStandardOutput: String {
        return board.enumerated().reduce(into: "", {
            if $1.offset > 0 && $1.offset % gameBoardWidth == 0 {
                $0 += "\n\($1.element.symbol)"
            } else {
                $0 += $1.element.symbol
            }
        })
    }
    
}

private extension Array where Element == (x: Int, y: Int) {
    func toCoordinates() -> [Coordinate] {
        map { (element) -> Coordinate in
            .init(x: element.x, y: element.y)
        }
    }
}

private struct Coordinate: Equatable {
    var x: Int
    var y: Int
}

private struct DiskCoordinates: Equatable {
    var disk: Disk
    var coordinates: [Coordinate]
    init(_ tuple: (diskType: Disk, coordinates: [(x: Int, y: Int)])) {
        self.disk = tuple.diskType
        self.coordinates = tuple.coordinates.toCoordinates()
    }
    init(disk: Disk, coordinates: [(x: Int, y: Int)]) {
        self.disk = disk
        self.coordinates = coordinates.toCoordinates()
    }
}
