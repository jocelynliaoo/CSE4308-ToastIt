//
//  ResultsViewController.swift
//  Toast-It
//
//  Created by Grace  Huang on 4/6/26.
//

import UIKit

class ResultsViewController: UIViewController {

    @IBOutlet weak var dishesSubmittedLabel: UILabel!
    @IBOutlet weak var dishesLostLabel: UILabel!
    @IBOutlet weak var finalScoreLabel: UILabel!
    
    @IBOutlet weak var mainMenuButton: UIButton!
    @IBOutlet weak var playAgainButton: UIButton!
    
    // data passed in from GameViewController
    var dishesSubmitted = 0
    var dishesLost = 0
    var finalScore = 0
    
    private var hasSavedStats = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dishesSubmittedLabel.text = "\(dishesSubmitted)"
        dishesLostLabel.text = "\(dishesLost)"
        finalScoreLabel.text = "\(finalScore)"
        
        saveLifetimeStatsIfNeeded()
    }
    
    func saveLifetimeStatsIfNeeded() {
        guard !hasSavedStats else { return }
        hasSavedStats = true
        
        StatsManager.shared.updateStats(
            roundsPlayed: 3,
            dishesSubmitted: dishesSubmitted,
            dishesLost: dishesLost,
            pointsScored: finalScore
        )
    }

    @IBAction func mainMenuClicked(_ sender: Any) {
        performSegue(withIdentifier: "showMainMenuSegue", sender: self)
    }
    
    @IBAction func playAgainClicked(_ sender: Any) {
        performSegue(withIdentifier: "showGameSegue", sender: self)
    }
    
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
