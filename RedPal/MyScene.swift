import SpriteKit
import CoreGraphics // For CGPoint, CGFloat

// For macOS, SKColor is NSColor. For iOS/tvOS, it's UIColor.
#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
typealias SKColor = UIColor
#elseif os(macOS)
import AppKit
typealias SKColor = NSColor
#endif

class MyScene: SKScene {
    // --- Carousel Properties ---
    private var tomyNode: SKSpriteNode!
    private var ombra1Node: SKSpriteNode!
    private var ombra2Node: SKSpriteNode!

    // Sprite per le scritte
    private var tomyTextSprite: SKSpriteNode!
    private var ombra1TextSprite: SKSpriteNode!
    private var ombra2TextSprite: SKSpriteNode!

    // Mappa i nomi dei nodi ai nomi delle immagini delle loro scritte specifiche
    private let textSpriteImageMapping: [String: String] = [
        "Tomy": "Default",
        "Ombra1": "Locked1",
        "Ombra2": "Locked2"
    ]

    // MAPPATURA: Definisce le posizioni X e Y per le scritte di ogni personaggio, relative al centro del personaggio.
    // Puoi modificare questi CGPoint per aggiustare la posizione di ogni scritta individualmente.
    private let textSpriteOffsetMapping: [String: CGPoint] = [
        "Tomy": CGPoint(x: 0.0, y: -750), // Posizione X, Y per la scritta "Default" di Tomy
        "Ombra1": CGPoint(x: 0.0, y: -375), // Posizione X, Y per la scritta "Locked1" di Ombra1
        "Ombra2": CGPoint(x: 0.0, y: -375)  // Posizione X, Y per la scritta "Locked2" di Ombra2
    ]

    // NUOVA MAPPATURA: Definisce la scala per le scritte di ogni personaggio.
    // Puoi modificare questi valori CGFloat per cambiare la grandezza di ogni scritta individualmente.
    private let textSpriteScaleMapping: [String: CGFloat] = [
        "Tomy": 1.4,   // Scala per la scritta "Default" di Tomy
        "Ombra1": 0.7, // Scala per la scritta "Locked1" di Ombra1
        "Ombra2": 0.7  // Scala per la scritta "Locked2" di Ombra2
    ]

    // Memorizza i nodi nell'ordine visivo corrente: [sinistra, centro, destra]
    private var carouselItems: [SKSpriteNode] = []

    // Costanti per layout e animazione del carosello
    private let carouselY: CGFloat = -560 // Modificato: Posiziona il carosello a 600px dal basso della scena (visibile)
    private let sideCarouselY: CGFloat = -600 // NUOVO: Y per i personaggi ai lati. Puoi modificarlo per alzarli/abbassarli.
    private let centerOffset: CGFloat = -590 // Modificato: Spostato il carosello più a destra (da -650 a -450)
    private let sideOffset: CGFloat = 438 // Spaziatura tra gli elementi del carosello

    private let smallScale: CGFloat = 0.7 // Scala generale per Ombra1/Ombra2 quando ai lati
    private let tomySideScale: CGFloat = 0.3 // Scala per Tomy quando è ai lati
    private let largeScale: CGFloat = 0.8 // Scala per Tomy quando è al centro

    // NUOVA COSTANTE: Scala per Ombra1 e Ombra2 quando sono al centro.
    // Puoi modificare questo valore per cambiare la loro grandezza.
    // Esempio: 0.5 (rimangono piccoli), 0.75 (scala media), 1.0 (si ingrandiscono come Tomy)
    private let ombraCentralScale: CGFloat = 1.6 // Ora Ombra1/Ombra2 si ingrandiscono come Tomy quando al centro

    // Costante per l'offset verticale delle scritte relative ai personaggi - RIMOSSA, ora usata la mapping
    // private let textSpriteOffsetFromNode: CGFloat = -120

    // NUOVA COSTANTE: Scala base per tutte le scritte (Default, Locked1, Locked2). - RIMOSSA, ora usata la mapping
    // private let textSpritesBaseScale: CGFloat = 0.5

    private let animationDuration: TimeInterval = 0.4

    // --- Original Scene Properties ---
    private var leftArrow: SKSpriteNode!
    private var rightArrow: SKSpriteNode!

    // Variabili per i nodi di aumento statistiche (non interattivi per i tocchi)
    private var increaseStatButtons: [SKSpriteNode] = []

    // Pulsante verde opzionale (non interattivi per i tocchi)
    private var greenButton: SKSpriteNode?

