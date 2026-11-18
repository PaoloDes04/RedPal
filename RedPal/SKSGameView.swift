import SwiftUI
import SpriteKit

struct SKSGameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sessionManager: SessionManager
    
    private let scene: SKScene = {
        let s = GameScene.fromSKS()
        return s
    }()

    var body: some View {
        SpriteView(scene: scene, preferredFramesPerSecond: 60, options: [.ignoresSiblingOrder, .allowsTransparency])
            .ignoresSafeArea()
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar) // nasconde eventuale X di sistema
            .onAppear {
                // Ensure the view can receive touches even when scene is paused
                if let skView = scene.view {
                    skView.isMultipleTouchEnabled = false
                }
                
                // Inject SessionManager into GameScene
                if let gs = scene as? GameScene {
                    gs.sessionManager = sessionManager
                }
                
                // Listen for goBack notification
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

