//
//  File.swift
//  UBRDeltaUI
//
//  Created by Karsten Bruns on 06.01.18.
//  Copyright © 2018 bruns.me. All rights reserved.
//

import Foundation


open class Presenter {
    
    public internal(set) var sections: [CellSectionModel] = []

    
    public init() { }
    
    
    open func generateCellModels(sections: inout [CellSectionModel]) {
        
    }
    
    
    // MARK: Content
    
    /// Returns the `CellSectionModel` that belongs to the provided section index.
    public func cellSectionModel(at sectionIndex: Int) -> CellSectionModel {
        return sections[sectionIndex]
    }
    
    
    /// Returns the `CellModel` that belongs to the provided index path.
    public func cellModel(at indexPath: IndexPath) -> AnyCellModel {
        return sections[indexPath.section].items[indexPath.row]
    }
}
