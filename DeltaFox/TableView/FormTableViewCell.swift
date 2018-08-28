//
//  FormTableViewCell.swift
//  DeltaFox
//
//  Created by Karsten Bruns on 06.01.18.
//  Copyright © 2018 bruns.me. All rights reserved.
//

import UIKit

public protocol AnyFormTableViewCell: AnyObject {
    var anyFormItem: AnyFormItem { get set }
    func itemDidChange(oldItem: AnyFormItem, animate: Bool)
}


public protocol FormTableViewCell: AnyFormTableViewCell {
    associatedtype FormItemType: FormItem
    var item: FormItemType { get set }
    func itemDidChange(oldItem: FormItemType, animate: Bool)
}


extension FormTableViewCell {
    public var anyFormItem: AnyFormItem {
        get {
            return item
        }
        set {
            if let item = newValue as? FormItemType {
                self.item = item
            }
        }
    }

    public func itemDidChange(oldItem: AnyFormItem, animate: Bool) {
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
    var anyFormItem: AnyFormItem { get set }
    func itemDidChange(oldItem: AnyFormItem, animate: Bool, type: HeaderFooterType)
}


public protocol FormHeaderFooterView: AnyFormHeaderFooterView {
    associatedtype FormItemType: FormItem
    var item: FormItemType { get set }
    func itemDidChange(oldItem: FormItemType, animate: Bool, type: HeaderFooterType)
}


extension FormHeaderFooterView {
    public var anyFormItem: AnyFormItem {
        get {
            return item
        }
        set {
            if let item = newValue as? FormItemType {
                self.item = item
            }
        }
    }
    
    public func itemDidChange(oldItem: AnyFormItem, animate: Bool, type: HeaderFooterType) {
        if let expectedOldItem = oldItem as? FormItemType {
            itemDidChange(oldItem: expectedOldItem, animate: animate, type: type)
        }
    }
}
