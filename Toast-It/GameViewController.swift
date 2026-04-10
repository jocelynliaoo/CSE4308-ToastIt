//
//  GameViewController.swift
//  Toast-It
//
//  Created by Jocelyn Liao on 4/1/26.
//

import UIKit
import MultipeerConnectivity

class GameViewController: UIViewController {
    
    // outlets
    @IBOutlet weak var recipeLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var plateImageView: UIImageView!
    @IBOutlet weak var toastImageView: UIImageView!
    
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var butterImageView: UIImageView!
    @IBOutlet weak var strawberryImageView: UIImageView!
    @IBOutlet weak var sugarImageView: UIImageView!
    
    // add timerLabel, scoreLabel, recipe progress view
    @IBOutlet weak var timerLabel: UILabel!
    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var recipeProgressView: UIProgressView!
    
    // game state
    var addedIngredients: [Ingredient] = []
    var butterPlaced = false
    
    // for results page
    var score = 0
    var dishesSubmitted = 0
    var dishesLost = 0
    
    var currentRecipe = Recipe(
        name: "Strawberry Toast",
        requiredIngredients: [
            Ingredient(name: "Butter"),
            Ingredient(name: "Strawberries"),
            Ingredient(name: "Powdered Sugar")
        ],
        points: 10
    )
    
    var originalCenters: [UIImageView: CGPoint] = [:]
    
    // game timer
    let gameDuration = 60
    var timeLeft = 60
    var gameTimer: Timer?
    var gameRunning = false
    
    // recipe timer
    let recipeDuration = 10
    var recipeTimeLeft = 10
    var recipeTimer: Timer?
    
    var officialSeatingOrder: [String] = []
    
    // recipe list
    let allRecipes = [
        Recipe(name: "Strawberry Toast", requiredIngredients: [Ingredient(name: "Butter"), Ingredient(name: "Strawberries"), Ingredient(name: "Powdered Sugar")], points: 10),
        Recipe(name: "Plain Butter Toast", requiredIngredients: [Ingredient(name: "Butter")], points: 5)
        // avocado toast
    ]
    
    let isMultiplayerEnabled = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.sendSubviewToBack(backgroundImageView)
        DispatchQueue.main.async {
            self.originalCenters[self.butterImageView]     = self.butterImageView.center
            self.originalCenters[self.strawberryImageView] = self.strawberryImageView.center
            self.originalCenters[self.sugarImageView]      = self.sugarImageView.center
            
            self.view.bringSubviewToFront(self.butterImageView)
            self.view.bringSubviewToFront(self.strawberryImageView)
            self.view.bringSubviewToFront(self.sugarImageView)
            
            self.setupDraggableIngredient(self.butterImageView)
            self.setupDraggableIngredient(self.strawberryImageView)
            self.setupDraggableIngredient(self.sugarImageView)
            
            self.setupSwipeGestures(for: self.butterImageView)
            self.setupSwipeGestures(for: self.strawberryImageView)
            self.setupSwipeGestures(for: self.sugarImageView)
        }
        
        func setupMultipeer() {
                guard isMultiplayerEnabled else { return }
                if ConnectionManager.shared.isHost {
                    broadcastCurrentRecipeIfHost()
                } else {
                    recipeLabel.text = "Waiting for Host..."
                }
                
                ConnectionManager.shared.onDataReceived = { [weak self] data in
                    guard let self = self else { return }
                    if let action = try? JSONDecoder().decode(GameAction.self, from: data) {
                        DispatchQueue.main.async {
                            switch action {
                            case .dropIngredient(let name):
                                self.receiveRemoteMove(ingredientName: name)
                            case .resetGame:
                                self.performLocalReset()
                            case .submitGame:
                                self.performLocalSubmit()
                            case .setRecipe(let recipe):
                                self.currentRecipe = recipe
                                self.updateRecipeUI()
                            case .passIngredient(let name):
                                self.receivePassedIngredient(name: name)
                            case .setSeatingOrder(let playerNames): // ADD THIS CASE
                                self.officialSeatingOrder = playerNames
                            }
                        }
                    }
                }
            }
    
