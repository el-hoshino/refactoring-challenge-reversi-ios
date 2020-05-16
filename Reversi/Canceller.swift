//
//  Canceller.swift
//  Reversi
//
//  Created by 史 翔新 on 2020/05/16.
//  Copyright © 2020 Yuta Koshizawa. All rights reserved.
//

import Foundation

final class Canceller {
    private(set) var isCancelled: Bool = false
    private let body: (() -> Void)?
    
    init(_ body: (() -> Void)?) {
        self.body = body
    }
    
    func cancel() {
        if isCancelled { return }
        isCancelled = true
        body?()
    }
}