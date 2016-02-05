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
public protocol ComparableItem {
    
    /// The uniqued identifier is used to determine if to instances
    /// represent the same set of data
    var uniqueIdentifier: Int { get }
    
    /// Implement this function to determine how two instances relate to another
    /// Are they the same, same but with changed data or completly differtent
    func compareTo(other: ComparableItem) -> ComparisonLevel
    
}