    // --- NUOVA PROPRIETÀ per ParteInf ---
    private var parteInfNode: SKSpriteNode!

    override func didMove(to view: SKView) {
        setupCarouselItems()
        setupArrows()
        setupIncreaseStatButtons()
        setupGreenButton()
        setupParteInf()
    }

    // --- Carousel Setup ---
    private func setupCarouselItems() {
        // Helper per recuperare nodo sprite e rimuovere eventuali text sprites esistenti
        func setupCharacterNode(name: String) -> SKSpriteNode {
            guard let retrievedNode = childNode(withName: name) as? SKSpriteNode else {
                fatalError("ERRORE: Nodo '\(name)' NON trovato nella scena .sks o non è un SKSpriteNode. Assicurati che sia un nodo Sprite, figlio diretto della scena, e che il suo nome sia ESATTAMENTE '\(name)'.")
            }
            retrievedNode.zPosition = 5
            // Rimuovi eventuali sprite di testo preesistenti con il nome "TextSprite"
            retrievedNode.children.filter({ $0.name == "TextSprite" }).forEach { $0.removeFromParent() }
            return retrievedNode
        }

        tomyNode = setupCharacterNode(name: "Tomy")
        ombra1Node = setupCharacterNode(name: "Ombra1")
        ombra2Node = setupCharacterNode(name: "Ombra2")

        // Crea e aggiungi gli sprite di testo come figli dei nodi principali
        func createAndAddTextSprite(to node: SKSpriteNode, initialImageName: String) -> SKSpriteNode {
            let textSprite = SKSpriteNode(imageNamed: initialImageName)

            guard textSprite.texture != nil else {
                fatalError("ERRORE: Immagine per la scritta '\(initialImageName)' NON trovata. Assicurati che il file immagine esista e sia presente negli Asset Catalog o nel bundle con il nome esatto. Riprova a pulire la build (Product > Clean Build Folder).")
            }

            guard let nodeName = node.name,
                  let offset = textSpriteOffsetMapping[nodeName],
                  let scale = textSpriteScaleMapping[nodeName] else { // RECUPERA LA SCALA SPECIFICA
                fatalError("ERRORE: Offset o Scala per il nodo '\(node.name ?? "Senza nome")' NON trovato nelle mapping. Assicurati di aver definito un CGPoint e una CGFloat per ogni personaggio nei rispettivi dizionari.")
            }

            textSprite.name = "TextSprite"
            textSprite.position = offset // UTILIZZA L'OFFSET SPECIFICO DAL DIZIONARIO
            textSprite.zPosition = 1
            textSprite.setScale(scale) // IMPOSTA LA SCALA SPECIFICA DELLA SCRITTA
            node.addChild(textSprite)
            print("DEBUG: '\(initialImageName)' textSprite aggiunto a \(node.name ?? "Senza nome"). Padre: \(textSprite.parent?.name ?? "Nessun padre") (Offset: \(offset), Scala: \(scale))")
            return textSprite
        }

        tomyTextSprite = createAndAddTextSprite(to: tomyNode, initialImageName: textSpriteImageMapping["Tomy"]!)
        ombra1TextSprite = createAndAddTextSprite(to: ombra1Node, initialImageName: textSpriteImageMapping["Ombra1"]!)
        ombra2TextSprite = createAndAddTextSprite(to: ombra2Node, initialImageName: textSpriteImageMapping["Ombra2"]!)

        carouselItems = [ombra1Node, tomyNode, ombra2Node]
        applyTransformations(animated: false)
    }

