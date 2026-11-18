// SKSTomyView.swift
import SwiftUI
import SpriteKit

struct SKSTomyView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let scene: SKScene = {
        TomyScene.fromSKS()
    }()

    var body: some View {
        SpriteView(scene: scene, preferredFramesPerSecond: 60, options: [.ignoresSiblingOrder, .allowsTransparency])
            .ignoresSafeArea()
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                if let skView = scene.view {
                    skView.isMultipleTouchEnabled = false
                }
                NotificationCenter.default.addObserver(
                    forName: Notification.Name("goBack"),
                    object: nil,
                    queue: .main
                ) { _ in
                    dismiss()
                }
            }
    }
}
