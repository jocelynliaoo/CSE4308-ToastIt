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
    
    @IBOutlet weak var butterImageView: UIImageView!
    @IBOutlet weak var strawberryImageView: UIImageView!
    @IBOutlet weak var sugarImageView: UIImageView!
    
    // add timerLabel, scoreLabel
    @IBOutlet weak var timerLabel: UILabel!
    @IBOutlet weak var scoreLabel: UILabel!
    
    // game state
    var addedIngredients: [Ingredient] = []
    var butterPlaced = false
    var score = 0
    
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
    
    // timer
    let gameDuration = 60
    var timeLeft = 60
    var gameTimer: Timer?
    var gameRunning = false
    
    // recipe list
    let allRecipes = [
        Recipe(name: "Strawberry Toast", requiredIngredients: [Ingredient(name: "Butter"), Ingredient(name: "Strawberries"), Ingredient(name: "Powdered Sugar")], points: 10),
        Recipe(name: "Plain Butter Toast", requiredIngredients: [Ingredient(name: "Butter")], points: 5)
        // avocado toast
    ]
    
    let isMultiplayerEnabled = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        DispatchQueue.main.async {
            self.originalCenters[self.butterImageView]     = self.butterImageView.center
            self.originalCenters[self.strawberryImageView] = self.strawberryImageView.center
            self.originalCenters[self.sugarImageView]      = self.sugarImageView.center
            
            self.setupDraggableIngredient(self.butterImageView)
            self.setupDraggableIngredient(self.strawberryImageView)
            self.setupDraggableIngredient(self.sugarImageView)
        }
        
        setupMultipeer()
        startGame()
        
        //            if ConnectionManager.shared.isHost {
        //                currentRecipe = allRecipes.randomElement()!
        //                recipeLabel.text = "Recipe: \(currentRecipe.name)"
        //
        //                let action = GameAction.setRecipe(recipe: currentRecipe)
        //                if let data = try? JSONEncoder().encode(action) {
        //                    try? ConnectionManager.shared.session.send(data, toPeers: ConnectionManager.shared.session.connectedPeers, with: .reliable)
        //                }
        //            } else {
        //                recipeLabel.text = "Waiting for Host..."
        //            }
        //
        //
        //
        //            ConnectionManager.shared.onDataReceived = { [weak self] data in
        //                if let action = try? JSONDecoder().decode(GameAction.self, from: data) {
        //                    switch action {
        //                    case .dropIngredient(let name):
        //                        self?.receiveRemoteMove(ingredientName: name)
        //                    case .resetGame:
        //                        self?.performLocalReset()
        //                    case .submitGame:
        //                        self?.performLocalSubmit()
        //                    case .setRecipe(let recipe): // 3. Handle the incoming recipe!
        //                        self?.currentRecipe = recipe
        //                        self?.recipeLabel.text = "Recipe: \(recipe.name)"
        //                    }
        //                }
        //            }
    }
    
    func pickRandomRecipe() {
        currentRecipe = allRecipes.randomElement()!
        updateRecipeUI()
        broadcastCurrentRecipeIfHost()
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
    
    // game flow
    func startGame() {
        score = 0
        timeLeft = gameDuration
        gameRunning = true
        
        updateScoreUI()
        updateTimerUI()
        pickRandomRecipe()
        statusLabel.text = "Drag butter onto the toast first!"
        
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
        
        statusLabel.text = "Time's up! Final score: \(score)"
        
        // TODO: Navigate to a results screen, or show an alert
        let alert = UIAlertController(
            title: "Time's Up!",
            message: "Final score: \(score)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Play Again", style: .default) { [weak self] _ in
            self?.performLocalReset()
            self?.startGame()
        })
        present(alert, animated: true)
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
    
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard gameRunning, let draggedView = gesture.view as? UIImageView else { return }
        
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
            statusLabel.text = "Nice! Now add the toppings."
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
            score += currentRecipe.points
            statusLabel.text = "Correct! +\(currentRecipe.points) pts. Total: \(score)"
            updateScoreUI()
            performLocalReset()
            pickRandomRecipe()
        } else {
            let missing = recipeSet.subtracting(addedSet)
            if missing.isEmpty {
                statusLabel.text = "Too many ingredients! Use Reset."
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
