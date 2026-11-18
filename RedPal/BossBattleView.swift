import SwiftUI
import SpriteKit
import AVFoundation

// MARK: - Componenti UI (rinominati per evitare conflitti)

struct BossHPBarView: View {
    let currentHP: Double
    let maxHP: Double
    let gradientColors: [Color]
    let title: String
    let overlayAsset: String?

    @State private var ghostHP: Double

    init(currentHP: Double, maxHP: Double, gradientColors: [Color], title: String, overlayAsset: String?) {
        self.currentHP = currentHP
        self.maxHP = maxHP
        self.gradientColors = gradientColors
        self.title = title
        self.overlayAsset = overlayAsset
        _ghostHP = State(initialValue: currentHP)
    }

    private var percentage: Double { maxHP > 0 ? currentHP / maxHP : 0 }
    private var ghostPercentage: Double { maxHP > 0 ? ghostHP / maxHP : 0 }

    var body: some View {
        VStack(spacing: 4) {
            if !title.isEmpty {
                Text(title)
                    .font(.custom("PressStart2P-Regular", size: 16))
                    .foregroundColor(gradientColors.last ?? .white)
            }

            ZStack {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.black.opacity(0.6))

                        Rectangle()
                            .fill(Color.gray.opacity(0.7))
                            .frame(width: max(0, ghostPercentage * geometry.size.width))
                            .animation(.linear(duration: 0.5), value: ghostHP)

                        Rectangle()
                            .fill(LinearGradient(colors: gradientColors, startPoint: .trailing, endPoint: .leading))
                            .frame(width: max(0, percentage * geometry.size.width))
                            .animation(.easeInOut(duration: 0.5), value: currentHP)
                            .overlay {
                                if let asset = overlayAsset {
                                    Image(asset)
                                        .resizable()
                                        .renderingMode(.template)
                                        .foregroundColor(.black.opacity(0.2))
                                        .blendMode(.multiply)
                                }
                            }
                    }
                }
                .frame(height: 20)

                Text("\(Int(currentHP)) / \(Int(maxHP))")
                    .font(.custom("PressStart2P-Regular", size: 14))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            .shadow(color: .black.opacity(0.5), radius: 5, x: 0, y: 3)
        }
        .onChange(of: currentHP) {
            if currentHP < ghostHP {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.easeOut(duration: 0.6)) {
                        ghostHP = currentHP
                    }
                }
            } else {
                ghostHP = currentHP
            }
        }
    }
}

struct BossActionButton: View {
    @ObservedObject var logic: GameLogic
    let action: () -> Void
    let assetName: String
    let actionType: ActionType
    let buttonSize: CGFloat

    init(logic: GameLogic, action: @escaping () -> Void, assetName: String, actionType: ActionType, buttonSize: CGFloat) {
        self.logic = logic
        self.action = action
        self.assetName = assetName
        self.actionType = actionType
        self.buttonSize = buttonSize
    }

    enum ActionType {
        case attack, parry
        var color: Color { self == .attack ? .indigo : .green }
    }

    var cooldown: Double { actionType == .attack ? logic.attackCooldown : logic.parryCooldown }
    var maxCooldown: Double { actionType == .attack ? logic.attackCDMax : logic.parryCDMax }
    var progress: Double { max(0, (maxCooldown - cooldown) / maxCooldown) }
    var isReady: Bool { cooldown <= 0 }

    var body: some View {
        Button(action: action) {
            ZStack {
                Image(assetName)
                    .resizable()
                    .renderingMode(.original)
                    .frame(width: buttonSize, height: buttonSize)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(actionType.color.opacity(0.6), lineWidth: isReady ? 3 : 0)
                            .animation(.easeInOut(duration: 0.2), value: isReady)
                    )
                    .opacity(isReady ? 1.0 : 0.6)

                if !isReady {
                    Circle()
                        .fill(.black)
                        .frame(width: buttonSize, height: buttonSize)
                        .opacity(0.7)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.white.opacity(0.8), lineWidth: 6)
                        .frame(width: buttonSize - 12, height: buttonSize - 12)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: progress)

                    Text(String(format: "%.1f", cooldown))
                        .font(.custom("PressStart2P-Regular", size: 20))
                        .foregroundColor(.white)
                }
            }
            .scaleEffect(isReady ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isReady)
        }
        .disabled(!logic.gameActive || !isReady)
        .opacity(logic.gameActive ? 1.0 : 0.8)
    }
}

// MARK: - Boss Battle View

