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
    var baseAnchorEntity: AnchorEntity!
    var batCaveScene: Experience.BatCave!
    
    var belt: ModelEntity!
    var staticBoxes: [ModelEntity] = []
    var movableObjects: [ModelEntity] = []
    var radio: Entity!
    var phone: Entity!
    
    var movableObject: Entity!
    var baseballEntity: Entity!
    var bateriaEntity: Entity!
    var tenisEntity: Entity!
    var donutEntity: Entity!
    var disqueteEntity: Entity!
    var dogEntity: Entity!
    
    private var intObjectsInRecipe: [Int] = []
    private var modelObjectsInRecipe: [ModelEntity] = []
    
    private var collisionSubs: [Cancellable] = []
    
    var targetPosition: SIMD3<Float> = [0.0,0.0,0.0]
    
    private var tapGesture: UITapGestureRecognizer?
    
    
    private var buckle: AudioFileResource!
    private var buckleController: AudioPlaybackController?
    
    private var audio1: AudioFileResource!
    private var audio1Controller: AudioPlaybackController?
    
    private var audio2: AudioFileResource!
    private var audio2Controller: AudioPlaybackController?
    
    private var audio3: AudioFileResource!
    private var audio3Controller: AudioPlaybackController?
    
    private var audio4: AudioFileResource!
    private var audio4Controller: AudioPlaybackController?
    
    private var transition: AudioFileResource!
    private var transitionController: AudioPlaybackController?
    
    private var phoneRing: AudioFileResource!
    private var phoneRingController: AudioPlaybackController?
    private var phoneRinging: Bool = false
    private var phoneCalling: Bool = false
    
    private var audioControllers: [AudioPlaybackController] = []
    
    private var currentAudio: Int = 0
    
    
    //MARK: UIView Components
    
    @IBOutlet weak var beltColoredView: UIView!
    @IBOutlet weak var beltMenuView: UIView!
    var hiddenConstraint: NSLayoutConstraint?
    var shownConstraint: NSLayoutConstraint?
    
    var objectsFitOnBelt: Int!
    
    
    
    //MARK: Load Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        objectsFitOnBelt = 0
        ObjectComponent.registerComponent()
        SlotComponent.registerComponent()
        
        setupAnchors()
        
        arView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapHandler(_:))))
        
        loadMovableBatmanItems(name: "baseball")
        loadMovableBatmanItems(name: "bateria")
        loadMovableBatmanItems(name: "disquete")
        loadMovableBatmanItems(name: "dog")
        loadMovableBatmanItems(name: "tenis")
        loadMovableBatmanItems(name: "donut")
        
        setupBelt(name: "bat_belt")
        prepareAudios()
        
