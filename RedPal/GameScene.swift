import SpriteKit
import SwiftUI

// MARK: - Notification Extensions

extension Notification.Name {
    static let pomodoroEnded = Notification.Name("pomodoroEnded")
    static let musicPreferenceChanged = Notification.Name("musicPreferenceChanged")
    static let buttonTapped = Notification.Name("buttonTapped")
    static let resumeAfterBoss = Notification.Name("resumeAfterBoss")
    static let showHomePergamena = Notification.Name("showHomePergamena")
    // Notifica di esclusività musicale: quando una sorgente parte, le altre si fermano
    static let musicExclusiveStart = Notification.Name("musicExclusiveStart")
    // NUOVO: training completato con successo (+1 esperienza)
    static let trainingCompleted = Notification.Name("trainingCompleted")
    static let gameTimerFinished = Notification.Name("gameTimerFinished") // AGGIUNTA
}

// MARK: - Custom Button Node

class ButtonNode: SKSpriteNode {
    var buttonName: String
    private let verticalOffset: CGFloat = 0
    
    init(imageNamed: String, name: String) {
        self.buttonName = name
        super.init(texture: SKTexture(imageNamed: imageNamed), color: .white, size: SKTexture(imageNamed: imageNamed).size())
        self.name = name
        self.isUserInteractionEnabled = true
        self.texture?.filteringMode = .nearest
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func contains(_ p: CGPoint) -> Bool {
        return super.contains(p)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        alpha = 0.7
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        alpha = 1.0
        NotificationCenter.default.post(name: .buttonTapped, object: nil, userInfo: ["buttonName": buttonName])
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        alpha = 1.0
    }
}

class GameScene: SKScene {
    
    // MARK: - Properties
    
    // Session Manager (iniettato da SKSGameView)
    weak var sessionManager: SessionManager?
    
    // Background
    private var bg1: SKSpriteNode?
    private var bg2: SKSpriteNode?
    private let bgSpeed: CGFloat = 15
    
    // Terrain
    private var dirts: [SKSpriteNode] = []
    private let dirtSpeed: CGFloat = 300
    
    // Trees
    private var Alberi1: SKSpriteNode?
    private var Alberi2: SKSpriteNode?
    private let alberiSpeed: CGFloat = 150
    
    // Timer
    private var tempo = SKLabelNode()
    private var previousTime = TimeInterval()
    private var timerValue: Int = 25 * 60 // Usa il valore corretto per una sessione Pomodoro
    private var lastUpdateTime: TimeInterval = 0
    private var initialTimerValue: Int = 2 * 1 // salva il valore iniziale per i restart
    
    // Game State
    private var hasEnded = false
    private var isMenuOpen = false
    
    // Hero
    private var pomyNode: SKSpriteNode?
    private var pomyAttackNode: SKSpriteNode? // NUOVO: Nodo per l'animazione di attacco
    
    // NUOVO: Offset per la posizione del nodo di attacco rispetto a Pomy
    private let pomyAttackOffsetX: CGFloat = 80
    private let pomyAttackOffsetY: CGFloat = 0
    
    // Audio
    private var musicNode: SKAudioNode?
    private var musicObserver: NSObjectProtocol?
    private var buttonObserver: NSObjectProtocol?
    private var bossObserver: NSObjectProtocol?
    private var exclusiveObserver: NSObjectProtocol?
    
    // Toggle grafico nel menu di pausa
    private var musicToggleNode: SKNode?
    
    // Dimensioni e posizione del toggle musica
    private let musicToggleSize = CGSize(width: 220, height: 80)
    private let musicToggleKnobRadius: CGFloat = 34
    private let musicToggleYOffsetPosition: CGFloat = -300
    
    // MiniMob
    private var miniMobPrototype: SKSpriteNode?
    private var miniMobs: [SKSpriteNode] = []
    private let miniMobScale: CGFloat = 0.33
    private let miniMobYOffset: CGFloat = -190
    private var activeCollisionMob: SKSpriteNode?
    private let pomyCollisionInset = CGSize(width: 0.25, height: 0.35)
    private let miniMobCollisionInset = CGSize(width: 0.35, height: 0.45)
    
    // Identificatore univoco per esclusività musicale di questa scena
    private let musicTrackID = "GameScene.SottofondoLoop"
    
    // MARK: - Scene Setup
    
    static func fromSKS() -> GameScene {
        guard let scene = GameScene(fileNamed: "GameScene") else {
            fatalError("GameScene.sks not found")
        }
        scene.scaleMode = .aspectFill
        return scene
    }
    
