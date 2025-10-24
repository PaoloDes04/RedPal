//
//  GameView.swift
//  RedPal
//
//  Created by You on 21/10/25.
//

import SwiftUI

struct GameView: View {
    // Controllo del movimento orizzontale (parallasse)
    @State private var isRunning: Bool = true
    @State private var baseSpeed: CGFloat = 8.0 // pixel al secondo (lento)
    
    // Dimensioni e layout
    private let groundHeight: CGFloat = 80
    private let whiteOverlayOpacity: CGFloat = 0.12 // patina bianca sopra
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // BACKGROUND PARALLASSE
                ParallaxBackground(
                    size: geo.size,
                    baseSpeed: baseSpeed,
                    isRunning: isRunning,
                    layers: [
                        // layer più lontano (più lento)
                        ParallaxLayer(imageName: "ParallaxFar", speedFactor: 0.2, opacity: 1.0),
                        // layer medio
                        ParallaxLayer(imageName: "ParallaxMid", speedFactor: 0.45, opacity: 1.0),
                        // layer vicino (più veloce, ma sempre lento)
                        ParallaxLayer(imageName: "ParallaxNear", speedFactor: 0.8, opacity: 1.0)
                    ]
                )
                .ignoresSafeArea()
                
                // GROUND (base solida)
                VStack {
                    Spacer()
                    ZStack {
                        // Puoi sostituire con un'immagine tipo "Ground" o "Terra"
                        Rectangle()
                            .fill(Color.brown.opacity(0.95))
                            .frame(height: groundHeight)
                            .overlay(
                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(0.15),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .frame(maxWidth: .infinity, alignment: .bottom)
                }
                .ignoresSafeArea(edges: .bottom)
                
                // PLAYER PLACEHOLDER (sostituisci con il tuo sprite)
                VStack {
                    Spacer()
                    HStack {
                        // Posiziona circa sopra il terreno
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue)
                            .frame(width: 48, height: 64)
                            .overlay(
                                Text("P")
                                    .foregroundColor(.white)
                                    .font(.headline)
                            )
                            .padding(.bottom, groundHeight + 4)
                        Spacer()
                    }
                    .padding(.leading, 40)
                }
                
                // PATINA BIANCA SOPRA
                Color.white.opacity(whiteOverlayOpacity)
                    .ignoresSafeArea()
                
                // CONTROLLI DI DEBUG/TEST (puoi rimuoverli in produzione)
                VStack {
                    HStack(spacing: 12) {
                        Button(isRunning ? "Pausa" : "Avvia") {
                            isRunning.toggle()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        HStack {
                            Text("Velocità")
                            Slider(value: Binding(
                                get: { Double(baseSpeed) },
                                set: { baseSpeed = CGFloat($0) }
                            ), in: 2...40)
                            .frame(width: 160)
                            Text(String(format: "%.0f", baseSpeed))
                                .frame(width: 36, alignment: .trailing)
                        }
                    }
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 8)
                    
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Parallax Background

struct ParallaxLayer: Identifiable {
    let id = UUID()
    let imageName: String
    let speedFactor: CGFloat // 0..1 (più piccolo = più lento)
    let opacity: CGFloat
}

struct ParallaxBackground: View {
    let size: CGSize
    let baseSpeed: CGFloat     // pixel/sec di riferimento
    let isRunning: Bool
    let layers: [ParallaxLayer]
    
    // Un updater temporizzato per animare lo scorrimento
    @State private var lastUpdate: Date = .now
    @State private var offsets: [UUID: CGFloat] = [:] // offset X per layer
    
    // Timer CADence
    private let displayLink = DisplayLink()
    
    var body: some View {
        ZStack {
            ForEach(layers) { layer in
                layerView(layer)
                    .opacity(layer.opacity)
            }
        }
        .onAppear {
            lastUpdate = .now
            displayLink.start { timestamp in
                tick(timestamp: timestamp)
            }
        }
        .onDisappear {
            displayLink.stop()
        }
    }
    
    @ViewBuilder
    private func layerView(_ layer: ParallaxLayer) -> some View {
        // Due copie dell’immagine affiancate per looping continuo
        let w = size.width
        let h = size.height
        
        let offsetX = offsets[layer.id, default: 0]
        
        HStack(spacing: 0) {
            Image(layer.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: w, height: h)
                .clipped()
            Image(layer.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: w, height: h)
                .clipped()
        }
        .offset(x: offsetX)
        .onChange(of: size) { _, _ in
            // Reset offset quando cambia dimensione
            offsets[layer.id] = 0
        }
    }
    
    private func tick(timestamp: Date) {
        let dt = timestamp.timeIntervalSince(lastUpdate)
        lastUpdate = timestamp
        
        guard isRunning, dt > 0 else { return }
        
        var newOffsets = offsets
        for layer in layers {
            let current = newOffsets[layer.id, default: 0]
            let speed = baseSpeed * layer.speedFactor
            let dx = CGFloat(dt) * -speed // scorre verso sinistra
            
            var updated = current + dx
            // Loop: quando superi la larghezza di una tile, riporta indietro
            let tileWidth = size.width
            if updated <= -tileWidth {
                updated += tileWidth
            }
            if updated >= 0 {
                updated -= tileWidth
            }
            newOffsets[layer.id] = updated
        }
        
        offsets = newOffsets
    }
}

// MARK: - DisplayLink helper

final class DisplayLink {
    private var link: CADisplayLink?
    private var callback: ((Date) -> Void)?
    
    func start(_ callback: @escaping (Date) -> Void) {
        stop()
        self.callback = callback
        let link = CADisplayLink(target: self, selector: #selector(step))
        link.add(to: .current, forMode: .common)
        self.link = link
    }
    
    func stop() {
        link?.invalidate()
        link = nil
        callback = nil
    }
    
    @objc private func step(_ sender: CADisplayLink) {
        callback?(Date())
    }
}

#Preview {
    GameView()
}
