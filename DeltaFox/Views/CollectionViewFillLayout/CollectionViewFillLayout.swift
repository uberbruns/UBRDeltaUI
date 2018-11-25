//
//  CollectionViewFillLayout.swift
//  StickyLayout
//
//  Created by Karsten Bruns on 29.10.18.
//  Copyright © 2018 bruns.me. All rights reserved.
//

import UIKit

private enum Config {
    static let defaultLevel = 020_000
    static let defaultLevelWhenAppearing = 010_000
    static let defaultLevelWhenDisappearing = 000_000
    static let pinnedToBottomLevel = 100_000
    static let pinnedToBottomLevelWhenAppearing = 090_000
    static let pinnedToBottomLevelWhenDisappearing = 080_000
}


public protocol CollectionViewDataSourceFillLayout: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, cellTypeAt indexPath: IndexPath) -> UICollectionViewCell.Type
    func collectionView(_ collectionView: UICollectionView, configureCell cell: UICollectionViewCell, for indexPath: IndexPath)

    func collectionView(_ collectionView: UICollectionView, supplementaryViewTypeAt indexPath: IndexPath, position: CollectionViewFillLayout.SupplementaryViewPosition) -> UICollectionReusableView.Type?
    func collectionView(_ collectionView: UICollectionView, configureSupplementaryView view: UICollectionReusableView, for indexPath: IndexPath, position: CollectionViewFillLayout.SupplementaryViewPosition)
}


public protocol CollectionViewDelegateFillLayout: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, alignmentForCellAt indexPath: IndexPath) -> CollectionViewFillLayout.Alignment
    func collectionView(_ collectionView: UICollectionView, minimumHeightForCellAt indexPath: IndexPath) -> CGFloat
    func collectionView(_ collectionView: UICollectionView, sizeInvalidationHashValueForCellAt indexPath: IndexPath) -> Int

    func collectionView(_ collectionView: UICollectionView, alignmentForSupplementaryViewAt indexPath: IndexPath, position: CollectionViewFillLayout.SupplementaryViewPosition) -> CollectionViewFillLayout.Alignment
    func collectionView(_ collectionView: UICollectionView, minimumHeightForSupplementaryViewAt indexPath: IndexPath, position: CollectionViewFillLayout.SupplementaryViewPosition) -> CGFloat
    func collectionView(_ collectionView: UICollectionView, sizeInvalidationHashValueForSupplementaryViewAt indexPath: IndexPath, position: CollectionViewFillLayout.SupplementaryViewPosition) -> Int
}


public class CollectionViewFillLayout: UICollectionViewLayout {

    // MARK: - Properties -

    // State
    private var collectionViewElementsAreUpdating = false
    private var performFullInvalidation = true
    private var performFrameAnimations = false

    // Cache
    private var cachedContentSize = CGSize.zero
    private var cachedItemSizes = SizeCache()
    private var cachedLayoutAttributes = [TaggedIndexPath: UICollectionViewLayoutAttributes]()

    // Configuration
    var automaticallyAdjustScrollIndicatorInsets = true
    var contentInsetObservationToken: AnyObject?

    // MARK: - Custom API -

    public func collectionViewUpdatesWillBegin() {
        collectionViewElementsAreUpdating = true
    }

    public func collectionViewUpdatesDidEnd() {
        collectionViewElementsAreUpdating = false
    }

    // MARK: - Layout Life Cycle -
    // MARK: Preperation

