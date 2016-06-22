//
//  DeltaTableViewController.swift
//  CompareApp
//
//  Created by Karsten Bruns on 30/08/15.
//  Copyright © 2015 bruns.me. All rights reserved.
//

import UIKit


/// Options to fine tune the debug output. Please note, that the options .Debug and .Warnings have an impact on performance
public enum DeltaDebugOutput {
    case None
    case Debug
    case Warnings
}


/// Options to finetune the update process
public enum DeltaUpdateOptions {
    /// Default incremental update
    case Default

    /// Non incremental update, like calling tableView.reloadData
    case HardReload
    
    /// Like default, but all visible cells will be updated
    case UpdateVisibleCells
    
    /// Use this if you know the table view is in a valid, but the data is in an invalid state
    case DataOnly
}


public class DeltaTableView : UITableView {}


public class DeltaTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - Controller -
    
    public var reusableCellClasses = [String:UITableViewCell.Type]()
    public var reusableHeaderFooterClasses = [String:UITableViewHeaderFooterView.Type]()
    
    public private(set) var sections: [DeltaTableViewSectionItem] = []
    private let contentDiffer = UBRDeltaContent()
    private var animateViews = true
    private var deltaUpdateOptions = DeltaUpdateOptions.Default
    public var deltaDebugOutput = DeltaDebugOutput.None
    
    private var estimatedCellHeights = DeltaMatrix<CGFloat>()
    private var learnedCellHeights = DeltaMatrix<CGFloat>()
    private var headerFooterPrototypes = [String:UITableViewHeaderFooterView]()
    public let tableView = DeltaTableView(frame: CGRectZero, style: .Grouped)
    
    
    // Table View API
    
    /// The type of animation when rows are deleted.
    public var rowDeletionAnimation = UITableViewRowAnimation.Automatic
    
    /// The type of animation when rows are inserted.
    public var rowInsertionAnimation = UITableViewRowAnimation.Automatic
    
    /// The type of animation when rows are reloaded (not updated)
    public var rowReloadAnimation = UITableViewRowAnimation.Automatic
    
    /// The type of animation when sections are deleted.
    public var sectionDeletionAnimation = UITableViewRowAnimation.Automatic
    
    /// The type of animation when sections are inserted.
    public var sectionInsertionAnimation = UITableViewRowAnimation.Automatic
    
    /// The type of animation when sections are reloaded (not updated)
    public var sectionReloadAnimation = UITableViewRowAnimation.Automatic
    
    
    
    // MARK: - View -
    // MARK: Life-Cycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        configureContentDiffer()
        prepareReusableTableViewCells()
        loadHeaderFooterViewPrototypes()
        addTableView()
        updateTableView()
    }
    
    
    // MARK: Add Views
    
    /// Adds and configures the table view to the controller
    private func addTableView() {
        // Add
        view.addSubview(tableView)
        
        // Configure
        tableView.delegate = self
        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        // Configuring rows for auto layout
        // Note: Header and footer views are calculated usnig protoype views, because
        // using UITableViewAutomaticDimension for header and footer views leads to broken
        // animated table view updates
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 44.0
        
        // Add reusable cells
        prepareReusableTableViewCells()
        reusableCellClasses.forEach { (identifier, cellClass) -> () in tableView.registerClass(cellClass, forCellReuseIdentifier: identifier) }
        reusableHeaderFooterClasses.forEach { (identifier, hfClass) -> () in tableView.registerClass(hfClass, forHeaderFooterViewReuseIdentifier: identifier) }
        
        // Constraints
        let viewDict = ["tableView" : tableView]
        let v = NSLayoutConstraint.constraintsWithVisualFormat("V:|-0-[tableView]-0-|", options: [], metrics: nil, views: viewDict)
        let h = NSLayoutConstraint.constraintsWithVisualFormat("H:|-0-[tableView]-0-|", options: [], metrics: nil, views: viewDict)
        view.addConstraints(v + h)
    }
    
    
    // MARK: Update Views
    
    /**
     Default way of updating the table view
     
     - Parameter animated: if true (default) performs a partial table view that will only update changes cells
     */
    public func updateView(animated animated: Bool = true) {
        if animated {
            animateViews = animated
            updateTableView()
        } else {
            updateTableView(options: .HardReload)
        }
    }
    
    
    /**
     Advanced way of updating the table view

     __Discussion:__ this functions and `updateView` should be replaced with another approach.
     For example `setTableViewNeedsUpdate`.

     - Parameter options: Enum with instructions on how to update the table view. Default is `.Default`.
     
     */
    public func updateTableView(options options: DeltaUpdateOptions = .Default) {
        let newSections: [DeltaTableViewSectionItem] = generateItems()
        
        deltaUpdateOptions = options
        learnedCellHeights.removeAll(true)
        
        if options == .DataOnly {
            sections = newSections
        } else if sections.count == 0 || options == .HardReload {
            tableViewWillUpdateCells(false)
            sections = newSections
            tableView.reloadData()
            updateLearnedHeights()
            tableViewDidUpdateCells(false)
        } else {
            let oldSections = sections.map({ $0 as ComparableSectionItem })
            let newSections = newSections.map({ $0 as ComparableSectionItem })
            contentDiffer.queueComparison(oldSections: oldSections, newSections: newSections)
        }
    }
    
    
    /**
     The better the estimated height, the better are animated table view updates. This function
     updates the internal data set of rendered cell heights for every index path.
     */
    private func updateLearnedHeights() {
        for indexPath in tableView.indexPathsForVisibleRows ?? [] {
            guard let cell = tableView.cellForRowAtIndexPath(indexPath) else { continue }
            estimatedCellHeights[indexPath.section, indexPath.row] = cell.bounds.height
            learnedCellHeights[indexPath.section, indexPath.row] = cell.bounds.height
        }
    }
    
    
    /**
     Because of aniamtion glitches with pure auto layout based table view headers and footers
     the heights of those elements are determined by keeping a set of view prototypes that
     is updated with real data upfront to learn the height of headers in footers in every sections.
     This functions creates the prototype directory.
     */
    private func loadHeaderFooterViewPrototypes() {
        headerFooterPrototypes.removeAll()
        for (reuseIdentifier, HeaderFooterClass) in reusableHeaderFooterClasses {
            let headerFooterPrototype = HeaderFooterClass.init(reuseIdentifier: reuseIdentifier)
            headerFooterPrototypes[reuseIdentifier] = headerFooterPrototype
        }
    }
    
    
    // MARK: Configuration
    
    /**
     `contentDiffer` is the heart of this class and determines what parts need to be updated.
     This functions links the `tableView` and the `contentDiffer` by calling table views update
     functions in the callback functions from the `contentDiffer`.
    */
    private func configureContentDiffer() {
        
        contentDiffer.userInterfaceUpdateTime = 0.16667
        contentDiffer.debugOutput = deltaDebugOutput != .None
        
        // Start updating table view
        contentDiffer.start = { [weak self] in
            guard let weakSelf = self else { return }
            if weakSelf.deltaDebugOutput == .Debug {
                print("Start updating table view", separator: "\n", terminator: "\n\n")
            }
            if weakSelf.animateViews == false {
                UIView.setAnimationsEnabled(false)
            }
            weakSelf.tableViewWillUpdateCells(weakSelf.animateViews)
        }
        
        // Insert, reload and delete table view rows
        contentDiffer.itemUpdate = { [weak self] (items, section, insertIndexes, reloadIndexMap, deleteIndexes) in
            guard let weakSelf = self else { return }
            
            weakSelf.sections[section].items = items.flatMap { $0 as? DeltaTableViewItem }
            
            if insertIndexes.count == 0 && reloadIndexMap.count == 0 && deleteIndexes.count == 0 {
                return
            }
            
            if weakSelf.deltaDebugOutput == .Debug {
                print("Updating rows in section \(section)", "items: \(items.map({ $0.uniqueIdentifier }))", "insertIndexes: \(insertIndexes)", "reloadIndexMap: \(reloadIndexMap)", "deleteIndexes: \(deleteIndexes)", separator: "\n", terminator: "\n\n")
            }
            
            var manualReloadMap = reloadIndexMap
            
            if weakSelf.deltaUpdateOptions != .UpdateVisibleCells {
                for (itemIndexBefore, itemIndexAfter) in reloadIndexMap {
                    let indexPathBefore = NSIndexPath(forRow: itemIndexBefore, inSection: section)
                    guard let cell = weakSelf.tableView.cellForRowAtIndexPath(indexPathBefore) else {
                        manualReloadMap.removeValueForKey(itemIndexBefore)
                        continue
                    }
                    guard let updateableCell = cell as? UpdateableTableViewCell else { continue }
                    let item: ComparableItem = items[itemIndexAfter]
                    updateableCell.updateCellWithItem(item, animated: true)
                    manualReloadMap.removeValueForKey(itemIndexBefore)
                }
            }
            
            weakSelf.tableView.beginUpdates()
            
            if manualReloadMap.count > 0 && weakSelf.deltaUpdateOptions != .UpdateVisibleCells {
                for (itemIndexBefore, _) in manualReloadMap {
                    let indexPathBefore = NSIndexPath(forRow: itemIndexBefore, inSection: section)
                    weakSelf.tableView.reloadRowsAtIndexPaths([indexPathBefore], withRowAnimation: weakSelf.rowReloadAnimation)
                }
            }
            
            if deleteIndexes.count > 0 {
                weakSelf.tableView.deleteRowsAtIndexPaths(deleteIndexes.map({ NSIndexPath(forRow: $0, inSection: section) }), withRowAnimation: weakSelf.rowDeletionAnimation)
            }
            
            if insertIndexes.count > 0 {
                weakSelf.tableView.insertRowsAtIndexPaths(insertIndexes.map({ NSIndexPath(forRow: $0, inSection: section) }), withRowAnimation: weakSelf.rowInsertionAnimation)
            }
            
            weakSelf.tableView.endUpdates()
        }
        
        // Reorder table view rows
        contentDiffer.itemReorder = { [weak self] (items, section, reorderMap) in
            guard let weakSelf = self else { return }
            
            weakSelf.sections[section].items = items.flatMap { $0 as? DeltaTableViewItem }
            
            if reorderMap.count == 0 {
                return
            }
            
            if weakSelf.deltaDebugOutput == .Debug {
                print("Reorder rows in section \(section)", "items: \(items.map({ $0.uniqueIdentifier }))", "reorderMap: \(reorderMap)", separator: "\n", terminator: "\n\n")
            }
            
            weakSelf.tableView.beginUpdates()
            for (from, to) in reorderMap {
                let fromIndexPath = NSIndexPath(forRow: from, inSection: section)
                let toIndexPath = NSIndexPath(forRow: to, inSection: section)
                weakSelf.tableView.moveRowAtIndexPath(fromIndexPath, toIndexPath: toIndexPath)
            }
            weakSelf.tableView.endUpdates()
        }
        
        // Insert, reload and delete table view sections
        contentDiffer.sectionUpdate = { [weak self] (sections, insertIndexes, reloadIndexMap, deleteIndexes) in
            guard let weakSelf = self else { return }
            
            weakSelf.sections = sections.flatMap({ $0 as? DeltaTableViewSectionItem })
            
            if insertIndexes.count == 0 && reloadIndexMap.count == 0 && deleteIndexes.count == 0 {
                return
            }
            
            if weakSelf.deltaDebugOutput == .Debug {
                print("Updating sections", "sections: \(sections.map({ $0.uniqueIdentifier }))", "insertIndexes: \(insertIndexes)", "reloadIndexMap: \(reloadIndexMap)", "deleteIndexes: \(deleteIndexes)", separator: "\n", terminator: "\n\n")
            }
            
            weakSelf.tableView.beginUpdates()
            
            let insertSet = NSMutableIndexSet()
            insertIndexes.forEach({ insertSet.addIndex($0) })
            
            let deleteSet = NSMutableIndexSet()
            deleteIndexes.forEach({ deleteSet.addIndex($0) })
            
            weakSelf.tableView.insertSections(insertSet, withRowAnimation: weakSelf.sectionInsertionAnimation)
            weakSelf.tableView.deleteSections(deleteSet, withRowAnimation: weakSelf.sectionDeletionAnimation)
            
            for (sectionIndexBefore, sectionIndexAfter) in reloadIndexMap {
                
                if let sectionItem = sections[sectionIndexAfter] as? DeltaTableViewSectionItem {
                    
                    if let headerView = weakSelf.tableView.headerViewForSection(sectionIndexBefore) as? UpdateableTableViewHeaderFooterView {
                        headerView.updateViewWithItem(sectionItem.headerItem ?? sectionItem, animated: true, type: .Header)
                    }
                    
                    if let footerView = weakSelf.tableView.footerViewForSection(sectionIndexBefore) as? UpdateableTableViewHeaderFooterView {
                        footerView.updateViewWithItem(sectionItem.footerItem ?? sectionItem, animated: true, type: .Footer)
                    }
                    
                } else {
                    weakSelf.tableView.reloadSections(NSIndexSet(index: sectionIndexBefore), withRowAnimation: weakSelf.sectionDeletionAnimation)
                }
            }
            
            weakSelf.tableView.endUpdates()
        }
        
        // Reorder table view sections
        contentDiffer.sectionReorder = { [weak self] (sections, reorderMap) in
            guard let weakSelf = self else { return }
            
            weakSelf.sections = sections.flatMap({ $0 as? DeltaTableViewSectionItem })
            
            if reorderMap.count == 0 {
                return
            }
            
            if weakSelf.deltaDebugOutput == .Debug {
                print("Reorder sections", "sections: \(sections.map({ $0.uniqueIdentifier }))", "reorderMap: \(reorderMap)", separator: "\n", terminator: "\n\n")
            }
            
            weakSelf.tableView.beginUpdates()
            for (from, to) in reorderMap {
                weakSelf.tableView.moveSection(from, toSection: to)
            }
            weakSelf.tableView.endUpdates()
        }
        
        // Updating table view did end
        contentDiffer.completion = { [weak self] in
            guard let weakSelf = self else { return }
            
            if weakSelf.deltaUpdateOptions == .UpdateVisibleCells {
                var manualReloads = [NSIndexPath]()
                for indexPath in weakSelf.tableView.indexPathsForVisibleRows ?? [] {
                    if let updateableCell = weakSelf.tableView.cellForRowAtIndexPath(indexPath) as? UpdateableTableViewCell {
                        let item: ComparableItem = weakSelf.sections[indexPath.section].items[indexPath.row]
                        updateableCell.updateCellWithItem(item, animated: false)
                    } else {
                        manualReloads.append(indexPath)
                    }
                }
                if manualReloads.count > 0 {
                    weakSelf.tableView.beginUpdates()
                    weakSelf.tableView.reloadRowsAtIndexPaths(manualReloads, withRowAnimation: weakSelf.rowReloadAnimation)
                    weakSelf.tableView.endUpdates()
                }
            }
            
            if weakSelf.deltaDebugOutput == .Debug {
                print("Updating table view ended", separator: "\n", terminator: "\n\n")
            }
            
            UIView.setAnimationsEnabled(true)
            weakSelf.tableViewDidUpdateCells(weakSelf.animateViews)
            weakSelf.animateViews = true
            weakSelf.updateLearnedHeights()
        }
    }
    
    
    // MARK: - API -
    // MARK: - Content -
    
    /// Use this function in subclasses to provide section and rows items you want to display
    /// as table view cells.
    public func generateItems() -> [DeltaTableViewSectionItem] {
        return []
    }

    
    /// Returns the `DeltaTableViewSectionItem` that belongs to the provided section index.
    public func tableViewSectionItem(section section: Int) -> DeltaTableViewSectionItem {
        return sections[section]
    }
    

    /// Returns the `ComparableItem` that belongs to the provided index path.
    public func tableViewItem(indexPath indexPath: NSIndexPath) -> DeltaTableViewItem {
        return sections[indexPath.section].items[indexPath.row]
    }

    
    // MARK: - Table View -
    
    /// Use this function in your subclass to update `reusableCellClasses` and `reusableHeaderFooterClasses`.
    public func prepareReusableTableViewCells() { }
    
    
    /// Subclass this function in your subclass to execute code when a table view will update.
    public func tableViewWillUpdateCells(animated: Bool) {}
    
    
    /// Subclass this function in your subclass to execute code when a table view did update.
    public func tableViewDidUpdateCells(animated: Bool) {}
    
    
    /**
     Dequeues a reusable cell from table view as long the item for this index path is of type `DeltaTableViewItem`
     and DeltaTableViewItem's `reuseIdentifier` property was registered in `prepareReusableTableViewCells()`.
     
     Use this method if you want to provide your own implementation of `tableView(tableView:cellForRowAtIndexPath:)` but
     you still want to be able to return cells provided by this class if needed.
     
     In most cases this function is only used internally and a custom implementation of `tableView(tableView:cellForRowAtIndexPath:)`
     is not needed.
     */
    public func tableViewCellForRowAtIndexPath(indexPath: NSIndexPath) -> UITableViewCell? {
        let item = sections[indexPath.section].items[indexPath.row]
        
        getTableViewCell : do {
            guard let cell = tableView.dequeueReusableCellWithIdentifier(item.reuseIdentifier) else { break getTableViewCell }

            if let updateableCell = cell as? UpdateableTableViewCell {
                updateableCell.updateCellWithItem(item, animated: false)
            }
            
            if let selectableItem = item as? SelectableTableViewItem {
                cell.selectionStyle = selectableItem.selectionHandler != nil ? .Default : .None
            }

            return cell
        }
        
        return nil
    }
    
    
    // MARK: - Protocols -
    // MARK: UITableViewDataSource
    
    public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return sections.count
    }
    
    
    public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].items.count
    }
    
    
    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if let cell = tableViewCellForRowAtIndexPath(indexPath) {
            return cell
        } else {
            fatalError("No cell provided for index path: \(indexPath)")
        }
    }
    
    
    // MARK: UITableViewDelegate
    // MARK: Row
    
    public func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if let learnedHeight = learnedCellHeights[indexPath.section, indexPath.row] {
            return learnedHeight
        } else {
            return UITableViewAutomaticDimension
        }
    }
    
    
    public func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return estimatedCellHeights[indexPath.section, indexPath.row] ?? tableView.estimatedRowHeight
    }
    
    
    public func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        estimatedCellHeights[indexPath.section, indexPath.row] = cell.bounds.height
        learnedCellHeights[indexPath.section, indexPath.row] = cell.bounds.height
    }
    
    
    // MARK: Header
    
    public func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let item = sections[section]
        var view: UIView?
        
        configureView : do {
            guard let headerItem = item.headerItem else { break configureView }
            guard let headerView = tableView.dequeueReusableHeaderFooterViewWithIdentifier(headerItem.reuseIdentifier) else { break configureView }
            // Update View
            headerView.prepareForReuse()
            if let updateableView = headerView as? UpdateableTableViewHeaderFooterView {
                updateableView.updateViewWithItem(headerItem as ComparableItem, animated: false, type: .Header)
            }
            view = headerView
        }
    
        return view
    }
    
    
    public func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let item = sections[section]
        var height: CGFloat = tableView.sectionHeaderHeight
        
        calculateHeight : do {
            guard let headerItem = item.headerItem else { break calculateHeight }
            guard let prototype = headerFooterPrototypes[headerItem.reuseIdentifier] else { break calculateHeight }
            // Update Prototype
            prototype.prepareForReuse()
            if let updatableView = prototype as? UpdateableTableViewHeaderFooterView {
                updatableView.updateViewWithItem(headerItem as ComparableItem, animated: false, type: .Header)
            }
            // Get Height
            let fittedWidth = tableView.bounds.width
            let fittedHeight = UILayoutFittingCompressedSize.height
            let fittingSize = CGSize(width: fittedWidth, height: fittedHeight)
            let size = prototype.contentView.systemLayoutSizeFittingSize(fittingSize, withHorizontalFittingPriority: 999, verticalFittingPriority: UILayoutPriorityFittingSizeLevel)
            height = size.height
        }
        
        return height
    }
    
    
    
    // MARK: Footer

    public func tableView(tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let item = sections[section]
        var view: UIView?
        
        configureView : do {
            guard let footerItem = item.footerItem else { break configureView }
            guard let footerView = tableView.dequeueReusableHeaderFooterViewWithIdentifier(footerItem.reuseIdentifier) else { break configureView }
            // Update View
            footerView.prepareForReuse()
            if let updateableView = footerView as? UpdateableTableViewHeaderFooterView {
                updateableView.updateViewWithItem(footerItem as ComparableItem, animated: false, type: .Footer)
            }
            view = footerView
        }
        
        return view
    }
    
    
    public func tableView(tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let item = sections[section]
        var height: CGFloat = CGFloat.min
        
        calculateHeight : do {
            guard let footerItem = item.footerItem else { break calculateHeight }
            guard let prototype = headerFooterPrototypes[footerItem.reuseIdentifier] else { break calculateHeight }
            // Update Prototype
            prototype.prepareForReuse()
            if let updatableView = prototype as? UpdateableTableViewHeaderFooterView {
                updatableView.updateViewWithItem(footerItem as ComparableItem, animated: false, type: .Footer)
            }
            // Get Height
            let fittedWidth = tableView.bounds.width
            let fittedHeight = UILayoutFittingCompressedSize.height
            let fittingSize = CGSize(width: fittedWidth, height: fittedHeight)
            let size = prototype.contentView.systemLayoutSizeFittingSize(fittingSize, withHorizontalFittingPriority: 999, verticalFittingPriority: UILayoutPriorityFittingSizeLevel)
            height = size.height
        }
        
        lastFooterHeight : do {
            guard section == tableView.numberOfSections - 1 else { break lastFooterHeight }
            guard item.footerItem == nil else { break lastFooterHeight }
            height = tableView.sectionFooterHeight
        }
        
        return height
    }

    
    // MARK: Selection
    
    public func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let item = sections[indexPath.section].items[indexPath.row]
        
        if let selectableItem = item as? SelectableTableViewItem {
            selectableItem.selectionHandler?()
        }
        
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
}