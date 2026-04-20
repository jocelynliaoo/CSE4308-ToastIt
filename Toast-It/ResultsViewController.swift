//
//  ResultsViewController.swift
//  Toast-It
//
//  Created by Grace  Huang on 4/6/26.
//

import UIKit
import MultipeerConnectivity

class ResultsViewController: UIViewController {

    @IBOutlet weak var dishesSubmittedLabel: UILabel!
    @IBOutlet weak var dishesLostLabel: UILabel!
    @IBOutlet weak var finalScoreLabel: UILabel!
    
    @IBOutlet weak var mainMenuButton: UIButton!
    @IBOutlet weak var playAgainButton: UIButton!
    @IBOutlet weak var statusLabel: UILabel!
    
    // data passed in from GameViewController
    var dishesSubmitted = 0
    var dishesLost = 0
    var finalScore = 0
    
    private var hasSavedStats = false

    private var playAgainCount = 0
    
    private var localReadyForPlayAgain = false
    
    private var totalPlayers: Int {
        ConnectionManager.shared.session.connectedPeers.count + 1
    }
    
    private var isMultiplayer: Bool {
        return !ConnectionManager.shared.session.connectedPeers.isEmpty
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dishesSubmittedLabel.text = "\(dishesSubmitted)"
        dishesLostLabel.text = "\(dishesLost)"
        finalScoreLabel.text = "\(finalScore)"
        statusLabel.text = ""
        
        saveLifetimeStatsIfNeeded()
        setupMultipeerListeners()
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
    
    // multiplayer listeners
    private func setupMultipeerListeners() {
        ConnectionManager.shared.onDataReceived = { [weak self] data in
            guard let self, let action = try? JSONDecoder().decode(GameAction.self, from: data) else { return }
            DispatchQueue.main.async {
                switch action {
                case .playAgain:
                    self.handleRemotePlayAgain()
                case .playerLeftLobby(let name):
                    self.handleRemotePlayerLeft(name: name)
                default:
                    break
                }
            }
        }
    }
    
    @IBAction func mainMenuClicked(_ sender: Any) {
        //performSegue(withIdentifier: "showMainMenuSegue", sender: self)
        if isMultiplayer {
            // Tell other players we're leaving before disconnecting
            let myName = ConnectionManager.shared.session.myPeerID.displayName
            ConnectionManager.shared.send(action: .playerLeftLobby(name: myName))
            
            // Small delay so the message can be delivered before the session drops
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                ConnectionManager.shared.reset()
                self?.navigateToMainMenu()
            }
        } else {
            // Single player — just reset and go
            ConnectionManager.shared.reset()
            navigateToMainMenu()
        }
    }
    
    @IBAction func playAgainClicked(_ sender: Any) {
        //performSegue(withIdentifier: "showGameSegue", sender: self)
        guard !localReadyForPlayAgain else { return }
        localReadyForPlayAgain = true
        
        if !isMultiplayer {
            launchNewGame()
            return
        }
        
        // Count self and update label immediately so it feels responsive
        playAgainCount += 1
        updateReadyStatus()
        
        // Multiplayer: tell everyone you're ready
        ConnectionManager.shared.send(action: .playAgain)
        
        if ConnectionManager.shared.isHost {
            checkAllPlayersReady()
        }
    }
    
    private func handleRemotePlayAgain() {
        guard ConnectionManager.shared.isHost else {
            // Guest receives this from host — it means everyone is ready, let's go
            launchNewGame()
            return
        }
        
        playAgainCount += 1
        updateReadyStatus()
        if ConnectionManager.shared.isHost {
            checkAllPlayersReady()
        }
    }
    
    private func updateReadyStatus() {
        statusLabel.text = "\(playAgainCount)/\(totalPlayers) players ready"
    }
    
    private func checkAllPlayersReady() {
        guard playAgainCount >= totalPlayers else { return }
        ConnectionManager.shared.send(action: .playAgain) // final broadcast to guests
        launchNewGame()
    }
    
    private func handleRemotePlayerLeft(name: String) {
        // Disable play again — the group can no longer play together
        playAgainButton.isEnabled = false
        localReadyForPlayAgain = false
        statusLabel.text = "\(name) left the game. You can't play again together."
        
        // Optionally show an alert for clarity
        let alert = UIAlertController(
            title: "Player Left",
            message: "\(name) returned to the main menu. Play Again is no longer available.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func launchNewGame() {
        performSegue(withIdentifier: "showGameSegue", sender: self)
    }
    
    private func navigateToMainMenu() {
        performSegue(withIdentifier: "showMainMenuSegue", sender: self)
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
