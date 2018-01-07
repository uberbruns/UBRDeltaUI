//
//  ElementTableViewController.swift
//  CompareApp
//
//  Created by Karsten Bruns on 30/08/15.
//  Copyright © 2015 bruns.me. All rights reserved.
//

import UIKit


/// Options to fine tune the debug output. Please note, that the options .Debug and .Warnings have an impact on performance
public enum DeltaDebugOutput {
    case none
    case debug
    case warnings
}



open class ElementTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - Properties -

    open var reusableCellClasses = [String:UITableViewCell.Type]()
    open var reusableHeaderFooterClasses = [String:UITableViewHeaderFooterView.Type]()
    
    public let elementSource: ElementSource
    private let sectionDiffer = SectionDiffer()
    private var animateViews = true
    private var updateOptions = UpdateOptions.default
    open var deltaDebugOutput = DeltaDebugOutput.none
    
    open class var tableView: UITableView {
        return UITableView(frame: .zero, style: .grouped)        
    }
    
    public private(set) lazy var tableView: UITableView = { return type(of: self).tableView }()
    
    
    // Table View API
    
    /// The type of animation when rows are deleted.
    open var rowDeletionAnimation = UITableViewRowAnimation.automatic
    
    /// The type of animation when rows are inserted.
    open var rowInsertionAnimation = UITableViewRowAnimation.automatic
    
    /// The type of animation when rows are reloaded (not updated)
    open var rowReloadAnimation = UITableViewRowAnimation.automatic
    
    /// The type of animation when sections are deleted.
    open var sectionDeletionAnimation = UITableViewRowAnimation.automatic
    
    /// The type of animation when sections are inserted.
    open var sectionInsertionAnimation = UITableViewRowAnimation.automatic
    
    /// The type of animation when sections are reloaded (not updated)
    open var sectionReloadAnimation = UITableViewRowAnimation.automatic
    

    // MARK: - Controller -
    // MARK: Life-Cycle
    
    public init(elementSource: ElementSource) {
        self.elementSource = elementSource
        super.init(nibName: nil, bundle: nil)
    }
    
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    // MARK: - View -
    // MARK: Life-Cycle
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        configureContentDiffer()
        prepareReusableTableViewCells()
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
        
        // Cell dimensions
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.sectionHeaderHeight = UITableViewAutomaticDimension
        tableView.sectionFooterHeight = UITableViewAutomaticDimension

        // Add reusable cells
        prepareReusableTableViewCells()
        
        // Constraints
        let viewDict = ["tableView" : tableView]
        let v = NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[tableView]-0-|", options: [], metrics: nil, views: viewDict)
        let h = NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[tableView]-0-|", options: [], metrics: nil, views: viewDict)
        view.addConstraints(v + h)
    }
    
    
    // MARK: Update Views
    
    /**
     Default way of updating the table view
     
     - Parameter animated: if true (default) performs a partial table view that will only update changes cells
     */
    open func updateView(_ animated: Bool = true) {
        if animated {
            animateViews = animated
            updateTableView()
        } else {
            updateTableView(.hardReload)
        }
    }
    
    
    /**
     Advanced way of updating the table view

     __Discussion:__ this functions and `updateView` should be replaced with another approach.
     For example `setTableViewNeedsUpdate`.

     - Parameter options: Enum with instructions on how to update the table view. Default is `.Default`.
     
     */
    open func updateTableView(_ options: UpdateOptions = .default) {
        var newSections = [SectionViewElement]()
        elementSource.generateElements(sections: &newSections)
        
        updateOptions = options
        
        if options == .dataOnly {
            elementSource.sections = newSections
        } else if elementSource.sections.isEmpty || options == .hardReload {
            tableViewWillUpdateCells(false)
            elementSource.sections = newSections
            tableView.reloadData()
            tableViewDidUpdateCells(false)
        } else {
            let oldSections = elementSource.sections.map({ $0 as SectionElement })
            let newSections = newSections.map({ $0 as SectionElement })
            sectionDiffer.queueComparison(oldSections: oldSections, newSections: newSections)
        }
    }

    
    // MARK: Configuration
    
    /**
     `contentDiffer` is the heart of this class and determines what parts need to be updated.
     This functions links the `tableView` and the `contentDiffer` by calling table views update
     functions in the callback functions from the `contentDiffer`.
    */
    private func configureContentDiffer() {
        
        sectionDiffer.throttleTimeInterval = 0.16667
        sectionDiffer.debugOutput = deltaDebugOutput != .none
        
        // Start updating table view
        sectionDiffer.start = { [weak self] in
            guard let weakSelf = self else { return }
            if weakSelf.deltaDebugOutput == .debug {
                print("Start updating table view", separator: "\n", terminator: "\n\n")
            }
            if weakSelf.animateViews == false {
                UIView.setAnimationsEnabled(false)
            }
            weakSelf.tableViewWillUpdateCells(weakSelf.animateViews)
        }
        
        // Insert, reload and delete table view rows
        sectionDiffer.itemUpdate = { [weak self] (items, section, insertIndexes, reloadIndexMap, deleteIndexes) in
            guard let weakSelf = self else { return }
            
            weakSelf.elementSource.sections[section].items = items.flatMap { $0 as? AnyViewElement }
            
            if insertIndexes.count == 0 && reloadIndexMap.count == 0 && deleteIndexes.count == 0 {
                return
            }
            
            if weakSelf.deltaDebugOutput == .debug {
                print("Updating rows in section \(section)", "items: \(items.map({ $0.uniqueIdentifier }))", "insertIndexes: \(insertIndexes)", "reloadIndexMap: \(reloadIndexMap)", "deleteIndexes: \(deleteIndexes)", separator: "\n", terminator: "\n\n")
            }
            
            var manualReloadMap = reloadIndexMap
            
            if weakSelf.updateOptions != .updateVisibleCells {
                for (itemIndexBefore, itemIndexAfter) in reloadIndexMap {
                    let indexPathBefore = IndexPath(row: itemIndexBefore, section: section)
                    guard let cell = weakSelf.tableView.cellForRow(at: indexPathBefore) else {
                        manualReloadMap.removeValue(forKey: itemIndexBefore)
                        continue
                    }
                    guard let elementCell = cell as? AnyElementTableViewCell, let element = items[itemIndexAfter] as? AnyViewElement else { continue }
                    let oldElement = elementCell.anyViewElement
                    elementCell.anyViewElement = element
                    elementCell.elementDidChange(oldElement: oldElement, animate: true)
                    manualReloadMap.removeValue(forKey: itemIndexBefore)
                }
            }
            
            weakSelf.tableView.beginUpdates()
            
            if manualReloadMap.count > 0 && weakSelf.updateOptions != .updateVisibleCells {
                for (itemIndexBefore, _) in manualReloadMap {
                    let indexPathBefore = IndexPath(row: itemIndexBefore, section: section)
                    weakSelf.tableView.reloadRows(at: [indexPathBefore], with: weakSelf.rowReloadAnimation)
                }
            }
            
            if deleteIndexes.count > 0 {
                weakSelf.tableView.deleteRows(at: deleteIndexes.map({ IndexPath(row: $0, section: section) }), with: weakSelf.rowDeletionAnimation)
            }
            
            if insertIndexes.count > 0 {
                weakSelf.tableView.insertRows(at: insertIndexes.map({ IndexPath(row: $0, section: section) }), with: weakSelf.rowInsertionAnimation)
            }
            
            weakSelf.tableView.endUpdates()
        }
        
        // Reorder table view rows
        sectionDiffer.itemReorder = { [weak self] (items, section, reorderMap) in
            guard let weakSelf = self else { return }
            
            weakSelf.elementSource.sections[section].items = items.flatMap { $0 as? AnyViewElement }
            
            if reorderMap.count == 0 {
                return
            }
            
            if weakSelf.deltaDebugOutput == .debug {
                print("Reorder rows in section \(section)", "items: \(items.map({ $0.uniqueIdentifier }))", "reorderMap: \(reorderMap)", separator: "\n", terminator: "\n\n")
            }
            
            weakSelf.tableView.beginUpdates()
            for (from, to) in reorderMap {
                let fromIndexPath = IndexPath(row: from, section: section)
                let toIndexPath = IndexPath(row: to, section: section)
                weakSelf.tableView.moveRow(at: fromIndexPath, to: toIndexPath)
            }
            weakSelf.tableView.endUpdates()
        }
        
        // Insert, reload and delete table view sections
        sectionDiffer.sectionUpdate = { [weak self] (sections, insertIndexes, reloadIndexMap, deleteIndexes) in
            guard let weakSelf = self else { return }
            
            weakSelf.elementSource.sections = sections.flatMap({ $0 as? SectionViewElement })
            
            if insertIndexes.count == 0 && reloadIndexMap.count == 0 && deleteIndexes.count == 0 {
                return
            }
            
            if weakSelf.deltaDebugOutput == .debug {
                print("Updating sections", "sections: \(sections.map({ $0.uniqueIdentifier }))", "insertIndexes: \(insertIndexes)", "reloadIndexMap: \(reloadIndexMap)", "deleteIndexes: \(deleteIndexes)", separator: "\n", terminator: "\n\n")
            }
            
            weakSelf.tableView.beginUpdates()
            
            let insertSet = NSMutableIndexSet()
            insertIndexes.forEach({ insertSet.add($0) })
            
            let deleteSet = NSMutableIndexSet()
            deleteIndexes.forEach({ deleteSet.add($0) })
            
            weakSelf.tableView.insertSections(insertSet as IndexSet, with: weakSelf.sectionInsertionAnimation)
            weakSelf.tableView.deleteSections(deleteSet as IndexSet, with: weakSelf.sectionDeletionAnimation)
            
            for (sectionIndexBefore, sectionIndexAfter) in reloadIndexMap {
                
                if let sectionElement = sections[sectionIndexAfter] as? SectionViewElement {
                    
                    if let headerView = weakSelf.tableView.headerView(forSection: sectionIndexBefore) as? AnyElementHeaderFooterView, let headerElement = sectionElement.headerElement {
                        let oldElement = headerView.anyViewElement
                        headerView.anyViewElement = headerElement
                        headerView.elementDidChange(oldElement: oldElement, animate: true, type: .header)
                    }
                    
                    if let footerView = weakSelf.tableView.footerView(forSection: sectionIndexBefore) as? AnyElementHeaderFooterView, let footerElement = sectionElement.footerElement {
                        let oldElement = footerView.anyViewElement
                        footerView.anyViewElement = footerElement
                        footerView.elementDidChange(oldElement: oldElement, animate: true, type: .footer)
                    }
                    
                } else {
                    weakSelf.tableView.reloadSections(IndexSet(integer: sectionIndexBefore), with: weakSelf.sectionDeletionAnimation)
                }
            }
            
            weakSelf.tableView.endUpdates()
        }
        
        // Reorder table view sections
        sectionDiffer.sectionReorder = { [weak self] (sections, reorderMap) in
            guard let weakSelf = self else { return }
            
            weakSelf.elementSource.sections = sections.flatMap({ $0 as? SectionViewElement })
            
            if reorderMap.count == 0 {
                return
            }
            
            if weakSelf.deltaDebugOutput == .debug {
                print("Reorder sections", "sections: \(sections.map({ $0.uniqueIdentifier }))", "reorderMap: \(reorderMap)", separator: "\n", terminator: "\n\n")
            }
            
            weakSelf.tableView.beginUpdates()
            for (from, to) in reorderMap {
                weakSelf.tableView.moveSection(from, toSection: to)
            }
            weakSelf.tableView.endUpdates()
        }
        
        // Updating table view did end
        sectionDiffer.completion = { [weak self] in
            guard let weakSelf = self else { return }
            
            if weakSelf.updateOptions == .updateVisibleCells {
                var manualReloads = [IndexPath]()
                for indexPath in weakSelf.tableView.indexPathsForVisibleRows ?? [] {
                    if let elementCell = weakSelf.tableView.cellForRow(at: indexPath) as? AnyElementTableViewCell {
                        let element: AnyViewElement = weakSelf.elementSource.sections[indexPath.section].items[indexPath.row]
                        let oldElement = elementCell.anyViewElement
                        elementCell.anyViewElement = element
                        elementCell.elementDidChange(oldElement: oldElement, animate: false)
                    } else {
                        manualReloads.append(indexPath)
                    }
                }
                if manualReloads.count > 0 {
                    weakSelf.tableView.beginUpdates()
                    weakSelf.tableView.reloadRows(at: manualReloads, with: weakSelf.rowReloadAnimation)
                    weakSelf.tableView.endUpdates()
                }
            }
            
            if weakSelf.deltaDebugOutput == .debug {
                print("Updating table view ended", separator: "\n", terminator: "\n\n")
            }
            
            UIView.setAnimationsEnabled(true)
            weakSelf.tableViewDidUpdateCells(weakSelf.animateViews)
            weakSelf.animateViews = true
        }
    }
    
    
    // MARK: - API -
    // MARK: Content
    
    /// Returns the `SectionViewElement` that belongs to the provided section index.
    open func tableViewSectionElement(_ section: Int) -> SectionViewElement {
        return elementSource.sections[section]
    }
    

    /// Returns the `Element` that belongs to the provided index path.
    open func tableViewElement(_ indexPath: IndexPath) -> AnyViewElement {
        return elementSource.sections[indexPath.section].items[indexPath.row]
    }

    
    // MARK: Table View
    
    /// Use this function in your subclass to update `reusableCellClasses` and `reusableHeaderFooterClasses`.
    open func prepareReusableTableViewCells() { }
    
    
    public func register<EC: ElementTableViewCell & UITableViewCell>(_ elementTableViewCellType: EC.Type) {
        let reuseIdentifier = elementTableViewCellType.VE.typeIdentifier
        tableView.register(elementTableViewCellType, forCellReuseIdentifier: reuseIdentifier)
    }
    

    public func register<EC: ElementHeaderFooterView & UITableViewHeaderFooterView>(_ elementViewHeaderFooterViewType: EC.Type) {
        let reuseIdentifier = elementViewHeaderFooterViewType.VE.typeIdentifier
        tableView.register(elementViewHeaderFooterViewType, forHeaderFooterViewReuseIdentifier: reuseIdentifier)
    }

    
    /// Subclass this function in your subclass to execute code when a table view will update.
    open func tableViewWillUpdateCells(_ animated: Bool) {}
    
    
    /// Subclass this function in your subclass to execute code when a table view did update.
    open func tableViewDidUpdateCells(_ animated: Bool) {}
    
    
    /**
     Dequeues a reusable cell from table view as long the element for this index path is of type `DeltaTableViewElement`
     and DeltaTableViewElement's `typeIdentifier` property was registered in `prepareReusableTableViewCells()`.
     
     Use this method if you want to provide your own implementation of `tableView(tableView:cellForRowAtIndexPath:)` but
     you still want to be able to return cells provided by this class if needed.
     
     In most cases this function is only used internally and a custom implementation of `tableView(tableView:cellForRowAtIndexPath:)`
     is not needed.
     */
    open func tableViewCellForRowAtIndexPath(_ indexPath: IndexPath) -> UITableViewCell? {
        let element = elementSource.sections[indexPath.section].items[indexPath.row]
        
        getTableViewCell : do {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: type(of: element).typeIdentifier) else { break getTableViewCell }

            if let elementCell = cell as? AnyElementTableViewCell {
                let oldElement = elementCell.anyViewElement
                elementCell.anyViewElement = element
                elementCell.elementDidChange(oldElement: oldElement, animate: false)
            }
            
            if let selectableElement = element as? SelectableTableViewElement {
                cell.selectionStyle = selectableElement.selectionHandler != nil ? .default : .none
            }

            return cell
        }
        
        return nil
    }
    
    
    // MARK: - Protocols -
    // MARK: UITableViewDataSource
    
    open func numberOfSections(in tableView: UITableView) -> Int {
        return elementSource.sections.count
    }
    
    
    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return elementSource.sections[section].items.count
    }
    
    
    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableViewCellForRowAtIndexPath(indexPath) {
            return cell
        } else {
            fatalError("No cell provided for index path: \(indexPath)")
        }
    }
    
    
    // MARK: UITableViewDelegate
    // MARK: Row
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }

    
    // MARK: Header
    
    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard elementSource.sections[section].headerElement != nil else {
            return 0
        }
        return UITableViewAutomaticDimension
    }

    
    open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        configureView : do {
            let element = elementSource.sections[section]
            guard let headerElement = element.headerElement else { break configureView }
            guard let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: type(of: headerElement).typeIdentifier) else { break configureView }
            
            // Update View
            if let headerView = headerView as? AnyElementHeaderFooterView {
                let oldElement = headerView.anyViewElement
                headerView.anyViewElement = headerElement
                headerView.elementDidChange(oldElement: oldElement, animate: false, type: .header)
            }
            return headerView
        }
        
        return nil
    }
    
    
    // MARK: Footer
    public func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        guard elementSource.sections[section].footerElement != nil else {
            return 0
        }
        return UITableViewAutomaticDimension
    }

    
    open func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        configureView : do {
            let element = elementSource.sections[section]
            guard let footerElement = element.footerElement else { break configureView }
            guard let footerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: type(of: footerElement).typeIdentifier) else { break configureView }
            
            // Update View
            if let footerView = footerView as? AnyElementHeaderFooterView {
                let oldElement = footerView.anyViewElement
                footerView.anyViewElement = footerElement
                footerView.elementDidChange(oldElement: oldElement, animate: false, type: .footer)
            }
            return footerView
        }
        
        return nil
    }

    
    // MARK: Selection
    
    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let element = elementSource.sections[indexPath.section].items[indexPath.row]
        
        if let selectableElement = element as? SelectableTableViewElement {
            selectableElement.selectionHandler?()
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}


extension ElementTableViewController {
    
    /// Options to finetune the update process
    public enum UpdateOptions {
        /// Default incremental update
        case `default`
        
        /// Non incremental update, like calling tableView.reloadData
        case hardReload
        
        /// Like default, but all visible cells will be updated
        case updateVisibleCells
        
        /// Use this if you know the table view is in a valid, but the data is in an invalid state
        case dataOnly
    }
}
