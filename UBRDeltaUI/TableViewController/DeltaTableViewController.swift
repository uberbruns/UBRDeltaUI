//
//  DeltaTableViewController.swift
//  CompareApp
//
//  Created by Karsten Bruns on 30/08/15.
//  Copyright © 2015 bruns.me. All rights reserved.
//

import UIKit



public class DeltaTableView : UITableView {}


public class DeltaTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - Controller -
    
    public var reusableCellNibs = [String:UINib]()
    public var reusableCellClasses = [String:UITableViewCell.Type]()
    
    public var reusableHeaderFooterNibs = [String:UINib]()
    public var reusableHeaderFooterClasses = [String:UITableViewHeaderFooterView.Type]()
    
    public private(set) var sections: [TableViewSectionItem] = []
    private let contentDiffer = UBRDeltaContent()
    private var animateViews = true
    public var deltaDebugOutput = false

    private var learnedRowHeights = DeltaMatrix<CGFloat>()
    private var learnedHeaderHeights = [Int:CGFloat]()
    private var learnedFooterHeights = [Int:CGFloat]()

    public let tableView = DeltaTableView(frame: CGRectZero, style: .Grouped)
    
    
    // MARK: - View -
    // MARK: Life-Cycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        configureContentDiffer()
        prepareReusableTableViewCells()
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
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.sectionHeaderHeight = UITableViewAutomaticDimension
        tableView.sectionFooterHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 44.0
        tableView.estimatedSectionHeaderHeight = 66.0
        tableView.estimatedSectionFooterHeight = 22.0
        
        // Removes an unwanted top padding
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0,y: 0,width: 0,height: CGFloat.min))

        // Add reusable cells
        prepareReusableTableViewCells()
        reusableCellNibs.forEach { (identifier, nib) -> () in tableView.registerNib(nib, forCellReuseIdentifier: identifier) }
        reusableCellClasses.forEach { (identifier, cellClass) -> () in tableView.registerClass(cellClass, forCellReuseIdentifier: identifier) }
        reusableHeaderFooterNibs.forEach { (identifier, nib) -> () in tableView.registerNib(nib, forHeaderFooterViewReuseIdentifier: identifier) }
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
    
    
    public func updateTableView() {
        let newSections: [TableViewSectionItem] = generateItems()
        
        if sections.count == 0 {
            sections = newSections
            tableView.reloadData()
        } else {
            let oldSections = sections.map({ $0 as ComparableSectionItem })
            let newSections = newSections.map({ $0 as ComparableSectionItem })
            contentDiffer.queueComparison(oldSections: oldSections, newSections: newSections)
        }
    }
    
    
    public func updateLearnedHeights() {
        for indexPath in tableView.indexPathsForVisibleRows ?? [] {
            guard let cell = tableView.cellForRowAtIndexPath(indexPath) else { continue }
            learnedRowHeights[indexPath.section, indexPath.row] = cell.bounds.height
        }
        for section in 0..<tableView.numberOfSections {
            if let headerView = tableView.headerViewForSection(section) {
                learnedHeaderHeights[section] = headerView.bounds.height
            }
            if let footerView = tableView.footerViewForSection(section) {
                learnedFooterHeights[section] = footerView.bounds.height
            }
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
            
            weakSelf.tableView.beginUpdates()
            
            if manualReloadMap.count > 0 {
                for (itemIndexBefore, _) in manualReloadMap {
                    let indexPathBefore = NSIndexPath(forRow: itemIndexBefore, inSection: section)
                    weakSelf.tableView.reloadRowsAtIndexPaths([indexPathBefore], withRowAnimation: .Automatic)
                }
            }

            if deleteIndexes.count > 0 {
                weakSelf.tableView.deleteRowsAtIndexPaths(deleteIndexes.map({ NSIndexPath(forRow: $0, inSection: section) }), withRowAnimation: .Top)
            }

            if insertIndexes.count > 0 {
                weakSelf.tableView.insertRowsAtIndexPaths(insertIndexes.map({ NSIndexPath(forRow: $0, inSection: section) }), withRowAnimation: .Top)
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
            
            weakSelf.tableView.insertSections(insertSet, withRowAnimation: .Automatic)
            weakSelf.tableView.deleteSections(deleteSet, withRowAnimation: .Automatic)
            
            for (sectionIndexBefore, sectionIndexAfter) in reloadIndexMap {
                
                if let sectionItem = sections[sectionIndexAfter] as? TableViewSectionItem {
                    
                    if let headerView = weakSelf.tableView.headerViewForSection(sectionIndexBefore) as? UpdateableTableViewHeaderFooterView {
                        headerView.updateViewWithItem(sectionItem.headerItem ?? sectionItem, animated: true, type: .Header)
                    }
                    
                    if let footerView = weakSelf.tableView.footerViewForSection(sectionIndexBefore) as? UpdateableTableViewHeaderFooterView {
                        footerView.updateViewWithItem(sectionItem.footerItem ?? sectionItem, animated: true, type: .Footer)
                    }

                } else {
                    weakSelf.tableView.reloadSections(NSIndexSet(index: sectionIndexBefore), withRowAnimation: .Automatic)
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
        return UITableViewAutomaticDimension
    }
    

    public func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return learnedRowHeights[indexPath.section, indexPath.row] ?? tableView.estimatedRowHeight
    }
    

    public func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        learnedRowHeights[indexPath.section, indexPath.row] = cell.bounds.height
    }
    

    public func tableView(tableView: UITableView, didEndDisplayingCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        learnedRowHeights[indexPath.section, indexPath.row] = cell.bounds.height
    }


    // MARK: Header
    
    public func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let item = sections[section]
        if let headerItem = item.headerItem as? DeltaTableViewHeaderFooterItem {
            let view = tableView.dequeueReusableHeaderFooterViewWithIdentifier(headerItem.reuseIdentifier)
            if let updateableView = view as? UpdateableTableViewHeaderFooterView {
                updateableView.updateViewWithItem(headerItem as ComparableItem, animated: false, type: .Header)
            }
            return view
        } else {
            return nil
        }
    }
    
    
    public func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let item = sections[section]
        if item.headerItem is DeltaTableViewHeaderFooterItem {
            return UITableViewAutomaticDimension // Auto Layout Height
        } else {
            return 33 // Default Height
        }
    }
    
    
    public func tableView(tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        return learnedHeaderHeights[section] ?? tableView.estimatedSectionHeaderHeight
    }
    
    
    public func tableView(tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        learnedHeaderHeights[section] = view.bounds.height
    }
    
    
    public func tableView(tableView: UITableView, didEndDisplayingHeaderView view: UIView, forSection section: Int) {
        learnedHeaderHeights[section] = view.bounds.height
    }

    
    
    // MARK: Footer
    
    public func tableView(tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let item = sections[section]
        if let footerItem = item.footerItem as? DeltaTableViewHeaderFooterItem {
            let view = tableView.dequeueReusableHeaderFooterViewWithIdentifier(footerItem.reuseIdentifier)
            if let updateableView = view as? UpdateableTableViewHeaderFooterView {
                updateableView.updateViewWithItem(footerItem as ComparableItem, animated: false, type: .Footer)
            }
            return view
        } else {
            return nil
        }
    }
    
    
    public func tableView(tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let item = sections[section]
        if item.footerItem is DeltaTableViewHeaderFooterItem {
            return UITableViewAutomaticDimension // Auto Layout Height
        } else if section == sections.count-1 {
            return UITableViewAutomaticDimension // Last cell should have a space to the end of the tableView
        } else {
            return 0.0 // Zero Height so there is no space between header and last cell
        }
    }
    
    
    public func tableView(tableView: UITableView, estimatedHeightForFooterInSection section: Int) -> CGFloat {
        return learnedFooterHeights[section] ?? tableView.estimatedSectionFooterHeight
    }
    
    
    public func tableView(tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        learnedFooterHeights[section] = view.bounds.height
    }
    
    
    public func tableView(tableView: UITableView, didEndDisplayingFooterView view: UIView, forSection section: Int) {
        learnedFooterHeights[section] = view.bounds.height
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
