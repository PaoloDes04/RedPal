import SwiftUI
import AVFoundation

// MARK: - Simple Music Manager for Homepage
final class MusicManager {
    static let shared = MusicManager()
    private var player: AVAudioPlayer?
    private var isPrepared: Bool = false

    // Usa esattamente il brano di menu "sottofondo" con estensioni comuni
    private let baseName = "sottofondo"
    private let candidateExts = ["mp3", "m4a", "wav", "caf"]

    private func prepareIfNeeded() {
        guard !isPrepared else { return }
        for ext in candidateExts {
            if let url = Bundle.main.url(forResource: baseName, withExtension: ext) {
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.numberOfLoops = -1
                    player.prepareToPlay()
                    self.player = player
                    self.isPrepared = true
                    return
                } catch {
                    // Continua a provare altre estensioni
                }
            }
        }
        // Se non trova nulla, resta silenzioso.
    }

    func play() {
        prepareIfNeeded()
        guard let player = player, !player.isPlaying else { return }
        // Richiedi esclusività prima di suonare
        NotificationCenter.default.post(name: .musicExclusiveStart, object: nil, userInfo: ["id": "Home.sottofondo"])
        player.play()
    }

    func stop() {
        guard let player = player else { return }
        player.stop()
        player.currentTime = 0
    }

    func pause() {
        player?.pause()
    }

    func isPlaying() -> Bool {
        return player?.isPlaying ?? false
    }
}

// MARK: - Press Down Button Style (generico)
struct PressDownStyle: ButtonStyle {
    var scale: CGFloat = 0.94
    var animation: Animation = .spring(response: 0.25, dampingFraction: 0.8, blendDuration: 0.2)
    var hapticOnTap: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(animation, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                #if os(iOS)
                if pressed && hapticOnTap {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                #endif
            }
    }
}

// MARK: - Press Down + Dim/Shadow (per "I understand")
struct PressDownDimStyle: ButtonStyle {
    var scale: CGFloat = 0.94
    var pressedOpacity: Double = 0.78
    var normalShadowRadius: CGFloat = 0
    var pressedShadowRadius: CGFloat = 6
    var shadowColor: Color = Color.black.opacity(0.25)
    var shadowX: CGFloat = 0
    var shadowY: CGFloat = 3
    var animation: Animation = .spring(response: 0.25, dampingFraction: 0.8, blendDuration: 0.2)
    var hapticOnTap: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? pressedOpacity : 1.0)
            .shadow(color: shadowColor, radius: configuration.isPressed ? pressedShadowRadius : normalShadowRadius, x: shadowX, y: shadowY)
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(animation, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                #if os(iOS)
                if pressed && hapticOnTap {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                #endif
            }
    }
}

// MARK: - Componenti UI Personalizzati per le Impostazioni

