//
//  Turn.swift
//  Reversi
//
//  Created by 史 翔新 on 2020/05/16.
//  Copyright © 2020 Yuta Koshizawa. All rights reserved.
//

import Foundation

enum Turn {
    
    case validTurn(Disk)
    case skippingTurn(Disk)
    case finished(winner: Disk?)
    
}
