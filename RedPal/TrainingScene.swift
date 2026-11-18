import SpriteKit
import UIKit

class TrainingScene: SKScene {
    private let backButtonName = "backButton"
    private let autoReturnActionKey = "autoReturnToGame"
    
    static func fromSKS() -> TrainingScene {
        if let scene = TrainingScene(fileNamed: "TrainingScene") {
            scene.scaleMode = .aspectFill
            return scene
        } else {
            let scene = TrainingScene(size: UIScreen.main.bounds.size)
            scene.scaleMode = .aspectFill
            return scene
        }
    }
    
    override func didMove(to view: SKView) {
        backgroundColor = .systemBlue
        
        let titleLabel = SKLabelNode(text: "Training Mode")
        titleLabel.fontName = "AvenirNext-Bold"
        titleLabel.fontSize = 40
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(titleLabel)
        
        let backButtonSize = CGSize(width: 80, height: 36)
        let backButtonBackground = SKShapeNode(rectOf: backButtonSize, cornerRadius: 8)
        backButtonBackground.fillColor = .white
        backButtonBackground.strokeColor = .clear
        backButtonBackground.name = backButtonName
        backButtonBackground.position = CGPoint(x: backButtonSize.width / 2 + 16, y: size.height - backButtonSize.height / 2 - 16)
        
        let backLabel = SKLabelNode(text: "Back")
        backLabel.fontName = "AvenirNext-Regular"
        backLabel.fontSize = 20
        backLabel.fontColor = .systemBlue
        backLabel.verticalAlignmentMode = .center
        backLabel.position = .zero
        backLabel.isUserInteractionEnabled = false
        
        backButtonBackground.addChild(backLabel)
        addChild(backButtonBackground)
        
        let waitAction = SKAction.wait(forDuration: 300.0)
        let fireAction = SKAction.run { [weak self] in
            guard let self = self else { return }
            let gameScene = GameScene.fromSKS()
            gameScene.size = self.size
            gameScene.scaleMode = self.scaleMode
            let transition = SKTransition.crossFade(withDuration: 0.5)
            self.view?.presentScene(gameScene, transition: transition)
        }
        self.run(.sequence([waitAction, fireAction]), withKey: autoReturnActionKey)
    }
    
    override func willMove(from view: SKView) {
        removeAction(forKey: autoReturnActionKey)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let touchedNode = atPoint(location)
        
        if touchedNode.name == backButtonName || touchedNode.parent?.name == backButtonName {
            let gameScene = GameScene.fromSKS()
            gameScene.size = size
            gameScene.scaleMode = scaleMode
            let transition = SKTransition.crossFade(withDuration: 0.4)
            view?.presentScene(gameScene, transition: transition)
        }
    }
}
