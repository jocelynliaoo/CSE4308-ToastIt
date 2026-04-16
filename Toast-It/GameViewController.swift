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
    
    // game state
    var addedIngredients: [Ingredient] = []
    var butterPlaced = false
    
    // for results page
    var score = 0
    var dishesSubmitted = 0
    var dishesLost = 0
    
    //for the ingredients to show up based on recipe
    var ingredientViews: [String: UIImageView] = [:]
    
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
    
    var isMultiplayerEnabled: Bool {
        return !ConnectionManager.shared.session.connectedPeers.isEmpty
    }
    
    // round state
    var currentRound = 1
    let totalRounds = 3
    let round1Duration = 60
    let round2Duration = 45
    let round3Duration = 20
    
    // game timer
    var timeLeft = 60
    var gameTimer: Timer?
    var gameRunning = false
    
    // recipe timer
    let recipeDuration = 10
    var recipeTimeLeft = 10
    var recipeTimer: Timer?
    
    var officialSeatingOrder: [String] = []
    
    // recipe list for each round
    let round1Recipes = [
        Recipe(name: "Plain Butter Toast", requiredIngredients: [Ingredient(name: "Butter")], points: 5),
        Recipe(name: "Strawberry Toast", requiredIngredients: [Ingredient(name: "Butter"), Ingredient(name: "Strawberries"), Ingredient(name: "Powdered Sugar")], points: 10),
        Recipe(name: "Egg Toast", requiredIngredients: [Ingredient(name: "Butter"), Ingredient(name: "Egg")], points: 8),
    ]
    
    let round2Recipes = [
        Recipe(name: "PB & J Toast", requiredIngredients: [Ingredient(name: "Butter"), Ingredient(name: "Peanut Butter"), Ingredient(name: "Jam")], points: 10),
        Recipe(name: "Strawberries and Cream Toast", requiredIngredients: [Ingredient(name: "Butter"), Ingredient(name: "Cream"), Ingredient(name: "Strawberries")], points: 8),
        Recipe(name: "Avocado Toast", requiredIngredients: [Ingredient(name: "Butter"), Ingredient(name: "Avocado"), Ingredient(name: "Seasoning")], points: 8),
        Recipe(name: "Avocado and Egg Toast", requiredIngredients: [Ingredient(name: "Butter"), Ingredient(name: "Avocado"), Ingredient(name: "Egg"), Ingredient(name: "Seasoning")], points: 10),
    ]
    
    var allRecipes: [Recipe] { round1Recipes + round2Recipes } // round 3
    
    var recipesForCurrentRound: [Recipe] {
        switch currentRound {
        case 1: return round1Recipes
        case 2: return round2Recipes
        default: return allRecipes
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.sendSubviewToBack(backgroundImageView)
        
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
        
        DispatchQueue.main.async {
            self.originalCenters[self.butterImageView] = self.butterImageView.center
            self.originalCenters[self.strawberryImageView] = self.strawberryImageView.center
            self.originalCenters[self.sugarImageView] = self.sugarImageView.center
            self.originalCenters[self.eggImageView] = self.eggImageView.center
            self.originalCenters[self.jamImageView] = self.jamImageView.center
            self.originalCenters[self.peanutButterImageView] = self.peanutButterImageView.center
            self.originalCenters[self.creamImageView] = self.creamImageView.center
            self.originalCenters[self.avocadoImageView] = self.avocadoImageView.center
            self.originalCenters[self.seasoningImageView] = self.seasoningImageView.center
            
            self.view.bringSubviewToFront(self.butterImageView)
            self.view.bringSubviewToFront(self.strawberryImageView)
            self.view.bringSubviewToFront(self.sugarImageView)
            self.view.bringSubviewToFront(self.eggImageView)
            self.view.bringSubviewToFront(self.jamImageView)
            self.view.bringSubviewToFront(self.peanutButterImageView)
            self.view.bringSubviewToFront(self.creamImageView)
            self.view.bringSubviewToFront(self.avocadoImageView)
            self.view.bringSubviewToFront(self.seasoningImageView)
            
            self.setupDraggableIngredient(self.butterImageView)
            self.setupDraggableIngredient(self.strawberryImageView)
            self.setupDraggableIngredient(self.sugarImageView)
            self.setupDraggableIngredient(self.eggImageView)
            self.setupDraggableIngredient(self.jamImageView)
            self.setupDraggableIngredient(self.peanutButterImageView)
            self.setupDraggableIngredient(self.creamImageView)
            self.setupDraggableIngredient(self.avocadoImageView)
            self.setupDraggableIngredient(self.seasoningImageView)
            
            self.setupSwipeGestures(for: self.butterImageView)
            self.setupSwipeGestures(for: self.strawberryImageView)
            self.setupSwipeGestures(for: self.sugarImageView)
            self.setupSwipeGestures(for: self.eggImageView)
            self.setupSwipeGestures(for: self.jamImageView)
            self.setupSwipeGestures(for: self.peanutButterImageView)
            self.setupSwipeGestures(for: self.creamImageView)
            self.setupSwipeGestures(for: self.avocadoImageView)
            self.setupSwipeGestures(for: self.seasoningImageView)
        }
        
        updateRecipeUI()
        updateScoreUI()
        updateTimerUI()
        recipeProgressView.progress = 1.0
        setupMultipeer()
        startGame()
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
        currentRecipe = recipesForCurrentRound.randomElement()!
        updateRecipeUI()
        updateVisibleIngredients()
        broadcastCurrentRecipeIfHost()
        updateRecipeTimer()
    }
    
    func updateVisibleIngredients() {
        // Hide and reset everything first
        for (_, imageView) in ingredientViews {
            if let originalCenter = originalCenters[imageView] {
                imageView.center = originalCenter
            }
            imageView.isHidden = true
            imageView.isUserInteractionEnabled = false
        }
        
        let requiredNames = Set(currentRecipe.requiredIngredients.map{$0.name })
        var visibleNames = requiredNames
        let allIngredientNames = Array(ingredientViews.keys)
        
        // add decoys in round 2 and on
        if currentRound >= 2 {
            let decoyPool = allIngredientNames.filter { !requiredNames.contains($0) }
            let decoys = Set(decoyPool.shuffled().prefix(2))
            visibleNames = requiredNames.union(decoys)
        }
        
        // show ingredients needed for the current recipe + decoys
        for ingredient in visibleNames {
            if let imageView = ingredientViews[ingredient] {
                if let originalCenter = originalCenters[imageView] {
                    imageView.center = originalCenter
                }
                imageView.isHidden = false
                imageView.isUserInteractionEnabled = true
                view.bringSubviewToFront(imageView)
            }
        }
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
        timerLabel.text = "R\(currentRound) \(String(format: "%d:%02d", minutes, seconds))"
        
        // Turn red in last 10 seconds
        timerLabel.textColor = timeLeft <= 10 ? .systemRed : .label
    }
    
    func updateRecipeTimer() {
        stopRecipeTimer() // cancel the current running timer
        recipeTimeLeft = recipeDuration
        recipeProgressView.progress = 1.0
        recipeProgressView.tintColor = .systemGreen
        
        let totalDuration = Double(recipeDuration)
        let startTime = Date()
        
        recipeTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let elapsed = Date().timeIntervalSince(startTime)
            let remaining = totalDuration - elapsed
            self.recipeTimeLeft = max(0, Int(ceil(remaining)))
            let fraction = Float(max(0, remaining) / totalDuration)
            self.recipeProgressView.setProgress(fraction, animated: false)
            
            // color changes
            if remaining <= 3 {
                self.recipeProgressView.tintColor = .systemRed
            } else if remaining <= 6 {
                self.recipeProgressView.tintColor = .systemOrange
            }
            if remaining <= 0 {
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
        currentRound = 1
        updateScoreUI()
        startRound()
    }
    
    func startRound() {
        // change text and timer based on round
        switch currentRound {
        case 1:
            timeLeft = round1Duration
            statusLabel.text = "Round 1: Make as many toasts as you can!"
        case 2:
            timeLeft = round2Duration
            statusLabel.text = "Round 2: New recipes! Watch out for decoy ingredients!"
        default:
            timeLeft = round3Duration
            statusLabel.text = "Round 3: Speed round — read the recipe carefully!"
        }
        
        gameRunning = false  // block interaction during countdown
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
            guard let self = self else { return }
            
            var countdown = 3
            self.statusLabel.text = "Starting in \(countdown)..."
            
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                guard let self = self else { timer.invalidate(); return }
                countdown -= 1
                if countdown > 0 {
                    self.statusLabel.text = "Starting in \(countdown)..."
                } else {
                    timer.invalidate()
                    self.gameRunning = true
                    self.pickRandomRecipe()
                    self.statusLabel.text = "Drag butter onto the toast first"
                    
                    self.gameTimer?.invalidate()
                    self.gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                        guard let self = self else { return }
                        self.timeLeft -= 1
                        self.updateTimerUI()
                        if self.timeLeft <= 0 {
                            self.endRound()
                        }
                    }
                }
            }
        }
    }
        
    func endRound() {
        gameTimer?.invalidate()
        gameTimer = nil
        gameRunning = false
        stopRecipeTimer()
        recipeProgressView.progress = 0
        
        if currentRound < totalRounds {
            performLocalReset()
            currentRound += 1
            startRound()
        } else {
            endGame()
        }
    }
    
    func endGame() {
        gameRunning = false
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
                        self.updateVisibleIngredients()
                        
                    case .passIngredient(let name):
                        self.receivePassedIngredient(name: name)
                        
                    case .setSeatingOrder(let playerNames):
                        self.officialSeatingOrder = playerNames
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
        
        if !isMultiplayerEnabled {
            // Just animate it off screen to "discard" it, then reset it
            UIView.animate(withDuration: 0.3, animations: {
                imageView.center.x += gesture.direction == .left ? -500 : 500
            }) { _ in
                // Remove it from the local toast if it was there
                self.addedIngredients.removeAll { $0.name == ingredientName }
                if ingredientName == "Butter" { self.butterPlaced = false }
                self.returnToOriginalPosition(imageView)
                self.statusLabel.text = "Discarded \(ingredientName)"
            }
            return
        }
        
        
        guard let targetPeer = getTargetPeer(for: gesture.direction) else {
            statusLabel.text = "No player there!"
            return
        }
        
        let offset: CGFloat = gesture.direction == .left ? -500 : 500
        imageView.isUserInteractionEnabled = false
        
        UIView.animate(withDuration: 0.3, animations: {
            imageView.center.x += offset
        }) { _ in
            imageView.isHidden = true
            
            self.addedIngredients.removeAll { $0.name == ingredientName }
        }
        
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
        } else if imageView == eggImageView {
            return "Egg"
        } else if imageView == jamImageView {
            return "Jam"
        } else if imageView == peanutButterImageView {
            return "Peanut Butter"
        } else if imageView == creamImageView {
            return "Cream"
        } else if imageView == avocadoImageView {
            return "Avocado"
        } else if imageView == seasoningImageView {
            return "Seasoning"
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
        } else if imageView == eggImageView {
            target = CGPoint(x: center.x + 28, y: center.y - 12)
        } else if imageView == jamImageView {
            target = CGPoint(x: center.x + 28, y: center.y - 12)
        } else if imageView == peanutButterImageView {
            target = CGPoint(x: center.x + 28, y: center.y - 12)
        } else if imageView == creamImageView {
            target = CGPoint(x: center.x + 28, y: center.y - 12)
        } else if imageView == avocadoImageView {
            target = CGPoint(x: center.x + 28, y: center.y - 12)
        } else if imageView == seasoningImageView {
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
        } else if ingredientName == "Egg" {
            targetView = eggImageView
            statusLabel.text = "Partner added an Egg!"
        } else if ingredientName == "Jam" {
            targetView = jamImageView
            statusLabel.text = "Partner added Jam!"
        } else if ingredientName == "Peanut Butter" {
            targetView = peanutButterImageView
            statusLabel.text = "Partner added Peanut Butter!"
        } else if ingredientName == "Avocado" {
            targetView = creamImageView
            statusLabel.text = "Partner added Avocado!"
        } else if ingredientName == "Seasoning" {
            targetView = creamImageView
            statusLabel.text = "Partner added Seasoning!"
        } else if ingredientName == "Cream" {
            targetView = creamImageView
            statusLabel.text = "Partner added Cream!"
        }else {
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
        returnToOriginalPosition(eggImageView)
        returnToOriginalPosition(jamImageView)
        returnToOriginalPosition(peanutButterImageView)
        returnToOriginalPosition(creamImageView)
        returnToOriginalPosition(avocadoImageView)
        returnToOriginalPosition(seasoningImageView)
        
        updateVisibleIngredients()
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


