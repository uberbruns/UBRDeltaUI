//
//  DeltaTableViewSectionElement.swift
//
//  Created by Karsten Bruns on 28/08/15.
//  Copyright © 2015 bruns.me. All rights reserved.
//

import Foundation



public struct DeltaTableViewSectionElement : ComparableSectionElement {
    
    public var uniqueIdentifier: Int { return id.hash }
    
    internal var subitems: [ComparableElement] { return items.map { $0 as ComparableElement } }
    public var items: [DeltaTableViewElement] = []
    
    public var headerElement: DeltaTableViewHeaderFooterElement?
    public var footerElement: DeltaTableViewHeaderFooterElement?
    
    public let id: String
    
    public init(id: String) {
        self.id = id
    }
    
    
    public func compareTo(_ other: ComparableElement) -> DeltaComparisonLevel {
        guard let other = other as? DeltaTableViewSectionElement else { return .different }
        guard other.id == self.id else { return .different }
        
        var headerElementChanged = (headerElement == nil) != (other.headerElement == nil)
        if let headerElement = headerElement, let otherheaderElement = other.headerElement {
            headerElementChanged = headerElement.compareTo(otherheaderElement) != .same
        }

        var footerElementChanged = (footerElement == nil) != (other.footerElement == nil)
        if let footerElement = footerElement, let otherFooterElement = other.footerElement {
            footerElementChanged = footerElement.compareTo(otherFooterElement) != .same
        }
        
        if  headerElementChanged || footerElementChanged {
            return .changed(["headerElement": headerElementChanged, "footerElement": footerElementChanged])
        } else {
            return .same
        }
    }
}
