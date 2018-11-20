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
    
    internal var diffableSubitems: [Diffable] { return items.map { $0 as Diffable } }
    public var items: [AnyFormItemProtocol] = []
    
    public var headerItem: AnyFormItemProtocol?
    public var footerItem: AnyFormItemProtocol?
    
    
    public init(id: FormItemIdentifier) {
        self.id = id
    }

    public var hashValue: Int {
        var hasher = Hasher()
        hasher.combine(headerItem?.hashValue ?? Int.max)
        hasher.combine(footerItem?.hashValue ?? Int.min)
        return hasher.finalize()
    }
}


extension Array where Element == FormSection {
    
    public mutating func append(id: FormItemIdentifier, _ setup: (FormItemIdentifier, inout FormSection) -> Void) {
        var new = FormSection(id: id)
        setup(id, &new)
        self.append(new)
    }
}
