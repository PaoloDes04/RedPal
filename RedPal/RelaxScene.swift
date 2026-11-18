import SpriteKit
import Foundation

class RelaxScene: SKScene {
    // MARK: - Sessioni
    weak var sessionManager: SessionManager?
    
    // MARK: - Timer
    private var relaxTimerLabel: SKLabelNode?
    private var relaxTimeRemaining: Int = 0
    private let relaxMax: Int = 5 * 60 // 5 minuti
    private var timer: Timer?

    // MARK: - Background (gestito solo dallo .sks)
    private weak var backgroundNode: SKSpriteNode?

    // MARK: - Overlay Pergamena / Countdown
    private var overlayNode: SKNode?
    private var isOverlayVisible: Bool = false
    private var isCountingDown: Bool = false
    private var countdownValue: Int = 3
    private var countdownImageNode: SKSpriteNode?

    static func fromSKS() -> RelaxScene {
        guard let scene = RelaxScene(fileNamed: "RelaxScene") else {
            fatalError("Failed to load RelaxScene.sks")
        }
        scene.scaleMode = .aspectFill
        return scene
    }

    override func didMove(to view: SKView) {
        // assicurati che nulla sia in pausa
        self.isPaused = false
        self.view?.isPaused = false
        self.speed = 1.0

        #if DEBUG
        print("[RelaxScene] didMove — isPaused=\(self.isPaused) viewPaused=\(self.view?.isPaused ?? false)")
        #endif

        // Rimuovi tutte le zeta esistenti
        self.children.filter { node in
            if let sprite = node as? SKSpriteNode, sprite.texture?.description.contains("Zeta") == true {
                return true
            }
            return false
        }.forEach { $0.removeFromParent() }
        // Rimuovi anche lo spawner precedente se la scena viene presentata di nuovo
        removeAction(forKey: "zetaSpawner")

        // BG preso dallo .sks
        if let bgRelax = childNode(withName: "//BG_Relax") as? SKSpriteNode {
            bgRelax.texture?.filteringMode = .nearest
            backgroundNode = bgRelax
        } else {
            #if DEBUG
            print("[RelaxScene] BG_Relax not found in SKS (background fully managed via SKS)")
            #endif
        }

        // Personaggio/area relax (dal .sks)
        if let areaRelax = childNode(withName: "//AreaRelax") as? SKSpriteNode {
            areaRelax.texture?.filteringMode = .nearest
            startZetaAnimation(around: areaRelax)
        } else {
            #if DEBUG
            print("[RelaxScene] Warning: AreaRelax node not found in SKS")
            #endif
        }

        // Timer label dal .sks (o fallback se assente)
        if let label = childNode(withName: "//Timer") as? SKLabelNode {
            relaxTimerLabel = label
            // Imposta font bold
            relaxTimerLabel?.fontName = "AvenirNext-Bold"
            // Mantieni dimensione leggibile (puoi regolare)
            relaxTimerLabel?.fontSize = max(relaxTimerLabel?.fontSize ?? 60, 60)
            relaxTimerLabel?.fontColor = .white
        } else {
            let label = SKLabelNode(fontNamed: "AvenirNext-Bold") // bold
            label.fontSize = 60
            label.fontColor = .white
            label.position = CGPoint(x: 0, y: 270)
            label.zPosition = 10
            addChild(label)
            relaxTimerLabel = label
            #if DEBUG
            print("[RelaxScene] Timer label not found in SKS — created fallback")
            #endif
        }

        // reset timer
        relaxTimeRemaining = relaxMax
        relaxTimerLabel?.text = formatTime(relaxTimeRemaining)

        // avvia il timer
        startTimer()
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)
        // Invalida il timer quando la scena sta per essere rimossa per evitare memory leak
        timer?.invalidate()
        timer = nil
        // Rimuovi l'azione che genera le "Z" sulla scena
        removeAction(forKey: "zetaSpawner")
        // Rimuovi anche tutte le zeta generate attive o statiche per una pulizia completa
        self.children.filter { node in
            if let sprite = node as? SKSpriteNode, sprite.texture?.description.contains("Zeta") == true {
                return true
            }
            return false
        }.forEach { $0.removeFromParent() }
    }
    
    // Non adattiamo nulla quando cambia la size: lo sfondo resta come definito nello .sks
    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        // Intenzionalmente vuoto
    }

    // MARK: - Animazione Zeta
    private func startZetaAnimation(around characterNode: SKSpriteNode) {
        // Constants for zeta animation tuning (Grandezza delle zeta mantenuta)
        let initialZetaScaleRange: ClosedRange<CGFloat> = 0.15...0.3
        let initialHorizontalSpread: ClosedRange<CGFloat> = -60...60
        let headLevelOffsetRatio: CGFloat = 0.3
        let verticalSpawnJitter: ClosedRange<CGFloat> = -15...15
        let verticalMoveDistance: CGFloat = 90
        let horizontalDriftRange: ClosedRange<CGFloat> = -60...60

        let spawnAction = SKAction.run { [weak self, weak characterNode] in
            guard let self = self, let characterNode = characterNode else { return }
            
            let zeta = SKSpriteNode(imageNamed: "Zeta")
            zeta.texture?.filteringMode = .nearest
            zeta.name = "animatedZeta"
            zeta.setScale(CGFloat.random(in: initialZetaScaleRange))
            zeta.alpha = 0
            
            let characterFrame = characterNode.calculateAccumulatedFrame()
            let startX = characterFrame.midX + CGFloat.random(in: initialHorizontalSpread)
            let headLevelY = characterFrame.maxY - (characterFrame.height * headLevelOffsetRatio)
            let startY = headLevelY + CGFloat.random(in: verticalSpawnJitter)

            zeta.position = CGPoint(x: startX, y: startY)
            zeta.zPosition = characterNode.zPosition + 1
            
            self.addChild(zeta)
            
            let lifeTime = TimeInterval.random(in: 2.5...4.0)
            let fadeIn = SKAction.fadeIn(withDuration: lifeTime * 0.25)
            let scaleUp = SKAction.scale(to: 0.5, duration: lifeTime)
            let moveUp = SKAction.moveBy(x: 0, y: verticalMoveDistance, duration: lifeTime)
            let moveSideways = SKAction.moveBy(x: CGFloat.random(in: horizontalDriftRange), y: 0, duration: lifeTime)
            let fadeOut = SKAction.sequence([
                .wait(forDuration: lifeTime * 0.5),
                .fadeOut(withDuration: lifeTime * 0.5)
            ])
            let animationGroup = SKAction.group([fadeIn, scaleUp, moveUp, moveSideways, fadeOut])
            let sequence = SKAction.sequence([animationGroup, .removeFromParent()])
            zeta.run(sequence)
        }
        
        let waitToSpawn = SKAction.wait(forDuration: 1.2, withRange: 0.8)
        let spawnSequence = SKAction.sequence([spawnAction, waitToSpawn])
        let spawner = SKAction.repeatForever(spawnSequence)
        self.run(spawner, withKey: "zetaSpawner")
    }

    // MARK: - Timer con Foundation.Timer
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.advanceTimer()
        }
    }

    private func advanceTimer() {
        guard relaxTimeRemaining > 0 else {
            // Ferma il timer quando raggiunge lo zero e mostra la pergamena
            timer?.invalidate()
            timer = nil
            relaxTimerLabel?.text = "00:00"
            showParchmentOverlay()
            return
        }
        relaxTimeRemaining -= 1
        relaxTimerLabel?.text = formatTime(relaxTimeRemaining)
        #if DEBUG
        if relaxTimeRemaining % 10 == 0 {
            print("[RelaxScene] remaining = \(relaxTimeRemaining)s")
        }
        #endif
    }

    private func formatTime(_ value: Int) -> String {
        let minutes = value / 60
        let seconds = value % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Overlay Pergamena (stile Boss)
    private func showParchmentOverlay() {
        guard !isOverlayVisible else { return }
        isOverlayVisible = true
        
        let panel = SKNode()
        panel.name = "relaxOverlayPanel"
        panel.zPosition = 10_000
        panel.position = CGPoint(x: frame.midX, y: frame.midY)
        addChild(panel)
        overlayNode = panel
        
        // Dimmer
        let dim = SKSpriteNode(color: .black.withAlphaComponent(0.55), size: CGSize(width: size.width * 2, height: size.height * 2))
        dim.zPosition = 1
        dim.position = .zero
        dim.name = "dim"
        panel.addChild(dim)
        
        // Pergamena
        let pergamena = SKSpriteNode(imageNamed: "pergamena")
        pergamena.texture?.filteringMode = .nearest
        pergamena.name = "pergamena"
        pergamena.zPosition = 2
        pergamena.setScale( min( size.width * 0.6 / pergamena.size.width, 700 / pergamena.size.width ) )
        panel.addChild(pergamena)
        
        // Congratulazioni
        let congrats = SKSpriteNode(imageNamed: "RelaxText")
        congrats.texture?.filteringMode = .nearest
        congrats.name = "congrats"
        congrats.zPosition = 3
        congrats.setScale( min( size.width * 0.6 / congrats.size.width, 520 / congrats.size.width ) )
        congrats.position = CGPoint(x: 0, y: 210)
        panel.addChild(congrats)
        
        // Bottone BackSession (uguale a Boss)
        let backBtn = SKSpriteNode(imageNamed: "BackSession")
        backBtn.texture?.filteringMode = .nearest
        backBtn.name = "backButton"
        backBtn.zPosition = 3
        backBtn.setScale( min( size.width * 0.5 / backBtn.size.width, 360 / backBtn.size.width ) )
        backBtn.position = CGPoint(x: 0, y: -60)
        panel.addChild(backBtn)
        
        // Nodo countdown (invisibile finché non parte)
        let cd = SKSpriteNode()
        cd.name = "countdownImage"
        cd.zPosition = 3
        cd.alpha = 0.0
        panel.addChild(cd)
        countdownImageNode = cd
    }
    
    private func startCountdownFlowOrExit() {
        // Se è l'ultima sessione: torna alla home e mostra la pergamena di home
        if sessionManager?.isLastSession == true {
            NotificationCenter.default.post(name: .showHomePergamena, object: nil)
            NotificationCenter.default.post(name: Notification.Name("goBack"), object: nil)
            return
        }
        
        // Altrimenti: countdown 3-2-1 e ritorno alla GameScene con resumeAfterBoss
        guard let cd = countdownImageNode else { return }
        isCountingDown = true
        countdownValue = 3
        
        // Nascondi bottone
        overlayNode?.childNode(withName: "backButton")?.isHidden = true
        
        func setCountdownImage(_ value: Int) {
            let asset: String
            switch value {
            case 3: asset = "tre"
            case 2: asset = "due"
            default: asset = "uno"
            }
            let tex = SKTexture(imageNamed: asset)
            tex.filteringMode = .nearest
            cd.texture = tex
            cd.size = tex.size()
            cd.setScale( min( size.width * 0.35 / cd.size.width, 220 / cd.size.width ) )
            cd.position = CGPoint(x: 0, y: -60)
            cd.alpha = 1.0
        }
        
        // Sequenza 3 -> 2 -> 1
        setCountdownImage(3)
        let step = SKAction.sequence([
            .wait(forDuration: 1.0),
            .run { [weak self] in
                guard let self = self else { return }
                self.countdownValue = 2
                setCountdownImage(2)
            },
            .wait(forDuration: 1.0),
            .run { [weak self] in
                guard let self = self else { return }
                self.countdownValue = 1
                setCountdownImage(1)
            },
            .wait(forDuration: 1.0)
        ])
        
        let finish = SKAction.run { [weak self] in
            guard let self = self else { return }
            // Avanza sessione
            if let sm = self.sessionManager {
                sm.currentSession += 1
            }
            // Notifica ripresa
            NotificationCenter.default.post(name: .resumeAfterBoss, object: nil)
            
            // Torna alla GameScene
            if let view = self.view {
                let scene = GameScene.fromSKS()
                scene.scaleMode = .aspectFill
                scene.sessionManager = self.sessionManager
                let transition = SKTransition.crossFade(withDuration: 0.5)
                view.presentScene(scene, transition: transition)
            }
        }
        
        run(SKAction.sequence([step, finish]), withKey: "relaxCountdown")
    }
    
    // MARK: - Touch Handling (per bottone BackSession)
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isOverlayVisible, !isCountingDown, let touch = touches.first else { return }
        let p = touch.location(in: overlayNode ?? self)
        if let back = overlayNode?.childNode(withName: "backButton") as? SKSpriteNode,
           back.contains(p) {
            startCountdownFlowOrExit()
        }
    }
}
