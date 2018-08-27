//
//  ViewModelTableViewAdapter
//  CompareApp
//
//  Created by Karsten Bruns on 30/08/15.
//  Copyright © 2015 bruns.me. All rights reserved.
//

import UIKit


public protocol DeltaTableViewDelegate: AnyObject {
    func deltaTableViewDidUpdate(_ deltaTableView: DeltaTableView, animated: Bool)
    func deltaTableViewWillUpdate(_ deltaTableView: DeltaTableView, animated: Bool)
    func registerModelableTableViewCells(in deltaTableView: DeltaTableView)
}


open class DeltaTableView: UIView, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - Properties -
    
    private var tableView: UITableView
    public weak var delegate: DeltaTableViewDelegate?

    private var animateViews = true
    private var updateOptions = UpdateOptions.default

    private let sectionDiffer = SectionDiffer()
    public var logging = LoggingOptions.none

    public private(set) var sections = [CellSectionModel]()

    
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

    public init(frame: CGRect, style: UITableViewStyle) {
        self.tableView = UITableView(frame: frame, style: style)
        super.init(frame: frame)
        commonInit()
    }

    public override init(frame: CGRect) {
        self.tableView = UITableView(frame: frame, style: .grouped)
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder aDecoder: NSCoder) {
        self.tableView = UITableView(frame: .zero, style: .grouped)
        super.init(coder: aDecoder)
        commonInit()
    }

    public func commonInit() {
        configureContentDiffer()
        addSubviews()
        addConstraints()

        setCellModels(sections: [])
    }
    
    
    // MARK: Subviews

    /// Configures the table view to the controller
    private func addSubviews() {
        // Configure
        tableView.delegate = self
        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        // Cell dimensions
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.sectionHeaderHeight = UITableViewAutomaticDimension
        tableView.sectionFooterHeight = UITableViewAutomaticDimension

        // Add reusable cells
        delegate?.registerModelableTableViewCells(in: self)
    }
    
    private func addConstraints() {
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.topAnchor.constraint(equalTo: topAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    /**
     Updates the table view

     - Parameter options: Enum with instructions on how to update the table view. Default is `.Default`.
     
     */
    public func setCellModels(sections newSections: [CellSectionModel], options: UpdateOptions = .default, animated: Bool = true) {
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
            let oldSections = sections.map({ $0 as SectionModel })
            let newSections = newSections.map({ $0 as SectionModel })
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
        
        sectionDiffer.animationWrapper = { [weak self] (work, completion) in
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
        sectionDiffer.modelUpdate = { [weak self] (items, section, insertIndexes, reloadIndexMap, deleteIndexes) in
            guard let this = self else { return }
            
            this.sections[section].items = items.compactMap { $0 as? AnyCellModel }
            
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
                    guard let modelCell = cell as? AnyModelableTableViewCell, let model = items[itemIndexAfter] as? AnyCellModel else { continue }
                    let previousModel = modelCell.anyModel
                    modelCell.anyModel = model
                    modelCell.modelDidChange(previousModel: previousModel, animate: true)
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
        sectionDiffer.modelReorder = { [weak self] (items, section, reorderMap) in
            guard let this = self else { return }

            this.sections[section].items = items.compactMap { $0 as? AnyCellModel }
            
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

            this.sections = sections.compactMap({ $0 as? CellSectionModel })
            
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
                
                if let sectionModel = sections[sectionIndexAfter] as? CellSectionModel {
                    
                    if let headerView = this.tableView.headerView(forSection: sectionIndexBefore) as? AnyModelableHeaderFooterView, let headerModel = sectionModel.headerModel {
                        let previousModel = headerView.anyCellModel
                        headerView.anyCellModel = headerModel
                        headerView.modelDidChange(previousModel: previousModel, animate: true, type: .header)
                    }
                    
                    if let footerView = this.tableView.footerView(forSection: sectionIndexBefore) as? AnyModelableHeaderFooterView, let footerModel = sectionModel.footerModel {
                        let previousModel = footerView.anyCellModel
                        footerView.anyCellModel = footerModel
                        footerView.modelDidChange(previousModel: previousModel, animate: true, type: .footer)
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

            this.sections = sections.compactMap({ $0 as? CellSectionModel })
            
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
                    if let modelCell = this.tableView.cellForRow(at: indexPath) as? AnyModelableTableViewCell {
                        let model: AnyCellModel = this.sections[indexPath.section].items[indexPath.row]
                        let previousModel = modelCell.anyModel
                        modelCell.anyModel = model
                        modelCell.modelDidChange(previousModel: previousModel, animate: false)
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
        delegate?.deltaTableViewWillUpdate(self, animated: animated)
    }


    private func tableViewDidUpdateCells(_ animated: Bool) {
        delegate?.deltaTableViewDidUpdate(self, animated: animated)
    }

    
    // MARK: - API -
    // MARK: Table View
    
    public func register<EC: ModelableTableViewCell & UITableViewCell>(_ modelTableViewCellType: EC.Type) {
        let reuseIdentifier = modelTableViewCellType.ModelType.typeIdentifier
        tableView.register(modelTableViewCellType, forCellReuseIdentifier: reuseIdentifier)
    }
    

    public func register<EC: ModelableHeaderFooterView & UITableViewHeaderFooterView>(_ modelViewHeaderFooterViewType: EC.Type) {
        let reuseIdentifier = modelViewHeaderFooterViewType.ModelType.typeIdentifier
        tableView.register(modelViewHeaderFooterViewType, forHeaderFooterViewReuseIdentifier: reuseIdentifier)
    }

    
    // MARK: Access Cell Models

    /// Returns the `CellSectionModel` that belongs to the provided section index.
    public func cellSectionModel(at sectionIndex: Int) -> CellSectionModel {
        return sections[sectionIndex]
    }


    /// Returns the `CellModel` that belongs to the provided index path.
    public func cellModel(at indexPath: IndexPath) -> AnyCellModel {
        return sections[indexPath.section].items[indexPath.row]
    }

    // MARK: Override Hooks

    /**
     Dequeues a reusable cell from table view as long the model for this index path is of type `DeltaTableCellModel`.
     
     Use this method if you want to provide your own implementation of `tableView(tableView:cellForRowAtIndexPath:)` but
     you still want to be able to return cells provided by this class if needed.
     
     In most cases this function is only used internally and a custom implementation of `tableView(tableView:cellForRowAtIndexPath:)`
     is not needed.
     */
    open func tableViewCellForRowAtIndexPath(_ indexPath: IndexPath) -> UITableViewCell? {
        let model = sections[indexPath.section].items[indexPath.row]
        
        getTableViewCell: do {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: type(of: model).typeIdentifier) else { break getTableViewCell }

            if let modelCell = cell as? AnyModelableTableViewCell {
                let previousModel = modelCell.anyModel
                modelCell.anyModel = model
                modelCell.modelDidChange(previousModel: previousModel, animate: false)
            }
            
            if let selectableModel = model as? SelectableCellModel {
                cell.selectionStyle = selectableModel.selectionHandler != nil ? .default : .none
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
        guard sections[section].headerModel != nil else {
            return 0
        }
        return UITableViewAutomaticDimension
    }

    
    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        configureView : do {
            let model = sections[section]
            guard let headerModel = model.headerModel else { break configureView }
            guard let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: type(of: headerModel).typeIdentifier) else { break configureView }
            
            // Update View
            if let headerView = headerView as? AnyModelableHeaderFooterView {
                let previousModel = headerView.anyCellModel
                headerView.anyCellModel = headerModel
                headerView.modelDidChange(previousModel: previousModel, animate: false, type: .header)
            }
            return headerView
        }
        
        return nil
    }
    
    
    public func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        guard sections[section].footerModel != nil else {
            return 0
        }
        return UITableViewAutomaticDimension
    }

    
    public func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        configureView : do {
            let sectionModel = sections[section]
            guard let footerModel = sectionModel.footerModel else { break configureView }
            guard let footerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: type(of: footerModel).typeIdentifier) else { break configureView }
            
            // Update View
            if let footerView = footerView as? AnyModelableHeaderFooterView {
                let previousModel = footerView.anyCellModel
                footerView.anyCellModel = footerModel
                footerView.modelDidChange(previousModel: previousModel, animate: false, type: .footer)
            }
            return footerView
        }
        
        return nil
    }

    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cellModel = sections[indexPath.section].items[indexPath.row]
        
        if let selectableCell = tableView.cellForRow(at: indexPath) as? SelectableCell {
            selectableCell.performSelectionAction()
        }
        
        if let selectableModel = cellModel as? SelectableCellModel {
            selectableModel.selectionHandler?()
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}


extension DeltaTableView {
    
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
}