    override func didMove(to view: SKView) {
        isUserInteractionEnabled = true
        
        childNode(withName: "//exitButton")?.isHidden = true
        
        setupBackgroundIfNeeded()
        setupDirtsIfNeeded()
        startPomyRun()
        setupAttackNode() // AGGIUNTO
        setupAlberi()
        setupTimer()
        addPauseButton()
        setupMusic()
        setupButtonListener()
        setupMiniMob()
        startMiniMobSpawner()
        
        // Salva il valore iniziale del timer (per i restart)
        initialTimerValue = timerValue
        
        // Osserva la chiusura BossBattle con richiesta di ripresa timer
        bossObserver = NotificationCenter.default.addObserver(
            forName: .resumeAfterBoss,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.restartTimerAndResume()
        }
        
        // Osserva avvii musicali esclusivi da altre sorgenti
        exclusiveObserver = NotificationCenter.default.addObserver(
            forName: .musicExclusiveStart,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self = self else { return }
            let otherID = note.userInfo?["id"] as? String
            if otherID != self.musicTrackID {
                self.pauseMusic()
            }
        }
    }
    
    override func willMove(from view: SKView) {
        musicNode?.run(.stop())
        
        if let obs = musicObserver { NotificationCenter.default.removeObserver(obs); musicObserver = nil }
        if let obs = buttonObserver { NotificationCenter.default.removeObserver(obs); buttonObserver = nil }
        if let obs = bossObserver { NotificationCenter.default.removeObserver(obs); bossObserver = nil }
        if let obs = exclusiveObserver { NotificationCenter.default.removeObserver(obs); exclusiveObserver = nil }
        
        removeAction(forKey: "miniMobSpawner")
    }
    
    // MARK: - Restart timer e ripresa gioco
    
    private func restartTimerAndResume() {
        closeEndMenu()
        hasEnded = false
        isMenuOpen = false
        
        timerValue = initialTimerValue
        tempo.text = formatTime(timerValue)
        previousTime = 0
        
        resumeHeroAnimation()
        // Riprendi o no la musica in base alle preferenze utente
        resumeMusic()
    }
    
    // MARK: - Setup Methods
    
    private func setupTimer() {
        tempo = SKLabelNode()
        tempo.fontSize = 85
        tempo.fontName = "AvenirNext-Bold" // Correzione del font
        tempo.fontColor = .white
        tempo.position = CGPoint(x: 0, y: 880)
        tempo.zPosition = 100
        tempo.text = formatTime(timerValue)
        scene?.addChild(tempo)
    }
    
    private func setupMusic() {
        if let node = childNode(withName: "//SottofondoLoop") as? SKAudioNode {
            musicNode = node
        } else {
            let node = SKAudioNode(fileNamed: "SottofondoLoop")
            node.autoplayLooped = true
            node.isPositional = false
            node.name = "SottofondoLoop"
            addChild(node)
            musicNode = node
        }
        
        guard let node = musicNode else { return }
        let enabled = UserDefaults.standard.bool(forKey: "musicEnabled")
        
        NotificationCenter.default.post(name: .musicExclusiveStart, object: nil, userInfo: ["id": musicTrackID])
        
        if enabled {
            node.run(.play())
        } else {
            node.run(.stop())
        }
        
        musicObserver = NotificationCenter.default.addObserver(
            forName: .musicPreferenceChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            let enabled = UserDefaults.standard.bool(forKey: "musicEnabled")
            if enabled {
                NotificationCenter.default.post(name: .musicExclusiveStart, object: nil, userInfo: ["id": self.musicTrackID])
                self.resumeMusic()
            } else {
                self.pauseMusic()
            }
            if let toggle = self.musicToggleNode {
                self.updateMusicToggleVisual(toggle, enabled: enabled)
            }
        }
    }
    
    // MARK: - Hero Animation
    
    private func startPomyRun() {
        guard let pomy = childNode(withName: "//pomy") as? SKSpriteNode else { return }
        
        pomyNode = pomy
        let atlas = SKTextureAtlas(named: "Corsa")
        
        atlas.preload { [weak pomy] in
            guard let pomy = pomy else { return }
            
            let orderedNames = atlas.textureNames
                .filter { $0.hasPrefix("run_") }
                .sorted {
                    let A = Int($0.replacingOccurrences(of: "run_", with: "")) ?? 0
                    let B = Int($1.replacingOccurrences(of: "run_", with: "")) ?? 0
                    return A < B
                }
            
            let frames = orderedNames.map { atlas.textureNamed($0) }
            frames.forEach { $0.filteringMode = .nearest }
            
            if let first = frames.first {
                pomy.texture = first
                pomy.colorBlendFactor = 0
            }
            
            let anim = SKAction.animate(
                with: frames,
                timePerFrame: 0.058,
                resize: false,
                restore: false
            )
            pomy.run(.repeatForever(anim), withKey: "run")
        }
    }
    
