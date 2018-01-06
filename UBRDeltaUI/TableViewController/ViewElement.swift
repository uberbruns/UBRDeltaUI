//
//  UITableViewCell+Protocols.swift
//  CompareApp
//
//  Created by Karsten Bruns on 29/08/15.
//  Copyright © 2015 bruns.me. All rights reserved.
//

import UIKit



public typealias SelectionHandler = () -> ()


public protocol AnyViewElement : AnyElement {
    var id: String { get }
    var typeIdentifier: String { get }
}


public protocol ViewElement: AnyViewElement, Element {
    static var placeholder: Self { get }
}


extension ViewElement {
    public var uniqueIdentifier: Int {
        return id.hashValue
    }
}


public enum HeaderFooterType {
    case header, footer
}


public protocol SelectableTableViewElement {
    var selectionHandler: SelectionHandler? { get }
}


/// A helper function to avoid reference cycles in action handler
public func weakActionHandler<Target: AnyObject, Result>(_ target: Target, handler: @escaping (Target) -> ((Result) -> Void)) -> ((Result) -> Void) {
    return { [weak target] result in
        guard let t = target else { return }
        handler(t)(result)
    }
}


/// A helper function to avoid reference cycles in action handler
public func weakActionHandler<Target: AnyObject>(_ target: Target, handler: @escaping (Target) -> (() -> Void)) -> (() -> Void) {
    return { [weak target] in
        guard let t = target else { return }
        handler(t)()
    }
}


/// A helper function to avoid reference cycles in action handler.
/// This version allows to provide extra context
public func weakActionHandler<Target: AnyObject, Context, Result>(_ target: Target, handler: @escaping (Target) -> ((Result, Context) -> Void), context: Context) -> ((Result) -> Void) {
    return { [weak target] result in
        guard let t = target else { return }
        handler(t)(result, context)
    }
}


/**
 A helper function to avoid reference cycles in action handler.
 This version allows to provide extra context, but does not take a value
 */
public func weakActionHandler<Target: AnyObject, Context>(_ target: Target, handler: @escaping (Target) -> ((Context) -> Void), context: Context) -> (() -> Void) {
    return { [weak target] in
        guard let t = target else { return }
        handler(t)(context)
    }
}
