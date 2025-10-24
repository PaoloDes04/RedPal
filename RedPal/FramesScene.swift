//
//  FramesScene.swift
//  RedPal
//
//  Created by You on 24/10/25.
//

import SpriteKit

final class FramesScene: SKScene {

    private let baseName = "frame_"
    private let suffix = "_delay-0.05s"
    private let lastIndex: Int = 75
    private let fps: Double = 24.0

    private var sprite: SKSpriteNode?

    override func didMove(to view: SKView) {
        backgroundColor = .clear

        // Carica le textures
        let textures = loadTextures()
        guard !textures.isEmpty else {
            print("FramesScene: Nessuna texture trovata. Controlla i nomi degli asset e il target membership.")
            return
        }

        // Nodo sprite centrato a schermo che si adatta alla scena
        let first = textures[0]
        let node = SKSpriteNode(texture: first)
        node.position = CGPoint(x: size.width / 2, y: size.height / 2)
        node.size = size
        node.zPosition = 1
        addChild(node)
        self.sprite = node

        // Durata per frame a 24 fps
        let timePerFrame = 1.0 / fps

        // Azione di animazione in loop
        let animate = SKAction.animate(with: textures, timePerFrame: timePerFrame, resize: false, restore: false)
        let forever = SKAction.repeatForever(animate)
        node.run(forever)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        // Aggiorna size del nodo quando la scena cambia dimensione (rotazioni, layout)
        sprite?.size = size
        sprite?.position = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    private func loadTextures() -> [SKTexture] {
        var result: [SKTexture] = []
        result.reserveCapacity(lastIndex + 1)

        for i in 0...lastIndex {
            let index = String(format: "%02d", i) // zero padding a due cifre
            let name = "\(baseName)\(index)\(suffix)"
            let tex = SKTexture(imageNamed: name)
            // SKTexture(imageNamed:) ritorna una texture anche se l’immagine non esiste,
            // ma possiamo verificare se la dimensione è zero come heuristica.
            if tex.size() == .zero {
                print("Attenzione: texture non trovata per nome: \(name)")
            }
            result.append(tex)
        }
        return result
    }
}
