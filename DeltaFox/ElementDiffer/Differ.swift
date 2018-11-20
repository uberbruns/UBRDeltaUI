//
//  Differ.swift
//
//  Created by Karsten Bruns on 26/08/15.
//  Copyright © 2015 bruns.me. All rights reserved.
//

import Foundation


public struct Differ {
    
    public static func compare(old oldItems: [Diffable], new newItems: [Diffable], findDuplicatedItems: Bool = false) -> DifferResult {
        // Init return vars
        var insertionIndexes = [Int]()
        var deletionIndexes = [Int]()
        var reloadIndexMap = [Int:Int]()
        var moveIndexMap = [Int:Int]()
        var unmovedItems = [Diffable]()
        var duplicatedIndexes: [Int]? = findDuplicatedItems ? [Int]() : nil
        
        // Diffing
        var newIds = [Int]()
        var unmIds = [Int]()
        var reloadIds = Set<Int>()
        var oldIdMap = [Int:Int]()
        var newIdMap = [Int:Int]()
        
        // Test
        if findDuplicatedItems {
            var uniqueIndexes = Set<Int>()
            for (newIndex, newItem) in newItems.enumerated() {
                let newId = newItem.uniqueIdentifier
                if uniqueIndexes.contains(newId) {
                    duplicatedIndexes?.append(newIndex)
                } else {
                    uniqueIndexes.insert(newId)
                }
            }
        }
        
        // Prepare mapping vars for new items
        for (newIndex, newItem) in newItems.enumerated() {
            let newId = newItem.uniqueIdentifier
            newIds.append(newId)
            newIdMap[newId] = newIndex
        }
        
        // - Prepare mapping vars for old items
        // - Create the unmoved array
        // - Search for deletions
        for (oldIndex, oldItem) in oldItems.enumerated() {
            let id = oldItem.uniqueIdentifier
            oldIdMap[id] = oldIndex
            if let newIndex = newIdMap[id] {
                let newItem = newItems[newIndex]
                unmovedItems.append(newItem)
                unmIds.append(id)
            } else {
                deletionIndexes.append(oldIndex)
            }
        }
        
        // Search for insertions and updates
        for (newIndex, newItem) in newItems.enumerated() {
            // Looking for changes
            let id = newItem.uniqueIdentifier
            if let oldIndex = oldIdMap[id] {
                let oldItem = oldItems[oldIndex]
                if oldItem.hashValue != newItem.hashValue {
                    // Found change
                    reloadIds.insert(id)
                }
            } else {
                // Found insertion
                insertionIndexes.append(newIndex)
                unmovedItems.insert(newItem, at: newIndex)
                unmIds.insert(id, at: newIndex)
            }
        }
        
        // Reload
        for (unmIndex, unmItem) in unmovedItems.enumerated() {
            let id = unmItem.uniqueIdentifier
            if reloadIds.contains(id) {
                let oldIndex = oldIdMap[id]!
                reloadIndexMap[oldIndex] = unmIndex
            }
        }
        
        // Detect moving items
        let diffResult = DiffArray<Int>.diff(unmIds, newIds)
        for diffStep in diffResult.results {
            switch diffStep {
            case .delete(let unmIndex, let id) :
                let newIndex = newIdMap[id]!
                moveIndexMap[unmIndex] = newIndex
            default :
                break
            }
        }
        
        // Bundle result
        let comparisonResult = DifferResult(
            insertionIndexes: insertionIndexes,
            deletionIndexes: deletionIndexes,
            reloadIndexMap: reloadIndexMap,
            moveIndexMap: moveIndexMap,
            oldItems: newItems,
            unmovedItems: unmovedItems,
            newItems: newItems,
            duplicatedIndexes: duplicatedIndexes
        )
        
        return comparisonResult
    }
    
}