struct CustomSwitch: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(.custom("PressStart2P", size: 18))
                .foregroundColor(Color.black.opacity(0.85))
            Spacer()
            Button(action: {
                withAnimation(Animation.easeInOut(duration: 0.2)) {
                    isOn.toggle()
                }
            }) {
                ZStack {
                    Capsule()
                        .frame(width: 50, height: 30)
                        .foregroundColor(isOn ? Color(red: 0.4, green: 0.7, blue: 0.4) : Color.gray.opacity(0.5))
                    
                    Circle()
                        .frame(width: 26, height: 26)
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                        .offset(x: isOn ? 10 : -10)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

struct CustomDivider: View {
    var body: some View {
        Rectangle()
            .frame(height: 1)
            .foregroundColor(Color.black.opacity(0.15))
    }
}

// MARK: - Vista Impostazioni Modale
struct SettingsView: View {
    @Binding var isPresented: Bool
    
    @AppStorage("musicEnabled") private var musicEnabled: Bool = true
    @AppStorage("soundEffectsEnabled") private var soundEffectsEnabled: Bool = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true

    var body: some View {
        VStack {
            ZStack {
                HStack {
                    Button {
                        withAnimation { isPresented = false }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(Color.black.opacity(0.7))
                    }
                    .buttonStyle(PressDownStyle(hapticOnTap: hapticsEnabled))
                    Spacer()
                }

                Text("Settings")
                    .font(.custom("PressStart2P", size: 28))
                    .foregroundColor(Color.black.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.bottom, 30)
            
            VStack(spacing: 25) {
                CustomSwitch(label: "Music", isOn: $musicEnabled)
                CustomDivider()
                CustomSwitch(label: "Sound effects", isOn: $soundEffectsEnabled)
            }
            
            Spacer()
            
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                Text("Version \(version)")
                    .font(.custom("PressStart2P", size: 12))
                    .foregroundColor(Color.black.opacity(0.6))
            }
        }
        .padding(EdgeInsets(top: 20, leading: 25, bottom: 20, trailing: 25))
        .frame(width: 320, height: 400)
        .background(
            Image("SfondoSettings")
                .resizable()
                .scaledToFill()
        )
        .clipShape(RoundedRectangle(cornerRadius: 25))
        .shadow(color: Color.black.opacity(0.4), radius: 20, y: 10)
        .transition(.scale.combined(with: .opacity))
        .onChange(of: musicEnabled) { _, _ in
            NotificationCenter.default.post(name: .musicPreferenceChanged, object: nil)
        }
    }
}

// MARK: - Vista Menu Sessione di Studio (25/5 fisso + numero sessioni)
struct StudySessionMenuView: View {
    private let studyMinutes = 25
    private let breakMinutes = 5
    @State private var sessions: Int = 1
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true

    var onStart: (Int, Int, Int) -> Void
    var onCancel: () -> Void

    private var blockMinutes: Int { studyMinutes + breakMinutes }
    private var totalMinutes: Int { sessions * blockMinutes }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(Color.black.opacity(0.7))
                }
                .buttonStyle(PressDownStyle(hapticOnTap: hapticsEnabled))
                Spacer()
            }

            VStack(spacing: 16) {
                Text("Set up your session")
                    .font(.custom("PressStart2P", size: 28))
                    .foregroundColor(Color.black.opacity(0.8))
                    .padding(.top, 8)

                VStack(spacing: 16) {
                    HStack {
                        Text("Study time")
                            .font(.custom("PressStart2P", size: 18))
                        Spacer()
                        Text("\(studyMinutes) min")
                            .font(.custom("PressStart2P", size: 20))
                            .fontWeight(.bold)
                    }

                    HStack {
                        Text("Break time")
                            .font(.custom("PressStart2P", size: 18))
                        Spacer()
                        Text("\(breakMinutes) min")
                            .font(.custom("PressStart2P", size: 20))
                            .foregroundColor(.gray)
                    }

                    CustomDivider().padding(.vertical, 6)

                    VStack(spacing: 10) {
                        Text("Total sessions")
                            .font(.custom("PressStart2P", size: 18))

                        Picker("Sessioni totali", selection: $sessions) {
                            ForEach(1...8, id: \.self) { n in
                                Text("\(n)").tag(n)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text("Total duration: \(totalMinutes) min (\(sessions)×\(blockMinutes))")
                            .font(.custom("PressStart2P", size: 14))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)

                Spacer()

                Button(action: {
                    onStart(studyMinutes, totalMinutes, sessions)
                }) {
                    Text("Start")
                        .font(.custom("PressStart2P", size: 24))
                        .bold()
                        .foregroundColor(.white)
                        .padding(.horizontal, 60)
                        .padding(.vertical, 15)
                        .background(Color(red: 0.4, green: 0.7, blue: 0.4))
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 6)
                }
                .buttonStyle(PressDownStyle(hapticOnTap: hapticsEnabled))
            }
            .offset(y: -12)
        }
        .padding(EdgeInsets(top: 30, leading: 25, bottom: 30, trailing: 25))
        .frame(width: 350, height: 450)
        .background(
            Image("SfondoSettings")
                .resizable()
                .scaledToFill()
        )
        .clipShape(RoundedRectangle(cornerRadius: 25))
        .shadow(color: Color.black.opacity(0.4), radius: 20, y: 10)
        .transition(.scale.combined(with: .opacity))
    }
}


struct ContentView: View {
    @StateObject private var sessionManager = SessionManager()
    
    @State private var isShowingSettings = false
    @State private var isZoomedIn = false
    @State private var isShowingStudyMenu = false
    @State private var navigateToFrames = false
    @State private var navigateToTomy = false
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @AppStorage("musicEnabled") private var musicEnabled: Bool = true
    
