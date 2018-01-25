//
//  ViewModelTableViewAdapter
//  CompareApp
//
//  Created by Karsten Bruns on 30/08/15.
//  Copyright © 2015 bruns.me. All rights reserved.
//

import UIKit


public protocol ViewModelTableViewController: class {
    var tableView: UITableView { get }
    var viewModel: ViewModel { get }

    func viewModelAdapterDidUpdateTableViewCells(_ viewModelAdapter: ViewModelTableViewAdapter, animated: Bool)
    func viewModelAdapterWillUpdateTableViewCells(_ viewModelAdapter: ViewModelTableViewAdapter, animated: Bool)
    func registerPresentableTableViewCell(with viewModelAdapter: ViewModelTableViewAdapter)
}


open class ViewModelTableViewAdapter: NSObject, UITableViewDelegate, UITableViewDataSource, ViewModelDelegate {
    
    // MARK: - Properties -
    
    private var tableView: UITableView? { return tableViewController?.tableView }
    private var viewModel: ViewModel { return tableViewController!.viewModel }

    public weak var tableViewController: (ViewModelTableViewController & UIViewController)?

    private var animateViews = true
    private var updateOptions = UpdateOptions.default

    private let sectionDiffer = SectionDiffer()
    public var logging = LoggingOptions.none

    
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
    

    // MARK: - Adapter -
    // MARK: Life-Cycle
    
    public init(tableViewController: ViewModelTableViewController & UIViewController) {
        self.tableViewController = tableViewController
        super.init()
    }
    
    public func start() {
        tableView?.delegate = self
        tableView?.dataSource = self
        viewModel.delegate = self

        configureContentDiffer()
        configureTableView()
        updateTableView()
    }
    
    
    // MARK: Views
    
