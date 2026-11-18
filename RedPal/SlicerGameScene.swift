import SpriteKit
import GameplayKit

class SlicerGameScene: SKScene {
    
    // MARK: - Proprietà di Gioco
    
    var SlicerGameData: SlicerGameData // Deve essere non opzionale (non 'SlicerGameData?')
    
    private var lastUpdateTime: TimeInterval = 0
    private var timeSinceLastSpawn: TimeInterval = 0
    private var slicerNode: SKSpriteNode!
    
    // Effetto scia del taglio
    private let sliceTrailLineWidth: CGFloat = 8.0
    private let sliceTrailGlowWidth: CGFloat = 3.0
    private let sliceTrailFadeDuration: TimeInterval = 0.25
    
    // Alternanza spawn
    private var spawnFromRight: Bool = false
    
    // Controlli anti-frustrazione per bombe
    private var lastBombSpawnTime: TimeInterval = -1000
    private var bombsAllowedInWave: Int = 3
    
    // MARK: - Azioni Audio (AGGIUNTE/CORRETTE)
    
    // Suono di taglio (Assumiamo che il file sia "katana tagliata.mp3")
    let cutSoundAction = SKAction.playSoundFileNamed("katana tagliata.mp3", waitForCompletion: false)
    
    // Suono Esplosione Bomba (Assicurati che il file si chiami "esplosione.wav" o .mp3)
    let bombSoundAction = SKAction.playSoundFileNamed("esplosione.mp3", waitForCompletion: false)

    // Helper: rispetta il toggle Settings "Sound effects"
    private func playEffect(_ action: SKAction) {
        let enabled = UserDefaults.standard.bool(forKey: "soundEffectsEnabled")
        if enabled {
            self.run(action)
        }
    }

    // Difficoltà dinamica
    private func scoreLevel50() -> Int { max(0, SlicerGameData.score / 50) }
    private func scoreLevel100() -> Int { max(0, SlicerGameData.score / 100) }
    
    private func bombsOnScreenCount() -> Int {
        var count = 0
        for child in children where child.name == "monster" {
            if let typeString = (child as? SKSpriteNode)?.userData?.value(forKey: "type") as? String, typeString == SlicerMonsterType.bomb.rawValue {
                count += 1
            }
        }
        return count
    }
    
    private func monstersOnScreenCount() -> Int {
        var count = 0
        for child in children where child.name == "monster" {
            if let typeString = (child as? SKSpriteNode)?.userData?.value(forKey: "type") as? String, typeString != SlicerMonsterType.bomb.rawValue {
                count += 1
            }
        }
        return count
    }
    
    private func maxBombsOnScreenCap() -> Int {
        // Scala con numero di mostri e punteggio
        let monsters = monstersOnScreenCount()
        if monsters >= 12 { return 5 }
        if monsters >= 8 { return 5 }
        if monsters >= 6 { return 4 }
        if monsters >= 4 { return 3 }
        let s = SlicerGameData.score
        if s >= 400 { return 5 }
        if s >= 300 { return 4 }
        if s >= 200 { return 3 }
        if s < 100 { return 2 }
        return 3
    }
    
    private func bombProbabilityPercent() -> Int {
        // Più difficile dopo 200 punti
        let s = SlicerGameData.score
        if s < 100 { return 15 }
        if s < 200 { return 35 }
        if s < 400 { return 50 }
        let extraSteps = (s - 400) / 100
        return min(75, 50 + extraSteps * 8)
    }
    
    // MARK: - Inizializzatori (CRUCIALE)
    