    // Overlay per primo avvio
    @State private var showFirstLaunchPergamena: Bool = false
    @AppStorage("hasShownFirstLaunchPergamena") private var hasShownFirstLaunchPergamena: Bool = false
    // Mostra una volta per versione (più comodo anche in debug/build nuove)
    @AppStorage("onboardingShownForVersion") private var onboardingShownForVersion: String = ""
    
    // Overlay per “fine sessioni” (già presente)
    @State private var showHomePergamena: Bool = false
    
    private let zoomScale: CGFloat = 2.3
    private let zoomDuration: Double = 1.0
    private let zoomAnchorY: CGFloat = 1.0

    private let backgroundOffsetX: CGFloat = -45
    private let backgroundOffsetY: CGFloat = 0
    
    private let titleOffsetX: CGFloat = -2
    private let titleOffsetY: CGFloat = -230
    private let titleScale: CGFloat = 1.00
    private let titleMaxWidth: CGFloat = 330
    private let buttonsOffsetX: CGFloat = 3
    private let buttonsOffsetY: CGFloat = -10
    private let buttonsWidth: CGFloat = 156
    private let buttonsSpacing: CGFloat = 28
    
    private let settingsButtonSize: CGFloat = 50.0
    private let settingsButtonOffsetX: CGFloat = 169.0
    private let settingsButtonOffsetY: CGFloat = -351.0

    private let startOverlayScale: CGFloat = 0.92
    private let startOverlayYOffset: CGFloat = 6.0

    private let tomyBaseYOffset: CGFloat = 200
    private let tomyFaceYOffset: CGFloat = 200
    private let tomyFaceXOffset: CGFloat = 5