    // NUOVO: Setup per il nodo di attacco
    private func setupAttackNode() {
        if let attackNode = childNode(withName: "//Pomyattacco") as? SKSpriteNode {
            self.pomyAttackNode = attackNode
            // Nascondi o sposta fuori dallo schermo finché non è necessario
            self.pomyAttackNode?.zPosition = -100
        } else {
            print("ATTENZIONE: Il nodo 'Pomyattacco' non è stato trovato in GameScene.sks!")
        }
    }
    
    private func pauseHeroAnimation() {
        guard let pomy = pomyNode else { return }
        pomy.isPaused = true
    }
    
    private func resumeHeroAnimation() {
        guard let pomy = pomyNode else { return }
        pomy.isPaused = false
    }
    
    // MARK: - Background Setup (omessi per brevità, sono identici)
    
    private func setupBackgroundIfNeeded() {
        if let a = childNode(withName: "//bg1") as? SKSpriteNode,
           let b = childNode(withName: "//bg2") as? SKSpriteNode {
            bg1 = a; bg2 = b; alignBackgroundPair(); return
        }
        if let single = childNode(withName: "//bg") as? SKSpriteNode {
            let clone = single.copy() as! SKSpriteNode; clone.name = "bg2"; single.name = "bg1"
            clone.position = CGPoint(x: single.position.x + single.size.width, y: single.position.y)
            addChild(clone); bg1 = single; bg2 = clone; alignBackgroundPair()
        }
    }
    
    private func alignBackgroundPair() {
        guard let a = bg1, let b = bg2 else { return }
        if a.position.x > b.position.x { bg1 = b; bg2 = a }
        bg2!.position.x = bg1!.position.x + bg1!.size.width
    }
    
    // MARK: - Terrain Setup (omessi per brevità, sono identici)
    
    private func setupDirtsIfNeeded() {
        let candidateNames = ["//dirt1", "//dirt2", "//dirt3"]; var found: [SKSpriteNode] = []
        for name in candidateNames { if let node = childNode(withName: name) as? SKSpriteNode { found.append(node) } }
        guard !found.isEmpty else { return }
        found.sort { $0.frame.minX < $1.frame.minX }; self.dirts = found
        for d in dirts { d.zPosition = 1 }; alignDirts()
    }
    
    private func alignDirts() {
        guard !dirts.isEmpty else { return }
        dirts.sort { $0.frame.minX < $1.frame.minX }
        for i in 1..<dirts.count {
            let left = dirts[i - 1]; let right = dirts[i]
            right.position.x = left.frame.maxX + (right.frame.width * 0.5)
        }
    }
    
    // MARK: - Trees Setup (omessi per brevità, sono identici)
    
    private func setupAlberi() {
        if let a = childNode(withName: "//Alberi1") as? SKSpriteNode,
           let b = childNode(withName: "//Alberi2") as? SKSpriteNode {
            Alberi1 = a; Alberi2 = b; return
        }
        if let one = childNode(withName: "//Alberi") as? SKSpriteNode {
            let clone = one.copy() as! SKSpriteNode; clone.name = "Alberi2"; one.name = "Alberi1"
            clone.position = CGPoint(x: one.position.x + one.size.width, y: one.position.y)
            addChild(clone); Alberi1 = one; Alberi2 = clone
        }
        if let a = Alberi1 { a.texture?.filteringMode = .nearest }
        if let b = Alberi2 { b.texture?.filteringMode = .nearest }
    }
    
    // MARK: - Update Loop
    
    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        
        updateTimer(currentTime)
        
        if !isMenuOpen && !hasEnded {
            moveBackground(dt: dt)
            moveDirts(dt: dt)
            moveAlberi(dt)
            moveMiniMobs(dt)
            checkPomyMiniMobCollision()
        }
    }
    
    private func updateTimer(_ currentTime: TimeInterval) {
        if previousTime == 0 {
            previousTime = currentTime
            return
        }
        
        guard currentTime - previousTime >= 1 else { return }
        previousTime = currentTime
        
        guard !isMenuOpen && !hasEnded else { return }
        
        timerValue = max(0, timerValue - 1)
        tempo.text = formatTime(timerValue)
        
        guard timerValue == 0 else { return }
        
        hasEnded = true
        tempo.text = "00:00"
        isMenuOpen = true
        isPaused = false
        
        pauseHeroAnimation()
        showEndMenu()
        NotificationCenter.default.post(name: .pomodoroEnded, object: nil)
        NotificationCenter.default.post(name: .gameTimerFinished, object: nil) // AGGIUNTA
    }
    
