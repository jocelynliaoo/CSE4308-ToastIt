//
//  GameViewController.swift
//  Toast-It
//
//  Created by Jocelyn Liao on 4/1/26.
//

import UIKit
import MultipeerConnectivity

class GameViewController: UIViewController, UIGestureRecognizerDelegate {
    
    // outlets
    @IBOutlet weak var recipeLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var plateImageView: UIImageView!
    @IBOutlet weak var toastImageView: UIImageView!
    
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var butterImageView: UIImageView!
    @IBOutlet weak var strawberryImageView: UIImageView!
    @IBOutlet weak var sugarImageView: UIImageView!
    @IBOutlet weak var eggImageView: UIImageView!
    @IBOutlet weak var jamImageView: UIImageView!
    @IBOutlet weak var peanutButterImageView: UIImageView!
    @IBOutlet weak var creamImageView: UIImageView!
    @IBOutlet weak var avocadoImageView: UIImageView!
    @IBOutlet weak var seasoningImageView: UIImageView!
    
    // add timerLabel, scoreLabel, recipe progress view
    @IBOutlet weak var timerLabel: UILabel!
    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var recipeProgressView: UIProgressView!
    
    // model
    private let gameModel = GameModel()
    
    // view state
    var officialSeatingOrder: [String] = []
    
    private var ingredientViews: [String: UIImageView] = [:]
    private var originalCenters: [UIImageView: CGPoint] = [:]
    
    private var isMultiplayerEnabled: Bool {
        return !ConnectionManager.shared.session.connectedPeers.isEmpty
    }
    
    private var myName: String {
        return ConnectionManager.shared.session.myPeerID.displayName
    }
    
    // landscape only
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
    
    // lifecycle
    override func viewDidLoad() {
       super.viewDidLoad()
       self.navigationItem.hidesBackButton = true
       view.sendSubviewToBack(backgroundImageView)
       buildIngredientViewsMap()

       DispatchQueue.main.async {
           self.captureOriginalCenters()
           self.setupAllIngredientGestures()
       }

       setupModelCallbacks()
       setupMultipeer()

       recipeProgressView.progress = 1.0
       gameModel.startGame()
        
       
        if ConnectionManager.shared.isHost {
                officialSeatingOrder = ConnectionManager.shared.hostSeatingOrder
                
               
                if officialSeatingOrder.isEmpty {
                    officialSeatingOrder = [myName] + ConnectionManager.shared.session.connectedPeers.map { $0.displayName }
                }
                
              
                ConnectionManager.shared.send(action: .setSeatingOrder(playerNames: officialSeatingOrder))
            }
        
    }
    
    // setup
    private func buildIngredientViewsMap() {
        ingredientViews = [
            "Butter": butterImageView,
            "Strawberries": strawberryImageView,
            "Powdered Sugar": sugarImageView,
            "Egg": eggImageView,
            "Jam": jamImageView,
            "Peanut Butter": peanutButterImageView,
            "Cream": creamImageView,
            "Avocado": avocadoImageView,
            "Seasoning": seasoningImageView
        ]
    }
    
    private func captureOriginalCenters() {
        for (_, imageView) in ingredientViews {
            originalCenters[imageView] = imageView.center
            view.bringSubviewToFront(imageView)
        }
    }
    
    private func setupAllIngredientGestures() {
        for (_, imageView) in ingredientViews {
            setupDraggableIngredient(imageView)
        }
    }
    