    /// Configures the table view to the controller
    private func configureTableView() {
        guard let tableView = tableView else { return }
        
        // Configure
        tableView.delegate = self
        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        // Cell dimensions
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.sectionHeaderHeight = UITableViewAutomaticDimension
        tableView.sectionFooterHeight = UITableViewAutomaticDimension

        // Add reusable cells
        tableViewController?.registerPresentableTableViewCell(with: self)
    }
    
    
    /**
     Updates the table view

     - Parameter options: Enum with instructions on how to update the table view. Default is `.Default`.
     
     */
    public func updateTableView(options: UpdateOptions = .default, animated: Bool = true) {
        guard let tableView = tableView else { return }
        
        var newSections = [CellSectionModel]()
        viewModel.generateCellModel(sections: &newSections)
        
        updateOptions = options
        
        if options == .dataOnly {
            animateViews = false
            viewModel.sections = newSections
            
        } else if viewModel.sections.isEmpty || options == .hardReload {
            animateViews = false
            tableViewWillUpdateCells(false)
            viewModel.sections = newSections
            tableView.reloadData()
            tableViewDidUpdateCells(false)
            
        } else {
            animateViews = animated
            let oldSections = viewModel.sections.map({ $0 as SectionModel })
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
            guard let adapter = self, let tableView = adapter.tableView else { return }
            tableView.performBatchUpdates({
                work()
            }, completion: { (_) in
                completion()
            })
        }
        
        // Start updating table view
        sectionDiffer.start = { [weak self] in
            guard let adapter = self else { return }
            if adapter.logging == .debug {
                print("Start updating table view", separator: "\n", terminator: "\n\n")
            }
            if adapter.animateViews == false {
                UIView.setAnimationsEnabled(false)
            }
            adapter.tableViewWillUpdateCells(adapter.animateViews)
        }
        
        // Insert, reload and delete table view rows
        sectionDiffer.modelUpdate = { [weak self] (items, section, insertIndexes, reloadIndexMap, deleteIndexes) in
            guard let adapter = self, let tableView = adapter.tableView else { return }
            
            adapter.viewModel.sections[section].items = items.flatMap { $0 as? AnyCellModel }
            
            if insertIndexes.count == 0 && reloadIndexMap.count == 0 && deleteIndexes.count == 0 {
                return
            }
            
            if adapter.logging == .debug {
                print("Updating rows in section \(section)", "items: \(items.map({ $0.uniqueIdentifier }))", "insertIndexes: \(insertIndexes)", "reloadIndexMap: \(reloadIndexMap)", "deleteIndexes: \(deleteIndexes)", separator: "\n", terminator: "\n\n")
            }
            
            var manualReloadMap = reloadIndexMap
            
            if adapter.updateOptions != .updateVisibleCells {
                for (itemIndexBefore, itemIndexAfter) in reloadIndexMap {
                    let indexPathBefore = IndexPath(row: itemIndexBefore, section: section)
                    guard let cell = tableView.cellForRow(at: indexPathBefore) else {
                        manualReloadMap.removeValue(forKey: itemIndexBefore)
                        continue
                    }
                    guard let modelCell = cell as? AnyPresentableTableViewCell, let model = items[itemIndexAfter] as? AnyCellModel else { continue }
                    let previousModel = modelCell.anyModel
                    modelCell.anyModel = model
                    modelCell.modelDidChange(previousModel: previousModel, animate: true)
                    manualReloadMap.removeValue(forKey: itemIndexBefore)
                }
            }

            if insertIndexes.count == 0 && manualReloadMap.count == 0 && deleteIndexes.count == 0 {
                return
            }

            tableView.beginUpdates()
            
            if manualReloadMap.count > 0 && adapter.updateOptions != .updateVisibleCells {
                for (itemIndexBefore, _) in manualReloadMap {
                    let indexPathBefore = IndexPath(row: itemIndexBefore, section: section)
                    tableView.reloadRows(at: [indexPathBefore], with: adapter.rowReloadAnimation)
                }
            }
            
            if deleteIndexes.count > 0 {
                tableView.deleteRows(at: deleteIndexes.map({ IndexPath(row: $0, section: section) }), with: adapter.rowDeletionAnimation)
            }
            
            if insertIndexes.count > 0 {
                tableView.insertRows(at: insertIndexes.map({ IndexPath(row: $0, section: section) }), with: adapter.rowInsertionAnimation)
            }
            
            tableView.endUpdates()
        }
        
        // Reorder table view rows
        sectionDiffer.modelReorder = { [weak self] (items, section, reorderMap) in
            guard let adapter = self, let tableView = adapter.tableView else { return }

            adapter.viewModel.sections[section].items = items.flatMap { $0 as? AnyCellModel }
            
            if reorderMap.count == 0 {
                return
            }
            
            if adapter.logging == .debug {
                print("Reorder rows in section \(section)", "items: \(items.map({ $0.uniqueIdentifier }))", "reorderMap: \(reorderMap)", separator: "\n", terminator: "\n\n")
            }
            
            tableView.beginUpdates()
            for (from, to) in reorderMap {
                let fromIndexPath = IndexPath(row: from, section: section)
                let toIndexPath = IndexPath(row: to, section: section)
                tableView.moveRow(at: fromIndexPath, to: toIndexPath)
            }
            tableView.endUpdates()
        }
        
        // Insert, reload and delete table view sections
        sectionDiffer.sectionUpdate = { [weak self] (sections, insertIndexes, reloadIndexMap, deleteIndexes) in
            guard let adapter = self, let tableView = adapter.tableView else { return }

            adapter.viewModel.sections = sections.flatMap({ $0 as? CellSectionModel })
            
            if insertIndexes.count == 0 && reloadIndexMap.count == 0 && deleteIndexes.count == 0 {
                return
            }
            
            if adapter.logging == .debug {
                print("Updating sections", "sections: \(sections.map({ $0.uniqueIdentifier }))", "insertIndexes: \(insertIndexes)", "reloadIndexMap: \(reloadIndexMap)", "deleteIndexes: \(deleteIndexes)", separator: "\n", terminator: "\n\n")
            }
            
            tableView.beginUpdates()
            
            let insertSet = NSMutableIndexSet()
            insertIndexes.forEach({ insertSet.add($0) })
            
            let deleteSet = NSMutableIndexSet()
            deleteIndexes.forEach({ deleteSet.add($0) })
            
            tableView.insertSections(insertSet as IndexSet, with: adapter.sectionInsertionAnimation)
            tableView.deleteSections(deleteSet as IndexSet, with: adapter.sectionDeletionAnimation)
            
            for (sectionIndexBefore, sectionIndexAfter) in reloadIndexMap {
                
                if let sectionModel = sections[sectionIndexAfter] as? CellSectionModel {
                    
                    if let headerView = tableView.headerView(forSection: sectionIndexBefore) as? AnyPresentableHeaderFooterView, let headerModel = sectionModel.headerModel {
                        let previousModel = headerView.anyCellModel
                        headerView.anyCellModel = headerModel
                        headerView.modelDidChange(previousModel: previousModel, animate: true, type: .header)
                    }
                    
                    if let footerView = tableView.footerView(forSection: sectionIndexBefore) as? AnyPresentableHeaderFooterView, let footerModel = sectionModel.footerModel {
                        let previousModel = footerView.anyCellModel
                        footerView.anyCellModel = footerModel
                        footerView.modelDidChange(previousModel: previousModel, animate: true, type: .footer)
                    }
                    
                } else {
                    tableView.reloadSections(IndexSet(integer: sectionIndexBefore), with: adapter.sectionDeletionAnimation)
                }
            }
            
            tableView.endUpdates()
        }
        
        // Reorder table view sections
        sectionDiffer.sectionReorder = { [weak self] (sections, reorderMap) in
            guard let adapter = self, let tableView = adapter.tableView else { return }

            adapter.viewModel.sections = sections.flatMap({ $0 as? CellSectionModel })
            
            if reorderMap.count == 0 {
                return
            }
            
            if adapter.logging == .debug {
                print("Reorder sections", "sections: \(sections.map({ $0.uniqueIdentifier }))", "reorderMap: \(reorderMap)", separator: "\n", terminator: "\n\n")
            }
            
            tableView.beginUpdates()
            for (from, to) in reorderMap {
                tableView.moveSection(from, toSection: to)
            }
            tableView.endUpdates()
        }
        
        // Updating table view did end
        sectionDiffer.completion = { [weak self] in
            guard let adapter = self, let tableView = adapter.tableView else { return }

            if adapter.updateOptions == .updateVisibleCells {
                var manualReloads = [IndexPath]()
                for indexPath in tableView.indexPathsForVisibleRows ?? [] {
                    if let modelCell = tableView.cellForRow(at: indexPath) as? AnyPresentableTableViewCell {
                        let model: AnyCellModel = adapter.viewModel.sections[indexPath.section].items[indexPath.row]
                        let previousModel = modelCell.anyModel
                        modelCell.anyModel = model
                        modelCell.modelDidChange(previousModel: previousModel, animate: false)
                    } else {
                        manualReloads.append(indexPath)
                    }
                }
                if manualReloads.count > 0 {
                    tableView.beginUpdates()
                    tableView.reloadRows(at: manualReloads, with: adapter.rowReloadAnimation)
                    tableView.endUpdates()
                }
            }
            
            if adapter.logging == .debug {
                print("Updating table view ended", separator: "\n", terminator: "\n\n")
            }
            
            UIView.setAnimationsEnabled(true)
            adapter.tableViewDidUpdateCells(adapter.animateViews)
            adapter.animateViews = true
        }
    }
    
    
    // MARK: - API -
    // MARK: Table View
    
