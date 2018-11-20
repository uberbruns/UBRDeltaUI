//
//  DeltaFoxTests.swift
//  DeltaFoxTests
//
//  Created by Karsten Bruns on 07/04/16.
//  Copyright © 2016 bruns.me. All rights reserved.
//

import XCTest
@testable import DeltaFox


class DeltaFoxTests: XCTestCase {
    
    let kirk = Captain(name: "James T. Kirk", ships: ["USS Enterprise", "USS Enterprise-A"], fistFights: Int.max)
    let picard = Captain(name: "Jean-Luc Picard", ships: ["USS Stargazer", "USS Enterprise-D", "USS Enterprise-E"], fistFights: 8)
    let sisko = Captain(name: "Benjamin Sisko", ships: ["USS Defiant"], fistFights: 36)
    let janeway = Captain(name: "Kathrin Janeway", ships: ["USS Voxager"], fistFights: 12)

    
    func diff(old oldElements: [Diffable], new newElements: [Diffable], findDuplicatedElements: Bool = false) -> DeltaFox.DifferResult {
        return Differ.compare(old: oldElements, new: newElements, findDuplicatedElements: findDuplicatedElements)
    }
    
    
    override func setUp() {
        super.setUp()
    }
    
    
    override func tearDown() {
        super.tearDown()
    }
    
    
    func testNothingModel() {
        do {
            let result = diff(old: [kirk, picard, sisko, janeway], new: [kirk, picard, sisko, janeway])
            XCTAssertEqual(result.insertionIndexes, [], "Nothing Inserted")
            XCTAssertEqual(result.insertionIndexes, [], "Nothing Deleted")
        }
    }
    
    
    func testInsertOneModel() {
        do {
            let result = diff(old: [kirk, picard], new: [sisko, kirk, picard])
            XCTAssertEqual(result.insertionIndexes, [0], "Insert one item at index 0")
        }
        
        do {
            let result = diff(old: [kirk, picard], new: [kirk, sisko, picard])
            XCTAssertEqual(result.insertionIndexes, [1], "Insert one item at index 1")
        }
        
        do {
            let result = diff(old: [kirk, picard], new: [kirk, picard, sisko])
            XCTAssertEqual(result.insertionIndexes, [2], "Insert one item at index 2")
        }
    }
    
    
    func testInsertMultipleModel() {
        do {
            let result = diff(old: [kirk], new: [picard, sisko, kirk])
            XCTAssertEqual(result.insertionIndexes, [0,1], "Insert two items at index 0")
        }
        do {
            let result = diff(old: [kirk], new: [kirk, picard, sisko])
            XCTAssertEqual(result.insertionIndexes, [1,2], "Insert two items at index 1")
        }
        do {
            let result = diff(old: [kirk], new: [picard, kirk, sisko])
            XCTAssertEqual(result.insertionIndexes, [0,2], "Insert two items at index 0 and 1")
        }
    }
    
    
    func testDeleteOneModel() {
        do {
            let result = diff(old: [kirk, picard, sisko, janeway], new: [picard, sisko, janeway])
            XCTAssertEqual(result.deletionIndexes, [0], "Delete one item at index 0")
        }
        do {
            let result = diff(old: [kirk, picard, sisko, janeway], new: [kirk, picard, janeway])
            XCTAssertEqual(result.deletionIndexes, [2], "Delete one item at index 2")
        }
        do {
            let result = diff(old: [kirk, picard, sisko, janeway], new: [kirk, sisko, picard])
            XCTAssertEqual(result.deletionIndexes, [3], "Delete one item at index 3")
        }
    }
    
    
    func testDeleteMultipleModel() {
        do {
            let result = diff(old: [kirk, picard, sisko, janeway], new: [sisko, janeway])
            XCTAssertEqual(result.deletionIndexes, [0,1], "Delete two items at index 0")
        }
        do {
            let result = diff(old: [kirk, picard, sisko, janeway], new: [kirk, janeway])
            XCTAssertEqual(result.deletionIndexes, [1,2], "Delete two items at index 1")
        }
        do {
            let result = diff(old: [kirk, picard, sisko, janeway], new: [kirk, picard])
            XCTAssertEqual(result.deletionIndexes, [2,3], "Delete two items at index 2")
        }
        do {
            let result = diff(old: [kirk, picard, sisko, janeway], new: [picard, sisko])
            XCTAssertEqual(result.deletionIndexes, [0,3], "Delete two items at index 0 and 3")
        }
        do {
            let result = diff(old: [kirk, picard, sisko, janeway], new: [])
            XCTAssertEqual(result.deletionIndexes, [0,1,2,3], "Delete all")
        }
    }
    
    
    func testInsertAndDeleteMultipleModel() {
        do {
            let result = diff(old: [kirk, picard, sisko], new: [kirk, sisko, janeway])
            XCTAssertEqual(result.deletionIndexes, [1], "Delete one item at index 1")
            XCTAssertEqual(result.insertionIndexes, [2], "Insert one item at index 2")
        }
        do {
            let result = diff(old: [kirk, picard], new: [sisko, janeway])
            XCTAssertEqual(result.deletionIndexes, [0,1], "Delete one item at index 1")
            XCTAssertEqual(result.insertionIndexes, [0,1], "Insert one item at index 2")
        }
    }
    
    
    func testUnmovedArray() {
        do {
            let result = diff(old: [kirk, picard, sisko, janeway], new: [sisko, picard, kirk, janeway])
            XCTAssertEqual(result.unmovedElements.flatMap({ $0 as? Captain }), [kirk, picard, sisko, janeway], "Not Moving")
        }
        do {
            let result = diff(old: [kirk, picard, sisko, janeway], new: [picard, kirk, janeway])
            XCTAssertEqual(result.unmovedElements.flatMap({ $0 as? Captain }), [kirk, picard, janeway], "Not Moving with Deletion")
        }
        do {
            let result = diff(old: [kirk, picard, janeway], new: [sisko, picard, kirk, janeway])
            XCTAssertEqual(result.unmovedElements.flatMap({ $0 as? Captain }), [sisko, kirk, picard, janeway], "Not moving with insertion")
        }
        do {
            let result = diff(old: [kirk, janeway, picard], new: [sisko, janeway, kirk])
            XCTAssertEqual(result.unmovedElements.flatMap({ $0 as? Captain }), [sisko, kirk, janeway], "Not Moving with Insertion and deletion")
        }
    }
    
    
    func testMoveOneModel() {
        do {
            let result = diff(old: [kirk, picard, sisko, janeway], new: [picard, kirk, sisko, janeway])
            XCTAssertEqual(result.moveIndexMap, [0:1], "Move one item from index 0 to index 1")
        }
        do {
            let result = diff(old: [kirk, picard, sisko, janeway], new: [picard, sisko, janeway, kirk])
            XCTAssertEqual(result.moveIndexMap, [0:3], "Move one item from index 0 to index 3")
        }
        do {
            let result = diff(old: [kirk, picard, sisko, janeway], new: [janeway, sisko, picard, kirk])
            XCTAssertEqual(result.moveIndexMap, [0:3, 1:2, 2:1], "Flip")
        }
    }
    
    
    func testReloadElements() {
        var janeway2 = janeway
        janeway2.ships.append("Delta Flyer")
        do {
            let result = diff(old: [kirk, picard, sisko, janeway], new: [kirk, picard, sisko, janeway2])
            XCTAssertEqual(result.reloadIndexMap, [3:3], "Reload one item at index 3")
        }
        do {
            let result = diff(old: [kirk, picard, sisko, janeway], new: [kirk, janeway2])
            XCTAssertEqual(result.reloadIndexMap, [3:1], "Reload one item at index 3 that ends up being at index 1")
        }
    }
    
    
    func testMixed() {
        var janeway2 = janeway
        janeway2.ships.append("Delta Flyer")
        do {
            let result = diff(old: [picard, sisko, janeway], new: [kirk, janeway2, picard])
            XCTAssertEqual(result.reloadIndexMap, [2:2], "Reload one item")
            XCTAssertEqual(result.insertionIndexes, [0], "Insert one item")
            XCTAssertEqual(result.deletionIndexes, [1], "Insert one item")
            XCTAssertEqual(result.unmovedElements.flatMap({ $0 as? Captain }).map({ $0.name }), [kirk, picard, janeway2].map({ $0.name }), "Unmoved state")
            XCTAssertEqual(result.moveIndexMap, [1:2], "Move one item")
        }
    }
    
    
    func testDynamic() {
        
        for _ in 0..<32 {
            
            // Create Original Array
            let oldCaptains = (0..<256).map { num in Captain(name: "\(num+10)", ships: ["USS Enterprise-\(num)"], fistFights: num) }
            
            // Create Changed Array
            var newCaptains = [Captain]()
            var moving = [Captain]()
            
            var deletions = 0
            var insertions = 0
            var changes = 0
            
            for (index, captain) in oldCaptains.enumerated() {
                let rand = arc4random_uniform(8)
                if rand == 0 {
                    deletions += 1
                } else if rand == 1 {
                    let num = oldCaptains.count + index
                    let newCaptian = Captain(name: "name\(num)", ships: ["USS Enterprise-\(num)"], fistFights: num)
                    newCaptains.append(newCaptian)
                    newCaptains.append(captain)
                    insertions += 1
                } else if rand == 2 {
                    var newCaptian = captain
                    newCaptian.fistFights += 1
                    newCaptains.append(newCaptian)
                    changes += 1
                } else if rand == 3 {
                    moving.append(captain)
                } else {
                    newCaptains.append(captain)
                }
            }
            
            // Move
            for captain in moving {
                let randIndex = Int(arc4random_uniform(UInt32(newCaptains.count)))
                newCaptains.insert(captain, at: randIndex)
            }
            
            // Diff Captains
            let result = self.diff(old: oldCaptains.map({ $0 as Diffable }), new: newCaptains.map({ $0 as Diffable }))
            
            // Apply comparison result to oldCaptians
            // Expectation is that the changed `oldCaptains` in the end equals `newCaptians`
            var unmovedCaptainsRef = [Captain]()
            
            // Apply Deletes and Reloads
            let deletionSet = Set(result.deletionIndexes)
            for (index, captain) in oldCaptains.enumerated() where !deletionSet.contains(index) {
                unmovedCaptainsRef.append(captain)
            }
            
            // Apply Inserts
            for index in result.insertionIndexes {
                unmovedCaptainsRef.insert(newCaptains[index], at: index)
            }
            
            // Apply Reloads
            for (oldIndex, unmIndex) in result.reloadIndexMap {
                let a = oldCaptains[oldIndex]
                let b = result.unmovedElements[unmIndex] as! Captain
                unmovedCaptainsRef[unmIndex] = b
                XCTAssertEqual(a.uniqueIdentifier, b.uniqueIdentifier, "Reloading same item")
            }
            
            // Move Elements
            var newCaptainsRef = [Captain]()
            for (oldIndex, captain) in unmovedCaptainsRef.enumerated() {
                if result.moveIndexMap[oldIndex] == nil {
                    newCaptainsRef.append(captain)
                }
            }
            
            for (_, to) in result.moveIndexMap.sorted(by: { $0.1 < $1.1 }) {
                let model = newCaptains[to]
                newCaptainsRef.insert(model, at: to)
            }
            
            // Test
            let unmovedCaptians = result.unmovedElements.flatMap({ $0 as? Captain })
            XCTAssertEqual(insertions, result.insertionIndexes.count, "Insertions")
            XCTAssertEqual(deletions, result.deletionIndexes.count, "Deletions")
            XCTAssertEqual(changes, result.reloadIndexMap.count, "Changes")
            XCTAssertEqual(unmovedCaptians, unmovedCaptainsRef, "Dynamic test of unmoved items")
            XCTAssertEqual(newCaptains, newCaptainsRef, "Dynamic test of final items")
        }
    }
    
    
    func testMeasure() {
        
        // Create Original Array
        let oldCaptains = (0..<512).map { num in Captain(name: "\(num+10)", ships: ["USS Enterprise-\(num)"], fistFights: num) }
        
        // Create Changed Array
        var newCaptains = [Captain]()
        var moving = [Captain]()
        
        for (index, captain) in oldCaptains.enumerated() {
            let num = index%8
            if num == 0 {
                // Delete
            } else if num == 2 {
                let num = oldCaptains.count + index
                let newCaptian = Captain(name: "name\(num)", ships: ["USS Enterprise-\(num)"], fistFights: num)
                newCaptains.append(newCaptian)
                newCaptains.append(captain)
            } else if num == 3 {
                var newCaptian = captain
                newCaptian.fistFights += 1
                newCaptains.append(newCaptian)
            } else if num == 4 {
                moving.append(captain)
            } else {
                newCaptains.append(captain)
            }
        }
        
        // Move
        for captain in moving {
            let randIndex = Int(arc4random_uniform(UInt32(newCaptains.count)))
            newCaptains.insert(captain, at: randIndex)
        }
        
        // Diff Captains
        let oldElements = oldCaptains.map({ $0 as Diffable })
        let newElements = newCaptains.map({ $0 as Diffable })
        
        measure {
            _ = self.diff(old: oldElements, new: newElements)
        }
    }
    
    
    func testDuplicateWarning() {
        do {
            let result = diff(old: [kirk, sisko], new: [sisko, sisko], findDuplicatedElements: true)
            XCTAssertEqual(result.duplicatedIndexes ?? [], [1], "Duplicate Warning")
        }

        do {
            let result = diff(old: [kirk, sisko], new: [sisko, picard, janeway, kirk, sisko], findDuplicatedElements: true)
            XCTAssertEqual(result.duplicatedIndexes ?? [], [4], "Duplicate Warning")
        }

        do {
            let result = diff(old: [kirk, sisko], new: [kirk, sisko], findDuplicatedElements: true)
            XCTAssertEqual(result.duplicatedIndexes ?? [], [], "Duplicate Warning")
        }
    }
}
