import SwiftUI

// Questo file NON è l'entry point dell’app (quello è RedPalApp).
// Lo lasciamo come supporto a preview/standalone senza @main per evitare il conflitto.

struct MySceneStandalonePreviewApp: View {
    var body: some View {
        MySceneView()
    }
}

// Preview SwiftUI (richiede Xcode 15+)
#Preview {
    MySceneStandalonePreviewApp()
}
