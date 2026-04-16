//
//  LobbyViewController.swift
//  Toast-It
//
//  Created by Chrisiten 4/2/26.
//

import Foundation
import UIKit


class LobbyViewController: UIViewController {
    
    @IBOutlet weak var loadingOverlayView: UIView!
    
    
    
    
    @IBAction func joinTapped(_ sender: UIButton) {
        loadingOverlayView.isHidden = false
        print("Searching for host...")
        
        ConnectionManager.shared.joinLobby(with: "1234")
    }
    
    
    @IBAction func hostTapped(_ sender: UIButton) {
        let code = "1234"
        
        ConnectionManager.shared.hostLobby(with: code)
        
        
        performSegue(withIdentifier: "showTableSetupSegue", sender: self)
    }
    
    override func viewDidLoad() {
            super.viewDidLoad()
            
            loadingOverlayView.isHidden = true
            
          
            ConnectionManager.shared.onDataReceived = { [weak self] data in
                if let action = try? JSONDecoder().decode(GameAction.self, from: data) {
                    if case .setSeatingOrder(let players) = action {
                        DispatchQueue.main.async {
                            
                            self?.loadingOverlayView.isHidden = true
                            
                           
                            self?.performSegue(withIdentifier: "guestStartGameSegue", sender: players)
                        }
                    }
                }
            }
        }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
            if segue.identifier == "guestStartGameSegue",
               let destinationVC = segue.destination as? GameViewController,
               let seatingOrder = sender as? [String] {
                destinationVC.officialSeatingOrder = seatingOrder
            }
        }
    
    
}

