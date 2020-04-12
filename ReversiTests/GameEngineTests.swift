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
        XCTAssertEqual(engine.board.standardOutput, """
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

private extension Array where Element == Disk? {
    
    var standardOutput: String {
        return enumerated().reduce(into: "", {
            if $1.offset > 0 && $1.offset % GameEngine.boardXRange.count == 0 {
                $0 += "\n\($1.element.symbol)"
            } else {
                $0 += $1.element.symbol
            }
        })
    }
    
}
