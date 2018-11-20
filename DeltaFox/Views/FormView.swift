//
//  FormView.swift
//  DeltaFox
//
//  Created by Karsten Bruns on 05.11.18.
//  Copyright © 2018 bruns.me. All rights reserved.
//

import UIKit


public protocol FormViewDelegate: AnyObject {
    func formViewDidUpdate(_ formView: FormView, animated: Bool)
    func formViewWillUpdate(_ formView: FormView, animated: Bool)
    func prepareFormView(_ formView: FormView)
}


open class FormView: UIView {

    // MARK: - Properties -

    let layout = CollectionViewFillLayout()
    open lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    public weak var delegate: FormViewDelegate?

    private var animateViews = true
    private var updateOptions = UpdateOptions.default

    private let sectionDiffer = SectionDiffer()
    public var logging = LoggingOptions.none

    public private(set) var sections = [FormSection]()
    private var cellTypes = [String: UICollectionViewCell.Type]()


    // MARK: - View -
    // MARK: Life-Cycle

    public init(delegate: FormViewDelegate) {
        self.delegate = delegate
        super.init(frame: .zero)

        delegate.prepareFormView(self)

        setupSectionDiffer()
        setupViews()
        setupConstraints()
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Setup

    func setupViews() {
        collectionView.contentInsetAdjustmentBehavior = .always
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.showsHorizontalScrollIndicator = false
        addSubview(collectionView)
    }

    func setupConstraints() {
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    // MARK: - Public API -

    public func setSections(_ newSections: [FormSection], options: UpdateOptions = .default, animated: Bool = true) {
        updateOptions = options

        if options == .dataOnly {
            animateViews = false
            sections = newSections

        } else if sections.isEmpty || options == .hardReload {
            animateViews = false
            collectionViewWillUpdateCells(false)
            sections = newSections
            collectionView.reloadData()
            collectionViewDidUpdateCells(false)

        } else {
            animateViews = animated
            let oldSections = sections.map({ $0 as DiffableSection })
            let newSections = newSections.map({ $0 as DiffableSection })
            sectionDiffer.queueComparison(oldSections: oldSections, newSections: newSections)
        }
    }

    public func register<FC: FormCellProtocol & UICollectionViewCell>(cellType: FC.Type) {
        let reuseIdentifier = cellType.FormItemType.typeIdentifier
        collectionView.register(cellType, forCellWithReuseIdentifier: cellType.FormItemType.typeIdentifier)
        cellTypes[reuseIdentifier] = cellType
    }

    public func register<FC: FormCellProtocol & UICollectionReusableView>(viewType: FC.Type) {
        collectionView.register(viewType, forSupplementaryViewOfKind: CollectionViewFillLayout.SupplementaryViewPosition.before.rawValue, withReuseIdentifier: viewType.FormItemType.typeIdentifier)
        collectionView.register(viewType, forSupplementaryViewOfKind: CollectionViewFillLayout.SupplementaryViewPosition.after.rawValue, withReuseIdentifier: viewType.FormItemType.typeIdentifier)
    }

    // MARK: Configuration

    /**
     `contentDiffer` is the heart of this class and determines what parts need to be updated.
     This functions links the `collectionView` and the `contentDiffer` by calling collection views update
     functions in the callback functions from the `contentDiffer`.
     */
    private func setupSectionDiffer() {

        sectionDiffer.throttleTimeInterval = 0.001
        sectionDiffer.debugOutput = logging != .none

        sectionDiffer.animationContext = { work, completion in
            work()
            completion()
        }

        // Start updating collection view
        sectionDiffer.start = { [weak self] in
            guard let this = self else { return }
            if this.logging == .debug {
                print("Start updating collection view", separator: "\n", terminator: "\n\n")
            }
            if this.animateViews == false {
                UIView.setAnimationsEnabled(false)
            }
            this.collectionViewWillUpdateCells(this.animateViews)
        }

        // Insert, reload and delete collection view items
        sectionDiffer.itemUpdate = { [weak self] (items, section, insertIndexes, reloadIndexMap, deleteIndexes) in
            guard let this = self else { return }

            this.sections[section].items = items.compactMap { $0 as? AnyFormItemProtocol }

            if insertIndexes.count == 0 && reloadIndexMap.count == 0 && deleteIndexes.count == 0 {
                return
            }

            if this.logging == .debug {
                print("Updating items in section \(section)", "items: \(items.map({ $0.uniqueIdentifier }))", "insertIndexes: \(insertIndexes)", "reloadIndexMap: \(reloadIndexMap)", "deleteIndexes: \(deleteIndexes)", separator: "\n", terminator: "\n\n")
            }

            var manualReloadMap = reloadIndexMap

            if this.updateOptions != .updateVisibleCells {
                for (itemIndexBefore, itemIndexAfter) in reloadIndexMap {
                    let indexPathBefore = IndexPath(item: itemIndexBefore, section: section)
                    guard let cell = this.collectionView.cellForItem(at: indexPathBefore) else {
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

            this.collectionView.performBatchUpdates({
                if manualReloadMap.count > 0 && this.updateOptions != .updateVisibleCells {
                    for (itemIndexBefore, _) in manualReloadMap {
                        let indexPathBefore = IndexPath(item: itemIndexBefore, section: section)
                        this.collectionView.reloadItems(at: [indexPathBefore])
                    }
                }

                if deleteIndexes.count > 0 {
                    this.collectionView.deleteItems(at: deleteIndexes.map({ IndexPath(item: $0, section: section) }))
                }

                if insertIndexes.count > 0 {
                    this.collectionView.insertItems(at: insertIndexes.map({ IndexPath(item: $0, section: section) }))
                }
            }, completion: nil)
        }

        // Reorder collection view items
        sectionDiffer.itemReorder = { [weak self] (items, section, reorderMap) in
            guard let this = self else { return }

            this.sections[section].items = items.compactMap { $0 as? AnyFormItemProtocol }

            if reorderMap.count == 0 {
                return
            }

            if this.logging == .debug {
                print("Reorder items in section \(section)", "items: \(items.map({ $0.uniqueIdentifier }))", "reorderMap: \(reorderMap)", separator: "\n", terminator: "\n\n")
            }

            this.collectionView.performBatchUpdates({
                for (from, to) in reorderMap {
                    let fromIndexPath = IndexPath(item: from, section: section)
                    let toIndexPath = IndexPath(item: to, section: section)
                    this.collectionView.moveItem(at: fromIndexPath, to: toIndexPath)
                }
            }, completion: nil)
        }

        // Insert, reload and delete collection view sections
        sectionDiffer.sectionUpdate = { [weak self] (sections, insertIndexes, reloadIndexMap, deleteIndexes) in
            guard let this = self else { return }

            this.sections = sections.compactMap({ $0 as? FormSection })

            if insertIndexes.count == 0 && reloadIndexMap.count == 0 && deleteIndexes.count == 0 {
                return
            }

            if this.logging == .debug {
                print("Updating sections", "sections: \(sections.map({ $0.uniqueIdentifier }))", "insertIndexes: \(insertIndexes)", "reloadIndexMap: \(reloadIndexMap)", "deleteIndexes: \(deleteIndexes)", separator: "\n", terminator: "\n\n")
            }

            this.collectionView.performBatchUpdates({
                let insertSet = NSMutableIndexSet()
                insertIndexes.forEach({ insertSet.add($0) })

                let deleteSet = NSMutableIndexSet()
                deleteIndexes.forEach({ deleteSet.add($0) })

                this.collectionView.insertSections(insertSet as IndexSet)
                this.collectionView.deleteSections(deleteSet as IndexSet)

                for (sectionIndexBefore, sectionIndexAfter) in reloadIndexMap {

                    if let sectionItem = sections[sectionIndexAfter] as? FormSection {

                        let headerView = this.collectionView.supplementaryView(forElementKind: CollectionViewFillLayout.SupplementaryViewPosition.before.rawValue,
                                                                               at: IndexPath(item: 0, section: sectionIndexBefore))

                        let footerView = this.collectionView.supplementaryView(forElementKind: CollectionViewFillLayout.SupplementaryViewPosition.after.rawValue,
                                                                               at: IndexPath(item: this.collectionView.numberOfItems(inSection: sectionIndexBefore)-1, section: sectionIndexBefore))

                        if let headerView = headerView as? AnyFormHeaderFooterView, let headerItem = sectionItem.headerItem {
                            let oldItem = headerView.anyFormItem
                            headerView.anyFormItem = headerItem
                            headerView.itemDidChange(oldItem: oldItem, animate: true, type: .header)
                        }

                        if let footerView = footerView as? AnyFormHeaderFooterView, let footerItem = sectionItem.footerItem {
                            let oldItem = footerView.anyFormItem
                            footerView.anyFormItem = footerItem
                            footerView.itemDidChange(oldItem: oldItem, animate: true, type: .footer)
                        }

                    } else {
                        this.collectionView.reloadSections(IndexSet(integer: sectionIndexBefore))
                    }
                }
            }, completion: nil)
        }

        // Reorder collection view sections
        sectionDiffer.sectionReorder = { [weak self] (sections, reorderMap) in
            guard let this = self else { return }

            this.sections = sections.compactMap({ $0 as? FormSection })

            if reorderMap.count == 0 {
                return
            }

            if this.logging == .debug {
                print("Reorder sections", "sections: \(sections.map({ $0.uniqueIdentifier }))", "reorderMap: \(reorderMap)", separator: "\n", terminator: "\n\n")
            }

            this.collectionView.performBatchUpdates({
                for (from, to) in reorderMap {
                    this.collectionView.moveSection(from, toSection: to)
                }
            }, completion: nil)
        }

        // Updating collection view did end
        sectionDiffer.completion = { [weak self] in
            guard let this = self else { return }

            if this.updateOptions == .updateVisibleCells {
                var manualReloads = [IndexPath]()
                for indexPath in this.collectionView.indexPathsForVisibleItems {
                    if let formCell = this.collectionView.cellForItem(at: indexPath) as? AnyFormCellProtocol {
                        let item: AnyFormItemProtocol = this.sections[indexPath.section].items[indexPath.item]
                        let oldItem = formCell.anyFormItem
                        formCell.anyFormItem = item
                        formCell.itemDidChange(oldItem: oldItem, animate: false)
                    } else {
                        manualReloads.append(indexPath)
                    }
                }
                if manualReloads.count > 0 {
                    this.collectionView.performBatchUpdates({
                        this.collectionView.reloadItems(at: manualReloads)
                    }, completion: nil)
                }
            }

            if this.logging == .debug {
                print("Updating collection view ended", separator: "\n", terminator: "\n\n")
            }

            UIView.setAnimationsEnabled(true)
            this.collectionViewDidUpdateCells(this.animateViews)
            this.animateViews = true
        }
    }

    // MARK: Delegate Callbacks

    private func collectionViewWillUpdateCells(_ animated: Bool) {
        delegate?.formViewWillUpdate(self, animated: animated)
    }


    private func collectionViewDidUpdateCells(_ animated: Bool) {
        delegate?.formViewDidUpdate(self, animated: animated)
    }
}


extension FormView: CollectionViewDataSourceFillLayout, CollectionViewDelegateFillLayout {

    open func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sections.count
    }


    open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sections[section].items.count
    }


    open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let item = sections[indexPath.section].items[indexPath.item]
        let itemType = type(of: item)
        let reuseIdentifier = itemType.typeIdentifier
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath)
        self.collectionView(collectionView, configureCell: cell, for: indexPath)
        return cell
    }


    open func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        fatalError()
    }


