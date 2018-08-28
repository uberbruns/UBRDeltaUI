//
//  UITableViewCell+Protocols.swift
//  CompareApp
//
//  Created by Karsten Bruns on 29/08/15.
//  Copyright © 2015 bruns.me. All rights reserved.
//

import UIKit



public typealias SelectionHandler = () -> ()


public protocol AnyFormItem : AnyDiffable {
    var id: String { get }
    static var typeIdentifier: String { get }
}


public protocol FormItem: AnyFormItem, Diffable {
    static var placeholder: Self { get }
}


extension FormItem {
    public var uniqueIdentifier: Int {
        return id.hashValue
    }
}


public enum HeaderFooterType {
    case header, footer
}


public protocol SelectableCell {
    func performSelectionAction()
}


public protocol SelectableFormItem {
    var selectionHandler: SelectionHandler? { get }
}
