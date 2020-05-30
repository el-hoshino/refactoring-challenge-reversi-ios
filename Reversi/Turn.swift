//
//  Turn.swift
//  Reversi
//
//  Created by 史 翔新 on 2020/05/16.
//  Copyright © 2020 Yuta Koshizawa. All rights reserved.
//

import Foundation

enum Turn: Equatable {
    
    case validTurn(Disk)
    case skippingTurn(Disk)
    case finished(winner: Disk?)
    
}

extension Turn: Codable {
    
    private enum Key: String, Codable {
        case validTurn
        case skippingTurn
        case finished
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
        case .validTurn(let disk):
            try container.encode(Key.validTurn)
            try container.encode(disk)
            
        case .skippingTurn(let disk):
            try container.encode(Key.skippingTurn)
            try container.encode(disk)
            
        case .finished(winner: let disk):
            try container.encode(Key.finished)
            try container.encode(disk)
        }
    }
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let key = try container.decode(Key.self)
        switch key {
        case .validTurn:
            let disk = try container.decode(Disk.self)
            self = .validTurn(disk)
            
        case .skippingTurn:
            let disk = try container.decode(Disk.self)
            self = .skippingTurn(disk)
            
        case .finished:
            let disk = try container.decode(Disk?.self)
            self = .finished(winner: disk)
        }
    }
    
}

extension Turn {
    
    func composed() -> String {
        
        switch self {
        case .validTurn(let disk):
            return "v\(disk.composed())"
            
        case .skippingTurn(let disk):
            return "s\(disk.composed())"
            
        case .finished(winner: let disk):
            return "f\(disk.composed())"
        }
        
    }
    
    static func parsed(from composed: String) -> Self {
        
        guard composed.count == 2 else {
            preconditionFailure("Invalid composed result: \(composed)")
        }
        
        let statusSymbol = composed[0]
        let diskSymbol = composed[1]
        
        switch statusSymbol {
        case "v":
            return .validTurn(Disk.parsed(from: diskSymbol))
            
        case "s":
            return .skippingTurn(Disk.parsed(from: diskSymbol))
            
        case "f":
            return .finished(winner: Disk?.parsed(from: diskSymbol))
            
        case let invalid:
            preconditionFailure("Invalid composed result: \(invalid)")
        }
        
    }
    
}

private extension Optional where Wrapped == Disk {
    
    func composed() -> String {
        
        switch self {
        case .none:
            return "-"
            
        case .some(let disk):
            return disk.composed()
        }
        
    }
    
    static func parsed(from composed: String) -> Self {
        
        switch composed {
        case "-":
            return .none
            
        case let c:
            return .some(Disk.parsed(from: c))
        }
        
    }
    
}

private extension Disk {
    
    func composed() -> String {
        
        switch self {
        case .dark:
            return "x"
            
        case .light:
            return "o"
        }
        
    }
    
    static func parsed(from composed: String) -> Self {
        
        switch composed {
        case "x":
            return .dark
            
        case "o":
            return .light
            
        case let invalid:
            preconditionFailure("Invalid composed result: \(invalid)")
        }
        
    }
    
}

private extension String {
    
    subscript(_ index: Int) -> String {
        
        let character = self[self.index(self.startIndex, offsetBy: index)]
        return String(character)
        
    }
    
}
