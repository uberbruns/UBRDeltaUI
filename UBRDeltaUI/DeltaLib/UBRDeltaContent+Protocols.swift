//
//  UBRDeltaContent+Types.swift
//  UBRDelta
//
//  Created by Karsten Bruns on 10/11/15.
//  Copyright © 2015 bruns.me. All rights reserved.
//

import Foundation

protocol SectionElement : AnyElement {
    
    var subitems: [AnyElement] { get }
    
}
