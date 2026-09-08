//
//  Item.swift
//  birdo
//
//  Created by Jeremy Beker on 9/8/26.
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
