//
//  FormCell.swift
//  DeltaFox
//
//  Created by Karsten Bruns on 06.01.18.
//  Copyright © 2018 bruns.me. All rights reserved.
//

import UIKit

public protocol AnyFormCellProtocol: AnyObject {
    var anyFormItem: AnyFormItemProtocol { get set }
    func itemDidChange(oldItem: AnyFormItemProtocol, animate: Bool)
}


public protocol FormCellProtocol: AnyFormCellProtocol {
    associatedtype FormItemType: FormItemProtocol
    var item: FormItemType { get set }
    func itemDidChange(oldItem: FormItemType, animate: Bool)
}


extension FormCellProtocol {
    public var anyFormItem: AnyFormItemProtocol {
        get {
            return item
        }
        set {
            if let item = newValue as? FormItemType {
                self.item = item
            }
        }
    }

    public func itemDidChange(oldItem: AnyFormItemProtocol, animate: Bool) {
        if let expectedOldItem = oldItem as? FormItemType {
            itemDidChange(oldItem: expectedOldItem, animate: animate)
        }
    }

    public func setItem(_ item: FormItemType, animated: Bool) {
        let oldItem = self.item
        self.item = item
        self.itemDidChange(oldItem: oldItem, animate: animated)
    }
}


public protocol AnyFormHeaderFooterView: AnyObject {
    var anyFormItem: AnyFormItemProtocol { get set }
    func itemDidChange(oldItem: AnyFormItemProtocol, animate: Bool, type: HeaderFooterType)
}


public protocol FormHeaderFooterView: AnyFormHeaderFooterView {
    associatedtype FormItemType: FormItemProtocol
    var item: FormItemType { get set }
    func itemDidChange(oldItem: FormItemType, animate: Bool, type: HeaderFooterType)
}


extension FormHeaderFooterView {
    public var anyFormItem: AnyFormItemProtocol {
        get {
            return item
        }
        set {
            if let item = newValue as? FormItemType {
                self.item = item
            }
        }
    }
    
    public func itemDidChange(oldItem: AnyFormItemProtocol, animate: Bool, type: HeaderFooterType) {
        if let expectedOldItem = oldItem as? FormItemType {
            itemDidChange(oldItem: expectedOldItem, animate: animate, type: type)
        }
    }
}
