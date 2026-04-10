//
//  LobbyViewController.swift
//  Toast-It
//
//  Created by Chrisiten 4/2/26.
//

import Foundation
import UIKit


class LobbyViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        ConnectionManager.shared.onConnected = { [weak self] in
            
            self?.performSegue(withIdentifier: "startGameSegue", sender: self)
        }
    }
    
    @IBAction func joinTapped(_ sender: UIButton) {
        print("Searching for host...")
        
        ConnectionManager.shared.joinLobby(with: "1234")
    }
    
    
    @IBAction func hostTapped(_ sender: UIButton) {
        let code = String(Int.random(in: 1000...9999))
        print("Hosting game with code: \(code)")
        ConnectionManager.shared.hostLobby(with: code)
    }
}
