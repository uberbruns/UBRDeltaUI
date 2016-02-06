//
//  UITableViewCell+Protocols.swift
//  CompareApp
//
//  Created by Karsten Bruns on 29/08/15.
//  Copyright © 2015 bruns.me. All rights reserved.
//

import UIKit



public typealias SelectionHandler = () -> ()


public protocol DeltaTableViewItem : ComparableItem {
    var id: String { get }
    var reuseIdentifier: String { get }
}


public protocol DeltaTableViewHeaderFooterItem : ComparableItem {
    var id: String { get }
    var reuseIdentifier: String { get }
}


public protocol UpdateableTableViewCell : class {
    func updateCellWithItem(item: ComparableItem, animated: Bool)
}


public protocol UpdateableTableViewHeaderFooterView : class {
    func updateViewWithItem(item: ComparableItem, animated: Bool, type: HeaderFooterType)
}


public enum HeaderFooterType {
    case Header, Footer
}


public protocol SelectableTableViewItem {
    var selectionHandler: SelectionHandler? { get }
}


/// A helper function to avoid reference cycles in action handler
public func weakActionHandler<Target: AnyObject, Result>(target: Target, handler: (Target) -> ((Result) -> Void)) -> ((Result) -> Void) {
    return { [weak target] result in
        guard let t = target else { return }
        handler(t)(result)
    }
}


/// A helper function to avoid reference cycles in action handler
public func weakActionHandler<Target: AnyObject>(target: Target, handler: (Target) -> (() -> Void)) -> (() -> Void) {
    return { [weak target] in
        guard let t = target else { return }
        handler(t)()
    }
}

