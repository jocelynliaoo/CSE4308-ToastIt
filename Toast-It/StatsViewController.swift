//
//  StatsViewController.swift
//  Toast-It
//
//  Created by Jocelyn Liao on 4/18/26.
//

import Foundation
import UIKit

class StatsViewController: UIViewController {
    
    @IBOutlet weak var roundsPlayedLabel: UILabel!
    @IBOutlet weak var dishesSubmittedLabel: UILabel!
    @IBOutlet weak var dishesLostLabel: UILabel!
    @IBOutlet weak var pointsScoredLabel: UILabel!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadStats()
    }
    
    func loadStats() {
        let stats = StatsManager.shared.loadStats()
        
        roundsPlayedLabel.text = "\(stats.roundsPlayed)"
        dishesSubmittedLabel.text = "\(stats.dishesSubmitted)"
        dishesLostLabel.text = "\(stats.dishesLost)"
        pointsScoredLabel.text = "\(stats.pointsScored)"
    }
}