    func receivePassedIngredient(name: String) {
        let targetView: UIImageView
        
        if name == "Butter" { targetView = butterImageView }
        else if name == "Strawberries" { targetView = strawberryImageView }
        else { targetView = sugarImageView }
        
        guard let originalCenter = originalCenters[targetView] else { return }
        
        // Place it above the screen to start, make it visible and interactable
        targetView.center = CGPoint(x: view.bounds.width / 2, y: -100)
        targetView.isHidden = false
        targetView.isUserInteractionEnabled = true
        statusLabel.text = "Received \(name)!"
        
        // Animate it sliding back into its resting position
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseOut, animations: {
            targetView.center = originalCenter
        }, completion: nil)
    }
    
    func pickRandomRecipe() {
        currentRecipe = allRecipes.randomElement()!
        updateRecipeUI()
        broadcastCurrentRecipeIfHost()
        updateRecipeTimer()
    }
    
    // UI Updates
    func updateRecipeUI() {
        recipeLabel.text = "Recipe: \(currentRecipe.name) (\(currentRecipe.points) pts)"
    }
    
    func updateScoreUI() {
        scoreLabel.text = "Score: \(score)"
    }
    
    func updateTimerUI() {
        let minutes = timeLeft / 60
        let seconds = timeLeft % 60
        timerLabel.text = String(format: "%d:%02d", minutes, seconds)
        
        // Turn red in last 10 seconds
        timerLabel.textColor = timeLeft <= 10 ? .systemRed : .label
    }
    
    func updateRecipeTimer() {
        stopRecipeTimer() // cancel the current running timer
        recipeTimeLeft = recipeDuration
        recipeProgressView.progress = 1.0
        recipeProgressView.tintColor = .systemGreen
        
        recipeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.recipeTimeLeft -= 1
            let fraction = Float(self.recipeTimeLeft) / Float(self.recipeDuration)
            UIView.animate(withDuration: 0.4) {
                self.recipeProgressView.setProgress(fraction, animated: true)
            }
            
            
            // change colors
            if self.recipeTimeLeft <= 3 {
                self.recipeProgressView.tintColor = .systemRed
            } else if self.recipeTimeLeft <= 6 {
                self.recipeProgressView.tintColor = .systemOrange
            }
            
            if self.recipeTimeLeft <= 0 {
                self.recipeExpired()
            }
        }
    }
    
    func stopRecipeTimer() {
        recipeTimer?.invalidate()
        recipeTimer = nil
    }

    func recipeExpired() {
        stopRecipeTimer( )
        recipeProgressView.progress = 0
        score -= currentRecipe.points // deduct points from score
        updateScoreUI()
        statusLabel.text = "Too slow! -\(currentRecipe.points) pts"
        dishesLost += 1
        
        // short pause then move on
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self = self, self.gameRunning else { return }
            self.performLocalReset()
            self.pickRandomRecipe()
        }
    }
    
    // game flow
    func startGame() {
        score = 0
        dishesLost = 0
        dishesSubmitted = 0
        timeLeft = gameDuration
        gameRunning = true
        updateScoreUI()
        updateTimerUI()
        pickRandomRecipe()
        statusLabel.text = "Drag butter onto the toast first"
        
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.timeLeft -= 1
            self.updateTimerUI()
            if self.timeLeft <= 0 {
                self.endGame()
            }
        }
    }
    
    func endGame() {
        gameTimer?.invalidate()
        gameTimer = nil
        gameRunning = false
        stopRecipeTimer()
        recipeProgressView.progress = 0
        statusLabel.text = "Time's up! Final score: \(score)"
        
        performSegue(withIdentifier: "showResultsSegue", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showResultsSegue",
           let resultsVC = segue.destination as? ResultsViewController {
            resultsVC.dishesSubmitted = dishesSubmitted
            resultsVC.dishesLost = dishesLost
            resultsVC.finalScore = score
        }
    }
    
    // multiplayer setup
    func setupMultipeer() {
        guard isMultiplayerEnabled else { return }
        if ConnectionManager.shared.isHost {
            broadcastCurrentRecipeIfHost()
        } else {
            recipeLabel.text = "Waiting for Host..."
        }
        
        ConnectionManager.shared.onDataReceived = { [weak self] data in
            guard let self = self else { return }
            if let action = try? JSONDecoder().decode(GameAction.self, from: data) {
                DispatchQueue.main.async {
                    switch action {
                    case .dropIngredient(let name):
                        self.receiveRemoteMove(ingredientName: name)
                    case .resetGame:
                        self.performLocalReset()
                    case .submitGame:
                        self.performLocalSubmit()
                    case .setRecipe(let recipe):
                        self.currentRecipe = recipe
                        self.updateRecipeUI()
                    case .passIngredient(let name):
                        self.receivePassedIngredient(name: name)
                    }
                }
            }
        }
    }
        
    func broadcastCurrentRecipeIfHost() {
        guard isMultiplayerEnabled else { return }
        guard ConnectionManager.shared.isHost else { return }
        let action = GameAction.setRecipe(recipe: currentRecipe)
        if let data = try? JSONEncoder().encode(action) {
            try? ConnectionManager.shared.session.send(
                data,
                toPeers: ConnectionManager.shared.session.connectedPeers,
                with: .reliable
            )
        }
    }
    
    // drag and drop
    func setupDraggableIngredient(_ imageView: UIImageView) {
        imageView.isUserInteractionEnabled = true
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        imageView.addGestureRecognizer(panGesture)
    }
    
    
    func setupSwipeGestures(for imageView: UIImageView) {
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeLeft.direction = .left
        imageView.addGestureRecognizer(swipeLeft)
        
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeRight.direction = .right
        imageView.addGestureRecognizer(swipeRight)
    }
    
    func getTargetPeer(for direction: UISwipeGestureRecognizer.Direction) -> MCPeerID? {
            let session = ConnectionManager.shared.session
            let myName = session.myPeerID.displayName
            
            guard officialSeatingOrder.count > 1,
                  let myIndex = officialSeatingOrder.firstIndex(of: myName) else { return nil }
            
            // Find the name of the person next to me
            let targetName: String
            if direction == .right {
                let nextIndex = (myIndex + 1) % officialSeatingOrder.count
                targetName = officialSeatingOrder[nextIndex]
            } else { // .left
                let prevIndex = (myIndex - 1 + officialSeatingOrder.count) % officialSeatingOrder.count
                targetName = officialSeatingOrder[prevIndex]
            }
            
            // Find the actual MCPeerID that matches that name
            return session.connectedPeers.first(where: { $0.displayName == targetName })
        }
    
    
    @objc func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        guard gameRunning,
              let imageView = gesture.view as? UIImageView,
              let ingredientName = ingredientNameForImageView(imageView) else { return }
        
        guard let targetPeer = getTargetPeer(for: gesture.direction) else {
            statusLabel.text = "No player there!"
            return
        }
        
        // 1. Animate ingredient off-screen
        let offset: CGFloat = gesture.direction == .left ? -500 : 500
        imageView.isUserInteractionEnabled = false // Prevent interacting while passed
        
        UIView.animate(withDuration: 0.3, animations: {
            imageView.center.x += offset
        }) { _ in
            imageView.isHidden = true // Hide it completely once off screen
        }
        
        // 2. Send exclusively to the target peer
        let action = GameAction.passIngredient(name: ingredientName)
        if let data = try? JSONEncoder().encode(action) {
            try? ConnectionManager.shared.session.send(data, toPeers: [targetPeer], with: .reliable)
            statusLabel.text = "Passed \(ingredientName) to \(targetPeer.displayName)"
        }
    }
    
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard gameRunning, let draggedView = gesture.view as? UIImageView else { return }
        
        if gesture.state == .began {
            view.bringSubviewToFront(draggedView)
        }
        
        let translation = gesture.translation(in: view)
        
        switch gesture.state {
        case .began, .changed:
            draggedView.center = CGPoint(
                x: draggedView.center.x + translation.x,
                y: draggedView.center.y + translation.y
            )
            gesture.setTranslation(.zero, in: view)
            
        case .ended:
            if toastImageView.frame.intersects(draggedView.frame) || plateImageView.frame.intersects(draggedView.frame) {
                handleDrop(for: draggedView)
            } else {
                returnToOriginalPosition(draggedView)
            }
            
        default:
            break
        }
    }
    
    func handleDrop(for imageView: UIImageView) {
        guard let ingredientName = ingredientNameForImageView(imageView) else {
            returnToOriginalPosition(imageView)
            return
        }
        
        if !butterPlaced && ingredientName != "Butter" {
            statusLabel.text = "Butter has to go first!"
            returnToOriginalPosition(imageView)
            return
        }
        
        if addedIngredients.contains(where: { $0.name == ingredientName }) {
            statusLabel.text = "\(ingredientName) is already on the toast"
            snapIngredientToToast(imageView)
            return
        }
        
        addedIngredients.append(Ingredient(name: ingredientName))
        
        if ingredientName == "Butter" {
            butterPlaced = true
            if currentRecipe.name != "Plain Butter Toast" {
                statusLabel.text = "Nice! Now add the toppings."
            } else {
                statusLabel.text = "Try submitting this plate!"
            }
        } else {
            statusLabel.text = "\(ingredientName) added!"
        }
        
        // Broadcast to peers
        let action = GameAction.dropIngredient(name: ingredientName)
        if let data = try? JSONEncoder().encode(action) {
            try? ConnectionManager.shared.session.send(
                data,
                toPeers: ConnectionManager.shared.session.connectedPeers,
                with: .reliable
            )
        }
        
    }
    
    func ingredientNameForImageView(_ imageView: UIImageView) -> String? {
        if imageView == butterImageView {
            return "Butter"
        } else if imageView == strawberryImageView {
            return "Strawberries"
        } else if imageView == sugarImageView {
            return "Powdered Sugar"
        }
        return nil
    }
    
    func snapIngredientToToast(_ imageView: UIImageView) {
        let center = toastImageView.center
        var target = center
        
        if imageView == butterImageView {
            target = center
        } else if imageView == strawberryImageView {
            target = CGPoint(x: center.x - 30, y: center.y + 5)
        } else if imageView == sugarImageView {
            target = CGPoint(x: center.x + 28, y: center.y - 12)
        }
        
        UIView.animate(withDuration: 0.25) {
            imageView.center = target
        }
    }
    
    func returnToOriginalPosition(_ imageView: UIImageView) {
        guard let originalCenter = originalCenters[imageView] else { return }
        
        UIView.animate(withDuration: 0.25) {
            imageView.center = originalCenter
        }
    }
    
    
    func receiveRemoteMove(ingredientName: String) {
        let targetView: UIImageView
        
        if ingredientName == "Butter" {
            targetView = butterImageView
            butterPlaced = true
            statusLabel.text = "Partner added Butter!"
        } else if ingredientName == "Strawberries" {
            targetView = strawberryImageView
            statusLabel.text = "Partner added Strawberries!"
        } else {
            targetView = sugarImageView
            statusLabel.text = "Partner added Powdered Sugar!"
        }
        
        if !addedIngredients.contains(where: { $0.name == ingredientName }) {
            addedIngredients.append(Ingredient(name: ingredientName))
            snapIngredientToToast(targetView)
        }
    }
    
    // submit and reset
    func performLocalSubmit() {
        let addedSet = Set(addedIngredients.map { $0.name })
        let recipeSet = Set(currentRecipe.requiredIngredients.map { $0.name })
        
        if addedSet == recipeSet {
            stopRecipeTimer()
            score += currentRecipe.points
            statusLabel.text = "Correct! +\(currentRecipe.points) pts."
            updateScoreUI()
            performLocalReset()
            pickRandomRecipe()
            dishesSubmitted += 1
        } else {
            let missing = recipeSet.subtracting(addedSet)
            if missing.isEmpty {
                statusLabel.text = "Too many ingredients! Reset this plate."
            } else {
                statusLabel.text = "Missing: \(missing.joined(separator: ", "))"
            }
        }
    }
    
    func performLocalReset() {
        addedIngredients.removeAll()
        butterPlaced = false
        
        returnToOriginalPosition(butterImageView)
        returnToOriginalPosition(strawberryImageView)
        returnToOriginalPosition(sugarImageView)
        
        let views = [butterImageView, strawberryImageView, sugarImageView]
        views.forEach {
            $0?.isHidden = false
            $0?.isUserInteractionEnabled = true
        }
        
        statusLabel.text = "Drag butter onto the toast first"
    }
    
    // actions
    @IBAction func submitTapped(_ sender: UIButton) {
        performLocalSubmit()
        let action = GameAction.submitGame
        if let data = try? JSONEncoder().encode(action) {
            try? ConnectionManager.shared.session.send(data, toPeers: ConnectionManager.shared.session.connectedPeers, with: .reliable)
        }
    }
    
    @IBAction func resetTapped(_ sender: UIButton) {
        performLocalReset()
        let action = GameAction.resetGame
        if let data = try? JSONEncoder().encode(action) {
            try? ConnectionManager.shared.session.send(data, toPeers: ConnectionManager.shared.session.connectedPeers, with: .reliable)
        }
    }
}
