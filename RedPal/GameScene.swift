//
//  GameScene.swift
//  RedPal
//
//  Created by Ignazio Finizio on 07/04/22.
//  Modified by You on 24/10/25
//

import SpriteKit

final class GameScene: SKScene {

    // MARK: - Config
    private let groundImageName = "TerrenoTranspBG"
    private let playerImageName = "Corsa_00"

    private let groundSpeed: CGFloat = 120.0 // pt/sec verso sinistra
    private let playerSize = CGSize(width: 72, height: 72)
    private let playerBottomPadding: CGFloat = 6   // distanza dal terreno
    private let playerLeftInset: CGFloat = 80      // quanto a sinistra posizionare il player

    // MARK: - Nodes
    private var groundNodes: [SKSpriteNode] = []
    private var playerNode: SKSpriteNode?

    // MARK: - Timing
    private var lastUpdateTime: TimeInterval = 0

    // MARK: - Scene lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        removeAllChildren()
        groundNodes.removeAll()

        setupGroundLoop()
        setupPlayer()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        // Ridimensiona correttamente terreno e player quando cambia la size della scena
        layoutGround()
        layoutPlayer()
    }

    // MARK: - Setup

    private func setupGroundLoop() {
        // Crea almeno due segmenti per il loop orizzontale
        // Useremo la larghezza della scena per dimensionare i segmenti in modo che coprano l’intero schermo.
        // Se l’immagine è molto larga, la scaleremo per riempire in larghezza e impostare un’altezza coerente.

        // Rimuovi eventuali precedenti
        for n in groundNodes { n.removeFromParent() }
        groundNodes.removeAll()

        // Crea due segmenti
        let segment1 = SKSpriteNode(imageNamed: groundImageName)
        let segment2 = SKSpriteNode(imageNamed: groundImageName)

        segment1.anchorPoint = CGPoint(x: 0, y: 0) // ancoriamo in basso a sinistra
        segment2.anchorPoint = CGPoint(x: 0, y: 0)

        segment1.zPosition = 0
        segment2.zPosition = 0

        addChild(segment1)
        addChild(segment2)

        groundNodes = [segment1, segment2]
        layoutGround()
    }

    private func setupPlayer() {
        // Crea il player con l’immagine "corsa_00"
        let tex = SKTexture(imageNamed: playerImageName)
        if tex.size() == .zero {
            print("Attenzione: texture \(playerImageName) non trovata (size zero). Controlla il nome asset e il target membership.")
        }

        let node = SKSpriteNode(texture: tex)
        node.name = "player"
        node.size = playerSize
        node.zPosition = 10 // davanti al terreno

        addChild(node)
        playerNode = node

        layoutPlayer()
    }

    // MARK: - Layout helpers

    private func layoutGround() {
        guard !groundNodes.isEmpty else { return }

        // Altezza del terreno: usa l’altezza della texture proporzionata alla larghezza della scena
        // Strategia: scala i segmenti per avere ciascuno larghezza = scene.width
        // In questo modo bastano 2 segmenti affiancati per il loop.
        let sceneW = max(size.width, 1)
        let sceneH = size.height

        for (i, node) in groundNodes.enumerated() {
            let texSize = node.texture?.size() ?? .zero
            var targetHeight: CGFloat = texSize.height
            var targetWidth: CGFloat = sceneW

            if texSize.width > 0 {
                // Scala mantenendo proporzioni per ottenere larghezza = sceneW
                let scale = sceneW / texSize.width
                targetHeight = texSize.height * scale
            }

            node.size = CGSize(width: targetWidth, height: targetHeight)

            // Posiziona alla base della scena (y = 0) con anchor in basso a sinistra
            let x = CGFloat(i) * targetWidth - sceneW * 0.5 // perché l'origine scena è al centro
            let y = -sceneH * 0.5 // in basso
            node.position = CGPoint(x: x, y: y)
        }
    }

    private func layoutPlayer() {
        guard let player = playerNode else { return }

        // Posiziona il player sopra il terreno:
        // prendiamo l'altezza del primo segmento terreno come base
        let groundHeight = groundNodes.first?.size.height ?? 96
        let x = -size.width * 0.5 + playerLeftInset + player.size.width * 0.5
        let y = -size.height * 0.5 + groundHeight + player.size.height * 0.5 + playerBottomPadding
        player.position = CGPoint(x: x, y: y)
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        var dt: CGFloat = 0
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
        } else {
            dt = CGFloat(currentTime - lastUpdateTime)
            lastUpdateTime = currentTime
        }
        guard dt > 0 else { return }

        scrollGround(by: groundSpeed * dt)
    }

    private func scrollGround(by dx: CGFloat) {
        guard groundNodes.count >= 2 else { return }

        // Muovi tutti i segmenti verso sinistra
        for node in groundNodes {
            node.position.x -= dx
        }

        // Se un segmento è completamente uscito a sinistra, riposizionalo a destra dell’ultimo
        // Dato che ogni segmento ha width = scene.width, il controllo è semplice.
        let sceneLeft = -size.width * 0.5
        let sceneRight = size.width * 0.5

        // Ordina per x crescente per capire qual è il più a sinistra e il più a destra
        groundNodes.sort { $0.position.x < $1.position.x }

        if let leftMost = groundNodes.first, let rightMost = groundNodes.last {
            // Quando il leftMost esce interamente a sinistra, lo mettiamo dopo il rightMost
            if leftMost.position.x + leftMost.size.width <= sceneLeft {
                leftMost.position.x = rightMost.position.x + rightMost.size.width
                // Riordina array per mantenere coerenza
                groundNodes.sort { $0.position.x < $1.position.x }
            }

            // Safety: se per qualsiasi motivo ci sono buchi, assicuriamoci che coprano sempre l'intera larghezza
            // (opzionale, in genere non serve con width = scene.width)
            if groundNodes.count == 2 {
                let gap = groundNodes[1].position.x - (groundNodes[0].position.x + groundNodes[0].size.width)
                if abs(gap) > 1 {
                    groundNodes[1].position.x = groundNodes[0].position.x + groundNodes[0].size.width
                }
            }
        }
    }

    // MARK: - Touches (lasciati per esempio; rimuovi se non servono)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Esempio: tap per aggiungere un fiore (come nel tuo template)
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let node = atPoint(location)
        if node.name == "bottone" {
            let flower1 = SKSpriteNode(imageNamed: "flower-BY")
            flower1.position = CGPoint(x: Int.random(in: -300...300), y: Int.random(in: -500...500))
            addChild(flower1)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let node = atPoint(location)
        if node.name == "bottone" {
            node.position = location
        }
    }
}
