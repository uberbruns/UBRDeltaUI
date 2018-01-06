//
//  ElementTableViewCell.swift
//  UBRDeltaUI
//
//  Created by Karsten Bruns on 06.01.18.
//  Copyright © 2018 bruns.me. All rights reserved.
//

import UIKit

public protocol AnyElementTableViewCell : class {
    var anyViewElement: AnyViewElement { get set }
    func elementDidChange(oldElement: AnyViewElement, animate: Bool)
}


public protocol ElementTableViewCell : AnyElementTableViewCell {
    associatedtype VE: ViewElement
    var element: VE { get set }
    func elementDidChange(oldElement: VE, animate: Bool)
}


extension ElementTableViewCell {
    public var anyViewElement: AnyViewElement {
        get {
            return element
        }
        set {
            if let element = newValue as? VE {
                self.element = element
            }
        }
    }

    public func elementDidChange(oldElement: AnyViewElement, animate: Bool) {
        if let expectedOldElement = oldElement as? VE {
            elementDidChange(oldElement: expectedOldElement, animate: animate)
        }
    }
}




public protocol AnyElementHeaderFooterView : class {
    var anyViewElement: AnyViewElement { get set }
    func elementDidChange(oldElement: AnyViewElement, animate: Bool, type: HeaderFooterType)
}


public protocol ElementHeaderFooterView : AnyElementHeaderFooterView {
    associatedtype VE: ViewElement
    var element: VE { get set }
    func elementDidChange(oldElement: VE, animate: Bool, type: HeaderFooterType)
}


extension ElementHeaderFooterView {
    public var anyViewElement: AnyViewElement {
        get {
            return element
        }
        set {
            if let element = newValue as? VE {
                self.element = element
            }
        }
    }
    
    public func elementDidChange(oldElement: AnyViewElement, animate: Bool, type: HeaderFooterType) {
        if let expectedOldElement = oldElement as? VE {
            elementDidChange(oldElement: expectedOldElement, animate: animate, type: type)
        }
    }
}
