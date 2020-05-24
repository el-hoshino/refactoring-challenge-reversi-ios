//
//  TurnTests.swift
//  ReversiTests
//
//  Created by 史 翔新 on 2020/05/24.
//  Copyright © 2020 Yuta Koshizawa. All rights reserved.
//

import XCTest
@testable import Reversi

class TurnTests: XCTestCase {
    
    func testTurnComposing() {
        
        typealias TestCase = (turn: Turn, composed: String)
        let testCases: [TestCase] = [
            (.validTurn(.dark), "vx"),
            (.validTurn(.light), "vo"),
            (.skippingTurn(.dark), "sx"),
            (.skippingTurn(.light), "so"),
            (.finished(winner: .dark), "fx"),
            (.finished(winner: .light), "fo"),
            (.finished(winner: nil), "f-"),
        ]
        
        for testCase in testCases {
            
            XCTAssertEqual(testCase.turn.composed(), testCase.composed)
            
        }
        
    }
    
    func testParsing() {
        
        typealias TestCase = (composed: String, turn: Turn)
        let testCases: [TestCase] = [
            ("vx", .validTurn(.dark)),
            ("vo", .validTurn(.light)),
            ("sx", .skippingTurn(.dark)),
            ("so", .skippingTurn(.light)),
            ("fx", .finished(winner: .dark)),
            ("fo", .finished(winner: .light)),
            ("f-", .finished(winner: nil)),
        ]
        
        for testCase in testCases {
            
            XCTAssertEqual(Turn.parsed(from: testCase.composed), testCase.turn)
            
        }
        
    }
    
}