    // Applica posizione, scala, zPosition e visibilità delle scritte in base al ruolo dell'elemento
    private func applyTransformations(animated: Bool) {
        let leftX = size.width / 2 - sideOffset + centerOffset
        let centerX = size.width / 2 + centerOffset
        let rightX = size.width / 2 + sideOffset + centerOffset

        let positions = [
            CGPoint(x: leftX, y: sideCarouselY),  // Usa sideCarouselY per il personaggio a sinistra
            CGPoint(x: centerX, y: carouselY),    // Usa carouselY per il personaggio centrale
            CGPoint(x: rightX, y: sideCarouselY)   // Usa sideCarouselY per il personaggio a destra
        ]

        // Le zPosition sono fisse per posizione
        let zPositions: [CGFloat] = [5, 9, 5] // Carosello dietro le frecce (zPosition 10)

        print("--- Applicando Trasformazioni (animated: \(animated)) ---") // DEBUG
        for (index, node) in carouselItems.enumerated() {
            let targetPosition = positions[index]
            let targetZPosition = zPositions[index]
            let isCentral = (index == 1)

            // LOGICA MODIFICATA PER LA SCALA:
            // Tomy si ingrandisce quando è al centro.
            // Ombra1 e Ombra2 usano ombraCentralScale quando sono al centro.
            // Tutti i nodi sono piccoli quando sono ai lati.
            let targetScale: CGFloat
            if isCentral {
                if node.name == "Tomy" {
                    targetScale = largeScale // Tomy diventa grande se è al centro (largeScale)
                } else { // Ombra1 o Ombra2 è al centro
                    targetScale = ombraCentralScale // Ombra1/Ombra2 usano questa scala quando sono al centro
                }
            } else { // Il nodo non è al centro (è ai lati)
                if node.name == "Tomy" {
                    targetScale = tomySideScale // Tomy usa la sua scala specifica quando ai lati
                } else {
                    targetScale = smallScale // Ombra1/Ombra2 usano la scala piccola generale quando ai lati
                }
            }

            let textSprite = node.children.first(where: { $0.name == "TextSprite" }) as? SKSpriteNode

            if let textSprite = textSprite {
                let targetTextAlpha: CGFloat = isCentral ? 1.0 : 0.0
                let targetTextTextureName: String = textSpriteImageMapping[node.name!]!

                if animated {
                    print("  Node: \(node.name ?? "N/A") - Posizione iniziale: \(node.position), Scala iniziale: \(node.xScale), Z iniziale: \(node.zPosition)") // DEBUG
                    let moveAction = SKAction.move(to: targetPosition, duration: animationDuration)
                    let scaleAction = SKAction.scale(to: targetScale, duration: animationDuration)

                    let startZPosition = node.zPosition
                    let zPositionAction = SKAction.customAction(withDuration: animationDuration) { (node, elapsed) in
                        let currentZPosition = startZPosition + (targetZPosition - startZPosition) * (elapsed / self.animationDuration)
                        node.zPosition = currentZPosition
                    }

                    let groupAction = SKAction.group([moveAction, scaleAction, zPositionAction])
                    node.run(groupAction) {
                        print("  Node: \(node.name ?? "N/A") - Posizione finale dopo azione: \(node.position), Scala finale: \(node.xScale), Z finale: \(node.zPosition)") // DEBUG
                    }

                    let fadeAction = SKAction.fadeAlpha(to: targetTextAlpha, duration: animationDuration)
                    let setTextureAction = SKAction.setTexture(SKTexture(imageNamed: targetTextTextureName))

                    let textSpriteActionSequence: SKAction
                    if targetTextAlpha == 1.0 {
                        // Quando appare, imposta prima la texture, poi sfuma in ingresso
                        textSpriteActionSequence = SKAction.sequence([setTextureAction, fadeAction])
                    } else {
                        // Quando scompare, sfuma prima in uscita, poi imposta la texture (o la mantiene invisibile)
                        textSpriteActionSequence = SKAction.sequence([fadeAction, setTextureAction])
                    }

                    textSprite.run(textSpriteActionSequence) {
                        print("  TextSprite per \(node.name ?? "N/A") - Texture finale: '\(targetTextTextureName)', Alpha finale: \(textSprite.alpha)") // DEBUG
                    }

                } else {
                    node.position = targetPosition
                    node.setScale(targetScale)
                    node.zPosition = targetZPosition
                    textSprite.texture = SKTexture(imageNamed: targetTextTextureName)
                    textSprite.alpha = targetTextAlpha
                    print("  Node: \(node.name ?? "N/A") - Impostato posizione: \(node.position), Scala: \(node.xScale), Z: \(node.zPosition), TextSprite: '\(targetTextTextureName)', Alpha: \(textSprite.alpha) (non animato)") // DEBUG
                }
            }
        }
    }

    // --- Carousel Rotation Logic ---
    enum CarouselDirection {
        case left, right
    }

    private func rotateCarousel(direction: CarouselDirection) {
        var newCarouselItems = carouselItems
        if direction == .right {
            let firstItem = newCarouselItems.removeFirst()
            newCarouselItems.append(firstItem)
        } else {
            let lastItem = newCarouselItems.removeLast()
            newCarouselItems.insert(lastItem, at: 0)
        }
        carouselItems = newCarouselItems
        applyTransformations(animated: true)
    }

