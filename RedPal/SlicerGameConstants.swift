import CoreGraphics
import Foundation

// MARK: - Game Enums

// Stati di gioco
enum SlicerGameState {
    case start
    case playing
    case gameOver
}

// Definizioni dei mostri, punteggi e nomi degli asset
enum SlicerMonsterType: String, CaseIterable {
    // Nomi logici dei mostri
    case fantasma = "fantasma"
    case fuoco = "fuoco"
    case veleno = "veleno"
    case bomb = "bomb"
    
    // Associa i punti (come definito nel tuo codice React)
    var points: Int {
        switch self {
        case .fantasma: return 3
        case .fuoco: return 5
        case .veleno: return 4
        case .bomb: return -10
        }
    }
    
    // Ritorna il nome ESATTO dell'asset INTERO (controlla il tuo Assets.xcassets!)
    var assetName: String {
        switch self {
        case .bomb:
            return "bomb"
        default:
            return rawValue // es. "fantasma"
        }
    }
    
    // Ritorna i nomi ESATTI degli asset TAGLIATI
    var halfAssetNames: (partA: String, partB: String)? {
        switch self {
        case .fantasma: return ("fantasma_half1", "fantasma_half2")
        case .fuoco: return ("fuoco_half1", "fuoco_half2")
        case .veleno: return ("veleno_half1", "veleno_half2")
        case .bomb: return nil
        }
    }
}

// MARK: - Game Constants

struct SlicerGameConstants {
    // Fisica
    static let GRAVITY_VECTOR = CGVector(dx: 0, dy: -200) // Gravità morbida
    static let OBJECT_DIAMETER: CGFloat = 110.0
    static let GAME_DURATION: TimeInterval = 300 // 5 minuti (300 secondi)
    
    // Caricamento .sks
    static let LOAD_SKS_SCENE: Bool = false

    // Nomi degli asset del Slicer (Personaggio Giocatore)
    static let SLICER_ASSET_IDLE = "base"
    static let SLICER_ASSET_CUT_LEFT = "sinistra"
    static let SLICER_ASSET_CUT_RIGHT = "destra"
    
    // Parametri di spawn
    static let MIN_SPAWN_INTERVAL: TimeInterval = 0.5
    static let MAX_SPAWN_INTERVAL: TimeInterval = 1.5
    
    // Array per lo spawn, esclude la bomba
    static let SLICEABLE_MONSTER_TYPES: [SlicerMonsterType] = [.fantasma, .fuoco, .veleno]
    
    // Categorie di fisica
    static let MonsterCategory: UInt32 = 0x1 << 0
}
