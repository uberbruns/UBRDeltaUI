//
//  Differ.swift
//
//  Created by Karsten Bruns on 26/08/15.
//  Copyright © 2015 bruns.me. All rights reserved.
//

import Foundation


public struct Differ {
    
    public static func compare(old oldItems: [AnyDiffable], new newItems: [AnyDiffable], findDuplicatedItems: Bool = false) -> DifferResult {
        // Init return vars
        var insertionIndexes = [Int]()
        var deletionIndexes = [Int]()
        var reloadIndexMap = [Int:Int]()
        var moveIndexMap = [Int:Int]()
        var unmovedItems = [AnyDiffable]()
        var duplicatedIndexes: [Int]? = findDuplicatedItems ? [Int]() : nil
        
        // Diffing
        var newIDs = [Int]()
        var unmIDs = [Int]()
        var reloadIDs = Set<Int>()
        var oldIDMap = [Int:Int]()
        var newIDMap = [Int:Int]()
        
        // Test
        if findDuplicatedItems {
            var uniqueIndexes = Set<Int>()
            for (newIndex, newModel) in newItems.enumerated() {
                let newId = newModel.uniqueIdentifier
                if uniqueIndexes.contains(newId) {
                    duplicatedIndexes?.append(newIndex)
                } else {
                    uniqueIndexes.insert(newId)
                }
            }
        }
        
        // Prepare mapping vars for new items
        for (newIndex, newModel) in newItems.enumerated() {
            let newId = newModel.uniqueIdentifier
            newIDs.append(newId)
            newIDMap[newId] = newIndex
        }
        
        // - Prepare mapping vars for old items
        // - Create the unmoved array
        // - Search for deletions
        for (oldIndex, oldItem) in oldItems.enumerated() {
            let id = oldItem.uniqueIdentifier
            oldIDMap[id] = oldIndex
            if let newIndex = newIDMap[id] {
                let newModel = newItems[newIndex]
                unmovedItems.append(newModel)
                unmIDs.append(id)
            } else {
                deletionIndexes.append(oldIndex)
            }
        }
        
        // Search for insertions and updates
        for (newIndex, newModel) in newItems.enumerated() {
            // Looking for changes
            let id = newModel.uniqueIdentifier
            if let oldIndex = oldIDMap[id] {
                let oldItem = oldItems[oldIndex]
                if !oldItem.isEqual(to: newModel) {
                    // Found change
                    reloadIDs.insert(id)
                }
            } else {
                // Found insertion
                insertionIndexes.append(newIndex)
                unmovedItems.insert(newModel, at: newIndex)
                unmIDs.insert(id, at: newIndex)
            }
        }
        
        // Reload
        for (unmIndex, unmModel) in unmovedItems.enumerated() {
            let id = unmModel.uniqueIdentifier
            if reloadIDs.contains(id) {
                let oldIndex = oldIDMap[id]!
                reloadIndexMap[oldIndex] = unmIndex
            }
        }
        
        // Detect moving items
        let diffResult = DiffArray<Int>.diff(unmIDs, newIDs)
        for diffStep in diffResult.results {
            switch diffStep {
            case .delete(let unmIndex, let id) :
                let newIndex = newIDMap[id]!
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
