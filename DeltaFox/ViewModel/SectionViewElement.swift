//
//  CellSectionModel.swift
//
//  Created by Karsten Bruns on 28/08/15.
//  Copyright © 2015 bruns.me. All rights reserved.
//

import Foundation



public struct CellSectionModel : SectionModel {
    
    public let id: String
    public var uniqueIdentifier: Int { return id.hash }
    
    internal var subitems: [AnyDiffable] { return items.map { $0 as AnyDiffable } }
    public var items: [AnyCellModel] = []
    
    public var headerModel: AnyCellModel?
    public var footerModel: AnyCellModel?
    
    
    public init(id: String) {
        self.id = id
    }

    
    public func isEqual(to other: AnyDiffable) -> Bool {
        guard let other = other as? CellSectionModel else { return false }
    
        let headerElementIsEqual = { () -> Bool in
            switch (headerModel, other.headerModel) {
            case (let model?, let otherModel?):
                return model.isEqual(to: otherModel)
            case (nil, nil):
                return true
            default:
                return false
            }
        }()

        let footerElementIsEqual = { () -> Bool in
            switch (footerModel, other.footerModel) {
            case (let model?, let otherModel?):
                return model.isEqual(to: otherModel)
            case (nil, nil):
                return true
            default:
                return false
            }
        }()
        
        return headerElementIsEqual && footerElementIsEqual
    }
}


extension Array where Element == CellSectionModel {
    
    public mutating func append(id: String, _ setup: (String, inout CellSectionModel) -> Void) {
        var new = CellSectionModel(id: id)
        setup(id, &new)
        self.append(new)
    }
}
