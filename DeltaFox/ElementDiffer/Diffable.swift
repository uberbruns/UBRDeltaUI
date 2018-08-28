//
//  UBRDelta+Protocols.swift
//  UBRDelta
//
//  Created by Karsten Bruns on 17/11/15.
//  Copyright © 2015 bruns.me. All rights reserved.
//

import Foundation

/// This protocol is the foundation for diffing types:
/// It allows UBRDelta to compare instances by determining
/// if instances are a) the same, b) the same with changed properties, c) completly different entities.
public protocol AnyDiffable {
    
    /// The uniqued identifier is used to determine if to instances
    /// represent the same set of data
    var uniqueIdentifier: Int { get }
    
    /// Implement this function to determine how two instances relate to another
    /// Are they the same, same but with changed data or completly differtent
    func isEqual(to other: AnyDiffable) -> Bool
}


public protocol Diffable: AnyDiffable {
    func isEqual(to other: Self) -> Bool
}


public extension Diffable {
    func isEqual(to other: AnyDiffable) -> Bool {
        if let otherOfSameType = other as? Self {
            return isEqual(to: otherOfSameType)
        } else {
            return false
        }
    }
}


protocol DiffableSection: AnyDiffable {
    var diffableSubitems: [AnyDiffable] { get }
}