    override public func prepare() {
        guard let collectionView = collectionView,
            let delegate = collectionView.delegate as? CollectionViewDelegateFillLayout & CollectionViewDataSourceFillLayout else { return }

        // Observe collection view content inset
        if contentInsetObservationToken == nil {
            contentInsetObservationToken = collectionView.observe(\.contentInset, options: [.new, .old, .prior]) { (collectionView, change) in
                guard change.isPrior, change.oldValue != change.newValue else { return }
                if !self.collectionViewElementsAreUpdating {
                    self.performFrameAnimations = true
                }
                self.invalidateLayout()
            }
        }

        // Cache invalidation
        cachedLayoutAttributes.removeAll(keepingCapacity: true)

        // Build an array of index paths
        var layoutItems = [CollectionViewFillLayout.Item<TaggedIndexPath>]()
        for section in 0..<collectionView.numberOfSections {
            for item in 0..<collectionView.numberOfItems(inSection: section) {
                for tag in [TaggedIndexPath.Tag.before, .item, .after] {
                    // Known Variables
                    let collectionViewWidth = collectionView.bounds.width
                    let indexPath = TaggedIndexPath(item: item, section: section, tag: tag)

                    // To be determined
                    let cellSize: CGSize
                    let contentHashValue: Int
                    let alignment: CollectionViewFillLayout.Alignment

                    // To be determined (if needed)
                    var cachedCellSize: CGSize?
                    var contentView: UIView?
                    var minimumHeight: CGFloat?

                    switch tag {
                    case .before, .after:
                        guard let viewType = delegate.collectionView(collectionView, supplementaryViewTypeAt: indexPath.native, position: .init(tag: tag)) else {
                            continue
                        }

                        alignment = delegate.collectionView(collectionView, alignmentForSupplementaryViewAt: indexPath.native, position: .init(tag: tag))
                        contentHashValue = delegate.collectionView(collectionView,
                                                                   sizeInvalidationHashValueForSupplementaryViewAt: indexPath.native,
                                                                   position: .init(tag: tag))

                        cachedCellSize = cachedItemSizes[collectionViewWidth, tag, contentHashValue]
                        if cachedCellSize == nil {
                            let supplementaryView = viewType.init(frame: .zero)
                            minimumHeight = delegate.collectionView(collectionView, minimumHeightForSupplementaryViewAt: indexPath.native, position: .init(tag: tag))
                            delegate.collectionView(collectionView, configureSupplementaryView: supplementaryView, for: indexPath.native, position: .init(tag: tag))
                            contentView = supplementaryView
                        }

                    case .item:
                        let cellType = delegate.collectionView(collectionView, cellTypeAt: indexPath.native)
                        let cell = cellType.init(frame: .zero)

                        alignment = delegate.collectionView(collectionView, alignmentForCellAt: indexPath.native)
                        contentHashValue = delegate.collectionView(collectionView, sizeInvalidationHashValueForCellAt: indexPath.native)

                        cachedCellSize = cachedItemSizes[collectionViewWidth, tag, contentHashValue]
                        if cachedCellSize == nil {
                            minimumHeight = delegate.collectionView(collectionView, minimumHeightForCellAt: indexPath.native)
                            delegate.collectionView(collectionView, configureCell: cell, for: indexPath.native)
                            contentView = cell.contentView
                        }
                    }

                    if let cachedCellSize = cachedCellSize {
                        cellSize = cachedCellSize
                    } else if let minimumHeight = minimumHeight, let contentView = contentView {
                        NSLayoutConstraint.activate([
                            { $0.priority = .defaultLow; return $0 }(contentView.heightAnchor.constraint(equalToConstant: minimumHeight)),
                            { $0.priority = .defaultHigh; return $0 }(contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: minimumHeight)),
                        ])
                        let maximumCellSize = CGSize(width: collectionViewWidth, height: UILayoutFittingCompressedSize.height)
                        cellSize = contentView.systemLayoutSizeFitting(maximumCellSize,
                                                                       withHorizontalFittingPriority: .required,
                                                                       verticalFittingPriority: UILayoutPriority(1))
                        cachedItemSizes[collectionViewWidth, tag, contentHashValue] = cellSize
                    } else {
                        fatalError()
                    }

                    let layoutItem = CollectionViewFillLayout.Item(with: indexPath, height: cellSize.height, alignment: alignment)
                    layoutItems.append(layoutItem)
                }
            }
        }

        // Solve layout
        let bounds = CGRect(x: 0, y: 0, width: collectionView.bounds.width, height: collectionView.bounds.height)
        let result = CollectionViewFillLayout.solve(with: layoutItems,
                                                    inside: bounds,
                                                    offset: collectionView.contentOffset.y,
                                                    clipOffset: performFullInvalidation,
                                                    contentInsets: collectionView.adjustedContentInset)

        // Cache
        cachedContentSize = result.contentSize

        for (index, positioning) in result.positionings.enumerated() {
            let indexPath = positioning.object
            let itemAttributes = UICollectionViewLayoutAttributes(taggedIndexPath: indexPath)
            itemAttributes.frame = positioning.frame
            itemAttributes.zIndex = positioning.alignment == .pinnedToBottom
                ? index + Config.pinnedToBottomLevel
                : index + Config.defaultLevel
            cachedLayoutAttributes[indexPath] = itemAttributes
        }

        // Reset state
        performFullInvalidation = false

