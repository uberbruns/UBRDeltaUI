//
//  DeltaTableViewController.swift
//  CompareApp
//
//  Created by Karsten Bruns on 30/08/15.
//  Copyright © 2015 bruns.me. All rights reserved.
//

import UIKit
import UBRDelta


public class DeltaTableView : UITableView {}


public class DeltaTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    // MARK: - Controller -

    public var reusableCellNibs = [String:UINib]()
    public var reusableCellClasses = [String:AnyClass]()
    
    public private(set) var sections: [TableViewSectionItem] = []
    private let contentDiffer = UBRDeltaContent()
    private var animateViews = true
    
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

        // Add reusable cells
        prepareReusableTableViewCells()
        reusableCellNibs.forEach { (identifier, nib) -> () in tableView.registerNib(nib, forCellReuseIdentifier: identifier) }
        reusableCellClasses.forEach { (identifier, cellClass) -> () in tableView.registerClass(cellClass, forCellReuseIdentifier: identifier) }

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

    
    // MARK: Configuration
    
    private func configureContentDiffer() {
        
        contentDiffer.userInterfaceUpdateTime = 0.16667
        
        contentDiffer.start = { [weak self] in
            guard let weakSelf = self else { return }
            if weakSelf.animateViews == false {
                UIView.setAnimationsEnabled(false)
            }
        }
        
        contentDiffer.itemUpdate = { [weak self] (items, section, insertIndexes, reloadIndexMap, deleteIndexes) in
            guard let weakSelf = self else { return }
            weakSelf.sections[section].items = items
            weakSelf.tableView.beginUpdates()
            
            for (itemIndexBefore, itemIndexAfter) in reloadIndexMap {
                let indexPathBefore = NSIndexPath(forRow: itemIndexBefore, inSection: section)
                guard let cell = weakSelf.tableView.cellForRowAtIndexPath(indexPathBefore) else { continue }
                if let updateableCell = cell as? UpdateableTableViewCell {
                    let item: ComparableItem = items[itemIndexAfter]
                    updateableCell.updateCellWithItem(item, animated: true)
                } else {
                    weakSelf.tableView.reloadRowsAtIndexPaths([indexPathBefore], withRowAnimation: .Automatic)
                }
            }
            
            weakSelf.tableView.deleteRowsAtIndexPaths(deleteIndexes.map({ NSIndexPath(forRow: $0, inSection: section) }), withRowAnimation: .Top)
            weakSelf.tableView.insertRowsAtIndexPaths(insertIndexes.map({ NSIndexPath(forRow: $0, inSection: section) }), withRowAnimation: .Top)
            weakSelf.tableView.endUpdates()
        }
        
        contentDiffer.itemReorder = { [weak self] (items, section, reorderMap) in
            guard let weakSelf = self else { return }
            weakSelf.sections[section].items = items
            weakSelf.tableView.beginUpdates()
            for (from, to) in reorderMap {
                let fromIndexPath = NSIndexPath(forRow: from, inSection: section)
                let toIndexPath = NSIndexPath(forRow: to, inSection: section)
                weakSelf.tableView.moveRowAtIndexPath(fromIndexPath, toIndexPath: toIndexPath)
            }
            weakSelf.tableView.endUpdates()
        }
        
        contentDiffer.sectionUpdate = { [weak self] (sections, insertIndexes, reloadIndexMap, deleteIndexes) in

            guard let weakSelf = self else { return }
            weakSelf.sections = sections.flatMap({ $0 as? TableViewSectionItem })
            weakSelf.tableView.beginUpdates()
            
            let insertSet = NSMutableIndexSet()
            insertIndexes.forEach({ insertSet.addIndex($0) })

            let deleteSet = NSMutableIndexSet()
            deleteIndexes.forEach({ deleteSet.addIndex($0) })

            weakSelf.tableView.insertSections(insertSet, withRowAnimation: .Automatic)
            weakSelf.tableView.deleteSections(deleteSet, withRowAnimation: .Automatic)
            
            for (sectionIndexBefore, sectionIndexAfter) in reloadIndexMap {
                
                if let sectionItem = sections[sectionIndexAfter] as? TableViewSectionItem,
                    let headerView = weakSelf.tableView.headerViewForSection(sectionIndexBefore) as? UpdateableTableViewHeaderFooterView,
                    let footerView = weakSelf.tableView.footerViewForSection(sectionIndexBefore) as? UpdateableTableViewHeaderFooterView {
                        headerView.updateViewWithItem(sectionItem, animated: true, type: .Header)
                        footerView.updateViewWithItem(sectionItem, animated: true, type: .Footer)
                        
                } else {
                    weakSelf.tableView.reloadSections(NSIndexSet(index: sectionIndexBefore), withRowAnimation: .Automatic)
                }
            }
            
            weakSelf.tableView.endUpdates()
        }
        
        contentDiffer.sectionReorder = { [weak self] (sections, reorderMap) in
            guard let weakSelf = self else { return }
            weakSelf.sections = sections.flatMap({ $0 as? TableViewSectionItem })
            if reorderMap.count > 0 {
                weakSelf.tableView.beginUpdates()
                for (from, to) in reorderMap {
                    weakSelf.tableView.moveSection(from, toSection: to)
                }
                weakSelf.tableView.endUpdates()
            }
        }
        
        contentDiffer.completion = { [weak self] in
            guard let weakSelf = self else { return }
            UIView.setAnimationsEnabled(true)
            weakSelf.animateViews = true
        }
    }

    
    // MARK: - API -
    
    public func prepareReusableTableViewCells() { }
    
    
    public func generateItems() -> [TableViewSectionItem] {
        return []
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
        
        let item = sections[indexPath.section].items[indexPath.row]
        
        if let tableViewItem = item as? DelataTableViewItem {
            
            let cell = tableView.dequeueReusableCellWithIdentifier(tableViewItem.reuseIdentifier)!
            
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
    
    
    public func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let section = sections[section]
        return section.title
    }
    
    
    public func tableView(tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let section = sections[section]
        return section.footer
    }
    
    
    // MARK: UITableViewDelegate
    
    public func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        let item = sections[indexPath.section].items[indexPath.row]
        
        if let selectableItem = item as? SelectableTableViewItem {
            selectableItem.selectionHandler?()
        }
        
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }


}
