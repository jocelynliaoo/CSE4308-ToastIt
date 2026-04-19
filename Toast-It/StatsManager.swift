//
//  StatsManager.swift
//  Toast-It
//
//  Created by Jocelyn Liao on 4/18/26.
//

import Foundation

struct PlayerStats: Codable {
    var roundsPlayed: Int
    var dishesSubmitted: Int
    var dishesLost: Int
    var pointsScored: Int
}

class StatsManager {
    static let shared = StatsManager()
    
    private let statsKey = "playerLifetimeStats"
    
    private init() {}
    
    func loadStats() -> PlayerStats {
        if let data = UserDefaults.standard.data(forKey: statsKey),
           let stats = try? JSONDecoder().decode(PlayerStats.self, from: data) {
            return stats
        }
        
        return PlayerStats(
            roundsPlayed: 0,
            dishesSubmitted: 0,
            dishesLost: 0,
            pointsScored: 0
        )
    }
    
    func saveStats(_ stats: PlayerStats) {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: statsKey)
        }
    }
    
    func updateStats(roundsPlayed: Int, dishesSubmitted: Int, dishesLost: Int, pointsScored: Int) {
        var stats = loadStats()
        stats.roundsPlayed += roundsPlayed
        stats.dishesSubmitted += dishesSubmitted
        stats.dishesLost += dishesLost
        stats.pointsScored += pointsScored
        saveStats(stats)
    }
}