struct BossBattleView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject var logic = GameLogic()

    @State private var battleScene: MyBattleScene = {
        // CARICA LA SCENA DALLO .sks DEL BOSS
        let scene = MyBattleScene(fileNamed: "BossScene") ?? MyBattleScene()
        scene.scaleMode = .aspectFill
        return scene
    }()

    let heroSpriteHeight: CGFloat = 72
    let hpBarHeight: CGFloat = 20
    let spaceAboveHero: CGFloat = 20
    let characterGroundY_SK: CGFloat = -200

    // Stato overlay countdown
    @State private var isCountingDown = false
    @State private var countdownValue = 3

    // Valore Y esplicito per i pulsanti (regolabile)
    let buttonsY: CGFloat = 780

    @Environment(\.dismiss) private var dismiss
    
    // Musica Boss
    @AppStorage("musicEnabled") private var musicEnabled: Bool = true
    @State private var bossPlayer: AVAudioPlayer?
    @State private var exclusiveObserver: NSObjectProtocol?
    private let musicTrackID = "Boss.BossFight"

    private func startCountdownAndDismiss() {
        isCountingDown = true
        countdownValue = 3

        // Step 2 e 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { countdownValue = 2 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { countdownValue = 1 }

        // Al termine: gestisci flusso in base alle sessioni
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if sessionManager.isLastSession {
                // Ultima (o unica) sessione: torna a Home e mostra pergamena
                NotificationCenter.default.post(name: .showHomePergamena, object: nil)
                NotificationCenter.default.post(name: Notification.Name("goBack"), object: nil)
                stopBossMusic()
                dismiss()
            } else {
                // Avanza sessione e riprendi GameScene
                sessionManager.currentSession += 1
                NotificationCenter.default.post(name: .resumeAfterBoss, object: nil)
                stopBossMusic()
                dismiss()
            }
        }
    }
    
    private func prepareBossMusicIfNeeded() {
        guard bossPlayer == nil else { return }
        let candidates = ["mp3", "m4a", "wav", "caf"]
        for ext in candidates {
            if let url = Bundle.main.url(forResource: "BossFight", withExtension: ext) {
                if let p = try? AVAudioPlayer(contentsOf: url) {
                    p.numberOfLoops = -1
                    p.prepareToPlay()
                    bossPlayer = p
                    break
                }
            }
        }
    }
    private func playBossMusic() {
        prepareBossMusicIfNeeded()
        // Chiedi esclusività
        NotificationCenter.default.post(name: .musicExclusiveStart, object: nil, userInfo: ["id": musicTrackID])
        if musicEnabled {
            bossPlayer?.play()
        } else {
            bossPlayer?.pause()
        }
    }
    private func stopBossMusic() {
        bossPlayer?.stop()
        bossPlayer = nil
    }

    private func countdownAssetName() -> String {
        switch countdownValue {
        case 3: return "tre"
        case 2: return "due"
        default: return "uno"
        }
    }
    
    private var isVictory: Bool { logic.bossHP <= 0 }
    private var isDefeat: Bool { logic.heroHP <= 0 }
    private var overlayHeaderAsset: String { isVictory ? "Congratulazioni" : "Lose" }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // NESSUN fondo: lasciamo che SpriteView copra tutto senza colore sotto
                SpriteView(scene: battleScene)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .ignoresSafeArea()
                    .background(Color.clear)
                    .onAppear {
                        logic.scene = battleScene
                        battleScene.gameLogic = logic
                        battleScene.size = geometry.size
                        playBossMusic()
                        // osserva esclusività: STOP se parte altro
                        exclusiveObserver = NotificationCenter.default.addObserver(forName: .musicExclusiveStart, object: nil, queue: .main) { note in
                            let otherID = note.userInfo?["id"] as? String
                            if otherID != musicTrackID {
                                stopBossMusic()
                            }
                        }
                    }
                    .onDisappear {
                        stopBossMusic()
                        if let obs = exclusiveObserver {
                            NotificationCenter.default.removeObserver(obs)
                            exclusiveObserver = nil
                        }
                    }
                    .onChange(of: geometry.size) { newSize in
                        battleScene.size = newSize
                    }

                VStack {
                    BossHPBarView(
                        currentHP: logic.bossHP,
                        maxHP: logic.bossMaxHP,
                        gradientColors: [
                            Color(red: 0, green: 0.4, blue: 0),
                            Color(red: 0.2, green: 0.8, blue: 0.2)
                        ],
                        title: "",
                        overlayAsset: "LeafTexture"
                    )
                    .padding(.top, geometry.safeAreaInsets.top + 20)
                    .frame(maxWidth: .infinity, alignment: .top)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)

                // Pulsanti con sfondo verde
                ZStack {
                    // Sfondo verde a tutta larghezza
                    Color(red: 0.05, green: 0.2, blue: 0.05).opacity(0.9)

                    HStack(spacing: 80) {
                        let buttonSize = geometry.size.width * 0.30

                        BossActionButton(
                            logic: logic,
                            action: { logic.attemptAttack() },
                            assetName: "AttackIcon",
                            actionType: .attack,
                            buttonSize: buttonSize
                        )

                        BossActionButton(
                            logic: logic,
                            action: { logic.attemptParry() },
                            assetName: "ParryIcon",
                            actionType: .parry,
                            buttonSize: buttonSize
                        )
                    }
                    .padding(.horizontal, 24)
                }
                .frame(width: geometry.size.width, height: 160)
                .position(
                    x: geometry.size.width / 2,
                    y: 750
                )

                BossHPBarView(
                    currentHP: logic.heroHP,
                    maxHP: logic.heroMaxHP,
                    gradientColors: [Color(red: 0.5, green: 0, blue: 0), .red],
                    title: "",
                    overlayAsset: nil
                )
                .frame(width: geometry.size.width * 0.3)
                .position(
                    x: geometry.size.width * 0.25,
                    y: (geometry.size.height / 2 - characterGroundY_SK)
                        - (heroSpriteHeight / 2)
                        - spaceAboveHero
                        - (hpBarHeight / 2)
                )

                if !logic.message.isEmpty {
                    Text(logic.message)
                        .font(.custom("PressStart2P-Regular", size: 12))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.yellow.opacity(0.8))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        .transition(.opacity.animation(.easeInOut(duration: 0.5)))
                        .offset(y: geometry.safeAreaInsets.top + 180)
                }

                // Mostra i bottoni di reset/menu SOLO se non stiamo mostrando l'overlay di vittoria/sconfitta
                if !logic.gameActive && !(isVictory || isDefeat) {
                    VStack(spacing: 20) {
                        Button("Ricomincia") { logic.resetGame() }
                            .font(.custom("PressStart2P-Regular", size: 16))
                            .padding()
                            .background(Color.green.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(10)

                        Button("Torna al Menu") {
                            stopBossMusic()
                            dismiss()
                        }
                            .font(.custom("PressStart2P-Regular", size: 16))
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .transition(.opacity.animation(.easeInOut(duration: 1.0)))
                }

                // Overlay "pergamena" con header dinamico (Congratulazioni/Lose), pulsante BackSession e countdown
                if isVictory || isDefeat {
                    ZStack {
                        Color.black.opacity(0.55)
                            .ignoresSafeArea()

                        // Pergamena centrata
                        Image("pergamena")
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: min(geometry.size.width * 0.8, 700))
                            .overlay(
                                VStack(spacing: 40) {
                                    Image(overlayHeaderAsset)
                                        .resizable()
                                        .interpolation(.none)
                                        .scaledToFit()
                                        .frame(width: min(geometry.size.width * 0.7, 520))
                                        .offset(y: -50)

                                    if isCountingDown {
                                        Image(countdownAssetName())
                                            .resizable()
                                            .interpolation(.none)
                                            .scaledToFit()
                                            .frame(width: min(geometry.size.width * 0.35, 220))
                                            .transition(.opacity)
                                    } else {
                                        Button {
                                            startCountdownAndDismiss()
                                        } label: {
                                            Image("BackSession")
                                                .resizable()
                                                .interpolation(.none)
                                                .scaledToFit()
                                                .frame(width: min(geometry.size.width * 0.5, 360))
                                        }
                                    }
                                }
                                .padding(.top, 60)
                                .padding(.bottom, 60)
                            )
                    }
                    .transition(.opacity.animation(.easeInOut(duration: 0.4)))
                    .zIndex(10)
                    .contentShape(Rectangle())
                    .allowsHitTesting(true)
                }
            }
        }
        .onChange(of: musicEnabled) { _, newValue in
            if newValue {
                playBossMusic()
            } else {
                bossPlayer?.pause()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .musicPreferenceChanged)) { _ in
            if musicEnabled {
                playBossMusic()
            } else {
                bossPlayer?.pause()
            }
        }
    }
    struct BattleScenePreview: View {
        var scene: MyBattleScene {
            let s = MyBattleScene(fileNamed: "BossScene") ?? MyBattleScene()
            s.scaleMode = .aspectFill
            s.size = CGSize(width: 390, height: 844) // importantissimo in preview
            return s
        }

        var body: some View {
            SpriteView(scene: scene)
                .ignoresSafeArea()
                .frame(width: 390, height: 844)
        }
    }

    struct BattleScenePreview_Previews: PreviewProvider {
        static var previews: some View {
            BattleScenePreview()
                .preferredColorScheme(.dark)
        }
    }
}
