//
//  StaticValueItem.swift
//  DeltaCamera
//
//  Created by Karsten Bruns on 25/11/15.
//  Copyright © 2015 bruns.me. All rights reserved.
//

import UIKit



public struct StaticValueItem : DeltaTableViewItem  {
    
    public let reuseIdentifier = "StaticValue"
    public let id: String
    public let title: String
    public let value: String
    
    public init(id: String, title: String, value: String) {
        self.id = id
        self.title = title
        self.value = value
    }
}



extension StaticValueItem : ComparableItem {
    
    public var uniqueIdentifier: Int { return id.hash }
    
    public func compareTo(other: ComparableItem) -> ComparisonLevel {
        guard other.uniqueIdentifier == self.uniqueIdentifier else { return .Different }
        guard let otherItem = other as? StaticValueItem else { return .Different }
        
        let titleDidChange = title != otherItem.title
        let valueDidChange = value != otherItem.value
        
        if !titleDidChange && !valueDidChange {
            return .Same
        } else {
            return .Changed(["title":titleDidChange, "value":valueDidChange])
        }
    }
    
}

