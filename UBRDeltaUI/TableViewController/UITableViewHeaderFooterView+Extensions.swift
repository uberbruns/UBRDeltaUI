//
//  UITableViewHeaderFooterView+Extensions.swift
//  CompareApp
//
//  Created by Karsten Bruns on 30/08/15.
//  Copyright © 2015 bruns.me. All rights reserved.
//

import UIKit
import UBRDelta

extension UITableViewHeaderFooterView : UpdateableTableViewHeaderFooterView {
    
    public  func updateViewWithItem(item: ComparableItem, animated: Bool, type: HeaderFooterType) {
        guard let sectionItem = item as? TableViewSectionItem else { return }
        switch type {
        case .Header :
            textLabel?.text = sectionItem.title?.uppercaseString
        case .Footer :
            textLabel?.text = sectionItem.footer
        }
    }
    
}