    public func register<EC: PresentableTableViewCell & UITableViewCell>(_ modelTableViewCellType: EC.Type) {
        guard let tableView = tableView else { return }
        let reuseIdentifier = modelTableViewCellType.Model.typeIdentifier
        tableView.register(modelTableViewCellType, forCellReuseIdentifier: reuseIdentifier)
    }
    

    public func register<EC: PresentableHeaderFooterView & UITableViewHeaderFooterView>(_ modelViewHeaderFooterViewType: EC.Type) {
        let reuseIdentifier = modelViewHeaderFooterViewType.Model.typeIdentifier
        guard let tableView = tableView else { return }
        tableView.register(modelViewHeaderFooterViewType, forHeaderFooterViewReuseIdentifier: reuseIdentifier)
    }

    
    private func tableViewWillUpdateCells(_ animated: Bool) {
        tableViewController?.viewModelAdapterWillUpdateTableViewCells(self, animated: animated)
    }
    
    
    private func tableViewDidUpdateCells(_ animated: Bool) {
        tableViewController?.viewModelAdapterDidUpdateTableViewCells(self, animated: animated)
    }
    
    
    /**
     Dequeues a reusable cell from table view as long the model for this index path is of type `DeltaTableCellModel`.
     
     Use this method if you want to provide your own implementation of `tableView(tableView:cellForRowAtIndexPath:)` but
     you still want to be able to return cells provided by this class if needed.
     
     In most cases this function is only used internally and a custom implementation of `tableView(tableView:cellForRowAtIndexPath:)`
     is not needed.
     */
    open func tableViewCellForRowAtIndexPath(_ indexPath: IndexPath) -> UITableViewCell? {
        let model = viewModel.sections[indexPath.section].items[indexPath.row]
        
        getTableViewCell: do {
            guard let cell = tableView?.dequeueReusableCell(withIdentifier: type(of: model).typeIdentifier) else { break getTableViewCell }

            if let modelCell = cell as? AnyPresentableTableViewCell {
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
        return viewModel.sections.count
    }
    
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.sections[section].items.count
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
        guard viewModel.sections[section].headerModel != nil else {
            return 0
        }
        return UITableViewAutomaticDimension
    }

    
    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        configureView : do {
            let model = viewModel.sections[section]
            guard let headerModel = model.headerModel else { break configureView }
            guard let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: type(of: headerModel).typeIdentifier) else { break configureView }
            
            // Update View
            if let headerView = headerView as? AnyPresentableHeaderFooterView {
                let previousModel = headerView.anyCellModel
                headerView.anyCellModel = headerModel
                headerView.modelDidChange(previousModel: previousModel, animate: false, type: .header)
            }
            return headerView
        }
        
