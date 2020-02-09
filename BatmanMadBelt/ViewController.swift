//
//  ViewController.swift
//  BatmanMadBelt
//
//  Created by Gabriel Taques on 06/02/20.
//  Copyright © 2020 Gabriel Taques. All rights reserved.
//

import UIKit
import RealityKit
import ARKit
import Combine


class ViewController: UIViewController {
    
    @IBOutlet var arView: ARView!
    
    var planeAnchor: AnchorEntity!
    
    var viewAnchor: ARAnchor!
    var viewAnchorEntity: AnchorEntity!
    
    var staticBoxes: [ModelEntity] = []
    var movableBoxes: [ModelEntity] = []
    var cardTemplates: [Entity] = []
    var cards: [Entity] = []
    
    private var intObjectsInRecipe: [Int] = []
    private var modelObjectsInRecipe: [ModelEntity] = []
    
    private var collisionSubs: [Cancellable] = []
    
    var targetPosition: SIMD3<Float> = [0.0,0.0,0.0]
    
    var tapGesture: UITapGestureRecognizer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        ObjectComponent.registerComponent()
        SlotComponent.registerComponent()
        
        planeAnchor = AnchorEntity(plane: .horizontal, classification: .any, minimumBounds: [0.2,  0.2])
        arView.scene.anchors.append(planeAnchor)
        
