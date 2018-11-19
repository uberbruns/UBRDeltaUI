//
//  FormSection.swift
//
//  Created by Karsten Bruns on 28/08/15.
//  Copyright © 2015 bruns.me. All rights reserved.
//

import Foundation



public struct FormSection: DiffableSection {
    
    public let id: FormItemIdentifier
    public var uniqueIdentifier: Int { return id.hashValue }
    
    internal var diffableSubitems: [AnyDiffable] { return items.map { $0 as AnyDiffable } }
    public var items: [AnyFormItemProtocol] = []
    
    public var headerItem: AnyFormItemProtocol?
    public var footerItem: AnyFormItemProtocol?
    
    
    public init(id: FormItemIdentifier) {
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
    
    public mutating func append(id: FormItemIdentifier, _ setup: (FormItemIdentifier, inout FormSection) -> Void) {
        var new = FormSection(id: id)
        setup(id, &new)
        self.append(new)
    }
}
