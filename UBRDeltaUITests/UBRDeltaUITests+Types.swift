//
//  UBRDeltaTests+Types.swift
//  UBRDelta
//
//  Created by Karsten Bruns on 17/11/15.
//  Copyright © 2015 bruns.me. All rights reserved.
//

import Foundation
import UBRDeltaUI

struct Captain {
    
    let name: String
    var ships: [String]
    var fistFights: Int
    
    init(name: String, ships: [String], fistFights: Int) {
        self.name = name
        self.ships = ships
        self.fistFights = fistFights
    }
    
}


extension Captain : Element {

    var uniqueIdentifier: Int {
        return name.hash
    }

    func isEqual(to other: Captain) -> Bool {
        let shipsChanged = ships != other.ships
        let fistFightsChanged = fistFights != other.fistFights
        
        if shipsChanged || fistFightsChanged {
            return false
        } else {
            return true
        }
    }
}


extension Captain : Equatable { }

func ==(lhs: Captain, rhs: Captain) -> Bool {
    let isSame = lhs.uniqueIdentifier == rhs.uniqueIdentifier
    let isEqual = lhs.isEqual(to: rhs)
    return isSame && isEqual
}
