//
//  DeltaTableViewCell.swift
//  UBRDeltaUI
//
//  Created by Karsten Bruns on 06.01.18.
//  Copyright © 2018 bruns.me. All rights reserved.
//

import UIKit

public protocol AnyDeltaTableViewCell : class {
    var anyModel: AnyCellModel { get set }
    func modelDidChange(oldModel: AnyCellModel, animate: Bool)
}


public protocol DeltaTableViewCell : AnyDeltaTableViewCell {
    associatedtype Model: CellModel
    var model: Model { get set }
    func modelDidChange(oldModel: Model, animate: Bool)
}


extension DeltaTableViewCell {
    public var anyModel: AnyCellModel {
        get {
            return model
        }
        set {
            if let model = newValue as? Model {
                self.model = model
            }
        }
    }

    public func modelDidChange(oldModel: AnyCellModel, animate: Bool) {
        if let expectedOldModel = oldModel as? Model {
            modelDidChange(oldModel: expectedOldModel, animate: animate)
        }
    }

    
    public func setModel(_ model: Model, animated: Bool) {
        let oldModel = self.model
        self.model = model
        self.modelDidChange(oldModel: oldModel, animate: animated)
    }
}


public protocol AnyDiffableHeaderFooterView : class {
    var anyCellModel: AnyCellModel { get set }
    func modelDidChange(oldModel: AnyCellModel, animate: Bool, type: HeaderFooterType)
}


public protocol ElementHeaderFooterView : AnyDiffableHeaderFooterView {
    associatedtype Model: CellModel
    var model: Model { get set }
    func modelDidChange(oldModel: Model, animate: Bool, type: HeaderFooterType)
}


extension ElementHeaderFooterView {
    public var anyCellModel: AnyCellModel {
        get {
            return model
        }
        set {
            if let model = newValue as? Model {
                self.model = model
            }
        }
    }
    
    public func modelDidChange(oldModel: AnyCellModel, animate: Bool, type: HeaderFooterType) {
        if let expectedOldModel = oldModel as? Model {
            modelDidChange(oldModel: expectedOldModel, animate: animate, type: type)
        }
    }
}
