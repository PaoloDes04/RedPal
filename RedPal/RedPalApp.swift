//Per i Font in debug

import SwiftUI
import UIKit // esplicito per UIFont (iOS/iPadOS)

@main
struct RedPalApp: App {

    init() {
        #if DEBUG
        // Stampa i font disponibili solo in Debug
        for family in UIFont.familyNames.sorted() {
            let names = UIFont.fontNames(forFamilyName: family)
            print("Famiglia: \(family) --- Nomi dei Font: \(names)")
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
