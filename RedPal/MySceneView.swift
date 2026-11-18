import SwiftUI
import SpriteKit
import Combine // Import Combine per ObservableObject conformance

// Stile bottone: animazione di pressione senza cambiare opacità
struct PressDownNoFadeStyle: ButtonStyle {
    var scale: CGFloat = 0.92
    var animation: Animation = .spring(response: 0.22, dampingFraction: 0.85, blendDuration: 0.15)
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(animation, value: configuration.isPressed)
    }
}

struct MySceneView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Usare @StateObject è generalmente preferibile per le istanze di classe che sono di proprietà di una View
    // e dovrebbero persistere per tutta la durata della View.
    @StateObject private var sceneHolder = MySceneHolder()
    
    // Contatore esperienza persistito (può scendere fino a 0)
    @AppStorage("experience") private var experience: Int = 0
    
    // CONTATORI PERSISTENTI per i 4 pulsanti (partono da 1 e restano salvati)
    @AppStorage("stat1") private var stat1: Int = 1
    @AppStorage("stat2") private var stat2: Int = 1
    @AppStorage("stat3") private var stat3: Int = 1
    @AppStorage("stat4") private var stat4: Int = 1
    
    // Messaggio di errore quando non c'è esperienza
    @State private var showNoExpMessage: Bool = false
    
    // Helper: verifica se l’asset esiste (con C maiuscola)
    private var hasCrocettaAsset: Bool {
        #if os(iOS) || os(tvOS) || os(watchOS)
        return UIImage(named: "Crocetta") != nil
        #elseif os(macOS)
        return NSImage(named: "Crocetta") != nil
        #else
        return false
        #endif
    }
    
    private func handleStatTap(_ idx: Int) {
        if experience <= 0 {
            // Niente experience: mostra messaggio in rosso
            withAnimation(.easeInOut(duration: 0.2)) {
                showNoExpMessage = true
            }
            // Auto-hide dopo un attimo
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showNoExpMessage = false
                }
            }
            return
        }
        // Abbiamo almeno 1 exp: incrementa la stat persistente e decrementa exp
        switch idx {
        case 1: stat1 += 1
        case 2: stat2 += 1
        case 3: stat3 += 1
        case 4: stat4 += 1
        default: break
        }
        experience = max(0, experience - 1)
    }
    
    var body: some View {
        ZStack {
            SpriteView(scene: sceneHolder.scene)
                .ignoresSafeArea()
                .zIndex(0)
            
            // Pulsante "Crocetta" (offset applicato al Button)
            Button {
                dismiss()
            } label: {
                Group {
                    if hasCrocettaAsset {
                        Image("Crocetta")
                            .resizable()
                            .renderingMode(.original)
                    } else {
                        // Fallback visibile se l’asset non c’è
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .scaledToFit()
                .frame(width: 44, height: 44)
                .padding(12) // allarga l’area di tap
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .zIndex(1000)
            // Spostala come vuoi qui:
            .offset(x: -155, y: -400)
            .onAppear {
                if !hasCrocettaAsset {
                    print("ATTENZIONE: asset 'Crocetta' non trovato nel bundle/target. Uso il fallback di sistema.")
                }
            }
            
            // LIVELLO 9: 4 pulsanti con asset (offset originali ripristinati)
            ZStack {
                // Pulsante 1 (Colpo Critico)
                Button(action: { handleStatTap(1) }) {
                    Image("Livello 9")
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: 32, height: 32) // 32x32
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressDownNoFadeStyle())
                .zIndex(9)
                .offset(x: -34, y: -98)
                
                // Pulsante 2 (Difesa)
                Button(action: { handleStatTap(2) }) {
                    Image("Livello 9")
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: 32, height: 32) // 32x32
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressDownNoFadeStyle())
                .zIndex(9)
                .offset(x: 126, y: -98)
                
                // Pulsante 3 (Vita)
                Button(action: { handleStatTap(3) }) {
                    Image("Livello 9")
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: 32, height: 32) // 32x32
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressDownNoFadeStyle())
                .zIndex(9)
                .offset(x: -34, y: -207)
                
                // Pulsante 4 (Attacco)
                Button(action: { handleStatTap(4) }) {
                    Image("Livello 9")
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: 32, height: 32) // 32x32
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressDownNoFadeStyle())
                .zIndex(9)
                .offset(x: 128, y: -206)
            }
            .zIndex(9) // intero gruppo al "Livello 9"
            
            // Numeri collegati ai 4 pulsanti (spostati solo loro 100pt a sinistra rispetto a prima)
            ZStack {
                // Numero per Pulsante 1
                Text("\(stat1)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                    .zIndex(9)
                    .offset(x: -122, y: -98) // prima era -22
                
                // Numero per Pulsante 2
                Text("\(stat2)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                    .zIndex(9)
                    .offset(x: 38, y: -98) // prima era 138-? -> 58, ora 100 in meno rispetto a 58 = -42? Manteniamo 38 coerente con posizionamento vicino al pulsante
                
                // Numero per Pulsante 3
                Text("\(stat3)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                    .zIndex(9)
                    .offset(x: -122, y: -207) // prima era -22
                
                // Numero per Pulsante 4
                Text("\(stat4)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                    .zIndex(9)
                    .offset(x: 40, y: -206) // prima era 140-? -> 60, ora 100 in meno = -40; regola se vuoi allinearlo meglio
            }
            .zIndex(9)
            
            // Messaggio rosso quando manca esperienza
            if showNoExpMessage {
                Text("You don't have enough experience to unlock this!")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(12)
                    .shadow(radius: 6)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
                    .zIndex(999)
            }
            
            // Overlay: solo il numero giallo in alto a destra 
            VStack {
                HStack {
                    Spacer()
                    Text("\(experience)")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                        .padding(.trailing, 16)
                        .offset(x: -156, y: 63)
                }
                .padding(.top, 12)
                Spacer()
            }
            .zIndex(500)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onReceive(NotificationCenter.default.publisher(for: .trainingCompleted)) { notif in
            // Leggi il delta dall'userInfo (fallback a 1 per retrocompatibilità)
            let delta = (notif.userInfo?["delta"] as? Int) ?? 1
            experience += max(0, delta)
        }
        .onAppear {
            // Reset una-tantum: porta experience a 0 e livelli a 1.
            // Cambia la chiave se vuoi forzare un nuovo reset in futuro.
            let resetKey = "booktomyReset_2025_11_06_v2"
            let defaults = UserDefaults.standard
            if defaults.bool(forKey: resetKey) == false {
                defaults.set(1, forKey: "stat1")
                defaults.set(1, forKey: "stat2")
                defaults.set(1, forKey: "stat3")
                defaults.set(1, forKey: "stat4")
                defaults.set(0, forKey: "experience") // <<< esperienza a zero
                defaults.set(true, forKey: resetKey)
            }
        }
    }
}

// This class contains the SKScene instance.
@MainActor // Add this attribute
final class MySceneHolder: ObservableObject {
    let scene: MyScene
    
    // Add this publisher for ObservableObject conformance.
    let objectWillChange = PassthroughSubject<Void, Never>()
    func send() { objectWillChange.send() }

    init() {
        // LOAD FROM .sks FILE USING NAME "MyScene"
        if let skscene = MyScene(fileNamed: "MyScene") {
            skscene.size = CGSize(width: 1206, height: 2622)
            skscene.scaleMode = .aspectFit
            self.scene = skscene
        } else {
            // Fallback
            let fallbackScene = MyScene()
            fallbackScene.size = CGSize(width: 1206, height: 2622)
            fallbackScene.scaleMode = .aspectFit
            self.scene = fallbackScene
        }
        // Set the scene to receive touches
        self.scene.isUserInteractionEnabled = true
    }
}
