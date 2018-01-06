//
//  UBRDelta.swift
//
//  Created by Karsten Bruns on 26/08/15.
//  Copyright © 2015 bruns.me. All rights reserved.
//

import Foundation


public struct UBRDelta {
    
    public static func diff(old oldElements: [AnyElement], new newElements: [AnyElement], findDuplicatedElements: Bool = false) -> DeltaComparisonResult {
        // Init return vars
        var insertionIndexes = [Int]()
        var deletionIndexes = [Int]()
        var reloadIndexMap = [Int:Int]()
        var moveIndexMap = [Int:Int]()
        var unmovedElements = [AnyElement]()
        var duplicatedIndexes: [Int]? = findDuplicatedElements ? [Int]() : nil
        
        // Diffing
        var newIDs = [Int]()
        var unmIDs = [Int]()
        var reloadIDs = Set<Int>()
        var oldIDMap = [Int:Int]()
        var newIDMap = [Int:Int]()
        
        // Test
        if findDuplicatedElements {
            var uniqueIndexes = Set<Int>()
            for (newIndex, newElement) in newElements.enumerated() {
                let newId = newElement.uniqueIdentifier
                if uniqueIndexes.contains(newId) {
                    duplicatedIndexes?.append(newIndex)
                } else {
                    uniqueIndexes.insert(newId)
                }
            }
        }
        
        // Prepare mapping vars for new items
        for (newIndex, newElement) in newElements.enumerated() {
            let newId = newElement.uniqueIdentifier
            newIDs.append(newId)
            newIDMap[newId] = newIndex
        }
        
        // - Prepare mapping vars for old items
        // - Create the unmoved array
        // - Search for deletions
        for (oldIndex, oldElement) in oldElements.enumerated() {
            let id = oldElement.uniqueIdentifier
            oldIDMap[id] = oldIndex
            if let newIndex = newIDMap[id] {
                let newElement = newElements[newIndex]
                unmovedElements.append(newElement)
                unmIDs.append(id)
            } else {
                deletionIndexes.append(oldIndex)
            }
        }
        
        // Search for insertions and updates
        for (newIndex, newElement) in newElements.enumerated() {
            // Looking for changes
            let id = newElement.uniqueIdentifier
            if let oldIndex = oldIDMap[id] {
                let oldElement = oldElements[oldIndex]
                if !oldElement.isEqual(to: newElement) {
                    // Found change
                    reloadIDs.insert(id)
                }
            } else {
                // Found insertion
                insertionIndexes.append(newIndex)
                unmovedElements.insert(newElement, at: newIndex)
                unmIDs.insert(id, at: newIndex)
            }
        }
        
        // Reload
        for (unmIndex, unmElement) in unmovedElements.enumerated() {
            let id = unmElement.uniqueIdentifier
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
        let comparisonResult = DeltaComparisonResult(
            insertionIndexes: insertionIndexes,
            deletionIndexes: deletionIndexes,
            reloadIndexMap: reloadIndexMap,
            moveIndexMap: moveIndexMap,
            oldElements: newElements,
            unmovedElements: unmovedElements,
            newElements: newElements,
            duplicatedIndexes: duplicatedIndexes
        )
        
        return comparisonResult
    }
    
}
