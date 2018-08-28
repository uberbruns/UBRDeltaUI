//
//  SectionDiffer.swift
//
//  Created by Karsten Bruns on 27/08/15.
//  Copyright © 2015 bruns.me. All rights reserved.
//

import Foundation


class SectionDiffer {
    
    typealias ItemUpdateHandler = (_ items: [AnyDiffable], _ section: Int, _ insertIndexPaths: [Int], _ reloadIndexPaths: [Int:Int], _ deleteIndexPaths: [Int]) -> Void
    typealias ItemReorderHandler = (_ items: [AnyDiffable], _ section: Int, _ reorderMap: [Int:Int]) -> Void
    typealias SectionUpdateHandler = (_ sections: [DiffableSection], _ insertIndexSet: [Int], _ reloadIndexSet: [Int:Int], _ deleteIndexSet: [Int]) -> Void
    typealias SectionReorderHandler = (_ sections: [DiffableSection], _ reorderMap: [Int:Int]) -> Void
    typealias StartHandler = () -> Void
    typealias CompletionHandler = () -> Void
    typealias AnimationContext = (() -> Void, @escaping () -> Void) -> Void

    var throttleTimeInterval: Double = 4.0 / 60.0
    var debugOutput = false
    
    // Update handler
    var animationContext: AnimationContext? = nil
    var itemUpdate: ItemUpdateHandler? = nil
    var itemReorder: ItemReorderHandler? = nil
    var sectionUpdate: SectionUpdateHandler? = nil
    var sectionReorder: SectionReorderHandler? = nil
    
    var start: StartHandler? = nil
    var completion: CompletionHandler? = nil
    
    // State vars for background operations
    private var isDiffing = false
    private var resultIsOutOfDate = false
    
    // State vars to throttle UI update
    private var nextDiffIsScheduled = false
    private var lastUpdateTime = Date.distantPast
    
    // Section data
    private var oldSections: [DiffableSection]? = nil
    private var newSections: [DiffableSection]? = nil
    
    
    init() {}
    
    
    func queueComparison(oldSections: [DiffableSection], newSections: [DiffableSection]) {
        // Set Sections
        if self.oldSections == nil {
            // Old section should change only when a diff completes
            // and it got niled out
            self.oldSections = oldSections
        }
        
        // New section are always defined
        self.newSections = newSections
        
        // Guarding
        if isDiffing == true {
            // We declare the current result as out-of-date
            // because more recent 'newSections' are available
            resultIsOutOfDate = true
            return
        }
        
        diff()
    }
    
    
    private func diff() {
        // Guarding
        guard let oldSections = self.oldSections,
            let newSections = self.newSections
            else { return }

        // Prepare
        let backgroundQueue = DispatchQueue.global(qos: .userInteractive)
        let reportDuplicatedItems = self.debugOutput

        // Define State
        isDiffing = true
        resultIsOutOfDate = false

        // Do the diffing on a background thread
        backgroundQueue.async {

            // Diffing Items
            var diffs = [Int:DifferResult]()
            for (oldSectionIndex, oldSection) in oldSections.enumerated() {
                
                let newIndex = newSections.index { newSection -> Bool in
                    let isSame = newSection.uniqueIdentifier == oldSection.uniqueIdentifier
                    let isEqual = newSection.isEqual(to: oldSection)
                    return isSame && isEqual
                }
                
                if let newIndex = newIndex {
                    // Diffing
                    let oldItems = oldSection.diffableSubitems
                    let newItems = newSections[newIndex].diffableSubitems
                    let diff = Differ.compare(old: oldItems, new: newItems, findDuplicatedItems: reportDuplicatedItems)
                    diffs[oldSectionIndex] = diff
                    
                    if reportDuplicatedItems, let duplicatedIndexes = diff.duplicatedIndexes, duplicatedIndexes.count > 0 {
                        print("\n")
                        print("WARNING: Duplicated items detected. App will probably crash.")
                        print("Dublicated indexes:", duplicatedIndexes)
                        print("Dublicated items:", duplicatedIndexes.map({ newItems[$0] }))
                        print("\n")
                    }
                }
            }
            
            // Satisfy argument requirements of UBRDelta.diff()
            let oldSectionAsItems = oldSections.map({ $0 as AnyDiffable })
            let newSectionsAsItems = newSections.map({ $0 as AnyDiffable })
            
            // Diffing sections
            let sectionDiff = Differ.compare(old: oldSectionAsItems, new: newSectionsAsItems, findDuplicatedItems: reportDuplicatedItems)
            
            if reportDuplicatedItems, let duplicatedIndexes = sectionDiff.duplicatedIndexes, duplicatedIndexes.count > 0 {
                print("\n")
                print("WARNING: Duplicated section items detected. App will probably crash.")
                print("Dublicated indexes:", duplicatedIndexes)
                print("Dublicated section items:", duplicatedIndexes.map({ newSections[$0] }))
                print("\n")
            }

            // Diffing is done - doing UI updates on the main thread
            DispatchQueue.main.async { [weak self] in
                guard let this = self else { return }

                this.animationContext?({
                    // Guardings
                    if this.resultIsOutOfDate == true {
                        // In the meantime 'newResults' came in, this means
                        // a new diff() and we are stopping the update
                        this.diff()
                        return
                    }
                    
                    if this.nextDiffIsScheduled {
                        // There is already a future diff() scheduled
                        // we are stopping here
                        return
                    }
                    
                    let updateAllowedIn = this.lastUpdateTime.timeIntervalSinceNow + this.throttleTimeInterval
                    if  updateAllowedIn > 0 {
                        // updateAllowedIn > 0 means the allowed update time is in the future
                        // so we schedule a new diff() for this point in time
                        this.nextDiffIsScheduled = true
                        SectionDiffer.executeDelayed(updateAllowedIn) {
                            this.nextDiffIsScheduled = false
                            this.diff()
                        }
                        return
                    }
                    
                    // Calling the handler functions
                    this.start?()
                    
                    // Diffable update for the old section order, because the sections
                    // are not moved yet
                    for (oldSectionIndex, diff) in diffs.sorted(by: { $0.0 < $1.0 }) {
                        
                        // Call item handler functions
                        this.itemUpdate?(
                            diff.unmovedItems,
                            oldSectionIndex,
                            diff.insertionIndexes,
                            diff.reloadIndexMap,
                            diff.deletionIndexes
                        )
                        this.itemReorder?(diff.newItems, oldSectionIndex, diff.moveIndexMap)
                    }
                    
                    // Change type from Diffable to DiffableSection.
                    // Since this is expected to succeed a force unwrap is justified
                    let updateItems = sectionDiff.unmovedItems.map({ $0 as! DiffableSection })
                    let reorderItems = sectionDiff.newItems.map({ $0 as! DiffableSection })
                    
                    // Call section handler functions
                    this.sectionUpdate?(updateItems, sectionDiff.insertionIndexes, sectionDiff.reloadIndexMap, sectionDiff.deletionIndexes)
                    this.sectionReorder?(reorderItems, sectionDiff.moveIndexMap)
                }, {
                    // Call completion block
                    this.completion?()
                })
                
                // Reset state
                this.lastUpdateTime = Date()
                this.oldSections = nil
                this.newSections = nil
                this.isDiffing = false
            }
        }
    }
    
    
    static private func executeDelayed(_ time: Int, action: @escaping () -> Void) {
        executeDelayed(Double(time), action: action)
    }
    
    
    static private func executeDelayed(_ time: Double, action: @escaping () -> Void) {
        if time > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + time, execute: action)
        } else {
            action()
        }
    }
}
