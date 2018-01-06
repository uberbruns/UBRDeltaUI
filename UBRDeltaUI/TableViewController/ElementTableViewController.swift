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
    
    // MARK: - Controller -

    open var reusableCellClasses = [String:UITableViewCell.Type]()
    open var reusableHeaderFooterClasses = [String:UITableViewHeaderFooterView.Type]()
    
    open private(set) var sections: [SectionViewElement] = []
    private let contentDiffer = ElementDiffer()
    private var animateViews = true
    private var updateOptions = UpdateOptions.default
    open var deltaDebugOutput = DeltaDebugOutput.none
    
    private var estimatedCellHeights = DeltaMatrix<CGFloat>()
    private var learnedCellHeights = DeltaMatrix<CGFloat>()
    private var headerFooterPrototypes = [String:UITableViewHeaderFooterView]()
    open var tableView = UITableView(frame: .zero, style: .grouped)
    
    
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
    
    
    
    // MARK: - View -
    // MARK: Life-Cycle
    
    override open func viewDidLoad() {
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
        reusableCellClasses.forEach { (identifier, cellClass) -> () in tableView.register(cellClass, forCellReuseIdentifier: identifier) }
        reusableHeaderFooterClasses.forEach { (identifier, hfClass) -> () in tableView.register(hfClass, forHeaderFooterViewReuseIdentifier: identifier) }
        
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
        let newSections: [SectionViewElement] = generateElements()
        
        updateOptions = options
        learnedCellHeights.removeAll(true)
        
        if options == .dataOnly {
            sections = newSections
        } else if sections.count == 0 || options == .hardReload {
            tableViewWillUpdateCells(false)
            sections = newSections
            tableView.reloadData()
            updateLearnedHeights()
            tableViewDidUpdateCells(false)
        } else {
            let oldSections = sections.map({ $0 as SectionElement })
            let newSections = newSections.map({ $0 as SectionElement })
            contentDiffer.queueComparison(oldSections: oldSections, newSections: newSections)
        }
    }
    
    
    /**
     The better the estimated height, the better are animated table view updates. This function
     updates the internal data set of rendered cell heights for every index path.
     */
    private func updateLearnedHeights() {
        for indexPath in tableView.indexPathsForVisibleRows ?? [] {
            guard let cell = tableView.cellForRow(at: indexPath) else { continue }
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
        
        contentDiffer.throttleTimeInterval = 0.16667
        contentDiffer.debugOutput = deltaDebugOutput != .none
        
        // Start updating table view
        contentDiffer.start = { [weak self] in
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
        contentDiffer.itemUpdate = { [weak self] (items, section, insertIndexes, reloadIndexMap, deleteIndexes) in
            guard let weakSelf = self else { return }
            
            weakSelf.sections[section].items = items.flatMap { $0 as? AnyViewElement }
            
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
        contentDiffer.itemReorder = { [weak self] (items, section, reorderMap) in
            guard let weakSelf = self else { return }
            
            weakSelf.sections[section].items = items.flatMap { $0 as? AnyViewElement }
            
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
        contentDiffer.sectionUpdate = { [weak self] (sections, insertIndexes, reloadIndexMap, deleteIndexes) in
            guard let weakSelf = self else { return }
            
            weakSelf.sections = sections.flatMap({ $0 as? SectionViewElement })
            
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
                    
                    if let headerView = weakSelf.tableView.headerView(forSection: sectionIndexBefore) as? ElementViewHeaderFooterView {
                        headerView.update(with: sectionElement.headerElement ?? sectionElement, animated: true, type: .header)
                    }
                    
                    if let footerView = weakSelf.tableView.footerView(forSection: sectionIndexBefore) as? ElementViewHeaderFooterView {
                        footerView.update(with: sectionElement.footerElement ?? sectionElement, animated: true, type: .footer)
                    }
                    
                } else {
                    weakSelf.tableView.reloadSections(IndexSet(integer: sectionIndexBefore), with: weakSelf.sectionDeletionAnimation)
                }
            }
            
            weakSelf.tableView.endUpdates()
        }
        
        // Reorder table view sections
        contentDiffer.sectionReorder = { [weak self] (sections, reorderMap) in
            guard let weakSelf = self else { return }
            
            weakSelf.sections = sections.flatMap({ $0 as? SectionViewElement })
            
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
        contentDiffer.completion = { [weak self] in
            guard let weakSelf = self else { return }
            
            if weakSelf.updateOptions == .updateVisibleCells {
                var manualReloads = [IndexPath]()
                for indexPath in weakSelf.tableView.indexPathsForVisibleRows ?? [] {
                    if let elementCell = weakSelf.tableView.cellForRow(at: indexPath) as? AnyElementTableViewCell {
                        let element: AnyViewElement = weakSelf.sections[indexPath.section].items[indexPath.row]
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
            weakSelf.updateLearnedHeights()
        }
    }
    
    
    // MARK: - API -
    // MARK: Content
    
    /// Use this function in subclasses to provide section and rows items you want to display
    /// as table view cells.
    open func generateElements() -> [SectionViewElement] {
        return []
    }

    
    /// Returns the `SectionViewElement` that belongs to the provided section index.
    open func tableViewSectionElement(_ section: Int) -> SectionViewElement {
        return sections[section]
    }
    

    /// Returns the `Element` that belongs to the provided index path.
    open func tableViewElement(_ indexPath: IndexPath) -> AnyViewElement {
        return sections[indexPath.section].items[indexPath.row]
    }

    
    // MARK: Table View
    
    /// Use this function in your subclass to update `reusableCellClasses` and `reusableHeaderFooterClasses`.
    open func prepareReusableTableViewCells() { }
    
    
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
        let element = sections[indexPath.section].items[indexPath.row]
        
        getTableViewCell : do {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: element.typeIdentifier) else { break getTableViewCell }

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
        return sections.count
    }
    
    
    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].items.count
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
    
    open func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if let learnedHeight = learnedCellHeights[indexPath.section, indexPath.row] {
            return learnedHeight
        } else {
            return UITableViewAutomaticDimension
        }
    }
    
    
    open func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return estimatedCellHeights[indexPath.section, indexPath.row] ?? tableView.estimatedRowHeight
    }
    
    
    open func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        estimatedCellHeights[indexPath.section, indexPath.row] = cell.bounds.height
        learnedCellHeights[indexPath.section, indexPath.row] = cell.bounds.height
    }
    
    
    // MARK: Header
    
    open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let element = sections[section]
        var view: UIView?
        
        configureView : do {
            guard let headerElement = element.headerElement else { break configureView }
            guard let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerElement.typeIdentifier) else { break configureView }
            // Update View
            headerView.prepareForReuse()
            if let updateableView = headerView as? ElementViewHeaderFooterView {
                updateableView.update(with: headerElement as AnyElement, animated: false, type: .header)
            }
            view = headerView
        }
    
        return view
    }
    
    
    open func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let element = sections[section]
        var height: CGFloat = tableView.sectionHeaderHeight
        
        calculateHeight : do {
            guard let headerElement = element.headerElement else { break calculateHeight }
            guard let prototype = headerFooterPrototypes[headerElement.typeIdentifier] else { break calculateHeight }
            // Update Prototype
            prototype.prepareForReuse()
            if let updatableView = prototype as? ElementViewHeaderFooterView {
                updatableView.update(with: headerElement as AnyElement, animated: false, type: .header)
            }
            // Get Height
            let fittedWidth = tableView.bounds.width
            let fittedHeight = UILayoutFittingCompressedSize.height
            let fittingSize = CGSize(width: fittedWidth, height: fittedHeight)
            let size = prototype.contentView.systemLayoutSizeFitting(fittingSize, withHorizontalFittingPriority: UILayoutPriority(rawValue: 999), verticalFittingPriority: UILayoutPriority.fittingSizeLevel)
            height = size.height
        }
        
        return height
    }
    
    
    
    // MARK: Footer

    open func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let element = sections[section]
        var view: UIView?
        
        configureView : do {
            guard let footerElement = element.footerElement else { break configureView }
            guard let footerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: footerElement.typeIdentifier) else { break configureView }
            // Update View
            footerView.prepareForReuse()
            if let updateableView = footerView as? ElementViewHeaderFooterView {
                updateableView.update(with: footerElement as AnyElement, animated: false, type: .footer)
            }
            view = footerView
        }
        
        return view
    }
    
    
    open func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let element = sections[section]
        var height: CGFloat = CGFloat.leastNormalMagnitude
        
        calculateHeight : do {
            guard let footerElement = element.footerElement else { break calculateHeight }
            guard let prototype = headerFooterPrototypes[footerElement.typeIdentifier] else { break calculateHeight }
            // Update Prototype
            prototype.prepareForReuse()
            if let updatableView = prototype as? ElementViewHeaderFooterView {
                updatableView.update(with: footerElement as AnyElement, animated: false, type: .footer)
            }
            // Get Height
            let fittedWidth = tableView.bounds.width
            let fittedHeight = UILayoutFittingCompressedSize.height
            let fittingSize = CGSize(width: fittedWidth, height: fittedHeight)
            let size = prototype.contentView.systemLayoutSizeFitting(fittingSize, withHorizontalFittingPriority: UILayoutPriority(rawValue: 999), verticalFittingPriority: UILayoutPriority.fittingSizeLevel)
            height = size.height
        }
        
        lastFooterHeight : do {
            guard section == tableView.numberOfSections - 1 else { break lastFooterHeight }
            guard element.footerElement == nil else { break lastFooterHeight }
            height = tableView.sectionFooterHeight
        }
        
        return height
    }

    
    // MARK: Selection
    
    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let element = sections[indexPath.section].items[indexPath.row]
        
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