    // MARK: - Movement (omessi per brevità, sono identici)
    
    private func moveBackground(dt: TimeInterval) {
        guard let a = bg1, let b = bg2, dt > 0 else { return }
        let dx = bgSpeed * CGFloat(dt); a.position.x -= dx; b.position.x -= dx
        if a.position.x <= -a.size.width { a.position.x = b.position.x + b.size.width; bg1 = b; bg2 = a }
        else if b.position.x <= -b.size.width { b.position.x = a.position.x + a.size.width; bg1 = a; bg2 = b }
    }
    
    private func moveDirts(dt: TimeInterval) {
        guard dt > 0, !dirts.isEmpty else { return }
        let dx = dirtSpeed * CGFloat(dt); for d in dirts { d.position.x -= dx }
        let leftEdge = self.frame.minX
        while let first = dirts.first, let last = dirts.last, first.frame.maxX <= leftEdge {
            first.position.x = last.frame.maxX + (first.frame.width * 0.5); dirts.removeFirst(); dirts.append(first)
        }
    }
    
    private func moveAlberi(_ dt: TimeInterval) {
        guard let a = Alberi1, let b = Alberi2, dt > 0 else { return }
        let dx = alberiSpeed * CGFloat(dt); a.position.x -= dx; b.position.x -= dx
        if a.position.x <= -a.size.width { a.position.x = b.position.x + b.size.width }
        if b.position.x <= -b.size.width { b.position.x = a.position.x + a.size.width }
    }
    
    // MARK: - Touch Handling (omessi per brevità, sono identici)

    private func isInsideMusicCapsule(_ node: SKNode) -> Bool {
        var n: SKNode? = node
        while let current = n {
            if current.name == "capsule" { return true }
            n = current.parent
        }
        return false
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        
        if !isMenuOpen, let nodeName = atPoint(point).name, nodeName == "pauseButton" {
            pauseAndOpenMenu()
            return
        }
        
        if isMenuOpen {
            let node = atPoint(point)
            if isInsideMusicCapsule(node) {
                toggleMusicPreference()
                return
            }
        }
    }
    
    private func setupButtonListener() {
        buttonObserver = NotificationCenter.default.addObserver(
            forName: .buttonTapped,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let buttonName = notification.userInfo?["buttonName"] as? String else { return }
            
            self.handleButtonTap(buttonName)
        }
    }
    
    private func handleButtonTap(_ buttonName: String) {
        switch buttonName {
        case "btnResume":
            closePauseMenu()
            resumeGame()
        case "btnExit":
            NotificationCenter.default.post(name: Notification.Name("goBack"), object: nil)
        case "btnRelax":
            closeEndMenu()
            presentRelaxScene()
        case "btnTraining":
            closeEndMenu()
            presentTrainingSwiftUI()
        case "btnBoss":
            closeEndMenu()
            presentBossBattleSwiftUI()
        default:
            break
        }
    }
    
    // MARK: - Scene Presentation
    
    private func presentTrainingScene() {
        guard let view = self.view else { return }
        let transition = SKTransition.crossFade(withDuration: 0.5)
        let scene = TrainingScene.fromSKS() // NOTA: TrainingScene non è definita qui
        scene.scaleMode = .aspectFill
        view.presentScene(scene, transition: transition)
    }
    
    private func presentBossScene() {
        guard let view = self.view else { return }
        let transition = SKTransition.crossFade(withDuration: 0.5)
        let scene = BossScene.fromSKS() // NOTA: BossScene non è definita qui
        scene.scaleMode = .aspectFill
        view.presentScene(scene, transition: transition)
    }
    
    private func presentRelaxScene() {
        guard let view = self.view else { return }
        let transition = SKTransition.crossFade(withDuration: 0.5)
        let scene = RelaxScene.fromSKS() // NOTA: RelaxScene non è definita qui
        scene.scaleMode = .aspectFill
        scene.sessionManager = self.sessionManager
        view.presentScene(scene, transition: transition)
    }
    
    // MARK: - Presentazione SwiftUI

