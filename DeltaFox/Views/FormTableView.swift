//
//  ViewModelTableViewAdapter
//  CompareApp
//
//  Created by Karsten Bruns on 30/08/15.
//  Copyright © 2015 bruns.me. All rights reserved.
//

import UIKit


public protocol FormTableViewDelegate: AnyObject {
    func formTableViewDidUpdate(_ formTableView: FormTableView, animated: Bool)
    func formTableViewWillUpdate(_ formTableView: FormTableView, animated: Bool)
    func prepareFormTableView(_ formTableView: FormTableView)
}


open class FormTableView: UIView, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - Properties -
    
    public private(set) var tableView: UITableView
    public private(set) var configuration: Configuration
    public weak var delegate: FormTableViewDelegate?

    private var animateViews = true
    private var updateOptions = UpdateOptions.default

    private let sectionDiffer = SectionDiffer()
    public var logging = LoggingOptions.none

    public private(set) var sections = [FormSection]()

    
    // MARK: Table View API
    
    /// The type of animation when rows are deleted.
    public var rowDeletionAnimation = UITableViewRowAnimation.automatic
    
    /// The type of animation when rows are inserted.
    public var rowInsertionAnimation = UITableViewRowAnimation.automatic
    
    /// The type of animation when rows are reloaded (not updated)
    public var rowReloadAnimation = UITableViewRowAnimation.automatic
    
    /// The type of animation when sections are deleted.
    public var sectionDeletionAnimation = UITableViewRowAnimation.automatic
    
    /// The type of animation when sections are inserted.
    public var sectionInsertionAnimation = UITableViewRowAnimation.automatic
    
    /// The type of animation when sections are reloaded (not updated)
    public var sectionReloadAnimation = UITableViewRowAnimation.automatic
    

    // MARK: - View -
    // MARK: Life-Cycle

    public init(delegate: FormTableViewDelegate, configuration: Configuration) {
        let preliminaryFrame = CGRect(x: 0, y: 0, width: 1024, height: 1024)

        self.configuration = configuration
        self.tableView = UITableView(frame: preliminaryFrame, style: configuration.tableStyle)
        self.delegate = delegate

        super.init(frame: preliminaryFrame)

        configureContentDiffer()
        setupViews()
        setupConstraints()
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    // MARK: Subviews

    /// Configures the table view to the controller
    private func setupViews() {
        // Configure
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.sectionHeaderHeight = UITableViewAutomaticDimension
        tableView.sectionFooterHeight = UITableViewAutomaticDimension
        tableView.contentInset = UIEdgeInsets(top: configuration.hiddenContentInsetForAnimationOptimization.top, left: 0, bottom: configuration.hiddenContentInsetForAnimationOptimization.bottom, right: 0)
        tableView.scrollIndicatorInsets = UIEdgeInsets(top: configuration.hiddenContentInsetForAnimationOptimization.top, left: 0, bottom: configuration.hiddenContentInsetForAnimationOptimization.bottom, right: 0)
        addSubview(tableView)

        // Add reusable cells
        delegate?.prepareFormTableView(self)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.topAnchor.constraint(equalTo: topAnchor, constant: -configuration.hiddenContentInsetForAnimationOptimization.top),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: configuration.hiddenContentInsetForAnimationOptimization.bottom)
        ])
    }

    /**
     Updates the table view

     - Parameter options: Enum with instructions on how to update the table view. Default is `.Default`.
     
     */
    public func setSections(_ newSections: [FormSection], options: UpdateOptions = .default, animated: Bool = true) {
        updateOptions = options
        
        if options == .dataOnly {
            animateViews = false
            sections = newSections
            
        } else if sections.isEmpty || options == .hardReload {
            animateViews = false
            tableViewWillUpdateCells(false)
            sections = newSections
            tableView.reloadData()
            tableViewDidUpdateCells(false)
            
        } else {
            animateViews = animated
            let oldSections = sections.map({ $0 as DiffableSection })
            let newSections = newSections.map({ $0 as DiffableSection })
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
        
        sectionDiffer.throttleTimeInterval = 0.001
        sectionDiffer.debugOutput = logging != .none
        
        sectionDiffer.animationContext = { [weak self] (work, completion) in
            guard let this = self else { return }
            this.tableView.performBatchUpdates({
                work()
            }, completion: { (_) in
                completion()
            })
        }
        
        // Start updating table view
        sectionDiffer.start = { [weak self] in
            guard let this = self else { return }
            if this.logging == .debug {
                print("Start updating table view", separator: "\n", terminator: "\n\n")
            }
            if this.animateViews == false {
                UIView.setAnimationsEnabled(false)
            }
            this.tableViewWillUpdateCells(this.animateViews)
        }
        
        // Insert, reload and delete table view rows
        sectionDiffer.itemUpdate = { [weak self] (items, section, insertIndexes, reloadIndexMap, deleteIndexes) in
            guard let this = self else { return }
            
            this.sections[section].items = items.compactMap { $0 as? AnyFormItemProtocol }
            
            if insertIndexes.count == 0 && reloadIndexMap.count == 0 && deleteIndexes.count == 0 {
                return
            }
            
            if this.logging == .debug {
                print("Updating rows in section \(section)", "items: \(items.map({ $0.uniqueIdentifier }))", "insertIndexes: \(insertIndexes)", "reloadIndexMap: \(reloadIndexMap)", "deleteIndexes: \(deleteIndexes)", separator: "\n", terminator: "\n\n")
            }
            
            var manualReloadMap = reloadIndexMap
            
            if this.updateOptions != .updateVisibleCells {
                for (itemIndexBefore, itemIndexAfter) in reloadIndexMap {
                    let indexPathBefore = IndexPath(row: itemIndexBefore, section: section)
                    guard let cell = this.tableView.cellForRow(at: indexPathBefore) else {
                        manualReloadMap.removeValue(forKey: itemIndexBefore)
                        continue
                    }
                    guard let formCell = cell as? AnyFormCellProtocol, let item = items[itemIndexAfter] as? AnyFormItemProtocol else { continue }
                    let oldItem = formCell.anyFormItem
                    formCell.anyFormItem = item
                    formCell.itemDidChange(oldItem: oldItem, animate: true)
                    manualReloadMap.removeValue(forKey: itemIndexBefore)
                }
            }

            if insertIndexes.count == 0 && manualReloadMap.count == 0 && deleteIndexes.count == 0 {
                return
            }

            this.tableView.beginUpdates()
            
            if manualReloadMap.count > 0 && this.updateOptions != .updateVisibleCells {
                for (itemIndexBefore, _) in manualReloadMap {
                    let indexPathBefore = IndexPath(row: itemIndexBefore, section: section)
                    this.tableView.reloadRows(at: [indexPathBefore], with: this.rowReloadAnimation)
                }
            }
            
            if deleteIndexes.count > 0 {
                this.tableView.deleteRows(at: deleteIndexes.map({ IndexPath(row: $0, section: section) }), with: this.rowDeletionAnimation)
            }
            
            if insertIndexes.count > 0 {
                this.tableView.insertRows(at: insertIndexes.map({ IndexPath(row: $0, section: section) }), with: this.rowInsertionAnimation)
            }
            
            this.tableView.endUpdates()
        }
        
        // Reorder table view rows
        sectionDiffer.itemReorder = { [weak self] (items, section, reorderMap) in
            guard let this = self else { return }

            this.sections[section].items = items.compactMap { $0 as? AnyFormItemProtocol }
            
            if reorderMap.count == 0 {
                return
            }
            
            if this.logging == .debug {
                print("Reorder rows in section \(section)", "items: \(items.map({ $0.uniqueIdentifier }))", "reorderMap: \(reorderMap)", separator: "\n", terminator: "\n\n")
            }
            
            this.tableView.beginUpdates()
            for (from, to) in reorderMap {
                let fromIndexPath = IndexPath(row: from, section: section)
                let toIndexPath = IndexPath(row: to, section: section)
                this.tableView.moveRow(at: fromIndexPath, to: toIndexPath)
            }
            this.tableView.endUpdates()
        }
        
        // Insert, reload and delete table view sections
        sectionDiffer.sectionUpdate = { [weak self] (sections, insertIndexes, reloadIndexMap, deleteIndexes) in
            guard let this = self else { return }

            this.sections = sections.compactMap({ $0 as? FormSection })
            
            if insertIndexes.count == 0 && reloadIndexMap.count == 0 && deleteIndexes.count == 0 {
                return
            }
            
            if this.logging == .debug {
                print("Updating sections", "sections: \(sections.map({ $0.uniqueIdentifier }))", "insertIndexes: \(insertIndexes)", "reloadIndexMap: \(reloadIndexMap)", "deleteIndexes: \(deleteIndexes)", separator: "\n", terminator: "\n\n")
            }
            
            this.tableView.beginUpdates()
            
            let insertSet = NSMutableIndexSet()
            insertIndexes.forEach({ insertSet.add($0) })
            
            let deleteSet = NSMutableIndexSet()
            deleteIndexes.forEach({ deleteSet.add($0) })
            
            this.tableView.insertSections(insertSet as IndexSet, with: this.sectionInsertionAnimation)
            this.tableView.deleteSections(deleteSet as IndexSet, with: this.sectionDeletionAnimation)
            
            for (sectionIndexBefore, sectionIndexAfter) in reloadIndexMap {
                
                if let sectionItem = sections[sectionIndexAfter] as? FormSection {
                    
                    if let headerView = this.tableView.headerView(forSection: sectionIndexBefore) as? AnyFormHeaderFooterView, let headerItem = sectionItem.headerItem {
                        let oldItem = headerView.anyFormItem
                        headerView.anyFormItem = headerItem
                        headerView.itemDidChange(oldItem: oldItem, animate: true, type: .header)
                    }
                    
                    if let footerView = this.tableView.footerView(forSection: sectionIndexBefore) as? AnyFormHeaderFooterView, let footerItem = sectionItem.footerItem {
                        let oldItem = footerView.anyFormItem
                        footerView.anyFormItem = footerItem
                        footerView.itemDidChange(oldItem: oldItem, animate: true, type: .footer)
                    }
                    
                } else {
                    this.tableView.reloadSections(IndexSet(integer: sectionIndexBefore), with: this.sectionDeletionAnimation)
                }
            }
            
            this.tableView.endUpdates()
        }
        
        // Reorder table view sections
        sectionDiffer.sectionReorder = { [weak self] (sections, reorderMap) in
            guard let this = self else { return }

            this.sections = sections.compactMap({ $0 as? FormSection })
            
            if reorderMap.count == 0 {
                return
            }
            
            if this.logging == .debug {
                print("Reorder sections", "sections: \(sections.map({ $0.uniqueIdentifier }))", "reorderMap: \(reorderMap)", separator: "\n", terminator: "\n\n")
            }
            
            this.tableView.beginUpdates()
            for (from, to) in reorderMap {
                this.tableView.moveSection(from, toSection: to)
            }
            this.tableView.endUpdates()
        }
        
        // Updating table view did end
        sectionDiffer.completion = { [weak self] in
            guard let this = self else { return }

            if this.updateOptions == .updateVisibleCells {
                var manualReloads = [IndexPath]()
                for indexPath in this.tableView.indexPathsForVisibleRows ?? [] {
                    if let formCell = this.tableView.cellForRow(at: indexPath) as? AnyFormCellProtocol {
                        let item: AnyFormItemProtocol = this.sections[indexPath.section].items[indexPath.row]
                        let oldItem = formCell.anyFormItem
                        formCell.anyFormItem = item
                        formCell.itemDidChange(oldItem: oldItem, animate: false)
                    } else {
                        manualReloads.append(indexPath)
                    }
                }
                if manualReloads.count > 0 {
                    this.tableView.beginUpdates()
                    this.tableView.reloadRows(at: manualReloads, with: this.rowReloadAnimation)
                    this.tableView.endUpdates()
                }
            }
            
            if this.logging == .debug {
                print("Updating table view ended", separator: "\n", terminator: "\n\n")
            }
            
            UIView.setAnimationsEnabled(true)
            this.tableViewDidUpdateCells(this.animateViews)
            this.animateViews = true
        }
    }

    // MARK: Delegate Callbacks

    private func tableViewWillUpdateCells(_ animated: Bool) {
        delegate?.formTableViewWillUpdate(self, animated: animated)
    }


    private func tableViewDidUpdateCells(_ animated: Bool) {
        delegate?.formTableViewDidUpdate(self, animated: animated)
    }

    
    // MARK: - API -
    // MARK: Table View
    
    public func register<FC: FormCellProtocol & UITableViewCell>(_ formTableViewCellType: FC.Type) {
        let reuseIdentifier = formTableViewCellType.FormItemType.typeIdentifier
        tableView.register(formTableViewCellType, forCellReuseIdentifier: reuseIdentifier)
    }
    

    public func register<FC: FormHeaderFooterView & UITableViewHeaderFooterView>(_ formViewHeaderFooterViewType: FC.Type) {
        let reuseIdentifier = formViewHeaderFooterViewType.FormItemType.typeIdentifier
        tableView.register(formViewHeaderFooterViewType, forHeaderFooterViewReuseIdentifier: reuseIdentifier)
    }

    
    // MARK: Access Cell Models

    /// Returns the `FormSection` that belongs to the provided section index.
    public func cellSectionItem(at sectionIndex: Int) -> FormSection {
        return sections[sectionIndex]
    }


    /// Returns the `AnyFormItem` that belongs to the provided index path.
    public func cellItem(at indexPath: IndexPath) -> AnyFormItemProtocol {
        return sections[indexPath.section].items[indexPath.row]
    }

    // MARK: Override Hooks

    /**
     Dequeues a reusable cell from table view as long the item for this index path is of type `DeltaTableCellItem`.
     
     Use this method if you want to provide your own implementation of `tableView(tableView:cellForRowAtIndexPath:)` but
     you still want to be able to return cells provided by this class if needed.
     
     In most cases this function is only used internally and a custom implementation of `tableView(tableView:cellForRowAtIndexPath:)`
     is not needed.
     */
    open func tableViewCellForRowAtIndexPath(_ indexPath: IndexPath) -> UITableViewCell? {
        let item = sections[indexPath.section].items[indexPath.row]
        
        getTableViewCell: do {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: type(of: item).typeIdentifier) else { break getTableViewCell }

            if let formCell = cell as? AnyFormCellProtocol & UITableViewCell {
                let oldItem = formCell.anyFormItem
                formCell.anyFormItem = item
                formCell.itemDidChange(oldItem: oldItem, animate: false)
                formCell.tintColor = tableView.tintColor
            }
            
            if let selectableItem = item as? SelectableFormItem {
                cell.selectionStyle = selectableItem.selectionHandler != nil ? .default : .none
            }

            return cell
        }
        
        return nil
    }
    
    
    // MARK: - Protocols -
    // MARK: UITableViewDataSource
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].items.count
    }
    
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableViewCellForRowAtIndexPath(indexPath) {
            return cell
        } else {
            fatalError("No cell provided for index path: \(indexPath)")
        }
    }
    
    
    // MARK: UITableViewDelegate
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }

    
    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard sections[section].headerItem != nil else {
            return 15
        }
        return UITableViewAutomaticDimension
    }

    
    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        configureView: do {
            let item = sections[section]
            guard let headerItem = item.headerItem else { break configureView }
            guard let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: type(of: headerItem).typeIdentifier) else { break configureView }
            
            // Update View
            if let headerView = headerView as? AnyFormHeaderFooterView {
                let oldItem = headerView.anyFormItem
                headerView.anyFormItem = headerItem
                headerView.itemDidChange(oldItem: oldItem, animate: false, type: .header)
            }
            return headerView
        }
        
        return nil
    }
    
    
    public func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        guard sections[section].footerItem != nil else {
            return 0
        }
        return UITableViewAutomaticDimension
    }

    
    public func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        configureView : do {
            let sectionItem = sections[section]
            guard let footerItem = sectionItem.footerItem else { break configureView }
            guard let footerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: type(of: footerItem).typeIdentifier) else { break configureView }
            
            // Update View
            if let footerView = footerView as? AnyFormHeaderFooterView {
                let oldItem = footerView.anyFormItem
                footerView.anyFormItem = footerItem
                footerView.itemDidChange(oldItem: oldItem, animate: false, type: .footer)
            }
            return footerView
        }
        
        return nil
    }

    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cellItem = sections[indexPath.section].items[indexPath.row]
        
        if let selectableCell = tableView.cellForRow(at: indexPath) as? SelectableCell {
            selectableCell.performSelectionAction()
        }
        
        if let selectableItem = cellItem as? SelectableFormItem {
            selectableItem.selectionHandler?()
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}


extension FormTableView {
    
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
    
    /// Options to fine tune the debug output. Please note, that the options .Debug and .Warnings have an impact on performance
    public enum LoggingOptions {
        case none
        case debug
        case warnings
    }

    public struct Configuration {
        public var tableStyle: UITableViewStyle
        public var hiddenContentInsetForAnimationOptimization: UIEdgeInsets

        public init(tableStyle: UITableViewStyle = .grouped, hiddenContentInsetForAnimationOptimization: UIEdgeInsets = .zero) {
            self.tableStyle = tableStyle
            self.hiddenContentInsetForAnimationOptimization = hiddenContentInsetForAnimationOptimization
        }
    }
}