    // --- Original Scene Setup Functions (adattate) ---
    private func setupArrows() {
        guard let retrievedLeftArrow = childNode(withName: "FrecciaSinistra") as? SKSpriteNode else {
            fatalError("ERRORE: FrecciaSinistra NON trovata nella scena .sks o non è un SKSpriteNode. Assicurati che sia un nodo Sprite, figlio diretto della scena, e che il suo nome sia ESATTAMENTE 'FrecciaSinistra'.")
        }
        leftArrow = retrievedLeftArrow
        leftArrow.zPosition = 10 // Le frecce rimangono sempre in primo piano

        guard let retrievedRightArrow = childNode(withName: "FrecciaDestra") as? SKSpriteNode else {
            fatalError("ERRORE: FrecciaDestra NON trovata nella scena .sks o non è un SKSpriteNode. Assicurati che sia un nodo Sprite, figlio diretto della scena, e che il suo nome sia ESATTAMENTE 'FrecciaDestra'.")
        }
        rightArrow = retrievedRightArrow
        rightArrow.zPosition = 10 // Le frecce rimangono sempre in primo piano
    }

    // NUOVE POSIZIONI PER I PULSANTI DI STATISTICHE
    private func setupIncreaseStatButtons() {
        let buttonNames = ["AumentoStats1", "AumentoStats2", "AumentoStats3", "AumentoStats4"]

        let statButtonRightOffset: CGFloat = 150 // Distanza dal bordo destro della scena
        let statButtonBottomOffset: CGFloat = 100 // Distanza dal bordo inferiore della scena
        let spacingY: CGFloat = 50 // Spaziatura verticale tra i pulsanti

        for (index, name) in buttonNames.enumerated() {
            let button = SKSpriteNode(imageNamed: name)
            guard button.texture != nil else {
                fatalError("ERRORE: Immagine per il pulsante '\(name)' NON trovata. Assicurati che il file immagine esista e sia presente negli Asset Catalog o nel bundle con il nome exacto. Riprova a pulire la build (Product > Clean Build Folder).")
            }
            button.name = name
            // Posiziona i pulsanti sul lato destro, distanziati dal bordo
            button.position = CGPoint(x: size.width - statButtonRightOffset, y: statButtonBottomOffset + CGFloat(index) * spacingY)
            button.setScale(0.5)
            addChild(button)
            increaseStatButtons.append(button)
        }
    }

    private func setupGreenButton() {
        let buttonImageName = "AumentoStats"
        let newGreenButton = SKSpriteNode(imageNamed: buttonImageName)
        guard newGreenButton.texture != nil else {
            fatalError("ERRORE: Immagine per il pulsante verde '\(buttonImageName)' NON trovata. Assicurati che il file immagine esista e sia presente negli Asset Catalog o nel bundle con il nome exacto. Riprova a pulire la build (Product > Clean Build Folder).")
        }
        newGreenButton.name = "greenButton"

        // Posiziona il pulsante verde un po' più in basso e a sinistra del blocco dei pulsanti stat
        let greenButtonRightOffset: CGFloat = 200 // Più a sinistra del blocco di stat buttons
        let greenButtonBottomOffset: CGFloat = 50 // Più in basso di tutto
        newGreenButton.position = CGPoint(x: size.width - greenButtonRightOffset, y: greenButtonBottomOffset)
        newGreenButton.setScale(0.5)
        addChild(newGreenButton)
        greenButton = newGreenButton
    }

    private func setupParteInf() {
        guard let retrievedParteInf = childNode(withName: "ParteInf") as? SKSpriteNode else {
            fatalError("ERRORE: Nodo 'ParteInf' NON trovato nella scena .sks o non è un SKSpriteNode. Assicurati che sia un nodo Sprite, figlio diretto della scena, e che il suo nome sia ESATTAMENTE 'ParteInf'.")
        }
        parteInfNode = retrievedParteInf
        parteInfNode.zPosition = -10
    }

    private func animateTap(on node: SKNode) {
        // Questa funzione è stata rimossa dalle chiamate, le frecce non animano più la scala.
        // Se in futuro si volesse un'animazione di tap diversa, andrebbe reintrodotta e usata.
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        let tappedNode = atPoint(location)

        if let leftArrow = leftArrow, tappedNode == leftArrow {
            rotateCarousel(direction: .left)
        }
        else if let rightArrow = rightArrow, tappedNode == rightArrow {
            rotateCarousel(direction: .right)
        }
    }
}
