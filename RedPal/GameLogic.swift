import SwiftUI
import SpriteKit
import Combine

// MARK: - 1. LOGICA DI GIOCO (ObservableObject)

/// Gestisce tutto lo stato e la logica della battaglia.
class GameLogic: ObservableObject {
    
    // Riferimento alla scena SpriteKit per chiamare le animazioni
    // Questo è un weak var per evitare cicli di riferimento forti.
    weak var scene: MyBattleScene?
    
    // Stato del gioco reattivo
    @Published var heroHP: Double = 1000
    @Published var heroMaxHP: Double = 1000
    @Published var bossHP: Double = 1000 // Vita del boss aumentata
    @Published var bossMaxHP: Double = 1000 // Vita del boss aumentata
    @Published var attackCooldown: Double = 0
    @Published var parryCooldown: Double = 0
    @Published var isParrying: Bool = false
    @Published var message: String = ""
    @Published var gameActive: Bool = true
    
    // Costanti per la logica
    let attackCDMax: Double = 3.0
    let parryCDMax: Double = 5.0
    
    // Variabile per il timer del boss
    private var bossAttackTimer: Timer?
    private var nextBossAttackTime: Date = Date()
    
    // Inizializza la logica di gioco
    init() {
        startBossTimer()
        nextBossAttackTime = Date().addingTimeInterval(Double.random(in: 2.0...4.0))
    }
    
    // MARK: - Timer e Loop di Gioco
    
    /// Avvia il timer principale per il cooldown e la logica del boss.
    func startBossTimer() {
        // Invalida un timer esistente prima di crearne uno nuovo
        bossAttackTimer?.invalidate()
        bossAttackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, self.gameActive else { return }
            
            // 1. Decremento Cooldowns
            self.attackCooldown = max(0, self.attackCooldown - 0.1)
            self.parryCooldown = max(0, self.parryCooldown - 0.1)
            
            // 2. Logica Boss Attack
            self.attemptBossAttack()
            
            // 3. Verifica fine gioco (in caso di HP a zero)
            if self.heroHP <= 0 {
                self.endGame(winner: "Boss")
            } else if self.bossHP <= 0 {
                self.endGame(winner: "Protagonista")
            }
        }
    }
    
    /// Interrompe il loop di gioco.
    func endGame(winner: String) {
        if !gameActive { return } // Evita di chiamare più volte
        gameActive = false
        bossAttackTimer?.invalidate()
        
        if winner == "Boss" {
            self.showMessage("Hai perso! Il Boss ha vinto.", type: .hit)
        } else {
            self.showMessage("Hai sconfitto il boss!", type: .parry)
        }
    }
    
    // MARK: - Azioni del Protagonista
    
    func attemptAttack() {
        guard gameActive else { return }
        
        if attackCooldown <= 0 {
            withAnimation {
                let damage = Double.random(in: 80...150)
                bossHP = max(0, bossHP - damage)
                attackCooldown = attackCDMax
                
                // Chiama le animazioni nella scena SpriteKit
                self.scene?.animateHeroAttack()
                self.scene?.animateBossHit()
                
                self.showMessage("You attacked! The boss loses \(Int(damage)) HP.")
            }
        } else {
            self.showMessage(String(format: "Attack recharging! (%.1fs)", attackCooldown), type: .fail)
        }
    }
    
    func attemptParry() {
        guard gameActive else { return }
        
        if parryCooldown <= 0 {
            parryCooldown = parryCDMax
            isParrying = true
            
            self.showMessage("You are in Guard stance for 1 second", type: .parry)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.isParrying = false
            }
        } else {
            self.showMessage(String(format: "Guard recharging! (%.1fs)", parryCooldown), type: .fail)
        }
    }
    
    // MARK: - Logica del Boss
    
    private func attemptBossAttack() {
        let now = Date()
        
        if now >= nextBossAttackTime {
            var damage = Double.random(in: 50...100)
            
            self.scene?.animateBossAttack() // Esegue l'animazione di attacco del boss
            
            if isParrying {
                damage /= 5
                self.showMessage("BOSS attacks! You BLOCKED, you only take \(Int(damage)) HP.", type: .parry)
            } else {
                self.showMessage("BOSS attacks! You take \(Int(damage)) HP.", type: .hit)
            }
            
            withAnimation(.easeInOut) {
                heroHP = max(0, heroHP - damage)
            }
            
            let nextInterval = Double.random(in: 2.0...4.0)
            nextBossAttackTime = now.addingTimeInterval(nextInterval)
        }
    }

    /// Resetta lo stato del gioco per ricominciare una battaglia.
    func resetGame() {
        heroHP = heroMaxHP
        bossHP = bossMaxHP
        attackCooldown = 0
        parryCooldown = 0
        isParrying = false
        message = ""
        gameActive = true
        nextBossAttackTime = Date().addingTimeInterval(Double.random(in: 2.0...4.0))
        startBossTimer() // Riavvia il timer del boss
        self.showMessage("Battaglia resettata! Inizia la battaglia!", type: .info)
    }

    // MARK: - Messaggistica
    
    enum MessageStyle { case info, hit, parry, fail }
    
    func showMessage(_ text: String, type: MessageStyle = .info) {
        self.message = text
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Controlla che il messaggio corrente sia ancora quello che abbiamo impostato,
            // per evitare di cancellare messaggi più recenti.
            if self.message == text {
                self.message = ""
            }
        }
    }
}
