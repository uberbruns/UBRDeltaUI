//
//  File.swift
//  UBRDeltaUI
//
//  Created by Karsten Bruns on 06.01.18.
//  Copyright © 2018 bruns.me. All rights reserved.
//

import Foundation

public protocol ViewModelDelegate: class {
    func viewModel(_ viewModel: ViewModel, cellModelsNeedUpdate animated: Bool)
}


open class ViewModel {
    
    public internal(set) var sections: [CellSectionModel] = []
    public weak var delegate: ViewModelDelegate?

    
    public init() { }
    
    
    open func generateCellModel(sections: inout [CellSectionModel]) {
        
    }
    
    
    public func cellModelNeedUpdate(animated: Bool) {
        delegate?.viewModel(self, cellModelsNeedUpdate: animated)
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
