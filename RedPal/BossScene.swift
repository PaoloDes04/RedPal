import SpriteKit
import UIKit

class BossScene: SKScene {
    private var backButton: SKSpriteNode!
    private let autoReturnActionKey = "autoReturnToGame"
    
    // Background preso dallo .sks (gestito SOLO dall’editor) ma adattato via codice a “aspect fill”
    private weak var backgroundNode: SKSpriteNode?
    
    static func fromSKS() -> BossScene {
        if let scene = BossScene(fileNamed: "BossScene") {
            scene.scaleMode = .aspectFill
            return scene
        } else {
            // Avoid using UIScreen.main; size will be set when the scene is presented.
            let scene = BossScene(size: .zero)
            scene.scaleMode = .aspectFill
            return scene
        }
    }

    override func didMove(to view: SKView) {
        // Ensure the scene uses the view's size when presented, avoiding UIScreen.main.
        if size == .zero {
            size = view.bounds.size
        }

        // Fallback background color per evitare bande chiare
        backgroundColor = .black

        // Neutralizza eventuali camere definite nello SKS
        if let cam = camera {
            self.camera = nil
            cam.removeFromParent()
        }
        children.compactMap { $0 as? SKCameraNode }.forEach { $0.removeFromParent() }

        // Usa lo sfondo definito nello .sks
        if let bg = childNode(withName: "//BG_Boss") as? SKSpriteNode {
            bg.texture?.filteringMode = .nearest
            backgroundNode = bg
            adaptBackgroundToScene()
        }

        // (Opzionale) contenuti extra: etichetta e back button
        let label = SKLabelNode(text: "Boss Mode")
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 48
        label.fontColor = .white
        label.position = CGPoint(x: size.width / 2, y: size.height / 2)
        label.zPosition = 10
        addChild(label)

        let texture = SKTexture(imageNamed: "backButton")
        texture.filteringMode = .nearest
        backButton = SKSpriteNode(texture: texture)
        backButton.name = "backButton"
        backButton.anchorPoint = CGPoint(x: 0, y: 1)
        backButton.position = CGPoint(x: 10, y: size.height - 10)
        backButton.zPosition = 20
        addChild(backButton)

        let waitAction = SKAction.wait(forDuration: 300.0)
        let fireAction = SKAction.run { [weak self] in self?.returnToGameScene() }
        self.run(.sequence([waitAction, fireAction]), withKey: autoReturnActionKey)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        adaptBackgroundToScene()
        // riallinea il backButton sul bordo alto-sinistra
        backButton?.position = CGPoint(x: 10, y: size.height - 10)
    }

    private func adaptBackgroundToScene() {
        guard let bg = backgroundNode else { return }
        bg.zPosition = -1000

        let bgBaseSize = bg.size
        guard bgBaseSize.width > 0 && bgBaseSize.height > 0 && size.width > 0 && size.height > 0 else {
            bg.position = CGPoint(x: size.width/2, y: size.height/2)
            return
        }

        // Calcola scala “aspect fill” e sovrascala leggermente per evitare linee 1px
        let scaleX = size.width / bgBaseSize.width
        let scaleY = size.height / bgBaseSize.height
        var scale = max(scaleX, scaleY)

        bg.xScale = scale
        bg.yScale = scale

        // In BossScene l'anchorPoint di default è (0,0): centra manualmente
        bg.position = CGPoint(x: size.width/2, y: size.height/2)
    }

    private func returnToGameScene() {
        let gameScene = GameScene.fromSKS()
        gameScene.scaleMode = scaleMode
        gameScene.size = size
        let transition = SKTransition.crossFade(withDuration: 0.5)
        view?.presentScene(gameScene, transition: transition)
    }

    override func willMove(from view: SKView) {
        removeAction(forKey: autoReturnActionKey)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodesAtPoint = nodes(at: location)

        if nodesAtPoint.contains(where: { $0.name == "backButton" }) {
            returnToGameScene()
        }
    }
}