    open func collectionView(_ collectionView: UICollectionView, cellTypeAt indexPath: IndexPath) -> UICollectionViewCell.Type {
        let item = sections[indexPath.section].items[indexPath.item]
        let itemType = type(of: item)
        let reuseIdentifier = itemType.typeIdentifier
        return cellTypes[reuseIdentifier]!
    }


    open func collectionView(_ collectionView: UICollectionView, configureCell cell: UICollectionViewCell, for indexPath: IndexPath) {
        let item = sections[indexPath.section].items[indexPath.item]
        if let formCell = cell as? AnyFormCellProtocol & UICollectionViewCell {
            let oldItem = formCell.anyFormItem
            formCell.anyFormItem = item
            formCell.itemDidChange(oldItem: oldItem, animate: false)
            formCell.tintColor = tintColor
        }
    }


    open func collectionView(_ collectionView: UICollectionView, supplementaryViewTypeAt indexPath: IndexPath, position: CollectionViewFillLayout.SupplementaryViewPosition) -> UICollectionReusableView.Type? {
        return nil
    }


    open func collectionView(_ collectionView: UICollectionView, configureSupplementaryView view: UICollectionReusableView, for indexPath: IndexPath, position: CollectionViewFillLayout.SupplementaryViewPosition) {
        fatalError()
    }


