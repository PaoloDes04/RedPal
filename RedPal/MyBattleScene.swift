//
//  MyBattleScene.swift
//  Boss battle2.0
//
//  Created by Vincenzo Mataluna on 03/11/25.
//  (Questo file è stato modificato da GameScene.swift per riflettere la nuova architettura)

import SpriteKit
import GameplayKit
import SwiftUI

class MyBattleScene: SKScene {

    weak var gameLogic: GameLogic?

    // Nodi creati e gestiti da codice
    private var heroNode: SKSpriteNode?
    private var bossNode: SKSpriteNode?

    // Sfondo preso dallo .sks (BossScene.sks). Non viene modificato (layout gestito dall’editor).
    private weak var backgroundNode: SKSpriteNode?

    // Target altezze logiche (manteniamo aspect ratio)
    private let targetHeroHeight: CGFloat = 240
    private let targetBossHeight: CGFloat = 400
    
    // Posizioni orizzontali in percentuale (0 = sinistra, 1 = destra)
    private let heroXRatio: CGFloat = -0.25
    private let bossXRatio: CGFloat = 0.1

    // Offset verticale opzionale (+ su, - giù) rispetto al terreno
    private let heroYOffset: CGFloat = -390
    private let bossYOffset: CGFloat = -0 // MODIFICATO: Aumentato da -120 a -90 (spostato più in alto)

    // Offset verticale “terreno” in coordinate di scena (anchorPoint di default: (0,0))
    // Puoi regolare questo valore per allinearlo con il tuo terreno nello .sks.
    private let groundYRatio: CGFloat = 0.18 // 18% dell’altezza scena

    override func didMove(to view: SKView) {
        // NON tocchiamo anchorPoint, backgroundColor, camera o layout della scena:
        // lasciamo che tutto sia come definito in BossScene.sks.

        // 1) Prendi solo lo sfondo dallo .sks
        backgroundNode = childNode(withName: "//BG_Boss") as? SKSpriteNode

        // 2) Crea da codice Eroe e Boss (texture, scale con aspect ratio, zPosition)
        createOrConfigureHero()
        createOrConfigureBoss()
    

        // 3) Layout iniziale dei personaggi in base alla size corrente
        layoutCharacters()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        // Riadatta SOLO i personaggi quando cambia la size (lo sfondo resta come nello .sks)
        layoutCharacters()
    }

    // MARK: - Setup personaggi (creati da codice)

    private func createOrConfigureHero() {
        if heroNode == nil {
            let heroTexture = SKTexture(imageNamed: "HeroIdle") // MODIFICATO: da "HeroIdle" a "Hero"
            heroTexture.filteringMode = .nearest
            let node = SKSpriteNode(texture: heroTexture)
            node.name = "hero_code"
            node.zPosition = 100
            addChild(node)
            heroNode = node
        }

        // Mantieni aspect ratio impostando scale in base a un'altezza target
        if let hero = heroNode, let tex = hero.texture {
            let texSize = tex.size()
            if texSize.height > 0 {
                let scale = targetHeroHeight / texSize.height
                hero.xScale = scale
                hero.yScale = scale
            }
        }
    }

    private func createOrConfigureBoss() {
        if bossNode == nil {
            let bossTexture = SKTexture(imageNamed: "BossIdle")
            bossTexture.filteringMode = .nearest
            let node = SKSpriteNode(texture: bossTexture)
            node.name = "boss_code"
            node.zPosition = 100
            addChild(node)
            bossNode = node
        }

        // Mantieni aspect ratio impostando scale in base a un'altezza target
        if let boss = bossNode, let tex = boss.texture {
            let texSize = tex.size()
            if texSize.height > 0 {
                let scale = targetBossHeight / texSize.height
                boss.xScale = scale
                boss.yScale = scale
            }
        }
    }

    // MARK: - Layout dei personaggi (senza toccare lo sfondo dallo .sks)

    private func layoutCharacters() {
        guard size.width > 0, size.height > 0 else { return }

        let groundY = size.height * groundYRatio

        if let hero = heroNode {
            let heroHalfHeight = (hero.size.height * abs(hero.yScale)) / 2
            hero.position = CGPoint(
                x: size.width * heroXRatio,
                y: groundY + heroHalfHeight + heroYOffset
            )
        }

        if let boss = bossNode {
            let bossHalfHeight = (boss.size.height * abs(boss.yScale)) / 2
            boss.position = CGPoint(
                x: size.width * bossXRatio,
                y: groundY + bossHalfHeight + bossYOffset
            )
        }
    }


    // MARK: - Animazioni (chiamate da GameLogic)

    func animateHeroAttack() {
        guard let hero = heroNode else { return }
        let originalPosition = hero.position
        let attackOffset = CGVector(dx: 60, dy: 0)
        let attackAction = SKAction.move(by: attackOffset, duration: 0.1)
        let returnAction = SKAction.move(to: originalPosition, duration: 0.2)
        let sequence = SKAction.sequence([attackAction, returnAction])
        hero.run(sequence)
    }

    func animateBossHit() {
        guard let boss = bossNode else { return }
        let originalScaleX = boss.xScale
        let originalScaleY = boss.yScale
        let pulseAction = SKAction.sequence([
            SKAction.group([
                SKAction.scaleX(to: originalScaleX * 0.95, duration: 0.05),
                SKAction.scaleY(to: originalScaleY * 0.95, duration: 0.05)
            ]),
            SKAction.group([
                SKAction.scaleX(to: originalScaleX * 1.05, duration: 0.05),
                SKAction.scaleY(to: originalScaleY * 1.05, duration: 0.05)
            ]),
            SKAction.group([
                SKAction.scaleX(to: originalScaleX, duration: 0.1),
                SKAction.scaleY(to: originalScaleY, duration: 0.1)
            ])
        ])
        let flashAction = SKAction.sequence([
            SKAction.colorize(with: .red, colorBlendFactor: 1.0, duration: 0.05),
            SKAction.wait(forDuration: 0.1),
            SKAction.colorize(with: .white, colorBlendFactor: 0.0, duration: 0.05)
        ])
        boss.run(SKAction.group([pulseAction, flashAction]))
    }

    func animateBossAttack() {
        guard let boss = bossNode else { return }
        let originalPosition = boss.position
        let attackOffset = CGVector(dx: -40, dy: 0)
        let attackAction = SKAction.move(by: attackOffset, duration: 0.1)
        let returnAction = SKAction.move(to: originalPosition, duration: 0.2)
        let sequence = SKAction.sequence([attackAction, returnAction])
        boss.run(sequence)
    }
    struct BattleScenePreview: View {
        var scene: MyBattleScene {
            let s = MyBattleScene(fileNamed: "BossScene") ?? MyBattleScene()
            s.scaleMode = .aspectFill
            s.size = CGSize(width: 390, height: 844) // importantissimo in preview
            return s
        }

        var body: some View {
            SpriteView(scene: scene)
                .ignoresSafeArea()
                .frame(width: 390, height: 844)
        }
    }

    struct BattleScenePreview_Previews: PreviewProvider {
        static var previews: some View {
            BattleScenePreview()
                .preferredColorScheme(.dark)
        }
    }
}
