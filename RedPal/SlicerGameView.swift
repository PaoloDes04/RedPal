//
// ContentView.swift
// Monster Slicer App
//

import SwiftUI
import SpriteKit
import AVKit // Import AVKit per VideoPlayer

struct SlicerGameView: View {
    // Stato centrale del gioco
    @StateObject var gameData = SlicerGameData()
    // Stato UI per mostrare subito l'overlay di pausa
    @State private var isPausedUI: Bool = false
    
    // NUOVO: Istanza di AVPlayer per il video
    @State private var player: AVPlayer?
    
    // NUOVO: Session manager per sapere quante sessioni restano e dove tornare
    @EnvironmentObject var sessionManager: SessionManager
    
    // Flag per garantire che l’esperienza venga accreditata una sola volta per partita
    @State private var expGranted: Bool = false
    
    // Persistenza esperienza direttamente qui (così non dipendiamo da listener esterni)
    @AppStorage("experience") private var experience: Int = 0
    
    // Crea una scena SpriteKit corretta e collegata ai dati
    func makeGameScene(size: CGSize) -> SlicerGameScene {
        let scene = SlicerGameScene(size: size, SlicerGameData: gameData)
        scene.scaleMode = SKSceneScaleMode.aspectFill
        gameData.gameScene = scene
        return scene
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                
                // SpriteKit Game Scene - Reso invisibile quando il video o la schermata di Game Over sono attivi
                SpriteView(scene: gameData.gameScene ?? SKScene())
                    .id(gameData.gameState)
                    .ignoresSafeArea()
                    .onAppear {
                        if gameData.gameScene == nil, geometry.size != .zero {
                            gameData.gameScene = makeGameScene(size: geometry.size)
                        }
                        // Avvio immediato della partita all'apertura
                        if gameData.gameState != .playing {
                            gameData.reset()
                            expGranted = false // reset accredito XP a inizio partita
                            gameData.gameState = .playing
                            gameData.startGameTimer()
                        }
                    }
                    // Nasconde la scena quando il video o la schermata di Game Over sono mostrati
                    .opacity(gameData.showEndGameVideo || gameData.gameState == .gameOver ? 0 : 1)
                
                // HUD mostrato solo mentre si gioca e il video non è attivo
                if gameData.gameState == .playing && !gameData.showEndGameVideo {
                    VStack {
                        HStack(alignment: .center) {
                            // Pulsante pausa in alto a sinistra con asset personalizzato
                            Button(action: {
                                // Apri sempre il menu di pausa (overlay pergamena)
                                if !isPausedUI {
                                    isPausedUI = true
                                    gameData.gameScene?.isPaused = true
                                    gameData.stopGameTimer()
                                }
                            }) {
                                Image("PauseIcon")
                                    .resizable()
                                    .renderingMode(.original)
                                    .frame(width: 100, height: 50)
                                    .padding(0) // area di tap leggermente più ampia
                                    .contentShape(Rectangle())
                                    .offset(x: -25)
                            }
                            
                            Spacer(minLength: 12)
                            
                            // Score centrato, più piccolo e stabile
                            Text("Score: \(gameData.score)")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .lineLimit(1)
                                .frame(width: 140, alignment: .center)
                                .padding(8)
                                .background(Color.black.opacity(0.4))
                                .cornerRadius(12)
                                .offset(x: -45)
                            
                            Spacer()
                            
                            // Time più piccolo e stabile
                            Text("Time: \(timeString(from: gameData.timeLeft))")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .lineLimit(1)
                                .frame(width: 120, alignment: .center)
                                .padding(8)
                                .background(Color.black.opacity(0.4))
                                .cornerRadius(12)
                                .offset(x: -45)
                        }
                        .padding()
                        Spacer()
                    }
                    .foregroundColor(.white)
                }
                
                // Overlay di Pausa che blocca l'interazione (solo se non c'è video)
                let showPause = isPausedUI && gameData.gameState == .playing && !gameData.showEndGameVideo
                if showPause {
                    ZStack {
                        Color.black.opacity(0.5)
                            .ignoresSafeArea()
                            .transition(.opacity)
                        
                        // Pergamena con scritta Pausa e bottone Riprendi
                        ZStack {
                            Image("pergamena")
                                .resizable()
                                .scaledToFit()
                                .frame(width: min(geometry.size.width * 0.7, 520))
                                .shadow(radius: 8)
                                .transition(.scale(scale: 0.9).combined(with: .opacity))
                                .overlay(
                                    ZStack {
                                        // Pulsante "Riprendi" centrato
                                        Button(action: {
                                            isPausedUI = false
                                            gameData.gameScene?.isPaused = false
                                            gameData.startGameTimer()
                                        }) {
                                            Image("riprendi")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: min(geometry.size.width * 0.45, 280))
                                        }
                                        .offset(y: 15)

                                        // Immagine "Pausa" in alto
                                        VStack {
                                            Image("pausa")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: min(geometry.size.width * 0.95, 780))
                                                .shadow(radius: 6)
                                                .padding(.top, -30)

                                            Spacer()
                                        }
                                    }
                                )
                        }
                        .offset(x: -15, y: -15)
                    }
                    .animation(.easeOut(duration: 0.15), value: showPause)
                    .allowsHitTesting(true) // blocca interazione con la scena sotto
                }
                
                // Vista Video per la fine del gioco
                if gameData.showEndGameVideo {
                    Color.black.opacity(0.9) // Sfondo scuro per il video
                        .ignoresSafeArea()
                        .transition(.opacity)
                    
                    if let player = player {
                        VideoPlayer(player: player)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .aspectRatio(16/9, contentMode: .fit)
                            .scaleEffect(1.1)
                            .disabled(true)
                            .offset(y: -35)
                            .onAppear {
                                // Accredita esperienza una sola volta quando il video appare
                                grantExperienceIfNeeded()
                                // Assicurati che il player parta dall'inizio e riproduca
                                player.seek(to: .zero)
                                player.play()
                                
                                // Imposta un osservatore per il completamento del video
                                NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
                                    gameData.showEndGameVideo = false // Video terminato
                                    gameData.gameState = .gameOver // Transizione alla schermata di Game Over
                                    self.player = nil // Rilascia le risorse del player
                                }
                            }
                            .onDisappear {
                                player.pause()
                                // Rimuovi l'osservatore per prevenire memory leaks o chiamate indesiderate
                                NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
                            }
                    } else {
                        // Prova a caricare il video quando showEndGameVideo diventa true
                        Text("Caricamento Video...")
                            .font(.title)
                            .foregroundColor(.white)
                            .onAppear {
                                // Scegli il video in base allo score: se < 1200 usa "videok.mp4", altrimenti "video.mp4"
                                let resourceName = (gameData.score < 1200) ? "videok" : "video"
                                if let url = Bundle.main.url(forResource: resourceName, withExtension: "mp4") {
                                    self.player = AVPlayer(url: url)
                                } else {
                                    // Video non trovato: accredita comunque XP e passa a game over
                                    grantExperienceIfNeeded()
                                    gameData.showEndGameVideo = false
                                    gameData.gameState = .gameOver
                                }
                            }
                    }
                }
                
                // Schermata Game Over - Mostra solo quando gameState è .gameOver e il video NON è attivo
                if gameData.gameState == .gameOver && !gameData.showEndGameVideo {
                    GameOverScreenView(gameData: gameData, sceneSize: geometry.size)
                        .environmentObject(sessionManager)
                }
            }
            .background(Color.black)
        }
        // Accredito robusto: se per qualunque motivo il video non parte, accreditiamo quando showEndGameVideo diventa true
        .onChange(of: gameData.showEndGameVideo) { _, newValue in
            if newValue {
                grantExperienceIfNeeded()
            }
        }
    }
    
    // Timer formatter
    func timeString(from totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // Calcolo e accredito XP (una volta sola)
    private func grantExperienceIfNeeded() {
        guard !expGranted else { return }
        var delta = 0
        if gameData.score >= 2000 {
            delta = 2
        } else if gameData.score >= 1200 {
            delta = 1
        }
        if delta > 0 {
            experience += delta                 // aggiorna persistenza qui
            NotificationCenter.default.post(    // mantieni la notifica per MySceneView
                name: .trainingCompleted,
                object: nil,
                userInfo: ["delta": delta]
            )
        }
        expGranted = true
    }
}


