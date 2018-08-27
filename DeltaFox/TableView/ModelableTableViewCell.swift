//
//  ModelableTableViewCell.swift
//  DeltaFox
//
//  Created by Karsten Bruns on 06.01.18.
//  Copyright © 2018 bruns.me. All rights reserved.
//

import UIKit

public protocol AnyModelableTableViewCell: AnyObject {
    var anyModel: AnyCellModel { get set }
    func modelDidChange(previousModel: AnyCellModel, animate: Bool)
}


public protocol ModelableTableViewCell: AnyModelableTableViewCell {
    associatedtype ModelType: CellModel
    var model: ModelType { get set }
    func modelDidChange(previousModel: ModelType, animate: Bool)
}


extension ModelableTableViewCell {
    public var anyModel: AnyCellModel {
        get {
            return model
        }
        set {
            if let model = newValue as? ModelType {
                self.model = model
            }
        }
    }

    public func modelDidChange(previousModel: AnyCellModel, animate: Bool) {
        if let expectedOldModel = previousModel as? ModelType {
            modelDidChange(previousModel: expectedOldModel, animate: animate)
        }
    }

    
    public func setModel(_ model: ModelType, animated: Bool) {
        let previousModel = self.model
        self.model = model
        self.modelDidChange(previousModel: previousModel, animate: animated)
    }
}


public protocol AnyModelableHeaderFooterView: AnyObject {
    var anyCellModel: AnyCellModel { get set }
    func modelDidChange(previousModel: AnyCellModel, animate: Bool, type: HeaderFooterType)
}


public protocol ModelableHeaderFooterView: AnyModelableHeaderFooterView {
    associatedtype ModelType: CellModel
    var model: ModelType { get set }
    func modelDidChange(previousModel: ModelType, animate: Bool, type: HeaderFooterType)
}


extension ModelableHeaderFooterView {
    public var anyCellModel: AnyCellModel {
        get {
            return model
        }
        set {
            if let model = newValue as? ModelType {
                self.model = model
            }
        }
    }
    
    public func modelDidChange(previousModel: AnyCellModel, animate: Bool, type: HeaderFooterType) {
        if let expectedOldModel = previousModel as? ModelType {
            modelDidChange(previousModel: expectedOldModel, animate: animate, type: type)
        }
    }
}
