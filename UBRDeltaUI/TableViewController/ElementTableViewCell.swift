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
    var anyViewElement: AnyViewElement {
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



public protocol ElementViewHeaderFooterView : class {
    func update(with element: AnyElement, animated: Bool, type: HeaderFooterType)
}


struct TestElement: ViewElement {
    
    let typeIdentifier = "test"

    var id: String
    var text: String
    
    static var placeholder: TestElement {
        return TestElement(id: "", text: "")
    }
    
    func isEqual(to other: TestElement) -> Bool {
        return text == other.text
    }
    
    init(id: String, text: String) {
        self.id = id
        self.text = text
    }
}


class TestCell: UITableViewCell, ElementTableViewCell {
    
    var element = TestElement.placeholder
    
    func elementDidChange(oldElement: TestElement, animate: Bool) {
    }
}