    // Inizializzatore necessario per l'iniezione dello stato da SwiftUI
    init(size: CGSize, SlicerGameData: SlicerGameData) {
        self.SlicerGameData = SlicerGameData
        super.init(size: size)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) non è implementato")
    }
    
    // MARK: - Setup
    
    override func didMove(to view: SKView) {
        physicsWorld.gravity = SlicerGameConstants.GRAVITY_VECTOR
        view.isMultipleTouchEnabled = false
            
        if SlicerGameConstants.LOAD_SKS_SCENE {
            loadDesignedSceneSafely()
        }
            
        if childNode(withName: "//arena") == nil {
            let background = SKSpriteNode(imageNamed: "arena")
            background.name = "arena"
            // Sposta lo sfondo leggermente a sinistra sottraendo un valore dalla coordinata x
            background.position = CGPoint(x: (size.width / 2) - 25, y: size.height / 2)
            background.zPosition = -1
            
            // Calcola la scala per riempire lo schermo ("aspect fill") senza stirare l'immagine.
            // In questo modo, l'immagine manterrà le sue proporzioni, coprirà l'intero schermo,
            // ma potrebbe essere ritagliata ai bordi se le proporzioni non corrispondono esattamente.
            if let textureSize = background.texture?.size(), textureSize.width > 0, textureSize.height > 0 {
                let scaleX = self.size.width / textureSize.width
                let scaleY = self.size.height / textureSize.height
                let scale = max(scaleX, scaleY) // Usa 'max' per riempire lo schermo (aspect fill)
                background.setScale(scale)
            } else {
                // Fallback nel caso in cui la texture non abbia dimensioni valide, riempie lo schermo stirando.
                background.size = self.size
            }

            addChild(background)
        }
            
        slicerNode = SKSpriteNode(imageNamed: SlicerGameConstants.SLICER_ASSET_IDLE)
        slicerNode.name = "slicerNode"
        slicerNode.position = CGPoint(x: size.width / 2, y: 50)
        slicerNode.zPosition = 10
        addChild(slicerNode)
            
        spawnMonster()
    }
    
    // MARK: - Game Loop (Update)
    
    override func update(_ currentTime: TimeInterval) {
        guard SlicerGameData.gameState == .playing else {
            self.isPaused = true
            return
        }
        self.isPaused = false
            
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
            
        timeSinceLastSpawn += deltaTime
        let lvl50 = scoreLevel50()
        let baseMax = SlicerGameConstants.MAX_SPAWN_INTERVAL
        let gentleAccel = min(lvl50, 6)
        let extraAccel = max(0, lvl50 - 6)
        // Boost inizio
        let earlyBoost: TimeInterval = SlicerGameData.score < 100 ? 0.22 : 0.0
        let spawnInterval = max(0.22, (baseMax - TimeInterval(gentleAccel) * 0.10 - TimeInterval(extraAccel) * 0.15 - earlyBoost))
        // Non aumentare troppo il numero: cap fisso a 3
        let multiSpawnCount = min(1 + max(lvl50 - 1, 0), 3)
            
        if timeSinceLastSpawn > spawnInterval {
            let score = SlicerGameData.score
            var defaultWaveBombCap = min(1 + (score / 100), 4)
            if score >= 200 { defaultWaveBombCap = max(defaultWaveBombCap, 2) }
            if score >= 300 { defaultWaveBombCap = max(defaultWaveBombCap, 3) }
            if score >= 400 { defaultWaveBombCap = max(defaultWaveBombCap, 4) }
            let crowd = monstersOnScreenCount() >= 12
            let heavyCrowdBonus = crowd ? 1 : (monstersOnScreenCount() >= 8 ? 1 : 0)
            var waveBombCap = min(defaultWaveBombCap + heavyCrowdBonus, 5)
            if crowd { waveBombCap = max(waveBombCap, 4) }
            bombsAllowedInWave = waveBombCap
            scheduleStaggeredSpawns(count: multiSpawnCount)
            timeSinceLastSpawn = 0
        }
            
        for child in children where child.name?.starts(with: "monster") ?? false {
            if child.position.y < -SlicerGameConstants.OBJECT_DIAMETER * 2 {
                child.removeFromParent()
            }
        }
    }
    
    override func didSimulatePhysics() {
        // Accelera la velocità massima di caduta fino a un cap più alto
        let boost = min(CGFloat(SlicerGameData.score) / 400.0, 1.0)
        let maxFallSpeed: CGFloat = -(190 + 110 * boost) // da ~-190 a ~-300
        for child in children where child.name == "monster" || child.name == "monster_sliced" {
            if let body = (child as? SKSpriteNode)?.physicsBody {
                if body.velocity.dy < maxFallSpeed {
                    body.velocity.dy = maxFallSpeed
                }
            }
        }
    }
    
    // MARK: - Logica di Spawn
    
    private func scheduleStaggeredSpawns(count: Int) {
        guard count > 0 else { return }
        spawnMonster()
        var actions: [SKAction] = []
        for _ in 1..<count {
            let wait = SKAction.wait(forDuration: TimeInterval.random(in: 0.12...0.35))
            let run = SKAction.run { [weak self] in self?.spawnMonster() }
            actions.append(wait)
            actions.append(run)
        }
        if !actions.isEmpty {
            run(SKAction.sequence(actions))
        }
    }

    private enum TrajectoryMode { case straight, arcUp, arcDown }

    private func applySpeedScaling(dx: CGFloat, dy: CGFloat) -> CGVector {
        let boost = min(CGFloat(SlicerGameData.score) / 400.0, 1.0)
        if dy < 0 {
            let factor = 1.0 + 0.8 * boost
            return CGVector(dx: dx, dy: dy * factor)
        } else {
            let factor = 1.0 + 0.35 * boost
            return CGVector(dx: dx, dy: dy * factor)
        }
    }

    private func computeSpawn(for type: SlicerMonsterType, hitRadius: CGFloat, size: CGSize) -> (position: CGPoint, velocity: CGVector) {
        let edgeMargin: CGFloat = 40
        let yStart: CGFloat = size.height + SlicerGameConstants.OBJECT_DIAMETER
        let chooseMode: TrajectoryMode = {
            let r = Int.random(in: 1...100)
            if r <= 35 { return .straight }
            if r <= 70 { return .arcUp }
            return .arcDown
        }()
        
        if SlicerGameData.score >= 50 {
            if type == .bomb {
                let preferCenter = Int.random(in: 0...100) < (SlicerGameData.score >= 200 ? 55 : 75)
                if preferCenter {
                    let xCenter = size.width / 2 + CGFloat.random(in: -60...60)
                    let mode = chooseMode
                    switch mode {
                    case .straight:
                        let dx: CGFloat = CGFloat.random(in: -25...25)
                        let dy: CGFloat = CGFloat.random(in: -100...(-65))
                        return (CGPoint(x: xCenter, y: yStart), applySpeedScaling(dx: dx, dy: dy))
                    case .arcUp:
                        let dx: CGFloat = CGFloat.random(in: -130...130)
                        let dy: CGFloat = CGFloat.random(in: 160...260)
                        return (CGPoint(x: xCenter, y: yStart), applySpeedScaling(dx: dx, dy: dy))
                    case .arcDown:
                        let dx: CGFloat = CGFloat.random(in: -100...100)
                        let dy: CGFloat = CGFloat.random(in: -120...(-70))
                        return (CGPoint(x: xCenter, y: yStart), applySpeedScaling(dx: dx, dy: dy))
                    }
                } else {
                    let useRight = Bool.random()
                    let xSide = useRight ? (size.width - hitRadius - edgeMargin) : (hitRadius + edgeMargin)
                    let xStart = max(hitRadius, min(size.width - hitRadius, xSide + CGFloat.random(in: -40...40)))
                    let direction: CGFloat = useRight ? -1.0 : 1.0
                    let mode = chooseMode
                    switch mode {
                    case .straight:
                        let dx = CGFloat.random(in: 60...120) * direction
                        let dy = CGFloat.random(in: -120...(-70))
                        return (CGPoint(x: xStart, y: yStart), applySpeedScaling(dx: dx, dy: dy))
                    case .arcUp:
                        let dx = CGFloat.random(in: 150...260) * direction
                        let dy = CGFloat.random(in: 180...300)
                        return (CGPoint(x: xStart, y: yStart), applySpeedScaling(dx: dx, dy: dy))
                    case .arcDown:
                        let dx = CGFloat.random(in: 100...200) * direction
                        let dy = CGFloat.random(in: -140...(-80))
                        return (CGPoint(x: xStart, y: yStart), applySpeedScaling(dx: dx, dy: dy))
                    }
                }
            } else {
                let useRight = (Bool.random() ? !spawnFromRight : spawnFromRight)
                spawnFromRight.toggle()
                let xSide = useRight ? (size.width - hitRadius - edgeMargin) : (hitRadius + edgeMargin)
                let highScoreJitter: ClosedRange<CGFloat> = (SlicerGameData.score >= 400) ? -90...90 : -35...35
                let xStart = max(hitRadius, min(size.width - hitRadius, xSide + CGFloat.random(in: highScoreJitter)))
                let mode = chooseMode
                switch mode {
                case .straight:
                    let direction: CGFloat = useRight ? -1.0 : 1.0
                    let dx = CGFloat.random(in: 10...50) * direction
                    let dy = CGFloat.random(in: -140...(-80))
                    return (CGPoint(x: xStart, y: yStart), applySpeedScaling(dx: dx, dy: dy))
                case .arcUp:
                    let direction: CGFloat = useRight ? -1.0 : 1.0
                    let dx = CGFloat.random(in: 120...230) * direction
                    let dy = CGFloat.random(in: 140...280)
                    return (CGPoint(x: xStart, y: yStart), applySpeedScaling(dx: dx, dy: dy))
                case .arcDown:
                    let direction: CGFloat = useRight ? -1.0 : 1.0
                    let dx = CGFloat.random(in: 90...200) * direction
                    let dy = CGFloat.random(in: -130...(-70))
                    return (CGPoint(x: xStart, y: yStart), applySpeedScaling(dx: dx, dy: dy))
                }
            }
        }
        // Default: dall'alto X casuale pre-50 pt
        let minX = hitRadius + edgeMargin
        let maxX = size.width - hitRadius - edgeMargin
        let xStart = CGFloat.random(in: minX...max(minX, maxX))
        let mode = chooseMode
        switch mode {
        case .straight:
            let dx = CGFloat.random(in: -20...20)
            let dy = CGFloat.random(in: -110...(-70))
            return (CGPoint(x: xStart, y: yStart), applySpeedScaling(dx: dx, dy: dy))
        case .arcUp:
            let dx = CGFloat.random(in: -130...130)
            let dy = CGFloat.random(in: 150...260)
            return (CGPoint(x: xStart, y: yStart), applySpeedScaling(dx: dx, dy: dy))
        case .arcDown:
            let dx = CGFloat.random(in: -100...100)
            let dy = CGFloat.random(in: -120...(-70))
            return (CGPoint(x: xStart, y: yStart), applySpeedScaling(dx: dx, dy: dy))
        }
    }

    private func spawnMonster() {
        let type: SlicerMonsterType
        let now = CACurrentMediaTime()
        let minBombGap: TimeInterval = SlicerGameData.score >= 200 ? 0.6 : 0.8
        let rolledBomb = Int.random(in: 1...100) <= bombProbabilityPercent()
        let bombsOnScreen = bombsOnScreenCount()
        let crowd12 = monstersOnScreenCount() >= 12
        let needMoreBombs = (SlicerGameData.score >= 200 && bombsOnScreen < 2) || (SlicerGameData.score >= 400 && bombsOnScreen < 3) || (crowd12 && bombsOnScreen < 4)
        let wantBomb = rolledBomb || needMoreBombs
        let canSpawnByCooldown = (now - lastBombSpawnTime) >= minBombGap
        let canSpawnByScreenCap = bombsOnScreen < maxBombsOnScreenCap()
        let canSpawnBombByWave = bombsAllowedInWave > 0 || needMoreBombs
        let canSpawnBomb = wantBomb && canSpawnBombByWave && canSpawnByCooldown && canSpawnByScreenCap
        if canSpawnBomb {
            type = .bomb
            if bombsAllowedInWave == 0 { bombsAllowedInWave = 1 }
            bombsAllowedInWave -= 1
            lastBombSpawnTime = now
        } else {
            guard let randomSliceableType = SlicerGameConstants.SLICEABLE_MONSTER_TYPES.randomElement() else { return }
            type = randomSliceableType
        }
        
        let monster = SKSpriteNode(imageNamed: type.assetName)
        monster.name = "monster"
        monster.zPosition = 0
        monster.userData = NSMutableDictionary()
        monster.userData?.setValue(type.rawValue, forKey: "type")
        monster.size = CGSize(width: SlicerGameConstants.OBJECT_DIAMETER, height: SlicerGameConstants.OBJECT_DIAMETER)
            
        let hitRadius = monster.size.width / 2 * 0.9
        monster.physicsBody = SKPhysicsBody(circleOfRadius: hitRadius)
        if let body = monster.physicsBody {
            body.isDynamic = true
            body.affectedByGravity = true
            body.categoryBitMask = SlicerGameConstants.MonsterCategory
            body.collisionBitMask = 0
            body.linearDamping = 0.6
            body.angularDamping = 0.3
        }
            
        let spawn = computeSpawn(for: type, hitRadius: hitRadius, size: size)
        monster.position = spawn.position
        if let body = monster.physicsBody {
            body.velocity = spawn.velocity
            body.angularVelocity = CGFloat.random(in: -0.8...0.8)
        }
            
        addChild(monster)
    }
    
    // MARK: - Taglio (Input Touch)
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, SlicerGameData.gameState == .playing, self.isPaused == false else { return }
            
        let location = touch.location(in: self)
        let previousLocation = touch.previousLocation(in: self)
            
        drawSliceTrail(from: previousLocation, to: location)
            
        let dx = location.x - previousLocation.x
        let sliceDirection: String = (dx > 5) ? SlicerGameConstants.SLICER_ASSET_CUT_RIGHT : (dx < -5 ? SlicerGameConstants.SLICER_ASSET_CUT_LEFT : SlicerGameConstants.SLICER_ASSET_IDLE)
        animateSlicer(to: sliceDirection)
            
        let affectedNodes = nodes(at: location)
            
        for node in affectedNodes where node.name == "monster" {
            guard let monsterNode = node as? SKSpriteNode,
                  let SlicerMonsterTypeString = monsterNode.userData?.value(forKey: "type") as? String,
                  let SlicerMonsterType = SlicerMonsterType(rawValue: SlicerMonsterTypeString)
            else { continue }
                
            let radius = monsterNode.size.width / 2 * 0.9
                
            if checkLineCircleIntersection(p1: previousLocation, p2: location, circle: monsterNode.position, radius: radius) {
                
                // LOGICA AGGIUNTA: Scegli il suono da riprodurre rispettando il toggle
                if SlicerMonsterType == .bomb {
                    // Effetto e suono esplosione
                    showBombSliceEffect(at: monsterNode.position)
                } else {
                    // Suono di taglio normale
                    playEffect(cutSoundAction)
                }
                
                sliceMonster(monsterNode: monsterNode, type: SlicerMonsterType, previousLocation: previousLocation, currentLocation: location)
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard self.isPaused == false else { return }
        if slicerNode != nil {
            animateSlicer(to: SlicerGameConstants.SLICER_ASSET_IDLE)
        }
    }
    
    // MARK: - Funzioni Helper
    
    private func checkLineCircleIntersection(p1: CGPoint, p2: CGPoint, circle: CGPoint, radius: CGFloat) -> Bool {
        let dp = CGPoint(x: p2.x - p1.x, y: p2.y - p1.y)
        let pc = CGPoint(x: circle.x - p1.x, y: circle.y - p1.y)
        let lenSq = dp.x * dp.x + dp.y * dp.y
            
        if lenSq == 0 {
            let distanceSq = pc.x * pc.x + pc.y * pc.y
            return distanceSq < radius * radius
        }
            
        var t = (pc.x * dp.x + pc.y * dp.y) / lenSq
        t = max(0, min(1, t))
            
        let closestPoint = CGPoint(x: p1.x + t * dp.x, y: p1.y + t * dp.y)
        let dx = circle.x - closestPoint.x
        let dy = circle.y - closestPoint.y
        let distanceSq = dx * dx + dy * dy
            
        return distanceSq < radius * radius
    }

    private func animateSlicer(to assetName: String) {
        guard slicerNode != nil else { return }
        if slicerNode.action(forKey: "cutAnimation") != nil {
            return
        }
            
        if assetName == SlicerGameConstants.SLICER_ASSET_IDLE {
            slicerNode.texture = SKTexture(imageNamed: assetName)
            return
        }

        let cutAction = SKAction.setTexture(SKTexture(imageNamed: assetName))
        let waitAction = SKAction.wait(forDuration: 0.1)
        let returnToIdle = SKAction.setTexture(SKTexture(imageNamed: SlicerGameConstants.SLICER_ASSET_IDLE))
            
        let sequence = SKAction.sequence([cutAction, waitAction, returnToIdle])
        slicerNode.run(sequence, withKey: "cutAnimation")
    }
    
    func sliceMonster(monsterNode: SKSpriteNode, type: SlicerMonsterType, previousLocation: CGPoint, currentLocation: CGPoint) {
            
        let originalVelocity = monsterNode.physicsBody?.velocity ?? CGVector.zero
            
        monsterNode.removeFromParent()
            
        if type == .bomb {
            SlicerGameData.score += type.points
            // La chiamata al suono e all'effetto visivo è gestita in showBombSliceEffect ora
            // showBombSliceEffect(at: monsterNode.position) // Non serve più qui se la chiami in touchesMoved
            children.filter { $0.name == "monster" }.forEach { $0.removeFromParent() }
            return
        }
        
        SlicerGameData.score += type.points
            
        guard let halfAssetNames = type.halfAssetNames else { return }
        let (assetA, assetB) = halfAssetNames
            
        let dx = currentLocation.x - previousLocation.x
        let dy = currentLocation.y - previousLocation.y
        let sliceAngleRad = atan2(dy, dx)
            
        let partA = createSlicedPart(textureName: assetA, position: monsterNode.position, angle: sliceAngleRad, multiplier: 1, originalVelocity: originalVelocity)
        let partB = createSlicedPart(textureName: assetB, position: monsterNode.position, angle: sliceAngleRad, multiplier: -1, originalVelocity: originalVelocity)
            
        addChild(partA)
        addChild(partB)
    }
    
    func createSlicedPart(textureName: String, position: CGPoint, angle: CGFloat, multiplier: CGFloat, originalVelocity: CGVector) -> SKSpriteNode {
        let part = SKSpriteNode(imageNamed: textureName)
        part.position = position
        part.zPosition = 0
        part.name = "monster_sliced"
        part.size = CGSize(width: SlicerGameConstants.OBJECT_DIAMETER, height: SlicerGameConstants.OBJECT_DIAMETER)
            
        part.physicsBody = SKPhysicsBody(circleOfRadius: part.size.width / 4)
        part.physicsBody?.isDynamic = true
        part.physicsBody?.affectedByGravity = true
        part.physicsBody?.collisionBitMask = 0
        part.physicsBody?.linearDamping = 0.35
        part.physicsBody?.angularDamping = 0.25
            
        let separationForce: CGFloat = 600.0
        let velocityX = originalVelocity.dx + cos(angle + CGFloat.pi / 2) * separationForce * multiplier
        let velocityY = originalVelocity.dy + sin(angle + CGFloat.pi / 2) * separationForce * multiplier
            
        part.zRotation = angle
            
        part.physicsBody?.velocity = CGVector(dx: velocityX, dy: velocityY)
        part.physicsBody?.angularVelocity = CGFloat.random(in: -3.0...3.0)
            
        let fadeOut = SKAction.sequence([
            SKAction.wait(forDuration: 0.6),
            SKAction.fadeOut(withDuration: 1.0),
            SKAction.removeFromParent()
        ])
        part.run(fadeOut)
            
        return part
    }
    
    private func drawSliceTrail(from start: CGPoint, to end: CGPoint) {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
            
        let trail = SKShapeNode(path: path)
        trail.strokeColor = .white
        trail.lineWidth = sliceTrailLineWidth
        trail.glowWidth = sliceTrailGlowWidth
        trail.zPosition = 100
        trail.alpha = 0.9
        trail.blendMode = .add
        addChild(trail)
            
        let fade = SKAction.fadeOut(withDuration: sliceTrailFadeDuration)
        let remove = SKAction.removeFromParent()
        trail.run(SKAction.sequence([fade, remove]))
    }
    
    private func showBombSliceEffect(at position: CGPoint) {
        
        // Suono esplosione rispettando il toggle effetti
        playEffect(bombSoundAction)

        if let explosion = SKEmitterNode(fileNamed: "BombExplosion") {
            explosion.position = position
            explosion.zPosition = 50
            addChild(explosion)
            explosion.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.6),
                SKAction.removeFromParent()
            ]))
        } else {
            let ring = SKShapeNode(circleOfRadius: 20)
            ring.position = position
            ring.strokeColor = .red
            ring.glowWidth = 6
            ring.lineWidth = 6
            ring.zPosition = 50
            addChild(ring)
            let expand = SKAction.scale(to: 6.0, duration: 0.4)
            let fade = SKAction.fadeOut(withDuration: 0.4)
            ring.run(SKAction.sequence([SKAction.group([expand, fade]), SKAction.removeFromParent()]))
        }
            
        let flash = SKSpriteNode(color: .red, size: CGSize(width: size.width, height: size.height))
        flash.position = CGPoint(x: size.width/2, y: size.height/2)
        flash.zPosition = 200
        flash.alpha = 0.0
        addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.35, duration: 0.06),
            SKAction.fadeOut(withDuration: 0.25),
            SKAction.removeFromParent()
        ]))
            
        let shakeX: CGFloat = 10
        let shakeY: CGFloat = 8
        let duration: TimeInterval = 0.25
        let steps = 5
        var actions: [SKAction] = []
        for _ in 0..<steps {
            let dx = CGFloat.random(in: -shakeX...shakeX)
            let dy = CGFloat.random(in: -shakeY...shakeY)
            actions.append(SKAction.moveBy(x: dx, y: dy, duration: duration/Double(steps)))
        }
        actions.append(SKAction.move(to: .zero, duration: 0.05))
        self.run(SKAction.sequence(actions))
    }
    
    private func removeStaticLeftTomatoIfPresent() {
        if let left = childNode(withName: "//pomodoro_left") ?? childNode(withName: "//tomato_left") ?? childNode(withName: "//pomodoro_sx") {
            left.removeFromParent()
            return
        }
        let leftCandidates = children.compactMap { $0 as? SKSpriteNode }
            .filter { ($0.name?.contains("pomodoro") ?? false) || ($0.name?.contains("tomato") ?? false) }
            .sorted { $0.position.x < $1.position.x }
        if let leftMost = leftCandidates.first, leftMost.physicsBody == nil || leftMost.physicsBody?.isDynamic == false {
            leftMost.removeFromParent()
        }
    }
    
    private func findSlicerNodeInScene() -> SKSpriteNode? {
        return nil
    }
    
    private func loadDesignedSceneSafely() {
        if let designedScene = SKScene(fileNamed: "MyScene") {
            importSafeChildren(from: designedScene)
            removeStaticLeftTomatoIfPresent()
            return
        }
        if let path = Bundle.main.path(forResource: "MyScene", ofType: "sks") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                if let decodedScene = try NSKeyedUnarchiver.unarchivedObject(ofClass: SKScene.self, from: data) {
                    importSafeChildren(from: decodedScene)
                    removeStaticLeftTomatoIfPresent()
                }
            } catch {
                
            }
        }
    }

    private func importSafeChildren(from scene: SKScene) {
        for child in scene.children {
            if child is SKSpriteNode || child is SKShapeNode || child is SKLabelNode || child is SKEmitterNode {
                child.removeFromParent()
                addChild(child)
            }
        }
    }
}