// ✅ Game Over Screen
struct GameOverScreenView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var gameData: SlicerGameData
    let sceneSize: CGSize
    
    // Session manager per decidere dove tornare
    @EnvironmentObject var sessionManager: SessionManager
    
    var body: some View {
        VStack {
            // Messaggio finale condizionale
            if gameData.score >= 2000 {
                Text("Congratulations! +2 Experience")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 10)
                    .multilineTextAlignment(.center)
            } else if gameData.score >= 1200 {
                Text("Congratulations! +1 Experience")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 10)
                    .multilineTextAlignment(.center)
            } else {
                Text("I'm sorry, this time you didn't reach the goal")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(.red)
                    .shadow(color: .black, radius: 10)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            
            Text("Your Score: \(gameData.score)")
                .font(.largeTitle)
                .foregroundColor(.white)
                .padding(.top, 10)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
            
            Text("High Score: \(gameData.highScore)")
                .font(.title2)
                .foregroundColor(.white.opacity(0.8))
                .padding(.bottom, 30)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
            
            // Pulsante con asset "BackSession" con la stessa logica di navigazione
            Button(action: {
                if sessionManager.isLastSession {
                    // Ultima (o unica) sessione: torna alla Home e mostra la pergamena di fine
                    NotificationCenter.default.post(name: .showHomePergamena, object: nil)
                    NotificationCenter.default.post(name: Notification.Name("goBack"), object: nil)
                    dismiss()
                } else {
                    // Altrimenti: avanza sessione e riprendi GameScene
                    sessionManager.currentSession += 1
                    NotificationCenter.default.post(name: .resumeAfterBoss, object: nil)
                    dismiss()
                }
            }) {
                Image("BackSession")
                    .resizable()
                    .interpolation(.none)
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: min(sceneSize.width * 0.5, 360))
            }
            .buttonStyle(.plain)
            .shadow(radius: 5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.7))
    }
}