    private func presentBossBattleSwiftUI() {
        pauseHeroAnimation()
        
        guard let skView = self.view else { return }

        let presenter: UIViewController?
        if let root = skView.window?.rootViewController {
            presenter = topMostViewController(from: root)
        } else {
            presenter = sequence(first: skView.next, next: { $0?.next })
                .first(where: { $0 is UIViewController }) as? UIViewController
        }
        guard let hostVC = presenter else { return }

        // Usa AnyView per unificare i due rami (con/senza environmentObject)
        let rootAnyView: AnyView
        if let sm = sessionManager {
            rootAnyView = AnyView(BossBattleView().environmentObject(sm)) // BossBattleView non è definita qui
        } else {
            rootAnyView = AnyView(BossBattleView())
        }
        let bossVC = UIHostingController(rootView: rootAnyView)
        bossVC.modalPresentationStyle = .fullScreen
        hostVC.present(bossVC, animated: true, completion: nil)
    }
    
    private func presentTrainingSwiftUI() {
        pauseHeroAnimation()

        guard let skView = self.view else { return }

        let presenter: UIViewController?
        if let root = skView.window?.rootViewController {
            presenter = topMostViewController(from: root)
        } else {
            presenter = sequence(first: skView.next, next: { $0?.next })
                .first(where: { $0 is UIViewController }) as? UIViewController
        }
        guard let hostVC = presenter else { return }

        // AGGIUNTO: inietta SessionManager se disponibile
        let rootAnyView: AnyView
        if let sm = sessionManager {
             rootAnyView = AnyView(SlicerGameView().environmentObject(sm)) // SlicerGameView non è definita qui
        } else {
             rootAnyView = AnyView(SlicerGameView())
        }
        let trainingVC = UIHostingController(rootView: rootAnyView)
        trainingVC.modalPresentationStyle = .fullScreen
        hostVC.present(trainingVC, animated: true, completion: nil)
    }

    private func topMostViewController(from root: UIViewController) -> UIViewController {
        var top = root
        while let presented = top.presentedViewController { top = presented }
        if let nav = top as? UINavigationController, let visible = nav.visibleViewController {
            return topMostViewController(from: visible)
        }
        if let tab = top as? UITabBarController, let selected = tab.selectedViewController {
            return topMostViewController(from: selected)
        }
        return top
    }
    
    // MARK: - UI Elements (omessi per brevità, sono identici)

    private func addPauseButton() {
        let sprite = SKSpriteNode(imageNamed: "PauseIcon")
        sprite.name = "pauseButton"; sprite.zPosition = 1000; sprite.setScale(0.2)
        sprite.texture?.filteringMode = .nearest
        sprite.position = CGPoint(x: frame.minX + 150, y: frame.maxY - 300)
        addChild(sprite)
    }

    private func makeRoundedCard(size: CGSize, cornerRadius: CGFloat, textureName: String) -> SKNode {
        let container = SKNode(); container.zPosition = 2
        let shadowPath = CGPath(roundedRect: CGRect(origin: CGPoint(x: -size.width/2, y: -size.height/2), size: size), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        let shadow = SKShapeNode(path: shadowPath); shadow.fillColor = .black.withAlphaComponent(0.4); shadow.strokeColor = .clear
        shadow.zPosition = 1; shadow.position = CGPoint(x: 0, y: -10); container.addChild(shadow)
        let crop = SKCropNode(); crop.zPosition = 2
        let maskShape = SKShapeNode(path: shadowPath); maskShape.fillColor = .white; maskShape.strokeColor = .clear
        crop.maskNode = maskShape
        let bg = SKSpriteNode(texture: SKTexture(imageNamed: textureName)); bg.texture?.filteringMode = .nearest
        bg.size = size; bg.position = .zero; crop.addChild(bg); container.addChild(crop)
        return container
    }
    
    // MARK: - Menu Panels (omessi per brevità, sono identici)
    
    private func makePergamenaPanel(name: String) -> SKNode {
        let panel = SKNode(); panel.name = name; panel.zPosition = 5000; panel.position = CGPoint(x: frame.midX, y: frame.midY)
        panel.isUserInteractionEnabled = false; addChild(panel)
        let dim = SKSpriteNode(color: .black.withAlphaComponent(0.55), size: CGSize(width: size.width * 2, height: size.height * 2))
        dim.position = .zero; dim.zPosition = 1; dim.name = "dim"; dim.isUserInteractionEnabled = false; panel.addChild(dim)
        let pergamena = SKSpriteNode(imageNamed: "SfondoSettings"); pergamena.position = .zero; pergamena.zPosition = 2
        pergamena.name = "pergamena"; pergamena.texture?.filteringMode = .nearest; pergamena.setScale(0.7)
        pergamena.isUserInteractionEnabled = false; panel.addChild(pergamena)
        return panel
    }
    
    private func showPauseMenu() {
        guard childNode(withName: "pausePanel") == nil else { return }
        let panel = makePergamenaPanel(name: "pausePanel")
        guard let perg = panel.childNode(withName: "pergamena") else { return }
        let topY = perg.frame.maxY; let bottomY = perg.frame.minY; let innerMargin: CGFloat = 80
        let title = SKLabelNode(fontNamed: "PressStart2P"); title.fontSize = 36; title.fontColor = .black
        title.verticalAlignmentMode = .top; title.horizontalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: topY - innerMargin); title.zPosition = perg.zPosition + 1
        panel.addChild(title)
        let header = SKSpriteNode(imageNamed: "PauseMenu"); header.texture?.filteringMode = .nearest
        header.setScale(0.8); header.position = CGPoint(x: 0, y: title.position.y - 80); header.zPosition = perg.zPosition + 1
        panel.addChild(header)
        func createButton(_ img: String, _ name: String, _ y: CGFloat) -> ButtonNode {
            let button = ButtonNode(imageNamed: img, name: name); button.zPosition = 10000; button.xScale = 0.85
            button.yScale = 0.70; button.position = CGPoint(x: 0, y: y); return button
        }
        let buttonVerticalOffset: CGFloat = 15; let buttonsTopY = header.position.y - 260
        panel.addChild(createButton("ResumeBtn", "btnResume", buttonsTopY + buttonVerticalOffset))
        panel.addChild(createButton("ExitBtn", "btnExit", buttonsTopY - 210 + buttonVerticalOffset))
        let rowWidth = min(perg.frame.width - innerMargin * 2, 900)
        let toggleRow = makeMusicToggleNode(rowWidth: rowWidth); let desiredY = musicToggleYOffsetPosition
        let minY = bottomY + innerMargin + musicToggleSize.height/2; let maxY = buttonsTopY - 260 + buttonVerticalOffset
        toggleRow.position = CGPoint(x: 0, y: max(min(desiredY, maxY), minY)); panel.addChild(toggleRow)
        musicToggleNode = toggleRow
    }
    
