//
//  CardComponent.swift
//  BatmanMadBelt
//
//  Created by Gabriel Taques on 06/02/20.
//  Copyright © 2020 Gabriel Taques. All rights reserved.
//

import RealityKit
import UIKit

struct ObjectComponent: Component, Codable {
    var position = SIMD3<Float>(0,0,0)
    var isFit = false
    var kind = ""
    var movable = false
    
}

