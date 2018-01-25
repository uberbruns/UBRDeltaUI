//
//  CellModelTableViewCell.swift
//  UBRDeltaUI
//
//  Created by Karsten Bruns on 06.01.18.
//  Copyright © 2018 bruns.me. All rights reserved.
//

import UIKit

public protocol AnyCellModelTableViewCell : class {
    var anyModel: AnyCellModel { get set }
    func modelDidChange(previousModel: AnyCellModel, animate: Bool)
}


public protocol CellModelTableViewCell : AnyCellModelTableViewCell {
    associatedtype Model: CellModel
    var model: Model { get set }
    func modelDidChange(previousModel: Model, animate: Bool)
}


extension CellModelTableViewCell {
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

    public func modelDidChange(previousModel: AnyCellModel, animate: Bool) {
        if let expectedOldModel = previousModel as? Model {
            modelDidChange(previousModel: expectedOldModel, animate: animate)
        }
    }

    
    public func setModel(_ model: Model, animated: Bool) {
        let previousModel = self.model
        self.model = model
        self.modelDidChange(previousModel: previousModel, animate: animated)
    }
}


public protocol AnyCellModelHeaderFooterView : class {
    var anyCellModel: AnyCellModel { get set }
    func modelDidChange(previousModel: AnyCellModel, animate: Bool, type: HeaderFooterType)
}


public protocol CellModelHeaderFooterView : AnyCellModelHeaderFooterView {
    associatedtype Model: CellModel
    var model: Model { get set }
    func modelDidChange(previousModel: Model, animate: Bool, type: HeaderFooterType)
}


extension CellModelHeaderFooterView {
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
    
    public func modelDidChange(previousModel: AnyCellModel, animate: Bool, type: HeaderFooterType) {
        if let expectedOldModel = previousModel as? Model {
            modelDidChange(previousModel: expectedOldModel, animate: animate, type: type)
        }
    }
}
