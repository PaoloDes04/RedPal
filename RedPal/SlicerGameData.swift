import Foundation
import SwiftUI
import Combine

class SlicerGameData: ObservableObject {
    @Published var score: Int = 0 // Punteggio iniziale ora 0
    @Published var timeLeft: Int = Int(SlicerGameConstants.GAME_DURATION)
    @Published var gameState: SlicerGameState = .start
    @Published var showEndGameVideo: Bool = false // Stato per il video finale
    
    // Riferimento alla scena (impostato dal ContentView)
    var gameScene: SlicerGameScene?
    
    private let highScoreKey = "MonsterSlicerHighScore"
    private var timer: AnyCancellable?
    
    var highScore: Int {
        get { UserDefaults.standard.integer(forKey: highScoreKey) }
        set {
            if newValue > UserDefaults.standard.integer(forKey: highScoreKey) {
                UserDefaults.standard.set(newValue, forKey: highScoreKey)
            }
        }
    }
    
    // Avvia il timer di gioco (chiamato dal pulsante Start)
    func startGameTimer() {
        // Interrompe il timer precedente se presente
        timer?.cancel()

        self.gameState = .playing
        self.showEndGameVideo = false // Assicurati che sia falso all'inizio di una partita
        
        // Avvia il timer su base Combine
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                if self.gameState == .playing {
                    self.timeLeft -= 1
                    
                    if self.timeLeft <= 0 {
                        self.stopGameTimer()
                        self.showEndGameVideo = true // Mostra il video
                        // IMPORTANTE: Non impostare gameState = .gameOver qui.
                        // Sarà impostato dal ContentView dopo la riproduzione del video.
                    }
                }
            }
    }
    
    func stopGameTimer() {
        timer?.cancel()
        timer = nil
    }
    
    func reset() {
        highScore = score // Aggiorna il record se superiore
        score = 0 // Punteggio di reset a 0
        timeLeft = Int(SlicerGameConstants.GAME_DURATION)
        stopGameTimer()
        self.showEndGameVideo = false
        self.gameState = .start
    }
}
