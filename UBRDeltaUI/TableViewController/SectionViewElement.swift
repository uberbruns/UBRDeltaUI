//
//  SectionViewElement.swift
//
//  Created by Karsten Bruns on 28/08/15.
//  Copyright © 2015 bruns.me. All rights reserved.
//

import Foundation



public struct SectionViewElement : SectionElement {
    
    public var uniqueIdentifier: Int { return id.hash }
    
    internal var subitems: [AnyElement] { return items.map { $0 as AnyElement } }
    public var items: [AnyViewElement] = []
    
    public var headerElement: AnyViewElement?
    public var footerElement: AnyViewElement?
    
    public let id: String
    
    public init(id: String) {
        self.id = id
    }
    
    
    public func isEqual(to other: AnyElement) -> Bool {
        guard let other = other as? SectionViewElement else { return false }
    
        let headerElementIsEqual = { () -> Bool in
            switch (headerElement, other.headerElement) {
            case (let element?, let otherElement?):
                return element.isEqual(to: otherElement)
            case (nil, nil):
                return true
            default:
                return false
            }
        }()

        let footerElementIsEqual = { () -> Bool in
            switch (footerElement, other.footerElement) {
            case (let element?, let otherElement?):
                return element.isEqual(to: otherElement)
            case (nil, nil):
                return true
            default:
                return false
            }
        }()
        
        return headerElementIsEqual && footerElementIsEqual
    }
}