        // Configure collection view
        collectionView.isPrefetchingEnabled = false // Removing this or setting it to true -> Dragons (Invisible and/or unresponsive cells when bounds are changing)
        if automaticallyAdjustScrollIndicatorInsets {
            collectionView.scrollIndicatorInsets.bottom = result.pinnedToBottomHeight
        }
    }

    // MARK: Invalidation

    override public func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        performFrameAnimations = newBounds.size != collectionView?.bounds.size
        print(#function,  newBounds.size != collectionView?.bounds.size)
        return true
    }

    override public func invalidateLayout(with context: UICollectionViewLayoutInvalidationContext) {
        super.invalidateLayout(with: context)
        if context.invalidateEverything {
            performFullInvalidation = true
        }
    }

    public override func finalizeAnimatedBoundsChange() {
        super.finalizeAnimatedBoundsChange()
        performFrameAnimations = false
    }

    // MARK: - Metrics -

    override public var collectionViewContentSize: CGSize {
        return cachedContentSize
    }

    // MARK: - Layout Attributes -
    // MARK: Getter

    override public func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return cachedLayoutAttributes.values.filter {
            $0.frame.intersects(rect)
        }
    }

    public override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let taggedIndexPath = TaggedIndexPath(item: indexPath.item, section: indexPath.section, tag: .item)
        return cachedLayoutAttributes[taggedIndexPath]!
    }

    public override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let taggedIndexPath = TaggedIndexPath(item: indexPath.item, section: indexPath.section, tag: TaggedIndexPath.Tag(rawValue: elementKind)!)
        return cachedLayoutAttributes[taggedIndexPath]!
    }

    // MARK: Appearance Animation

    override public func initialLayoutAttributesForAppearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        print(#function, performFrameAnimations)
        guard performFrameAnimations else {
            return super.initialLayoutAttributesForAppearingItem(at: itemIndexPath)
        }
        return cachedLayoutAttributes[itemIndexPath.tagged(with: .item)]
    }

    override public func finalLayoutAttributesForDisappearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard performFrameAnimations else {
            return super.finalLayoutAttributesForDisappearingItem(at: itemIndexPath)
        }
        return cachedLayoutAttributes[itemIndexPath.tagged(with: .item)]
    }

    override public func initialLayoutAttributesForAppearingSupplementaryElement(ofKind elementKind: String, at elementIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard performFrameAnimations else {
            return super.initialLayoutAttributesForAppearingSupplementaryElement(ofKind: elementKind, at: elementIndexPath)
        }
        return cachedLayoutAttributes[elementIndexPath.tagged(with: CollectionViewFillLayout.TaggedIndexPath.Tag(rawValue: elementKind)!)]
    }

    override public func finalLayoutAttributesForDisappearingSupplementaryElement(ofKind elementKind: String, at elementIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard performFrameAnimations else {
            return super.finalLayoutAttributesForDisappearingSupplementaryElement(ofKind: elementKind, at: elementIndexPath)
        }
        return cachedLayoutAttributes[elementIndexPath.tagged(with: CollectionViewFillLayout.TaggedIndexPath.Tag(rawValue: elementKind)!)]
    }
}


public extension CollectionViewFillLayout {
    fileprivate struct TaggedIndexPath: Hashable {
        enum Tag: String, Hashable, CaseIterable {
            case before
            case item
            case after
        }

        let item: Int
        let section: Int
        let tag: Tag
        let native: IndexPath

        init(item: Int, section: Int, tag: Tag) {
            self.item = item
            self.section = section
            self.tag = tag
            self.native = IndexPath(item: item, section: section)
        }

        init(layoutAttributes: UICollectionViewLayoutAttributes) {
            let tag: Tag
            switch (layoutAttributes.representedElementCategory, layoutAttributes.representedElementKind) {
            case (.cell, _):
                tag = .item
            case let (.supplementaryView, kind?):
                tag = Tag(rawValue: kind)!
            default:
                fatalError()
            }
            self.init(item: layoutAttributes.indexPath.item, section: layoutAttributes.indexPath.section, tag: tag)
        }
    }

    public enum SupplementaryViewPosition: String {
        case before
        case after

        fileprivate init(tag: TaggedIndexPath.Tag) {
            switch tag {
            case .after:
                self = .after
            default:
                self = .before
            }
        }
    }
}


private extension UICollectionViewLayoutAttributes {
    convenience init(taggedIndexPath: CollectionViewFillLayout.TaggedIndexPath) {
        switch taggedIndexPath.tag {
        case .before, .after:
            self.init(forSupplementaryViewOfKind: CollectionViewFillLayout.SupplementaryViewPosition(tag: taggedIndexPath.tag).rawValue, with: taggedIndexPath.native)
        case .item:
            self.init(forCellWith: taggedIndexPath.native)
        }
    }
}


private extension IndexPath {
    func tagged(with tag: CollectionViewFillLayout.TaggedIndexPath.Tag) -> CollectionViewFillLayout.TaggedIndexPath {
        return CollectionViewFillLayout.TaggedIndexPath.init(item: item, section: section, tag: tag)
    }
}


private class SizeCache {

    struct Key: Hashable {
        let width: CGFloat
        let tag: CollectionViewFillLayout.TaggedIndexPath.Tag
        let contentHashValue: Int
    }

    private var cache = [Key: CGSize]()

    subscript(width: CGFloat, tag: CollectionViewFillLayout.TaggedIndexPath.Tag, hashValue: Int) -> CGSize? {
        get {
            let key = Key(width: width, tag: tag, contentHashValue: hashValue)
            return cache[key]
        }
        set {
            let key = Key(width: width, tag: tag, contentHashValue: hashValue)
            cache[key] = newValue
        }
    }
}
