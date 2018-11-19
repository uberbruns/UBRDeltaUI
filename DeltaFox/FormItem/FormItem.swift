//
//  UITableViewCell+Protocols.swift
//  CompareApp
//
//  Created by Karsten Bruns on 29/08/15.
//  Copyright © 2015 bruns.me. All rights reserved.
//

import UIKit



public typealias SelectionHandler = () -> ()


public protocol AnyFormItemProtocol: AnyDiffable {
    var id: FormItemIdentifier { get }
    static var typeIdentifier: String { get }
}


public protocol FormItemProtocol: AnyFormItemProtocol, Diffable {
    static var placeholder: Self { get }
}


extension FormItemProtocol {
    public var uniqueIdentifier: Int {
        return id.hashValue
    }
}


public struct FormItemIdentifier: Hashable {
    let rawValue: String
}


extension FormItemIdentifier: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String

    public init(stringLiteral value: String) {
        self.rawValue = value
    }
}

public extension FormItemIdentifier {
    static func auto(file: String = #file, line: Int = #line) -> FormItemIdentifier {
        return autoFormItemIdentifier(file: file, line: line, other: [])
    }

    static func auto(file: String = #file, line: Int = #line, _ other: AnyHashable...) -> FormItemIdentifier {
        return autoFormItemIdentifier(file: file, line: line, other: other)
    }

    private static func autoFormItemIdentifier(file: String, line: Int, other: [AnyHashable]) -> FormItemIdentifier {
        let resolvedFile = URL(fileURLWithPath: file).lastPathComponent
        let resolvedOther = other.map { ":\($0.hashValue)" }
        return FormItemIdentifier(rawValue: "\(resolvedFile):\(line)\(resolvedOther)")
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
