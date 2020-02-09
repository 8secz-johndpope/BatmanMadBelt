//
//  SlotComponent.swift
//  BatmanMadBelt
//
//  Created by Gabriel Taques on 08/02/20.
//  Copyright © 2020 Gabriel Taques. All rights reserved.
//

import RealityKit

struct SlotComponent: Component, Codable {
    var expectedObject = ""
    var hasObject = false
    var isCorrect = false
}
