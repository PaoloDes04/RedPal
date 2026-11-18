import Foundation
import Combine

final class SessionManager: ObservableObject {
    @Published var totalSessions: Int = 1
    @Published var currentSession: Int = 1
    
    var isLastSession: Bool {
        currentSession >= totalSessions
    }
    
    func reset(with total: Int) {
        totalSessions = max(1, total)
        currentSession = 1
    }
}