//        displayAndPositionObjects(anchor: planeAnchor, movableObjects: movableObjects)
        
        addOcclusionPlane(anchor: planeAnchor)
        addOcclusionBox(anchor: planeAnchor)
        
        setupInitialView()
        
        for object in modelObjectsInRecipe {
            print(object.name)
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        collisionSubs.append(arView.scene.subscribe(to: CollisionEvents.Began.self) { event in
            // Get both CustomBox entities, if either entityA or entityB isn't a CustomBox
            // then return becasue this is not the collision we're looking for
            // As far as I know, BoxA is the Entity that is touched, BoxB is the entity touching!
            guard let boxA = event.entityA as? Entity, let boxB = event.entityB as? ModelEntity else {
                return
            }
            
            if boxA.components.has(ObjectComponent.self) && boxB.components.has(ObjectComponent.self) {
                return
            }
            
            if boxA.components[SlotComponent.self]?.hasObject == false {
                if self.modelObjectsInRecipe[Int(boxA.name)!].name == boxB.name {
                    
                    print("Object in list", self.modelObjectsInRecipe[Int(boxA.name)!].name)
                    
                    self.fitInObject(boxA.name, slot: boxA.position)
                    self.planeAnchor.removeChild(boxA)
                    print("Box A name: ", boxA.name)
                    
                    self.buckleController?.play()
                    let cloneObject = boxB.clone(recursive: true)
                    cloneObject.position =  boxA.position - boxB.components[ObjectComponent.self]!.position
                    
                    self.planeAnchor.addChild(cloneObject)
                    boxB.position = [0,0,0]
                    boxA.components[SlotComponent.self]!.hasObject = true
                    
                    print("Posicao da caixinha menos a posicao do clone object: ", boxA.position - cloneObject.position)
                    print("Posicao inicial do objeto: " , boxB.components[ObjectComponent.self]!.position)
                    print("Cloned Object: Center of Visual bounds: ", cloneObject.visualBounds(relativeTo: nil).center)
                    print("BoxA:          Center of Visual bounds: ", boxA.visualBounds(relativeTo: nil).center)
                    self.objectsFitOnBelt += 1
                    if self.objectsFitOnBelt == 4 {
                        self.batCaveScene.notifications.indicarCaminho.post()
                        self.objectsFitOnBelt = 0
                    }
                }
                
            }
        })
        collisionSubs.append(arView.scene.subscribe(to: CollisionEvents.Ended.self) { event in
        })
        
        collisionSubs.append(arView.scene.subscribe(to: SceneEvents.Update.self) { event in
            
            let cameraPosition = self.arView.cameraTransform.translation
            
            let totalDistanceFromRadio = self.distance(from: cameraPosition, to:  self.radio.position(relativeTo: self.baseAnchorEntity!))
            
            if totalDistanceFromRadio < 0.8  {
                
                self.audioControllers[self.currentAudio].play()
                
            } else if totalDistanceFromRadio >= 0.5 {
                
                self.audioControllers[self.currentAudio].fade(to: .zero, duration: 2)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { // Change `2.0` to the desired number of seconds.
                    self.audioControllers[self.currentAudio].stop()
                }
            }
            
            let totalDistanceFromPhone = self.distance(from: cameraPosition, to: self.phone.position(relativeTo: self.baseAnchorEntity!))
            if totalDistanceFromPhone < 0.5 {
                self.phoneRingController!.play()
                if !self.phoneCalling {
                    self.phoneRinging = true
                }
                
            } else {
                self.phoneRingController?.stop()
                self.phoneRinging = false
            }
            
        })
    }
    
    //MARK: Audio Helpers
    
    func prepareAudios() {
        audio1 = try! AudioFileResource.load(named: "intro.mp3")
        audio1Controller = radio.prepareAudio(audio1)
        
        audio2 = try! AudioFileResource.load(named: "ukulele.wav")
        audio2Controller = radio.prepareAudio(audio2)
        
        audio3 = try! AudioFileResource.load(named: "happy_song.wav")
        audio3Controller = radio.prepareAudio(audio3)
    
        transition = try! AudioFileResource.load(named: "tune.wav")
        transitionController = radio.prepareAudio(transition)
        
        phoneRing = try! AudioFileResource.load(named: "phone_ring.wav")
        phoneRingController = phone.prepareAudio(phoneRing)
        
    
        audioControllers.append(audio1Controller!)
        audioControllers.append(audio2Controller!)
        audioControllers.append(audio3Controller!)
        
        
    }
    
    //MARK: Scene Build and Setup
    
    func setupAnchors() {
        planeAnchor = AnchorEntity(plane: .horizontal, classification: .any, minimumBounds: [0.2,  0.2])
        arView.scene.anchors.append(planeAnchor)
        
        let arConfiguration = ARWorldTrackingConfiguration()
        arConfiguration.planeDetection = .horizontal
        arView.session.run(arConfiguration, options: .resetTracking)
        
        batCaveScene = try! Experience.loadBatCave()
        
        arView.scene.anchors.append(batCaveScene)
        radio = batCaveScene.radio!
        print(batCaveScene.radio?.name)
        radio.name = "radio"
        phone = batCaveScene.phone
        phone.name = "phone"
        
        let baseAnchor = ARAnchor(transform: self.arView.cameraTransform.matrix)
        
        // cria AnchorEntity com base na ARAnchor
        baseAnchorEntity = AnchorEntity(anchor: baseAnchor)
        arView.scene.addAnchor(baseAnchorEntity)
        
    }
    
    // Load objects that are movable and adds to the list of movable objects (Batman Items)
    func loadBatmanItem(name: String, movable: Bool) {
        let box = try! ModelEntity.loadModel(named: name)
        box.generateCollisionShapes(recursive: true)
        box.name = name
        box.components[ObjectComponent.self] = ObjectComponent()
        box.components[ObjectComponent.self]!.kind = name
        if movable {
            box.components[ObjectComponent.self]!.movable = true
            arView.installGestures([.all], for: box)
            movableObjects.append(box)
        } else {
            staticBoxes.append(box)
        }
    }
    
    func loadMovableBatmanItems(name: String) {
//        var movableObject: Entity?
        var position: SIMD3<Float>!
        switch name {
        case "baseball":
            //Create instance of the object pre positioned on Reality Composer
            movableObject = batCaveScene.baseball!
            print("Baseball bat position relative to plane anchor:", movableObject.position(relativeTo: planeAnchor))
            baseballEntity = batCaveScene.baseball!.clone(recursive: false)
            position = movableObject.position(relativeTo: planeAnchor)
        case "bateria":
            movableObject = batCaveScene.bateria!
            print("Baseball bat position relative to plane anchor:", movableObject.position(relativeTo: planeAnchor))
            bateriaEntity = batCaveScene.bateria!.clone(recursive: false)
            position = movableObject.position(relativeTo: planeAnchor)
        case "disquete":
            movableObject = batCaveScene.disquete!
            print("Baseball bat position relative to plane anchor:", movableObject.position(relativeTo: planeAnchor))
            disqueteEntity = batCaveScene.disquete!.clone(recursive: false)
            position = movableObject.position(relativeTo: planeAnchor)
        case "dog":
            movableObject = batCaveScene.dog!
            print("Baseball bat position relative to plane anchor:", movableObject.position(relativeTo: planeAnchor))
            dogEntity = batCaveScene.dog!.clone(recursive: false)
            position = movableObject.position(relativeTo: planeAnchor)
        case "tenis":
            movableObject = batCaveScene.tenis!
            print("Baseball bat position relative to plane anchor:", movableObject.position(relativeTo: planeAnchor))
            tenisEntity = batCaveScene.tenis!.clone(recursive: false)
            position = movableObject.position(relativeTo: planeAnchor)
        case "donut":
            movableObject = batCaveScene.donut!
            print("Baseball bat position relative to plane anchor:", movableObject.position(relativeTo: planeAnchor))
            donutEntity = batCaveScene.donut!.clone(recursive: false)
            position = movableObject.position(relativeTo: planeAnchor)
            
        default:
            movableObject = batCaveScene.baseball!
            position = movableObject.position(relativeTo: planeAnchor)
        }
        //Creates the parent Entity
        let parentEntity = ModelEntity()
        //Adds baseballBat to a ModelEntity
        parentEntity.addChild(movableObject!)
        
        //Creates bounds based on the size of the parent
        let childBounds = movableObject?.visualBounds(relativeTo: parentEntity)
        //Adds collision
        parentEntity.collision = CollisionComponent(shapes: [ShapeResource.generateBox(size: childBounds!.extents).offsetBy(translation: childBounds!.center)])
        
        parentEntity.name = name
        parentEntity.components[ObjectComponent.self] = ObjectComponent()
        parentEntity.components[ObjectComponent.self]!.kind = name
        parentEntity.components[ObjectComponent.self]!.movable = true
        parentEntity.components[ObjectComponent.self]!.position = position
        print("Position do parent \(name):" ,  parentEntity.components[ObjectComponent.self]!.position)
        print("Position do movable \(name):" ,  parentEntity.components[ObjectComponent.self]!.position)
        arView.installGestures([.all], for: parentEntity)
        movableObjects.append(parentEntity)
        
//        planeAnchor.addChild(parentEntity)
        
        
    }
    
    func setupBelt(name: String) {
        belt = try! ModelEntity.loadModel(named: name)
        //Generate recipe
        //Iterate over array creating each slot for objects
        //Pass on param the object that should fit in slot
        generateRecipe(4)
        
        loadObjectsInRecipe()
        buckle = try! AudioFileResource.load(named: "buckle.wav")
        buckleController = belt.prepareAudio(buckle)
    }
    
    func addBeltToAnchor() {
        planeAnchor.addChild(belt)
        
        var initX: Float = -0.5
        for (index, _) in modelObjectsInRecipe.enumerated() {
            buildSlotOnBelt(x: initX, name: String(index))
            if index == 1 {
                initX += 0.5
                continue
            }
            initX += 0.25
        }
        displayAndPositionObjects(anchor: planeAnchor, movableObjects: movableObjects)
    }
    
    func displayAndPositionObjects(anchor: AnchorEntity, movableObjects: [ModelEntity]) {
        for (index,box) in movableObjects.enumerated() {
            let x = Float(index % 4) - 1.5
            let z = Float(index / 4) + 1.5
            
            anchor.addChild(box)
        }
    }
    
    
    
    //MARK: Gameplay Helpers
    
    @objc
    func tapHandler(_ sender: UITapGestureRecognizer) {
        let tapLocation = sender.location(in: arView)
        if let entity =  arView.entity(at: tapLocation) {
            print(entity.name)
            if entity.name == "radio" {
                audioControllers[currentAudio].stop()
                transitionController?.play()
                if currentAudio < audioControllers.count - 1 {
                    currentAudio += 1
                } else {
                    currentAudio = 0
                }
            } else if entity.name == "phone" {
                 let cameraAnchor = AnchorEntity(.camera)
                if phoneRinging && !phoneCalling {
                   
                    cameraAnchor.addChild(phone)
                    arView.scene.addAnchor(cameraAnchor)
                    
                    
                    phone.transform.translation = [0.12,-0.04,-0.2]
                    phone.stopAllAnimations(recursive: true)
                    self.phoneRingController?.stop()
                    phoneCalling = true
                    
                    // playAudio()
                } else {
                    cameraAnchor.removeChild(phone)
                    planeAnchor.addChild(phone)
                    
                    toggleBeltMenu()
                    addBeltToAnchor()
                    
                }
                
                
                //anima banana
                //toca audio da missao
            }
            
        }
//        transition1Controller?.play()

    }
    
    func generateRecipe(_ n:Int) {
        intObjectsInRecipe = (0..<n).map { _ in .random(in: 1...6) }
    }
    
    //This func adds all the items on the recipe to then be added to the belt
    func loadObjectsInRecipe() {
        for i in intObjectsInRecipe {
            modelObjectsInRecipe.append(loadModelFromInteger(i))
        }
    }
    
    //This func builds the slots for the objects on the belt
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
    
    //This func positions the object on the correct spot on the belt
    func fitInObject(_ slot: String, slot position: SIMD3<Float>) {
        switch slot {
        case "3":
            modelObjectsInRecipe[3].position = position
            print(modelObjectsInRecipe[3].name)
            planeAnchor.addChild(modelObjectsInRecipe[3])
            slotFourImageView.image = UIImage(named: modelObjectsInRecipe[3].name)
        case "2":
            modelObjectsInRecipe[2].position = position
            print(modelObjectsInRecipe[2].name)
            planeAnchor.addChild(modelObjectsInRecipe[2])
            slotThreeImageView.image = UIImage(named: modelObjectsInRecipe[2].name)
        case "1":
            modelObjectsInRecipe[1].position = position
            print(modelObjectsInRecipe[1].name)
            planeAnchor.addChild(modelObjectsInRecipe[1])
            slotTwoImageView.image = UIImage(named: modelObjectsInRecipe[1].name)
        case "0":
            modelObjectsInRecipe[0].position = position
            print(modelObjectsInRecipe[0].name)
            planeAnchor.addChild(modelObjectsInRecipe[0])
            slotOneImageView.image = UIImage(named: modelObjectsInRecipe[0].name)
        default:
            return
            
        }
        
    }
    
    
    
    //MARK: Helpers
    private func distance(from origin: SIMD3<Float>, to end: SIMD3<Float>) -> Float {
        
        let xD = (end.x) - (origin.x)
        let yD = (end.y) - (origin.y)
        let zD = (end.z) - (origin.z)
        
        return sqrt(xD * xD + yD * yD + zD * zD)
    }
    
    //MARK: UIView Setup and Build
    
    @IBOutlet weak var beltMenuButton: UIButton!
    
    @IBOutlet weak var slotOne: UIView!
    @IBOutlet weak var slotTwo: UIView!
    @IBOutlet weak var slotThree: UIView!
    @IBOutlet weak var slotFour: UIView!
    
    @IBOutlet weak var slotOneImageView: UIImageView!
    @IBOutlet weak var slotTwoImageView: UIImageView!
    @IBOutlet weak var slotThreeImageView: UIImageView!
    @IBOutlet weak var slotFourImageView: UIImageView!
    
    
    
    func setupInitialView() {
        hiddenConstraint = beltMenuView.topAnchor.constraint(equalTo: self.view.bottomAnchor)
        hiddenConstraint?.isActive = true
        
        shownConstraint = beltMenuView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        shownConstraint?.isActive = false
        
        beltMenuView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        beltMenuView.widthAnchor.constraint(equalTo: self.view.widthAnchor).isActive = true
        beltMenuView.heightAnchor.constraint(equalTo: self.view.heightAnchor, multiplier: 0.2).isActive = true
        
        self.view.layoutIfNeeded()
        
        beltColoredView.heightAnchor.constraint(equalTo: beltMenuView.heightAnchor).isActive = true
        beltColoredView.widthAnchor.constraint(equalTo: beltMenuView.widthAnchor).isActive = true
        beltColoredView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        beltColoredView.centerYAnchor.constraint(equalTo: beltMenuView.centerYAnchor).isActive = true
        
        slotOne.trailingAnchor.constraint(equalTo: self.beltMenuView.trailingAnchor).isActive = true
        slotOne.heightAnchor.constraint(equalTo: self.beltMenuView.heightAnchor).isActive = true
        slotOne.widthAnchor.constraint(equalTo: self.beltMenuView.widthAnchor, multiplier: 0.2).isActive = true
        slotOne.centerYAnchor.constraint(equalTo: self.beltMenuView.centerYAnchor).isActive = true
        
        slotTwo.leadingAnchor.constraint(equalTo: self.slotOne.trailingAnchor).isActive = true
        slotTwo.heightAnchor.constraint(equalTo: self.beltMenuView.heightAnchor).isActive = true
        slotTwo.widthAnchor.constraint(equalTo: self.beltMenuView.widthAnchor).isActive = true
        slotTwo.centerYAnchor.constraint(equalTo: self.beltMenuView.centerYAnchor).isActive = true
        
        slotFour.trailingAnchor.constraint(equalTo: self.beltMenuView.trailingAnchor).isActive = true
        slotFour.widthAnchor.constraint(equalTo: self.beltMenuView.widthAnchor, multiplier: 0.2).isActive = true
        slotFour.heightAnchor.constraint(equalTo: self.beltMenuView.heightAnchor).isActive = true
        slotFour.centerYAnchor.constraint(equalTo: self.beltMenuView.centerYAnchor).isActive = true
        
        slotThree.trailingAnchor.constraint(equalTo: self.slotFour.leadingAnchor).isActive = true
        slotThree.widthAnchor.constraint(equalTo: self.beltMenuView.widthAnchor, multiplier: 0.2).isActive = true
        slotThree.heightAnchor.constraint(equalTo: self.beltMenuView.heightAnchor).isActive = true
        slotThree.centerYAnchor.constraint(equalTo: self.beltMenuView.centerYAnchor).isActive = true
        
        beltMenuButton.clipsToBounds = true
        beltMenuButton.layer.cornerRadius = beltMenuButton.frame.height / 2
        beltMenuButton.layer.borderWidth = 1
        beltMenuView.layer.borderColor = UIColor.yellow.cgColor
        beltMenuButton.layer.backgroundColor = UIColor.black.cgColor
        beltMenuButton.alpha = 0.6
        beltMenuButton.tintColor = .yellow
        
        self.view.layoutIfNeeded()
        
        slotOneImageView.image = UIImage(named: "\(modelObjectsInRecipe[0].name)_x")
        slotTwoImageView.image = UIImage(named: "\(modelObjectsInRecipe[1].name)_x")
        slotThreeImageView.image = UIImage(named: "\(modelObjectsInRecipe[2].name)_x")
        slotFourImageView.image = UIImage(named: "\(modelObjectsInRecipe[3].name)_x")
        
    }
    
    func buildImagePlaceHolders() {
        
    }
    
    //MARK: UIView Methods
    @IBAction func openBeltMenu(_ sender: Any) {
        toggleBeltMenu()
    }
    
    func toggleBeltMenu() {
        hiddenConstraint?.isActive.toggle()
        shownConstraint?.isActive.toggle()
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    // Load a ModelEntity from a Integer, generated in the recipe
    func loadModelFromInteger(_ n: Int) -> ModelEntity {
        switch n {
        case 1:
            //Creates the parent Entity
            let baseballParentEntity = ModelEntity()
            //Adds baseballBat to a ModelEntity
            baseballParentEntity.addChild(bateriaEntity)
            
            //Creates bounds based on the size of the parent
            let childBounds = bateriaEntity.visualBounds(relativeTo: baseballParentEntity)
            //Adds collision
            baseballParentEntity.collision = CollisionComponent(shapes: [ShapeResource.generateBox(size: childBounds.extents).offsetBy(translation: childBounds.center)])
            baseballParentEntity.name = "bateria"
            return baseballParentEntity
        case 2:
            //Creates the parent Entity
            let baseballParentEntity = ModelEntity()
            //Adds baseballBat to a ModelEntity
            baseballParentEntity.addChild(disqueteEntity)
            
            //Creates bounds based on the size of the parent
            let childBounds = disqueteEntity.visualBounds(relativeTo: baseballParentEntity)
            //Adds collision
            baseballParentEntity.collision = CollisionComponent(shapes: [ShapeResource.generateBox(size: childBounds.extents).offsetBy(translation: childBounds.center)])
            baseballParentEntity.name = "disquete"
            return baseballParentEntity
        case 3:
            //Creates the parent Entity
            let baseballParentEntity = ModelEntity()
            //Adds baseballBat to a ModelEntity
            baseballParentEntity.addChild(dogEntity)
            
            //Creates bounds based on the size of the parent
            let childBounds = dogEntity.visualBounds(relativeTo: baseballParentEntity)
            //Adds collision
            baseballParentEntity.collision = CollisionComponent(shapes: [ShapeResource.generateBox(size: childBounds.extents).offsetBy(translation: childBounds.center)])
            baseballParentEntity.name = "dog"
            return baseballParentEntity
        case 4:
            //Creates the parent Entity
            let baseballParentEntity = ModelEntity()
            //Adds baseballBat to a ModelEntity
            baseballParentEntity.addChild(tenisEntity)
            
            //Creates bounds based on the size of the parent
            let childBounds = tenisEntity.visualBounds(relativeTo: baseballParentEntity)
            //Adds collision
            baseballParentEntity.collision = CollisionComponent(shapes: [ShapeResource.generateBox(size: childBounds.extents).offsetBy(translation: childBounds.center)])
            baseballParentEntity.name = "tenis"
            return baseballParentEntity
        case 5:
            //Creates the parent Entity
            let baseballParentEntity = ModelEntity()
            //Adds baseballBat to a ModelEntity
            baseballParentEntity.addChild(donutEntity)
            
            //Creates bounds based on the size of the parent
            let childBounds = donutEntity.visualBounds(relativeTo: baseballParentEntity)
            //Adds collision
            baseballParentEntity.collision = CollisionComponent(shapes: [ShapeResource.generateBox(size: childBounds.extents).offsetBy(translation: childBounds.center)])
            baseballParentEntity.name = "donut"
            return baseballParentEntity
        case 6:
            
//            let baseball1Entity = batCaveScene.baseball!
            //Create instance of the object pre positioned on Reality Composer
//            guard let baseballEntity = batCaveScene.baseball else { return ModelEntity() }
            //Creates the parent Entity
            let baseballParentEntity = ModelEntity()
            //Adds baseballBat to a ModelEntity
            baseballParentEntity.addChild(baseballEntity)
            
            //Creates bounds based on the size of the parent
            let childBounds = baseballEntity.visualBounds(relativeTo: baseballParentEntity)
            //Adds collision
            baseballParentEntity.collision = CollisionComponent(shapes: [ShapeResource.generateBox(size: childBounds.extents).offsetBy(translation: childBounds.center)])
            baseballParentEntity.name = "baseball"
            return baseballParentEntity
            
        
        default:
            let model = try! ModelEntity.loadModel(named: "donut")
            model.name = "donut"
            return model
        }
    }
    
}

extension ViewController {
    
    func generatePlane() {
        let planeMesh = MeshResource.generatePlane(width: 0.5, depth: 0.5)
        let material = SimpleMaterial(color: .green, isMetallic: false)
        
        let materialPlane = ModelEntity(mesh: planeMesh, materials: [material])
        materialPlane.position.y = -0.001
        planeAnchor.addChild(materialPlane)
        arView.scene.addAnchor(planeAnchor)
    }
    
    func addOcclusionPlane(anchor: AnchorEntity) {
        let planeMesh = MeshResource.generatePlane(width: 2, depth: 2)
        let material = OcclusionMaterial()
        let occlusionPlane = ModelEntity(mesh: planeMesh, materials: [material])
        occlusionPlane.position.y = -0.001
        anchor.addChild(occlusionPlane)
    }
    
    
    func addOcclusionBox(anchor: AnchorEntity) {
        let boxSize: Float = 2
        let boxMesh = MeshResource.generateBox(size: boxSize)
        let material = OcclusionMaterial()
        let occlusionBox = ModelEntity(mesh: boxMesh, materials: [material])
        occlusionBox.position.y = -boxSize / 2 - 0.001
        anchor.addChild(occlusionBox)
    }
    
}
