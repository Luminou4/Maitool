//
//  Item.swift
//  Maitool
//
//  Created by Luminous on 2024/7/2.
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
