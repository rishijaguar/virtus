//
//  Item.swift
//  Virtus
//
//  Created by Rishi Jaguar on 12/21/25.
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
