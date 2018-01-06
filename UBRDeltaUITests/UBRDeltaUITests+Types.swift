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


extension Captain : ComparableElement {
    
    var uniqueIdentifier: Int {
        return name.hash
    }
    
    
    func compareTo(_ other: ComparableElement) -> DeltaComparisonLevel {
        guard uniqueIdentifier == other.uniqueIdentifier else { return .different }
        guard let otherPlayer = other as? Captain else { return .different }
        
        let shipsChanged = ships != otherPlayer.ships
        let fistFightsChanged = fistFights != otherPlayer.fistFights
        
        if shipsChanged || fistFightsChanged {
            return .changed(["ships": shipsChanged, "fistFights": fistFightsChanged])
        } else {
            return .same
        }
    }
    
}


extension Captain : Equatable { }

func ==(lhs: Captain, rhs: Captain) -> Bool {
    return lhs.compareTo(rhs) == DeltaComparisonLevel.same
}
