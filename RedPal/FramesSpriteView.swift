//
//  FramesSpriteView.swift
//  RedPal
//
//  Created by You on 24/10/25.
//

import SwiftUI
import SpriteKit

struct FramesSpriteView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geo in
            let scene = makeScene(size: geo.size)
            ZStack {
                SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                    .ignoresSafeArea()

                // Pulsante di chiusura opzionale in alto a destra
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.9))
                                .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 16)
                        .padding(.top, 12)
                    }
                    Spacer()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private func makeScene(size: CGSize) -> SKScene {
        let scene = FramesScene()
        scene.scaleMode = .resizeFill
        scene.size = size
        return scene
    }
}

#Preview {
    FramesSpriteView()
}