    private func showEndMenu() {
        guard childNode(withName: "endPanel") == nil else { return }
        let panel = makePergamenaPanel(name: "endPanel"); guard let perg = panel.childNode(withName: "pergamena") else { return }
        perg.setScale(0.95); let topY = perg.frame.maxY; let innerMargin: CGFloat = 80
        let choose = SKSpriteNode(imageNamed: "ChoosePath"); choose.texture?.filteringMode = .nearest
        choose.setScale(0.9); choose.position = CGPoint(x: 0, y: topY - innerMargin - 100); choose.zPosition = perg.zPosition + 1
        panel.addChild(choose)
        func createButton(_ img: String, _ name: String, _ y: CGFloat) -> ButtonNode {
            let button = ButtonNode(imageNamed: img, name: name); button.zPosition = 10000; button.xScale = 0.80
            button.yScale = 0.80; button.position = CGPoint(x: 0, y: y); return button
        }
        let buttonVerticalOffset: CGFloat = -120
        panel.addChild(createButton("RelaxBtn", "btnRelax", 300 + buttonVerticalOffset))
        panel.addChild(createButton("TrainingBtn", "btnTraining", 0 + buttonVerticalOffset))
        panel.addChild(createButton("BossBtn", "btnBoss", -300 + buttonVerticalOffset))
    }
    
    private func closePauseMenu() {
        childNode(withName: "pausePanel")?.removeFromParent(); musicToggleNode = nil
    }
    
    private func closeEndMenu() {
        childNode(withName: "endPanel")?.removeFromParent(); isMenuOpen = false
    }
    
    // MARK: - Game State
    
    private func pauseAndOpenMenu() {
        guard !isMenuOpen else { return }
        isMenuOpen = true; isPaused = false
        pauseHeroAnimation(); showPauseMenu()
    }
    
    private func resumeGame() {
        isMenuOpen = false; isPaused = false
        resumeHeroAnimation(); resumeMusic()
    }
    
    // MARK: - Audio Control
    
    private func pauseMusic() {
        musicNode?.run(.stop())
    }
    
    private func resumeMusic() {
        guard let node = musicNode else { return }
        let enabled = UserDefaults.standard.bool(forKey: "musicEnabled")
        if enabled {
            NotificationCenter.default.post(name: .musicExclusiveStart, object: nil, userInfo: ["id": musicTrackID])
            node.run(.play())
        }
    }
    
    // MARK: - Music Toggle (SpriteKit) (omessi per brevità, sono identici)

