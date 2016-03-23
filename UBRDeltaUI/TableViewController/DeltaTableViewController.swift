//
//  DeltaTableViewController.swift
//  CompareApp
//
//  Created by Karsten Bruns on 30/08/15.
//  Copyright © 2015 bruns.me. All rights reserved.
//

import UIKit


public enum DeltaUpdateOptions {
    case Default, HardReload, ReloadVisibleCells
}


public class DeltaTableView : UITableView {}


public class DeltaTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - Controller -
    
    public var reusableCellClasses = [String:UITableViewCell.Type]()
    public var reusableHeaderFooterClasses = [String:UITableViewHeaderFooterView.Type]()
    
    public private(set) var sections: [TableViewSectionItem] = []
    private let contentDiffer = UBRDeltaContent()
    private var animateViews = true
    private var deltaUpdateOptions = DeltaUpdateOptions.Default
    public var deltaDebugOutput = false
    
    private var estimatedCellHeights = DeltaMatrix<CGFloat>()
    private var learnedCellHeights = DeltaMatrix<CGFloat>()
    private var headerFooterPrototypes = [String:UITableViewHeaderFooterView]()
    public let tableView = DeltaTableView(frame: CGRectZero, style: .Grouped)
    
    
    // Table View API
    
    public var rowDeletionAnimation = UITableViewRowAnimation.Automatic
    public var rowInsertionAnimation = UITableViewRowAnimation.Automatic
    public var rowReloadAnimation = UITableViewRowAnimation.Automatic
    public var sectionDeletionAnimation = UITableViewRowAnimation.Automatic
    public var sectionInsertionAnimation = UITableViewRowAnimation.Automatic
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
    
    
    public  override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        self.view.endEditing(true)
    }
    
    
    // MARK: Add Views
    
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
    
    public func updateView(animated: Bool = true) {
        animateViews = animated
        updateTableView()
    }
    
    
    public func updateTableView(options: DeltaUpdateOptions = .Default) {
        let newSections: [TableViewSectionItem] = generateItems()
        
        deltaUpdateOptions = options
        learnedCellHeights.removeAll(true)
        
        if sections.count == 0 || options == .HardReload {
            sections = newSections
            tableView.reloadData()
            updateLearnedHeights()
        } else {
            let oldSections = sections.map({ $0 as ComparableSectionItem })
            let newSections = newSections.map({ $0 as ComparableSectionItem })
            contentDiffer.queueComparison(oldSections: oldSections, newSections: newSections)
        }
    }
    
    
    private func updateLearnedHeights() {
        for indexPath in tableView.indexPathsForVisibleRows ?? [] {
            guard let cell = tableView.cellForRowAtIndexPath(indexPath) else { continue }
            estimatedCellHeights[indexPath.section, indexPath.row] = cell.bounds.height
            learnedCellHeights[indexPath.section, indexPath.row] = cell.bounds.height
        }
    }
    
    
    private func loadHeaderFooterViewPrototypes() {
        headerFooterPrototypes.removeAll()
        for (reuseIdentifier, HeaderFooterClass) in reusableHeaderFooterClasses {
            let headerFooterPrototype = HeaderFooterClass.init(reuseIdentifier: reuseIdentifier)
            headerFooterPrototypes[reuseIdentifier] = headerFooterPrototype
        }
    }
    
    
    // MARK: Configuration
    
    private func configureContentDiffer() {
        
        contentDiffer.userInterfaceUpdateTime = 0.16667
        
        // Start updating table view
        contentDiffer.start = { [weak self] in
            guard let weakSelf = self else { return }
            if weakSelf.deltaDebugOutput {
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
            
            weakSelf.sections[section].items = items
            
            if insertIndexes.count == 0 && reloadIndexMap.count == 0 && deleteIndexes.count == 0 {
                return
            }
            
            if weakSelf.deltaDebugOutput {
                print("Updating rows in section \(section)", "items: \(items.map({ $0.uniqueIdentifier }))", "insertIndexes: \(insertIndexes)", "reloadIndexMap: \(reloadIndexMap)", "deleteIndexes: \(deleteIndexes)", separator: "\n", terminator: "\n\n")
            }
            
            var manualReloadMap = reloadIndexMap
            
            if weakSelf.deltaUpdateOptions != .ReloadVisibleCells {
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
            
            if manualReloadMap.count > 0 && weakSelf.deltaUpdateOptions != .ReloadVisibleCells {
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
            
            weakSelf.sections[section].items = items
            
            if reorderMap.count == 0 {
                return
            }
            
            if weakSelf.deltaDebugOutput {
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
            
            weakSelf.sections = sections.flatMap({ $0 as? TableViewSectionItem })
            
            if insertIndexes.count == 0 && reloadIndexMap.count == 0 && deleteIndexes.count == 0 {
                return
            }
            
            if weakSelf.deltaDebugOutput {
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
                
                if let sectionItem = sections[sectionIndexAfter] as? TableViewSectionItem {
                    
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
            
            weakSelf.sections = sections.flatMap({ $0 as? TableViewSectionItem })
            
            if reorderMap.count == 0 {
                return
            }
            
            if weakSelf.deltaDebugOutput {
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
            
            if weakSelf.deltaUpdateOptions == .ReloadVisibleCells {
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
            
            if weakSelf.deltaDebugOutput {
                print("Updating table view ended", separator: "\n", terminator: "\n\n")
            }
            
            UIView.setAnimationsEnabled(true)
            weakSelf.tableViewDidUpdateCells(weakSelf.animateViews)
            weakSelf.animateViews = true
            weakSelf.updateLearnedHeights()
        }
    }
    
    
    // MARK: - API -
    
    public func prepareReusableTableViewCells() { }
    
    
    public func generateItems() -> [TableViewSectionItem] {
        return []
    }
    
    
    public func tableViewWillUpdateCells(animated: Bool) {}
    
    public func tableViewDidUpdateCells(animated: Bool) {}
    
    
    // MARK: - Protocols -
    // MARK: UITableViewDataSource
    
    public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return sections.count
    }
    
    
    public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].items.count
    }
    
    
    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let item = sections[indexPath.section].items[indexPath.row]
        
        if let tableViewItem = item as? DeltaTableViewItem,
            let cell = tableView.dequeueReusableCellWithIdentifier(tableViewItem.reuseIdentifier){
                
                if let updateableCell = cell as? UpdateableTableViewCell {
                    updateableCell.updateCellWithItem(item, animated: false)
                }
                
                if let selectableItem = item as? SelectableTableViewItem {
                    cell.selectionStyle = selectableItem.selectionHandler != nil ? .Default : .None
                }
                
                return cell
                
        } else {
            
            let cell = tableView.dequeueReusableCellWithIdentifier("Cell")!
            cell.textLabel?.text = nil
            cell.detailTextLabel?.text = nil
            return cell
            
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
            guard let headerItem = item.headerItem as? DeltaTableViewHeaderFooterItem else { break configureView }
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
            guard let headerItem = item.headerItem as? DeltaTableViewHeaderFooterItem else { break calculateHeight }
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
            guard let footerItem = item.footerItem as? DeltaTableViewHeaderFooterItem else { break configureView }
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
            guard let footerItem = item.footerItem as? DeltaTableViewHeaderFooterItem else { break calculateHeight }
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