    // MARK: CollectionViewDelegateFillLayout

    open func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print(#function)
    }


    open func collectionView(_ collectionView: UICollectionView, alignmentForCellAt indexPath: IndexPath) -> CollectionViewFillLayout.Alignment {
        return .default
    }


    open func collectionView(_ collectionView: UICollectionView, minimumHeightForCellAt indexPath: IndexPath) -> CGFloat {
        return 44
    }


    public func collectionView(_ collectionView: UICollectionView, sizeInvalidationHashValueForCellAt indexPath: IndexPath) -> Int {
        let item = sections[indexPath.section].items[indexPath.item]
        return item.hashValue
    }

    open func collectionView(_ collectionView: UICollectionView, alignmentForSupplementaryViewAt indexPath: IndexPath) -> CollectionViewFillLayout.Alignment {
        return .default
    }


    open func collectionView(_ collectionView: UICollectionView, minimumHeightForSupplementaryViewAt indexPath: IndexPath) -> CGFloat {
        return 0
    }

    public func collectionView(_ collectionView: UICollectionView, sizeInvalidationHashValueForSupplementaryViewAt indexPath: IndexPath) -> Int {
        let item = sections[indexPath.section].items[indexPath.item]
        return item.hashValue
    }
}



extension FormView {

    /// Options to finetune the update process
    public enum UpdateOptions {
        /// Default incremental update
        case `default`

        /// Non incremental update, like calling collectionView.reloadData
        case hardReload

        /// Like default, but all visible cells will be updated
        case updateVisibleCells

        /// Use this if you know the collection view is in a valid, but the data is in an invalid state
        case dataOnly
    }

    /// Options to fine tune the debug output. Please note, that the options .Debug and .Warnings have an impact on performance
    public enum LoggingOptions {
        case none
        case debug
        case warnings
    }
}
