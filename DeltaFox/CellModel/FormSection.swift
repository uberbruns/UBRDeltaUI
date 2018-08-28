//
//  FormSection.swift
//
//  Created by Karsten Bruns on 28/08/15.
//  Copyright © 2015 bruns.me. All rights reserved.
//

import Foundation



public struct FormSection: DiffableSection {
    
    public let id: String
    public var uniqueIdentifier: Int { return id.hash }
    
    internal var diffableSubitems: [AnyDiffable] { return items.map { $0 as AnyDiffable } }
    public var items: [AnyFormItem] = []
    
    public var headerItem: AnyFormItem?
    public var footerItem: AnyFormItem?
    
    
    public init(id: String) {
        self.id = id
    }

    
    public func isEqual(to other: AnyDiffable) -> Bool {
        guard let other = other as? FormSection else { return false }
    
        let headerItemIsEqual = { () -> Bool in
            switch (headerItem, other.headerItem) {
            case (let model?, let otherModel?):
                return model.isEqual(to: otherModel)
            case (nil, nil):
                return true
            default:
                return false
            }
        }()

        let footerItemIsEqual = { () -> Bool in
            switch (footerItem, other.footerItem) {
            case (let model?, let otherModel?):
                return model.isEqual(to: otherModel)
            case (nil, nil):
                return true
            default:
                return false
            }
        }()
        
        return headerItemIsEqual && footerItemIsEqual
    }
}


extension Array where Element == FormSection {
    
    public mutating func append(id: String, _ setup: (String, inout FormSection) -> Void) {
        var new = FormSection(id: id)
        setup(id, &new)
        self.append(new)
    }
}
