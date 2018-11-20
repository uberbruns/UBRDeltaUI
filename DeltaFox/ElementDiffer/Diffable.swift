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
public protocol Diffable {
    
    /// The uniqued identifier is used to determine if to instances
    /// represent the same set of data
    var uniqueIdentifier: Int { get }
    
    /// ...
    var hashValue: Int { get }
}


protocol DiffableSection: Diffable {
    var diffableSubitems: [Diffable] { get }
}