    private func seedPreferencesIfNeeded() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "musicEnabled") == nil {
            defaults.set(true, forKey: "musicEnabled")
        }
        if defaults.object(forKey: "soundEffectsEnabled") == nil {
            defaults.set(true, forKey: "soundEffectsEnabled")
        }
        if defaults.object(forKey: "hapticsEnabled") == nil {
           defaults.set(true, forKey: "hapticsEnabled")
        }
    }
    
    @State private var exclusiveObserver: NSObjectProtocol?

    var body: some View {
        NavigationStack {
            ZStack {
                GeometryReader { geo in
                    let anchorX = ((geo.size.width / 1.6125) + backgroundOffsetX) / max(geo.size.width, 1)
                    
                    Image("HomepageApp")
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea(.all, edges: .all)
                        .padding(.bottom, -1)
                        .scaleEffect(isZoomedIn ? zoomScale : 1.0,
                                     anchor: UnitPoint(x: anchorX, y: zoomAnchorY))
                        .offset(x: backgroundOffsetX, y: backgroundOffsetY)
                        .animation(.linear(duration: zoomDuration), value: isZoomedIn)
                }
                .ignoresSafeArea()

                ZStack {
                    Image("Titolo")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: titleMaxWidth)
                        .scaleEffect(titleScale)
                        .offset(x: titleOffsetX, y: titleOffsetY)
                        .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)

                    VStack(spacing: buttonsSpacing) {
                        Button {
                            isZoomedIn = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + zoomDuration) {
                                withAnimation(.spring()) {
                                    isShowingStudyMenu = true
                                }
                            }
                        } label: {
                            ZStack {
                                Image("BookStart")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 230)
                                    .offset(y: 40)
                                    .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 6)
                                
                                Image("Start")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: buttonsWidth)
                                    .scaleEffect(1.3)
                                    .offset(x: 3, y: 20)
                                    .allowsHitTesting(false)
                                    .zIndex(1)
                            }
                        }
                        .buttonStyle(PressDownStyle(hapticOnTap: hapticsEnabled))
                        
                        Button {
                            navigateToTomy = true
                            MusicManager.shared.stop()
                        } label: {
                            ZStack {
                                Image("BookTomy2")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 180)
                                    .offset(x: 0, y: -140)
                                    .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 6)
                                    .offset(y: tomyBaseYOffset)
                                Image("BookTomy")
                                    .resizable()
                                    .scaledToFit()
                                    .offset(x: -4, y: -147)
                                    .frame(width: 95)
                                    .allowsHitTesting(false)
                                    .offset(x: tomyFaceXOffset, y: tomyFaceYOffset)
                            }
                        }
                        .buttonStyle(PressDownStyle(hapticOnTap: hapticsEnabled))
                    }
                    .offset(x: buttonsOffsetX, y: buttonsOffsetY)
                    
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image("Settings")
                            .renderingMode(.original)
                            .resizable()
                            .scaledToFit()
                            .frame(width: settingsButtonSize, height: settingsButtonSize)
                    }
                    .buttonStyle(PressDownStyle(hapticOnTap: hapticsEnabled))
                    .offset(x: settingsButtonOffsetX, y: settingsButtonOffsetY)
                }
                .opacity(isZoomedIn ? 0 : 1)
                .animation(.linear(duration: zoomDuration).delay(0.2), value: isZoomedIn)
                .allowsHitTesting(!isZoomedIn && !isShowingSettings)

                // --- Overlay per le Impostazioni ---
                if isShowingSettings {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { isShowingSettings = false }
                        .transition(.opacity)

                    SettingsView(isPresented: $isShowingSettings)
                }
                
                // --- Overlay per il Menu di Studio ---
                if isShowingStudyMenu {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .transition(.opacity)

                    StudySessionMenuView(
                        onStart: { studyTime, totalTime, sessions in
                            sessionManager.reset(with: sessions)
                            withAnimation { isShowingStudyMenu = false }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                navigateToFrames = true
                            }
                        },
                        onCancel: {
                            withAnimation { isShowingStudyMenu = false }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isZoomedIn = false
                            }
                        }
                    )
                }
                
                // --- Overlay Primo Avvio ---
                if showFirstLaunchPergamena {
                    GeometryReader { geo in
                        ZStack {
                            Color.black.opacity(0.55)
                                .ignoresSafeArea()
                                .onTapGesture {
                                    showFirstLaunchPergamena = false
                                }
                            
                            Group {
                                if UIImage(named: "pergamena") != nil {
                                    Image("pergamena")
                                        .resizable()
                                        .interpolation(.none)
                                        .scaledToFit()
                                } else {
                                    // Fallback se l'immagine non esiste negli asset
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(Color(white: 0.95))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 24)
                                                .stroke(Color.black.opacity(0.2), lineWidth: 2)
                                        )
                                }
                            }
                            .frame(width: min(geo.size.width * 0.80, 520))
                            .shadow(radius: 10)
                            // X rimossa: resta solo il bottone "I understand" con animazione + dim/ombra
                            .overlay {
                                // Contenuto scrollabile per schermi piccoli
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 16) {
                                        // 1
                                        Text("1. Session Setup")
                                            .font(.custom("PressStart2P", size: 18))
                                            .foregroundColor(.black)
                                        Text("First, start your session using the Pomodoro Technique. As soon as you are ready, press “Start” to begin.")
                                            .font(.custom("PressStart2P", size: 12))
                                            .foregroundColor(.black)
                                            .fixedSize(horizontal: false, vertical: true)

                                        // 2
                                        Text("2. Study Phase (Focus)")
                                            .font(.custom("PressStart2P", size: 18))
                                            .foregroundColor(.black)
                                        Text("During the set study time, the application activates an auto-scrolling game that represents your focus phase. Your character, Tomy, advances in the level while you dedicate yourself to studying.")
                                            .font(.custom("PressStart2P", size: 12))
                                            .foregroundColor(.black)
                                            .fixedSize(horizontal: false, vertical: true)

                                        // 3
                                        Text("3. Break Phase (Rest)")
                                            .font(.custom("PressStart2P", size: 18))
                                            .foregroundColor(.black)
                                        Text("Once the study time is over, the rest phase begins. During this break, you can choose whether to train via a mini-game, face a boss battle, or simply let Tomy rest while you do something else during the break minutes.")
                                            .font(.custom("PressStart2P", size: 12))
                                            .foregroundColor(.black)
                                            .fixedSize(horizontal: false, vertical: true)

                                        // 4
                                        Text("4. Progression and Customization")
                                            .font(.custom("PressStart2P", size: 18))
                                            .foregroundColor(.black)
                                        Text("By using the app consistently, you will see your success reflected directly in Tomy's growth. The app also includes sections for customization and acquiring power-ups for your character.")
                                            .font(.custom("PressStart2P", size: 12))
                                            .foregroundColor(.black)
                                            .fixedSize(horizontal: false, vertical: true)

                                        HStack {
                                            Spacer()
                                            Button {
                                                showFirstLaunchPergamena = false
                                            } label: {
                                                Text("I understand")
                                                    .font(.custom("PressStart2P", size: 14))
                                                    .padding(.horizontal, 18)
                                                    .padding(.vertical, 10)
                                                    .background(Color.black.opacity(0.1))
                                                    .clipShape(Capsule())
                                            }
                                            .buttonStyle(PressDownDimStyle(hapticOnTap: hapticsEnabled))
                                            Spacer()
                                        }
                                        .padding(.top, 8)
                                    }
                                    .padding(.horizontal, 30)
                                    .padding(.top, 24)
                                    .padding(.bottom, 28)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        }
                    }
                    .transition(.opacity.combined(with: .scale))
                    .zIndex(25)
                }
                
                // --- Overlay Pergamena a casa (dopo Boss / fine sessioni) — esistente ---
                if showHomePergamena {
                    GeometryReader { geo in
                        ZStack {
                            Color.black.opacity(0.55)
                                .ignoresSafeArea()
                            
                            Image("pergamena")
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .frame(width: min(geo.size.width * 0.7, 420))
                                .shadow(radius: 8)
                                .overlay(alignment: .topLeading) {
                                    Button {
                                        withAnimation { showHomePergamena = false }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 28, weight: .bold))
                                            .foregroundColor(.black.opacity(0.8))
                                            .padding(16)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .overlay {
                                    Text("Your sessions are over! See you next time!")
                                        .font(.custom("PressStart2P", size: 18))
                                        .foregroundColor(.black)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 32)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        }
                    }
                    .transition(.opacity)
                    .zIndex(20)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                seedPreferencesIfNeeded()
                isZoomedIn = false
                isShowingSettings = false
                isShowingStudyMenu = false
                navigateToFrames = false
                navigateToTomy = false
                showHomePergamena = false
                showFirstLaunchPergamena = false

                // Mostra la pergamena subito al primo avvio della VERSIONE corrente
                let currentVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
                if onboardingShownForVersion != currentVersion {
                    onboardingShownForVersion = currentVersion
                    hasShownFirstLaunchPergamena = true // mantieni anche il vecchio flag per retrocompatibilità
                    showFirstLaunchPergamena = true
                }

                if musicEnabled {
                    MusicManager.shared.play()
                } else {
                    MusicManager.shared.stop()
                }
                
                exclusiveObserver = NotificationCenter.default.addObserver(forName: .musicExclusiveStart, object: nil, queue: .main) { note in
                    let otherID = note.userInfo?["id"] as? String
                    if otherID != "Home.sottofondo" {
                        MusicManager.shared.stop()
                    }
                }
            }
            .onChange(of: musicEnabled) { _, newValue in
                if newValue {
                    if !navigateToFrames && !navigateToTomy {
                        MusicManager.shared.play()
                    }
                } else {
                    MusicManager.shared.stop()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .musicPreferenceChanged)) { _ in
                let enabled = UserDefaults.standard.bool(forKey: "musicEnabled")
                if enabled {
                    if !navigateToFrames && !navigateToTomy {
                        MusicManager.shared.play()
                    }
                } else {
                    MusicManager.shared.stop()
                }
            }
            .onChange(of: navigateToFrames) { _, newValue in
                if newValue == true {
                    MusicManager.shared.stop()
                } else {
                    if musicEnabled {
                        MusicManager.shared.play()
                    }
                    withAnimation {
                        isZoomedIn = false
                    }
                }
            }
            .onChange(of: navigateToTomy) { _, newValue in
                if newValue == true {
                    MusicManager.shared.stop()
                } else {
                    if musicEnabled {
                        MusicManager.shared.play()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .showHomePergamena)) { _ in
                if navigateToFrames {
                    navigateToFrames = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation { showHomePergamena = true }
                }
            }
            .navigationDestination(isPresented: $navigateToFrames) {
                SKSGameView()
                    .environmentObject(sessionManager)
                    .navigationBarBackButtonHidden(true)
            }
            .navigationDestination(isPresented: $navigateToTomy) {
                MySceneView()
                    .navigationBarBackButtonHidden(true)
            }
        }
        .environmentObject(sessionManager)
        .onDisappear {
            if let obs = exclusiveObserver {
                NotificationCenter.default.removeObserver(obs)
                exclusiveObserver = nil
            }
        }
    }
}

#Preview {
    ContentView()
}