    private func makeMusicToggleNode(rowWidth: CGFloat) -> SKNode {
        let enabled = UserDefaults.standard.bool(forKey: "musicEnabled"); let container = SKNode()
        container.name = "musicToggle"; container.zPosition = 10000
        let label = SKLabelNode(fontNamed: "PressStart2P"); label.text = "Music"; label.fontSize = 50
        label.fontColor = .black; label.verticalAlignmentMode = .center; label.horizontalAlignmentMode = .left
        let horizontalPadding: CGFloat = 24; let leftX = -rowWidth / 2 + horizontalPadding
        label.position = CGPoint(x: leftX, y: 0); label.name = "label"; container.addChild(label)
        let capsule = SKNode(); capsule.name = "capsule"; container.addChild(capsule)
        let bgPath = CGPath(roundedRect: CGRect(origin: CGPoint(x: -musicToggleSize.width/2, y: -musicToggleSize.height/2), size: musicToggleSize), cornerWidth: musicToggleSize.height/2, cornerHeight: musicToggleSize.height/2, transform: nil)
        let bg = SKShapeNode(path: bgPath); bg.lineWidth = 0; bg.name = "bg"; capsule.addChild(bg)
        let knob = SKShapeNode(circleOfRadius: musicToggleKnobRadius); knob.lineWidth = 0
        knob.name = "knob"; capsule.addChild(knob)
        let rightX = rowWidth / 2 - musicToggleSize.width / 2 - horizontalPadding
        capsule.position = CGPoint(x: rightX, y: 0); updateMusicToggleVisual(container, enabled: enabled)
        return container
    }
    
    private func updateMusicToggleVisual(_ toggle: SKNode, enabled: Bool) {
        guard let capsule = toggle.childNode(withName: "capsule"),
              let bg = capsule.childNode(withName: "bg") as? SKShapeNode,
              let knob = capsule.childNode(withName: "knob") as? SKShapeNode else { return }
        let onColor = UIColor(red: 0.4, green: 0.7, blue: 0.4, alpha: 1.0)
        let offColor = UIColor(white: 0.8, alpha: 1.0); bg.fillColor = enabled ? onColor : offColor
        let xOffset: CGFloat = (musicToggleSize.width / 2) - (musicToggleKnobRadius + 8)
        let targetX = enabled ? xOffset : -xOffset; knob.fillColor = .white
        knob.position = CGPoint(x: targetX, y: 0); knob.glowWidth = 0
    }
    
    private func toggleMusicPreference() {
        let defaults = UserDefaults.standard; let current = defaults.bool(forKey: "musicEnabled")
        let newValue = !current; defaults.set(newValue, forKey: "musicEnabled")
        if let toggle = musicToggleNode { updateMusicToggleVisual(toggle, enabled: newValue) }
        NotificationCenter.default.post(name: .musicPreferenceChanged, object: nil)
        if newValue { resumeMusic() } else { pauseMusic() }
    }
    
    // MARK: - Utility (omessi per brevità, sono identici)
    
