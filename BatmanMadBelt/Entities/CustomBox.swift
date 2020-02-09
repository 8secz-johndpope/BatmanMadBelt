//
//  CustomBox.swift
//  BatmanMadBelt
//
//  Created by Gabriel Taques on 06/02/20.
//  Copyright © 2020 Gabriel Taques. All rights reserved.
//

import UIKit
import RealityKit
import Combine

class CustomBox: Entity, HasModel, HasAnchoring, HasCollision {
    var collisionSubs: [Cancellable] = []
    
    var initPosition: SIMD3<Float>?
    var initColor: UIColor?
    
    required init(color: UIColor) {
        super.init()

        self.components[CollisionComponent] = CollisionComponent(
            shapes: [.generateBox(size: [0.1,0.1,0.1])],
            mode: .trigger,
            filter: .sensor
        )
        
        self.components[ModelComponent] = ModelComponent(
            mesh: .generateBox(size: [0.1, 0.1, 0.1]),
            materials: [SimpleMaterial(
                color: color,
                isMetallic: false
                )
            ])
        
    }
    
    convenience init(color: UIColor, position: SIMD3<Float>) {
        self.init(color: color)
        self.position = position
        initPosition = position
        initColor = color

    }
    
    required convenience init() {
        self.init(color: .orange)
    }
    
}

extension CustomBox {
    func addCollisions() {
        guard let scene = self.scene else {
            return
        }
        // Add the subscription for when this cube
        collisionSubs.append(scene.subscribe(to: CollisionEvents.Began.self, on: self) { event in
            // Get both CustomBox entities, if either entityA or entityB isn't a CustomBox
            // then return becasue this is not the collision we're looking for
            guard let boxA = event.entityA as? CustomBox, let boxB = event.entityB as? CustomBox else {
                return
            }
            
            
            // Change the material color on the entity
//            boxA.model?.materials = [SimpleMaterial(color: .red, isMetallic: false)]
//            boxB.model?.materials = [SimpleMaterial(color: .red, isMetallic: false)]
            
//            if boxA.initColor == boxB.initColor && self.initPosition != nil {
//                boxA.position = self.initPosition!
//            }
            
            
            
            
        })
        collisionSubs.append(scene.subscribe(to: CollisionEvents.Ended.self, on: self) { event in
            guard let boxA = event.entityA as? CustomBox, let boxB = event.entityB as? CustomBox else {
                return
            }
            
//            boxA.model?.materials = [SimpleMaterial(color: .green, isMetallic: false)]
//            boxB.model?.materials = [SimpleMaterial(color: .green, isMetallic: false)]
        })
    }
}

