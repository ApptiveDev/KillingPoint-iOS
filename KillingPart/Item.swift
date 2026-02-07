//
//  Item.swift
//  KillingPart
//
//  Created by 이병찬 on 2/7/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
