//
//  UBRDelta+Types.swift
//
//  Created by Karsten Bruns on 27/08/15.
//  Copyright © 2015 bruns.me. All rights reserved.
//

import Foundation


public typealias ComparisonChanges = [String:Bool]


public enum ComparisonLevel {
    
    case Same, Different, Changed(ComparisonChanges)
    
    public var isSame: Bool {
        return self != .Different
    }
    
    public var isChanged: Bool {
        return self != .Different && self != .Same
    }
}


extension ComparisonLevel : Equatable { }

public func ==(lhs: ComparisonLevel, rhs: ComparisonLevel) -> Bool {
    switch (lhs, rhs) {
    case (.Different, .Different) :
        return true
    case (.Same, .Same) :
        return true
    case (.Changed(let a), .Changed(let b)) :
        return a == b
    default :
        return false
    }
}


public struct ComparisonResult {
    
    public let insertionIndexes: [Int]
    public let deletionIndexes: [Int]
    public let reloadIndexMap: [Int:Int] // Old Index, New Index
    public let moveIndexMap: [Int:Int]

    public let oldItems: [ComparableItem]
    public let unmovedItems: [ComparableItem]
    public let newItems: [ComparableItem]
    
    public init(insertionIndexes: [Int], deletionIndexes: [Int], reloadIndexMap: [Int:Int], moveIndexMap: [Int:Int], oldItems: [ComparableItem], unmovedItems: [ComparableItem], newItems: [ComparableItem])
    {
        self.insertionIndexes = insertionIndexes
        self.deletionIndexes = deletionIndexes
        self.reloadIndexMap = reloadIndexMap
        self.moveIndexMap = moveIndexMap
        
        self.oldItems = oldItems
        self.unmovedItems = unmovedItems
        self.newItems = newItems
    }
    
}


public struct DeltaMatrix<T> {
    
    var rows = [Int:[Int:T]]()

    subscript(row: Int, col: Int) -> T? {
        get {
            guard let cols = rows[row] else { return nil }
            return cols[col]
        }
        set(newValue) {
            var cols = rows[row] ?? [Int:T]()
            cols[col] = newValue
            rows[row] = cols
        }
    }
    
    init() {}
    
    mutating func removeAll(keepCapicity: Bool) {
        rows.removeAll(keepCapacity: keepCapicity)
    }
}