    private func setupModelCallbacks() {
        gameModel.onTeamScoreChanged = { [weak self] score in
            self?.scoreLabel.text = "Score: \(score)"
        }
 
        gameModel.onRecipeChanged = { [weak self] recipe in
            self?.recipeLabel.text = "Recipe: \(recipe.name) (\(recipe.points) pts)"
        }
 
        gameModel.onTimerChanged = { [weak self] timeLeft, currentRound in
            guard let self else { return }
            let minutes = timeLeft / 60
            let seconds = timeLeft % 60
            self.timerLabel.text = "R\(currentRound) \(String(format: "%d:%02d", minutes, seconds))"
            self.timerLabel.textColor = timeLeft <= 10 ? .systemRed : .label
        }
 
        gameModel.onRecipeTimerChanged = { [weak self] fraction in
            self?.recipeProgressView.setProgress(fraction, animated: false)
        }
 
        gameModel.onRecipeTimerColor = { [weak self] color in
            switch color {
            case .normal:  self?.recipeProgressView.tintColor = .systemGreen
            case .warning: self?.recipeProgressView.tintColor = .systemOrange
            case .danger:  self?.recipeProgressView.tintColor = .systemRed
            }
        }
 
        gameModel.onStatusChanged = { [weak self] message in
            self?.statusLabel.text = message
        }
        
        gameModel.onRoundStarted = { [weak self] in
            self?.assignNewRecipe()
        }
 
        gameModel.onVisibleIngredientsChanged = { [weak self] in
            self?.refreshIngredientVisibility()
        }
 
        gameModel.onPlateReset = { [weak self] in
            self?.returnAllIngredientsToOrigin()
        }
 
        gameModel.onRecipeExpired = { [weak self] in
                    guard let self else { return }
                        
                    // 1. Synchronize the score penalty across the network
                    if self.isMultiplayerEnabled {
                        if ConnectionManager.shared.isHost {
                            ConnectionManager.shared.send(action: .syncScore(teamScore: self.gameModel.teamScore))
                         } else {
                            // FIX: Broadcast the penalty (the host will automatically intercept and apply this)
                            ConnectionManager.shared.send(action: .awardPoints(points: -self.gameModel.currentRecipe.points))
                        }
                    }
                    
                    // 2. Reset the local player's plate state
                    self.gameModel.clearPlateState()
                    self.returnAllIngredientsToOrigin()

                    // 3. Assign a new recipe after a brief delay so the player can see the failure state
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        guard self.gameModel.gameRunning else { return }
                        self.assignNewRecipe(notifyPeers: true)
                    }
                }
 
