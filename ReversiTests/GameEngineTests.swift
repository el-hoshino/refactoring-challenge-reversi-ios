//
//  GameEngineTests.swift
//  ReversiTests
//
//  Created by 史 翔新 on 2020/04/12.
//  Copyright © 2020 Yuta Koshizawa. All rights reserved.
//

import XCTest
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
        XCTAssertEqual(engine.validMoves(for: .dark).toDiskPlace(), [
            .init(x: 3, y: 2),
            .init(x: 2, y: 3),
            .init(x: 5, y: 4),
            .init(x: 4, y: 5),
        ])
        XCTAssertEqual(engine.validMoves(for: .light).toDiskPlace(), [
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
    func toDiskPlace() -> [DiskPlace] {
        map { (element) -> DiskPlace in
            .init(x: element.x, y: element.y)
        }
    }
}

private struct DiskPlace: Equatable {
    var x: Int
    var y: Int
}
