//
//  UBRDelta+Types.swift
//
//  Created by Karsten Bruns on 27/08/15.
//  Copyright © 2015 bruns.me. All rights reserved.
//

import Foundation


public struct DifferResult {
    
    public let insertionIndexes: [Int]
    public let deletionIndexes: [Int]
    public let duplicatedIndexes: [Int]?
    public let reloadIndexMap: [Int:Int] // Old Index, New Index
    public let moveIndexMap: [Int:Int]

    public let oldItems: [Diffable]
    public let unmovedItems: [Diffable]
    public let newItems: [Diffable]
    
    
    init(insertionIndexes: [Int],
                deletionIndexes: [Int],
                reloadIndexMap: [Int:Int],
                moveIndexMap: [Int:Int],
                oldItems: [Diffable],
                unmovedItems: [Diffable],
                newItems: [Diffable],
                duplicatedIndexes: [Int]? = nil) {
        self.insertionIndexes = insertionIndexes
        self.deletionIndexes = deletionIndexes
        self.reloadIndexMap = reloadIndexMap
        self.moveIndexMap = moveIndexMap
        
        self.oldItems = oldItems
        self.unmovedItems = unmovedItems
        self.newItems = newItems
        self.duplicatedIndexes = duplicatedIndexes
    }
    
}


struct DeltaMatrix<T> {
    
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
    
    mutating func removeAll(_ keepCapicity: Bool) {
        rows.removeAll(keepingCapacity: keepCapicity)
    }
}