        gameModel.onGameEnded = { [weak self] in
            self?.performSegue(withIdentifier: "showResultsSegue", sender: self)
        }
    }
    
    // recipe assignment
    private func assignNewRecipe(notifyPeers: Bool = true) {
        let allPeerIDs: [MCPeerID] = [ConnectionManager.shared.session.myPeerID]
            + ConnectionManager.shared.session.connectedPeers
        let allPlayers: [String] = officialSeatingOrder.isEmpty
            ? allPeerIDs.map { $0.displayName }
            : officialSeatingOrder
        
        let possibleRecipes = gameModel.recipesForCurrentRound
//        var roundIngredientPool: [String] = []
//        
//        for recipe in possibleRecipes {
//            for ingredient in recipe.requiredIngredients {
//                if ingredient.name != "Butter" {
//                    roundIngredientPool.append(ingredient.name)
//                }
//            }
//        }
        
        if isMultiplayerEnabled {
            if ConnectionManager.shared.isHost && notifyPeers {
                var recipeAssignments: [String: Recipe] = [:]
                var roundIngredientPool: [String] = []
                
                for player in allPlayers {
                    let assignedRecipe = possibleRecipes.randomElement()!
                    recipeAssignments[player] = assignedRecipe
                    for ingredient in assignedRecipe.requiredIngredients where ingredient.name != "Butter"{
                        roundIngredientPool.append(ingredient.name)
                    }
                }
                
                // extra random ingredients
                for _ in 0..<allPlayers.count {
                    if let randomRecipe = possibleRecipes.randomElement() {
                        let extra = randomRecipe.requiredIngredients.randomElement()!.name
                        if extra != "Butter" { roundIngredientPool.append(extra) }
                    }
                }
                
                // Start everyone with Butter
                var distribution: [String: [String]] = allPlayers.reduce(into: [:]) { result, player in
                    if result[player] == nil {
                        result[player] = ["Butter"]
                    }
                }
                
                let shuffledPool = roundIngredientPool.shuffled()
                
                // Randomly scatter the pool to different players
                for (index, ingredient) in shuffledPool.enumerated() {
                    let recipient = allPlayers[index % allPlayers.count]
                    distribution[recipient]?.append(ingredient)
                }
                
                // Set local state
                let myRecipe = recipeAssignments[myName]!
                gameModel.assignRecipe(myRecipe, visibleIngredients: distribution[myName] ?? ["Butter"])
                
                // Broadcast to guests
                for peer in ConnectionManager.shared.session.connectedPeers {
                    if let peerRecipe = recipeAssignments[peer.displayName],
                       let peerVisible = distribution[peer.displayName] {
                        ConnectionManager.shared.send(action: .setRecipe(recipe: peerRecipe), toPeers: [peer])
                        ConnectionManager.shared.send(action: .setMyIngredients(names: peerVisible), toPeers: [peer])
                    }
                }
            } else if !notifyPeers {
                let newRecipe = possibleRecipes.randomElement()!
                
                self.gameModel.clearPlateState()
                self.returnAllIngredientsToOrigin()
                
                var myNewIngredients = ["Butter"]
                
                let requiredToppings = newRecipe.requiredIngredients.map { $0.name }.filter { $0 != "Butter" }
                var toppingsToDistribute = requiredToppings
                
                if let luckyTopping = toppingsToDistribute.randomElement(),
                   let index = toppingsToDistribute.firstIndex(of: luckyTopping) {
                    myNewIngredients.append(luckyTopping)
                    toppingsToDistribute.remove(at: index)
                }
                
                for ingredientName in toppingsToDistribute {
                    if let partner = ConnectionManager.shared.session.connectedPeers.randomElement() {
                        ConnectionManager.shared.send(action: .passIngredient(name: ingredientName), toPeers: [partner])
                    }
                }
                
                gameModel.assignRecipe(newRecipe, visibleIngredients: myNewIngredients)
            }
        } else {
            if let recipe = possibleRecipes.randomElement() {
                gameModel.assignRecipe(recipe, visibleIngredients: recipe.requiredIngredients.map { $0.name })
            }
        }
    }
    
    // ingredient visibility
    private func refreshIngredientVisibility() {
        for (name, imageView) in ingredientViews {
            let inventoryCount = gameModel.myVisibleIngredientNames.filter { $0 == name }.count
            let isPlacedOnPlate = gameModel.addedIngredients.contains(where: { $0.name == name })

            if inventoryCount > 0 || isPlacedOnPlate {
                imageView.isHidden = false
                imageView.isUserInteractionEnabled = inventoryCount > 0
                // Show a count badge when duplicates are present
                showCountBadge(on: imageView, count: inventoryCount)
            } else {
                imageView.isHidden = true
                imageView.isUserInteractionEnabled = false
                showCountBadge(on: imageView, count: 0)
            }
        }
    }
    
    private func showCountBadge(on imageView: UIImageView, count: Int) {
        // Remove any existing badge
        imageView.subviews.forEach { if $0.tag == 999 { $0.removeFromSuperview() } }
        guard count > 1 else { return }

        let badge = UILabel()
        badge.tag = 999
        badge.text = "×\(count)"
        badge.font = .boldSystemFont(ofSize: 12)
        badge.textColor = .white
        badge.backgroundColor = .systemRed
        badge.textAlignment = .center
        badge.layer.cornerRadius = 10
        badge.layer.masksToBounds = true
        badge.frame = CGRect(x: imageView.bounds.width - 24, y: 0, width: 24, height: 20)
        imageView.addSubview(badge)
    }
    
    private func returnAllIngredientsToOrigin() {
        for (_, imageView) in ingredientViews {
            returnToOriginalPosition(imageView)
        }
    }
    
    // drag and drop
    private func setupDraggableIngredient(_ imageView: UIImageView) {
        imageView.isUserInteractionEnabled = true

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.delegate = self
        imageView.addGestureRecognizer(panGesture)
    }
    
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard gameModel.gameRunning, let draggedView = gesture.view as? UIImageView else { return }
    
        switch gesture.state {
        case .began:
            view.bringSubviewToFront(draggedView)
            
        case .changed:
            let translation = gesture.translation(in: view)
            if draggedView.layer.value(forKey: "startCenter") == nil {
                draggedView.layer.setValue(draggedView.center, forKey: "startCenter")
            }
            
            let startCenter = draggedView.layer.value(forKey: "startCenter") as! CGPoint
            draggedView.center = CGPoint(
                x: startCenter.x + translation.x,
                y: startCenter.y + translation.y
            )
 
        case .ended:
            let velocity = gesture.velocity(in: view)

            let onToast = toastImageView.frame.intersects(draggedView.frame)
            let onPlate = plateImageView.frame.intersects(draggedView.frame)
            let isFlick = abs(velocity.x) > 800 && abs(velocity.x) > abs(velocity.y)
            
            draggedView.layer.setValue(nil, forKey: "startCenter")
            
            if isFlick {
                handleFlick(draggedView, velocity: velocity)
                return
            }
            
            if onToast || onPlate {
                handleDrop(for: draggedView)
            } else {
                returnToOriginalPosition(draggedView)
            }
        default: break
        }
    }
    
    private func handleDrop(for imageView: UIImageView) {
        guard let name = ingredientNameForImageView(imageView) else {
            returnToOriginalPosition(imageView)
            return
        }
 
        let accepted = gameModel.addIngredient(name: name)
 
        if accepted {
            snapIngredientToToast(imageView)
            refreshIngredientVisibility()
        } else {
            returnToOriginalPosition(imageView)
        }
    }
    
    private func handleFlick(_ imageView: UIImageView, velocity: CGPoint) {
        guard let name = ingredientNameForImageView(imageView) else { return }
        
        AudioManager.shared.playSFX(fileName: "swipe_whoosh")
        let direction: CGFloat = velocity.x > 0 ? 1 : -1
        let offset: CGFloat = direction * 700

        if !isMultiplayerEnabled {
            UIView.animate(withDuration: 0.25, animations: {
                imageView.center.x += offset
            }) { _ in
//                self.gameModel.removeIngredient(name: name)
                self.returnToOriginalPosition(imageView)
            }
            return
        }

        guard let targetPeer = targetPeer(for: direction > 0 ? .right : .left) else {
            statusLabel.text = "Can't pass right now!"
            returnToOriginalPosition(imageView)
            return
        }

        imageView.isUserInteractionEnabled = false

        UIView.animate(withDuration: 0.25, animations: {
            imageView.center.x += offset
            imageView.alpha = 0
        }) { _ in
            self.gameModel.removeIngredientFromInventory(name: name)
            imageView.isHidden = true
            imageView.alpha = 1.0
            imageView.isUserInteractionEnabled = true
            self.returnToOriginalPosition(imageView)
            ConnectionManager.shared.send(action: .passIngredient(name: name), toPeers: [targetPeer])
        }
    }
    
    private func targetPeer(for direction: UISwipeGestureRecognizer.Direction) -> MCPeerID? {
        guard officialSeatingOrder.count > 1,
              let myIndex = officialSeatingOrder.firstIndex(of: myName) else { return nil }
 
        let targetName: String
        if direction == .right {
            targetName = officialSeatingOrder[(myIndex + 1) % officialSeatingOrder.count]
        } else {
            targetName = officialSeatingOrder[(myIndex - 1 + officialSeatingOrder.count) % officialSeatingOrder.count]
        }
 
        return ConnectionManager.shared.session.connectedPeers.first { $0.displayName == targetName }
    }
    
    private func showReceivedIngredient(name: String, from senderName: String) {
        guard let imageView = ingredientViews[name],
              let originalCenter = originalCenters[imageView] else { return }
        
        gameModel.receivePassedIngredient(name: name)
        statusLabel.text = "\(senderName) passed you \(name)!"
        
        if !imageView.isHidden && imageView.alpha > 0.9 {
            UIView.animate(withDuration: 0.1, animations: {
                imageView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            }) { _ in
                UIView.animate(withDuration: 0.1) {
                    imageView.transform = .identity
                }
            }
            return
        }
 
        // Determine which side the sender is on
        let comesFromRight: Bool
        if let myIndex = officialSeatingOrder.firstIndex(of: myName),
           let senderIndex = officialSeatingOrder.firstIndex(of: senderName) {
            comesFromRight = senderIndex == (myIndex + 1) % officialSeatingOrder.count
        } else {
            comesFromRight = true
        }
 
        imageView.center = CGPoint(x: comesFromRight ? view.bounds.width + 60 : -60, y: originalCenter.y)
        imageView.alpha = 1.0
        imageView.isHidden = false
        imageView.isUserInteractionEnabled = true
        view.bringSubviewToFront(imageView)
 
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseOut, animations: {
            imageView.center = originalCenter
        }, completion: nil)