        return nil
    }
    
    
    public func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        guard viewModel.sections[section].footerModel != nil else {
            return 0
        }
        return UITableViewAutomaticDimension
    }

    
    public func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        configureView : do {
            let sectionModel = viewModel.sections[section]
            guard let footerModel = sectionModel.footerModel else { break configureView }
            guard let footerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: type(of: footerModel).typeIdentifier) else { break configureView }
            
            // Update View
            if let footerView = footerView as? AnyPresentableHeaderFooterView {
                let previousModel = footerView.anyCellModel
                footerView.anyCellModel = footerModel
                footerView.modelDidChange(previousModel: previousModel, animate: false, type: .footer)
            }
            return footerView
        }
        
        return nil
    }

    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cellModel = viewModel.sections[indexPath.section].items[indexPath.row]
        
        if let selectableCell = tableView.cellForRow(at: indexPath) as? SelectableCell, let tableViewController = tableViewController {
            selectableCell.performSelectionAction(sourceViewController: tableViewController)
        }
        
        if let selectableModel = cellModel as? SelectableCellModel {
            selectableModel.selectionHandler?()
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    
    // MARK: ViewModelDelegate
    
    public func viewModel(_ viewModel: ViewModel, cellModelsNeedUpdate animated: Bool) {
        updateTableView(options: .default, animated: animated)
    }
}


extension ViewModelTableViewAdapter {
    
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
