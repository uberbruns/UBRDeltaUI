//
//  DeltaTableViewSectionItem.swift
//
//  Created by Karsten Bruns on 28/08/15.
//  Copyright © 2015 bruns.me. All rights reserved.
//

import Foundation



public struct DeltaTableViewSectionItem : ComparableSectionItem {
    
    public var uniqueIdentifier: Int { return id.hash }
    
    internal var subitems: [ComparableItem] { return items.map { $0 as ComparableItem } }
    public var items: [DeltaTableViewItem] = []
    
    public var headerItem: DeltaTableViewHeaderFooterItem?
    public var footerItem: DeltaTableViewHeaderFooterItem?
    
    public let id: String
    
    public init(id: String) {
        self.id = id
    }
    
    
    public func compareTo(other: ComparableItem) -> ComparisonLevel {
        guard let other = other as? DeltaTableViewSectionItem else { return .Different }
        guard other.id == self.id else { return .Different }
        
        var headerItemChanged = (headerItem == nil) != (other.headerItem == nil)
        if let headerItem = headerItem, otherheaderItem = other.headerItem {
            headerItemChanged = headerItem.compareTo(otherheaderItem) != .Same
        }

        var footerItemChanged = (footerItem == nil) != (other.footerItem == nil)
        if let footerItem = footerItem, otherFooterItem = other.footerItem {
            footerItemChanged = footerItem.compareTo(otherFooterItem) != .Same
        }
        
        if  headerItemChanged || footerItemChanged {
            return .Changed(["headerItem": headerItemChanged, "footerItem": footerItemChanged])
        } else {
            return .Same
        }
    }
}