        arView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapHandler(_:))))
        
        buildObjects(name: "toy_biplane", movable: true)
        buildObjects(name: "toy_car", movable: true)
        buildObjects(name: "toy_drummer", movable: true)
        buildObjects(name: "donut", movable: true)
        buildObjects(name: "toy_robot_vintage", movable: true)
        
        setupBelt(name: "bat_belt")
        
        displayAndPositionObjects(anchor: planeAnchor, listObjects: movableBoxes)
        
        addOcclusionPlane(anchor: planeAnchor)
        addOcclusionBox(anchor: planeAnchor)
        
        for object in modelObjectsInRecipe {
            print(object.name)
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        collisionSubs.append(arView.scene.subscribe(to: CollisionEvents.Began.self) { event in
            // Get both CustomBox entities, if either entityA or entityB isn't a CustomBox
            // then return becasue this is not the collision we're looking for
            
            //As far as I know, BoxA is the Entity that is touched, BoxB is the entity touching!
            guard let boxA = event.entityA as? Entity, let boxB = event.entityB as? ModelEntity else {
                return
            }
            
            if boxA.components.has(ObjectComponent.self) && boxB.components.has(ObjectComponent.self) {
                return
            }
            
            
            if boxA.components[SlotComponent.self]!.hasObject == false {
                print("Box A name:", boxA.name)
                print("Box B name:", boxB.name)
                if self.modelObjectsInRecipe[Int(boxA.name)!].name == boxB.name {
                    print("Box A name:", boxA.name)
                    print("Box B name:", boxB.name)
                    print("Object in list", self.modelObjectsInRecipe[Int(boxA.name)!].name)
                    self.planeAnchor.removeChild(boxA)
                    self.fitInObject(boxA.name, slot: boxA.position)
                    //playSound
                    boxB.position = boxB.components[ObjectComponent.self]!.position
                    boxA.components[SlotComponent.self]!.hasObject = true
                }
                
            }
        })
        
        collisionSubs.append(arView.scene.subscribe(to: CollisionEvents.Ended.self) { event in
            guard let boxA = event.entityA as? CustomBox, let boxB = event.entityB as? CustomBox else {
                return
            }
        })
    }
    
    @objc
    func tapHandler(_ sender: UITapGestureRecognizer) {
        
    }
    
    func buildObjects(name: String, movable: Bool) {
        let box = try! ModelEntity.loadModel(named: name)
        box.generateCollisionShapes(recursive: true)
        box.name = name
        box.components[ObjectComponent.self] = ObjectComponent()
        box.components[ObjectComponent.self]!.kind = name
        if movable {
            box.components[ObjectComponent.self]!.movable = true
            arView.installGestures([.all], for: box)
            movableBoxes.append(box)
        } else {
            staticBoxes.append(box)
        }
        
    }
    
    func setupBelt(name: String) {
        let belt = try! ModelEntity.loadModel(named: name)
        planeAnchor.addChild(belt)
        
        //Generate recipe
        //Iterate over array creating each slot for objects
        //Pass on param the object that should fit in slot
        generateRecipe(4)
        loadObjectsInRecipe()
        
        var initX: Float = -0.5
        
        for (index, _) in modelObjectsInRecipe.enumerated() {
            buildSlotOnBelt(x: initX, name: String(index))
            if index == 1 {
                initX += 0.5
                continue
            }
            initX += 0.25
        }
    }
    
    func generateRecipe(_ n:Int) {
        intObjectsInRecipe = (0..<n).map { _ in .random(in: 1...5) }
    }
    
    func loadObjectsInRecipe() {
        for i in intObjectsInRecipe {
            modelObjectsInRecipe.append(Int.loadModelFromInteger(i))
        }
    }
    
    func buildSlotOnBelt(x position: Float, name: String) {
        let slot = Entity()
        slot.generateCollisionShapes(recursive: true)
        slot.components[ModelComponent] = ModelComponent(
            mesh: .generateBox(size: [0.05, 0.03, 0.05]),
            materials: [SimpleMaterial(
                color: .lightGray,
                isMetallic: false
                )
        ])
        slot.position = [position, 0, 0]
        
        slot.components[CollisionComponent] = CollisionComponent(
            shapes: [.generateBox(size: [0.1,0.1,0.1])],
            mode: .trigger,
            filter: .sensor)
        slot.name = name
        slot.components[SlotComponent.self] = SlotComponent()
        //set expected object
        
        planeAnchor.addChild(slot)
    }
    
    func fitInObject(_ slot: String, slot position: SIMD3<Float>) {
        switch slot {
        case "3":
            modelObjectsInRecipe[3].position = position
            planeAnchor.addChild(modelObjectsInRecipe[3])
        case "2":
            modelObjectsInRecipe[2].position = position
            planeAnchor.addChild(modelObjectsInRecipe[2])
        case "1":
            modelObjectsInRecipe[1].position = position
            planeAnchor.addChild(modelObjectsInRecipe[1])
        case "0":
            modelObjectsInRecipe[0].position = position
            planeAnchor.addChild(modelObjectsInRecipe[0])
        default:
            return
            
        }
    }
    
    func displayAndPositionObjects(anchor: AnchorEntity, listObjects: [ModelEntity]) {
        for (index,box) in listObjects.enumerated() {
            let x = Float(index % 4) - 1.5
            let z = Float(index / 4) + 1.5
            
            box.position = [x * -0.3, 0.01, z * 0.3]
            box.components[ObjectComponent.self]!.position = box.position
            anchor.addChild(box)
        }
    }
    
    
    func generatePlane() {
        let planeMesh = MeshResource.generatePlane(width: 0.5, depth: 0.5)
        let material = SimpleMaterial(color: .green, isMetallic: false)
        let materialPlane = ModelEntity(mesh: planeMesh, materials: [material])
        materialPlane.position.y = -0.001
        planeAnchor.addChild(materialPlane)
        arView.scene.addAnchor(planeAnchor)
    }
    
    func loadCardTemplates() {
        for index in 1...8 {
            let assetName = "toy_robot_vintage"
            let  cardTemplate = try! Entity.loadModel(named: assetName)
            
            print(type(of: cardTemplate))
            
            cardTemplate.generateCollisionShapes(recursive: true)
            
            cardTemplate.name = assetName
            
            cardTemplates.append(cardTemplate)
            
        }
    }
    
    func createCard() {
        for cardTemplate in cardTemplates {
            for _ in 1...2 {
                cards.append(cardTemplate.clone(recursive: true))
            }
        }
    }
    
    func placeCards(anchor: AnchorEntity) {
        // Embaralha cartas
        cards.shuffle()
        
        // Posiciona as cartas em uma grid de 4x4
        for (index, card) in cards.enumerated() {
            let x = Float(index % 4) - 1.5
            let z = Float(index / 4) - 1.5
            
            // Determina a posicao de cada carta
            card.position = [x * 0.3, 0, z * 0.3]
            
            // Adiciona a carta na ancora
            anchor.addChild(card)
            
        }
    }
    
    
    
    func addOcclusionPlane(anchor: AnchorEntity) {
        let planeMesh = MeshResource.generatePlane(width: 0.5, depth: 0.5)
        
        let material = OcclusionMaterial()
        
        let occlusionPlane = ModelEntity(mesh: planeMesh, materials: [material])
        
        occlusionPlane.position.y = -0.001
        
        anchor.addChild(occlusionPlane)
    }
    
    
    func addOcclusionBox(anchor: AnchorEntity) {
        let boxSize: Float = 0.5
        let boxMesh = MeshResource.generateBox(size: boxSize)
        
        let material = OcclusionMaterial()
        
        let occlusionBox = ModelEntity(mesh: boxMesh, materials: [material])
        
        occlusionBox.position.y = -boxSize / 2 - 0.001
        
        anchor.addChild(occlusionBox)
    }
}

extension Int {
    
    static func loadModelFromInteger(_ n: Int) -> ModelEntity {
        switch n {
        case 1:
            let model = try! ModelEntity.loadModel(named: "toy_biplane")
            model.name = "toy_biplane"
            return model
        case 2:
            let model = try! ModelEntity.loadModel(named: "toy_car")
            model.name = "toy_car"
            return model
        case 3:
            let model = try! ModelEntity.loadModel(named: "toy_drummer")
            model.name = "toy_drummer"
            return model
        case 4:
            let model = try! ModelEntity.loadModel(named: "toy_robot_vintage")
            model.name = "toy_robot_vintage"
            return model
        default:
            let model = try! ModelEntity.loadModel(named: "donut")
            model.name = "donut"
            return model
        }
    }
}