// 
//        gameModel.receivePassedIngredient(name: name)
//        statusLabel.text = "\(senderName) passed you \(name)!"
    }
    
    // multiplayer
    private func setupMultipeer() {
        ConnectionManager.shared.onDataReceived = { [weak self] data in
            guard let self else { return }
            guard let action = try? JSONDecoder().decode(GameAction.self, from: data) else { return }
 
            DispatchQueue.main.async {
                switch action {
                case .playAgain:
                    break // not handled during gameplay
                    
                case .playerLeftLobby(let name):
                    // Stop the game and notify the remaining player
                    self.gameModel.abruptlyEndGame()
                    self.statusLabel.text = "\(name) left the game."
                    
                    let alert = UIAlertController(
                        title: "Player Left",
                        message: "\(name) left the game. Returning to main menu.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                        ConnectionManager.shared.reset()
                        self.performSegue(withIdentifier: "showMainMenuSegue", sender: self)
                    })
                    self.present(alert, animated: true)
                case .clearInventory:
                    self.gameModel.clearPlateState()
                    self.gameModel.clearInventoryOnly()
                    self.returnAllIngredientsToOrigin()
                    
                case .passIngredient(let name):
                    let sender = ConnectionManager.shared.lastSenderName ?? "a player"
                    self.showReceivedIngredient(name: name, from: sender)
 
                case .setRecipe(let recipe):
                    self.gameModel.currentRecipe = recipe
 
                case .setMyIngredients(let names):
                    self.gameModel.clearPlateState()
                    self.gameModel.clearInventoryOnly()
                    self.returnAllIngredientsToOrigin()
                    self.gameModel.assignRecipe(self.gameModel.currentRecipe, visibleIngredients: names)
 
                case .awardPoints(let points):
                    // Only the host handles this — add points and broadcast new total
                    if ConnectionManager.shared.isHost {
                        let newScore = self.gameModel.hostApplyScore(points: points)
                        ConnectionManager.shared.send(action: .syncScore(teamScore: newScore))
                    }
 
                case .syncScore(let score):
                    self.gameModel.applySyncedScore(score)
 
                case .setSeatingOrder(let playerNames):
                    self.officialSeatingOrder = playerNames
                }
            }
        }
    }
    
    // actions
    @IBAction func submitTapped(_ sender: UIButton) {
        let result = gameModel.submitDish()
            switch result {
            case .correct(let points):
                AudioManager.shared.playSFX(fileName: "order_bell")
                statusLabel.text = "Correct! +\(points) pts."

               
                if ConnectionManager.shared.isHost || !isMultiplayerEnabled {
                    let newScore = gameModel.hostApplyScore(points: points)
                    if isMultiplayerEnabled {
                        ConnectionManager.shared.send(action: .syncScore(teamScore: newScore))
                    }
                } else {
                   
                    ConnectionManager.shared.send(action: .awardPoints(points: points))
                }
                    
                gameModel.clearPlateState()
                self.returnAllIngredientsToOrigin()
                assignNewRecipe(notifyPeers: false)

            case .tooManyIngredients, .missingIngredients:
                break
            }
    }
    
    @IBAction func resetTapped(_ sender: UIButton) {
        gameModel.resetPlate()
    }
    
    // navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showResultsSegue",
           let resultsVC = segue.destination as? ResultsViewController {
            resultsVC.dishesSubmitted = gameModel.dishesSubmitted
            resultsVC.dishesLost = gameModel.dishesLost
            resultsVC.finalScore = gameModel.teamScore
        }
    }
    
    // helpers
    private func ingredientNameForImageView(_ imageView: UIImageView) -> String? {
        return ingredientViews.first(where: { $0.value == imageView })?.key
    }
 
    private func snapIngredientToToast(_ imageView: UIImageView) {
        let center = toastImageView.center
        let name = ingredientNameForImageView(imageView)
 
        let target: CGPoint
        if name == "Butter" {
            target = center
        } else {
            target = CGPoint(x: center.x + 28, y: center.y - 12)
        }
 
        UIView.animate(withDuration: 0.25) {
            imageView.center = target
        }
    }
 
    private func returnToOriginalPosition(_ imageView: UIImageView) {
        guard let originalCenter = originalCenters[imageView] else { return }
        UIView.animate(withDuration: 0.25) {
            imageView.center = originalCenter
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        AudioManager.shared.playMusic(trackName: "game_music")
    }
}