    private func formatTime(_ value: Int) -> String {
        let minutes = value / 60; let seconds = value % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - MiniMob Spawner & Collision (omessi per brevità, sono identici tranne la collisione)
    
    private func setupMiniMob() {
        if let proto = childNode(withName: "//MiniMob") as? SKSpriteNode {
            miniMobPrototype = proto; proto.isHidden = true; proto.texture?.filteringMode = .nearest
        } else {
            let proto = SKSpriteNode(imageNamed: "MiniMob"); proto.name = "MiniMob"; proto.isHidden = true
            proto.texture?.filteringMode = .nearest; addChild(proto); miniMobPrototype = proto
        }
    }
    
    private func startMiniMobSpawner() {
        let initial = SKAction.sequence([
            .wait(forDuration: 5.0),
            .run { [weak self] in self?.spawnMiniMob() },
            .run { [weak self] in
                guard let self = self else { return }
                let wait = SKAction.wait(forDuration: 40.0)
                let spawn = SKAction.run { [weak self] in self?.spawnMiniMob() }
                self.run(.repeatForever(.sequence([wait, spawn])), withKey: "miniMobSpawner")
            }
        ])
        run(initial, withKey: "miniMobSpawnerInit")
    }
    
    private func spawnMiniMob() {
        guard let proto = miniMobPrototype else { return }
        guard let mob = proto.copy() as? SKSpriteNode else { return }
        mob.isHidden = false; mob.texture?.filteringMode = .nearest; mob.setScale(miniMobScale)
        var spawnPosition = proto.position; var spawnZ: CGFloat = max(proto.zPosition, 200)
        if let dirt1 = childNode(withName: "//dirt1") as? SKSpriteNode {
            let topY = dirt1.frame.maxY; let offscreenRightX = frame.maxX + (mob.frame.width * 0.5) + 20
            spawnPosition = CGPoint(
                x: offscreenRightX,
                y: topY + (mob.frame.height * 0.5) + miniMobYOffset
            )
            spawnZ = max(dirt1.zPosition + 10, 200)
        } else {
            let offscreenRightX = frame.maxX + (mob.frame.width * 0.5) + 20
            spawnPosition = CGPoint(x: offscreenRightX, y: frame.midY)
        }
        mob.position = spawnPosition; mob.zPosition = spawnZ
        #if DEBUG
        print("[MiniMob] Spawned at (\(spawnPosition.x), \(spawnPosition.y)) z=\(spawnZ)")
        #endif
        addChild(mob); miniMobs.append(mob)
    }

    private func moveMiniMobs(_ dt: TimeInterval) {
        guard dt > 0, !miniMobs.isEmpty else { return }
        let dx = dirtSpeed * CGFloat(dt); for mob in miniMobs { mob.position.x -= dx }
        let leftEdge = self.frame.minX
        miniMobs.removeAll { mob in
            if mob.frame.maxX <= leftEdge { mob.removeFromParent(); return true }
            return false
        }
    }

    private func checkPomyMiniMobCollision() {
        guard activeCollisionMob == nil else { return }
        guard let pomy = pomyNode else { return }
        guard !miniMobs.isEmpty else { return }
        
        let pomyFrame = pomy.frame.insetBy(
            dx: pomy.frame.width * pomyCollisionInset.width,
            dy: pomy.frame.height * pomyCollisionInset.height
        )
        if let hit = miniMobs.first(where: {
            let mobFrame = $0.frame.insetBy(
                dx: $0.frame.width * miniMobCollisionInset.width,
                dy: $0.frame.height * miniMobCollisionInset.height
            )
            return mobFrame.intersects(pomyFrame)
        }) {
            handleCollision(with: hit)
        }
    }
    
    // MODIFICATO: Logica di collisione per gestire l'attacco
    private func handleCollision(with mob: SKSpriteNode) {
        guard activeCollisionMob == nil else { return }
        activeCollisionMob = mob
        
        pauseHeroAnimation()
        
        if let idx = miniMobs.firstIndex(of: mob) {
            miniMobs.remove(at: idx)
        }
        
        // Fai sparire il mob con una dissolvenza
        let removeMobAction = SKAction.sequence([
            .fadeOut(withDuration: 0.2),
            .removeFromParent()
        ])
        mob.run(removeMobAction)
        
        // Esegui l'animazione di attacco
        playPomyAttackAnimation { [weak self] in
            self?.resumeHeroAnimation()
            self?.activeCollisionMob = nil // Permetti nuove collisioni
        }
    }
    
    // NUOVO: Funzione per l'animazione di attacco
    private func playPomyAttackAnimation(completion: @escaping () -> Void) {
        guard let pomy = pomyNode, let attackNode = pomyAttackNode else {
            completion()
            return
        }
        
        // 1. Carica i frame dall'atlas "attacco.atlas"
        let atlas = SKTextureAtlas(named: "attacco")
        // Ordina i frame (attacco_0, attacco_1, ...)
        let orderedNames = atlas.textureNames.sorted { (nameA, nameB) -> Bool in
            let numA = Int(nameA.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 0
            let numB = Int(nameB.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 0
            return numA < numB
        }
        
        let frames = orderedNames.map { atlas.textureNamed($0) }
        frames.forEach { $0.filteringMode = .nearest }
        
        guard !frames.isEmpty else {
            print("ATTENZIONE: Nessun frame trovato in 'attacco.atlas'.")
            completion()
            return
        }
        
        // 2. Crea l'azione di animazione (tempoPerFrame 0.08 per renderla rapida)
        let animationAction = SKAction.animate(with: frames, timePerFrame: 0.08, resize: false, restore: true)
        
        // 3. Prepara il nodo di attacco e scambia la visibilità
        attackNode.size = pomy.size
        attackNode.position = CGPoint(
            x: pomy.position.x + pomyAttackOffsetX,
            y: pomy.position.y + pomyAttackOffsetY
        )
        // Nascondi Pomy (corsa) e mostra l'attacco
        pomy.zPosition = -100
        attackNode.zPosition = 100
        
        // 4. Crea la sequenza di azioni sul NODO DI ATTACCO
        let attackSequence = SKAction.sequence([
            animationAction,
            SKAction.run {
                // Al termine, ripristina le zPosition
                pomy.zPosition = 100
                attackNode.zPosition = -100
                completion() // Esegui la completion per riprendere il gioco
            }
        ])
        
        // 5. Esegui la sequenza SUL NODO DI ATTACCO
        attackNode.run(attackSequence, withKey: "pomyNodeAttacking")
    }

}
