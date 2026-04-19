//
//  TableSetupViewController.swift
//  Toast-It
//
//  Created by user286461 on 4/16/26.
//

import Foundation
import UIKit
import MultipeerConnectivity

class TableSetupViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var startGameButton: UIButton!
    
   
    var players: [String] = [UIDevice.current.name]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Arrange Table"
        
        setupUI()
        
     
        tableView.isEditing = true
        
     
        ConnectionManager.shared.onPeerChanged = { [weak self] peers in
            DispatchQueue.main.async {
               
                self?.players = [UIDevice.current.name] + peers.map { $0.displayName }
                self?.tableView.reloadData()
            }
        }
    }
    
    func setupUI() {
        tableView.frame = CGRect(x: 0, y: 100, width: view.bounds.width, height: view.bounds.height - 200)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)
        
        startGameButton.frame = CGRect(x: 20, y: view.bounds.height - 80, width: view.bounds.width - 40, height: 50)
        startGameButton.setTitle("Start Dinner", for: .normal)
        startGameButton.backgroundColor = .systemBlue
        startGameButton.setTitleColor(.white, for: .normal)
//        startGameButton.addTarget(self, action: #selector(startGameTapped), for: .touchUpInside)
//        view.addSubview(startGameButton)
    }
    
    private var hasStartedGame = false
    @objc func startGameTapped() {
        guard !hasStartedGame else { return }
        hasStartedGame = true
        
        let action = GameAction.setSeatingOrder(playerNames: players)
        if let data = try? JSONEncoder().encode(action) {
            try? ConnectionManager.shared.session.send(data, toPeers: ConnectionManager.shared.session.connectedPeers, with: .reliable)
        }
        
        ConnectionManager.shared.hostSeatingOrder = players
        performSegue(withIdentifier: "hostStartGameSegue", sender: self)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { return players.count }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = players[indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let movedPlayer = players.remove(at: sourceIndexPath.row)
        players.insert(movedPlayer, at: destinationIndexPath.row)
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none 
    }
    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
        override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
            if segue.identifier == "hostStartGameSegue",
               let destinationVC = segue.destination as? GameViewController {
                
               
                destinationVC.officialSeatingOrder = self.players
            }
        }
    @IBAction func startGameTapped(_ sender: UIButton) {
        AudioManager.shared.playSFX(fileName: "menu_click")
        guard !hasStartedGame else { return }
        hasStartedGame = true
        
        let action = GameAction.setSeatingOrder(playerNames: players)
        if let data = try? JSONEncoder().encode(action) {
            try? ConnectionManager.shared.session.send(data, toPeers: ConnectionManager.shared.session.connectedPeers, with: .reliable)
        }
        
        performSegue(withIdentifier: "hostStartGameSegue", sender: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
       
        AudioManager.shared.playMusic(trackName: "menu_music")
    }
}
