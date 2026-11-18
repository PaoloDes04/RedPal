//
//  TomyScene.swift
//  RedPal
//
//  Created by Gianmarco Montella on 04/11/25.
//

import SpriteKit
import UIKit

class TomyScene: SKScene {
    private var backButton: SKSpriteNode!
    
    static func fromSKS() -> TomyScene {
        if let scene = TomyScene(fileNamed: "TomyScene") {
            scene.scaleMode = .aspectFill
            return scene
        } else {
            // Evita UIScreen.main: la size verrà impostata quando presentata
            let scene = TomyScene(size: .zero)
            scene.scaleMode = .aspectFill
            return scene
        }
    }
    
    override func didMove(to view: SKView) {
        if size == .zero {
            size = view.bounds.size
        }
        
        backgroundColor = .black
        
        let label = SKLabelNode(text: "Tomy")
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 48
        label.fontColor = .white
        label.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(label)
        
        let texture = SKTexture(imageNamed: "backButton")
        texture.filteringMode = .nearest
        backButton = SKSpriteNode(texture: texture)
        backButton.name = "backButton"
        backButton.anchorPoint = CGPoint(x: 0, y: 1)
        backButton.position = CGPoint(x: 10, y: size.height - 10)
        addChild(backButton)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodesAtPoint = nodes(at: location)
        
        if nodesAtPoint.contains(where: { $0.name == "backButton" }) {
            // Chiedi alla SKS view SwiftUI di chiudersi
            NotificationCenter.default.post(name: Notification.Name("goBack"), object: nil)
        }
    }
}
