//
//  GameModels.swift
//  Toast-It
//
//  Created by Jocelyn Liao on 4/1/26.
//

import Foundation
import MultipeerConnectivity

// data types

struct Ingredient: Equatable, Codable {
    let name: String
}

struct Recipe: Codable, Equatable {
    let name: String
    let requiredIngredients: [Ingredient]
    let points: Int
}

enum GameAction: Codable {
    case passIngredient(name: String)
    case setSeatingOrder(playerNames: [String])
    case syncScore(teamScore: Int)
    case awardPoints(points: Int)
    case setMyIngredients(names: [String])
    case setRecipe(recipe: Recipe)
    case clearInventory
    case playAgain
    case playerLeftLobby(name: String)
    case startGame
}

enum SubmitResult {
    case correct(points: Int)
    case tooManyIngredients
    case missingIngredients(names: Set<String>)
}

// game model

class GameModel {
    // recipe data
    let round1Recipes = [
            Recipe(name: "Plain Butter Toast", requiredIngredients: [Ingredient(name: "Butter")], points: 5),
            Recipe(name: "Strawberry Toast", requiredIngredients: [Ingredient(name: "Butter"), Ingredient(name: "Strawberries"), Ingredient(name: "Powdered Sugar")], points: 5),
            Recipe(name: "Egg Toast", requiredIngredients: [Ingredient(name: "Butter"), Ingredient(name: "Egg")], points: 8),
    ]
 
    let round2Recipes = [
        Recipe(name: "PB & J Toast", requiredIngredients: [Ingredient(name: "Butter"), Ingredient(name: "Peanut Butter"), Ingredient(name: "Jam")], points: 10),
        Recipe(name: "Strawberries and Cream Toast", requiredIngredients: [Ingredient(name: "Butter"), Ingredient(name: "Cream"), Ingredient(name: "Strawberries")], points: 10),
        Recipe(name: "Avocado Toast", requiredIngredients: [Ingredient(name: "Butter"), Ingredient(name: "Avocado"), Ingredient(name: "Seasoning")], points: 8),
        Recipe(name: "Avocado and Egg Toast", requiredIngredients: [Ingredient(name: "Butter"), Ingredient(name: "Avocado"), Ingredient(name: "Egg"), Ingredient(name: "Seasoning")], points: 10),
    ]
 
    var allRecipes: [Recipe] { round1Recipes + round2Recipes }

    var recipesForCurrentRound: [Recipe] {
        switch currentRound {
        case 1: return round1Recipes
        case 2: return round2Recipes
        default: return allRecipes
        }
    }
    
    // round configuration
    let totalRounds = 3
    let round1Duration = 45
    let round2Duration = 30
    let round3Duration = 15
    let recipeDuration = 10
    
    // game state
    private(set) var teamScore = 0
    private(set) var dishesSubmitted = 0
    private(set) var dishesLost = 0
    private(set) var currentRound = 1
    private(set) var timeLeft = 45
    private(set) var gameRunning = false
    
    // player's own plate
    private(set) var addedIngredients: [Ingredient] = []
    private(set) var butterPlaced = false
    var currentRecipe: Recipe
    
    var myVisibleIngredientNames: [String] = []
    
    // timers
    private var gameTimer: Timer?
    private var recipeTimer: Timer?
    
    // callbacks to ViewController
    var onTeamScoreChanged: ((Int) -> Void)?
    var onRecipeChanged: ((Recipe) -> Void)?
    var onTimerChanged: ((Int, Int) -> Void)?
    var onRecipeTimerChanged: ((Float) -> Void)?
    var onRecipeTimerColor: ((RecipeTimerColor) -> Void)?
    var onStatusChanged: ((String) -> Void)?
    var onVisibleIngredientsChanged: (() -> Void)?
    var onPlateReset: (() -> Void)?
    var onRoundStarting: ((Int) -> Void)?
    var onGameEnded: (() -> Void)?
    var onRecipeExpired: (() -> Void)?
    var onRoundStarted: (() -> Void)?
 
    enum RecipeTimerColor {
        case normal, warning, danger
    }
    
    // init
    init() {
        currentRecipe = Recipe(
            name: "Strawberry Toast",
            requiredIngredients: [Ingredient(name: "Butter"), Ingredient(name: "Strawberries"), Ingredient(name: "Powdered Sugar")],
            points: 5
        )
    }
    
    // game flow
    func startGame() {
        teamScore = 0
        dishesLost = 0
        dishesSubmitted = 0
        currentRound = 1
        onTeamScoreChanged?(teamScore)
        startRound()
    }
    
    func startRound() {
        switch currentRound {
        case 1:
            timeLeft = round1Duration
            self.onStatusChanged?("Round 1: Make as many toasts as you can!")
        case 2:
            timeLeft = round2Duration
            self.onStatusChanged?("Round 2: New recipes!")
        default:
            timeLeft = round3Duration
            self.onStatusChanged?("Round 3: Final 15 seconds!")
        }
 
        onRoundStarting?(currentRound)
        gameRunning = false
 
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
            guard let self else { return }
            var countdown = 3
            self.onStatusChanged?("Starting in \(countdown)...")
 
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                guard let self else { timer.invalidate(); return }
                countdown -= 1
                if countdown > 0 {
                    self.onStatusChanged?("Starting in \(countdown)...")
                } else {
                    timer.invalidate()
                    self.gameRunning = true
                    self.onStatusChanged?("Drag butter onto the toast first")
                    self.onRoundStarted?()
                    self.gameTimer?.invalidate()
                    self.gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                        guard let self else { return }
                        self.timeLeft -= 1
                        self.onTimerChanged?(self.timeLeft, self.currentRound)
                        if self.timeLeft <= 0 { self.endRound() }
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
 
        if currentRound < totalRounds {
            currentRound += 1
            startRound()
        } else {
            endGame()
        }
    }
    
    func endGame() {
        gameRunning = false
        onStatusChanged?("Time's up! Final score: \(teamScore)")
        onGameEnded?()
    }
    
    // recipe and ingredient assignment logic
    func assignRecipe(_ recipe: Recipe, visibleIngredients: [String]) {
        self.currentRecipe = recipe
        
        if isSinglePlayer() {
            // Clean Slate
            let required = recipe.requiredIngredients.map { $0.name }
            let decoys = generateDecoys(for: recipe, count: 2)
            
            // Combine and shuffle s
            self.myVisibleIngredientNames = (required + decoys).shuffled()
        } else {
            for item in visibleIngredients {
                if !myVisibleIngredientNames.contains(item) {
                    myVisibleIngredientNames.append(item)
                }
            }
        }
        
        onRecipeChanged?(recipe)
        onVisibleIngredientsChanged?()
        startRecipeTimer()
    }
    
    func receivePassedIngredient(name: String) {
        myVisibleIngredientNames.append(name)
        onVisibleIngredientsChanged?()
    }
    
    func removeIngredientFromInventory(name: String) {
        if let index = myVisibleIngredientNames.firstIndex(of: name) {
            myVisibleIngredientNames.remove(at: index)
            onVisibleIngredientsChanged?()
        }
    }
    
    private func isSinglePlayer() -> Bool {
        return ConnectionManager.shared.session.connectedPeers.isEmpty
    }

    private func generateDecoys(for recipe: Recipe, count: Int) -> [String] {
        let requiredNames = Set(recipe.requiredIngredients.map { $0.name })
        let allPossibleIngredients = [
            "Butter", "Strawberries", "Powdered Sugar", "Egg", "Jam",
            "Peanut Butter", "Cream", "Avocado", "Seasoning"
        ]
        
     
        let potentialDecoys = allPossibleIngredients.filter { !requiredNames.contains($0) }
        return Array(potentialDecoys.shuffled().prefix(count))
    }
    
    func clearInventoryOnly() {
        self.myVisibleIngredientNames.removeAll()
        self.onVisibleIngredientsChanged?()
    }
    
    // plate logic
    @discardableResult
    func addIngredient(name: String) -> Bool {
        if !butterPlaced && name != "Butter" {
            onStatusChanged?("Butter has to go first!")
            return false
        }

        addedIngredients.append(Ingredient(name: name))
        
        if let index = myVisibleIngredientNames.firstIndex(of: name) {
            myVisibleIngredientNames.remove(at: index)
        }
        
        onVisibleIngredientsChanged?()
        
        if name == "Butter" {
            butterPlaced = true
            onStatusChanged?(currentRecipe.name == "Plain Butter Toast" ? "Try submitting this plate!" : "Nice! Now add the toppings.")
        } else {
            onStatusChanged?("\(name) added!")
        }
        return true
    }
 
    func removeIngredient(name: String) {
        addedIngredients.removeAll { $0.name == name }
        if name == "Butter" { butterPlaced = false }
    }
 
    @discardableResult
    func submitDish() -> SubmitResult {
        let addedSet = Set(addedIngredients.map { $0.name })
        let recipeSet = Set(currentRecipe.requiredIngredients.map { $0.name })
 
        if addedSet == recipeSet {
            stopRecipeTimer()
            dishesSubmitted += 1
            return .correct(points: currentRecipe.points)
        } else {
            let missing = recipeSet.subtracting(addedSet)
            if missing.isEmpty {
                onStatusChanged?("Too many ingredients! Reset this plate.")
                return .tooManyIngredients
            } else {
                onStatusChanged?("Missing: \(missing.joined(separator: ", "))")
                return .missingIngredients(names: missing)
            }
        }
    }
 
    func resetPlate() {
        for ingredient in addedIngredients {
            myVisibleIngredientNames.append(ingredient.name)
        }
        clearPlateState()
        onVisibleIngredientsChanged?()
        onPlateReset?()
        onStatusChanged?("Drag butter onto the toast first")
    }
 
  func clearPlateState() {
        addedIngredients.removeAll()
        butterPlaced = false
    }
    
    // score
    func hostApplyScore(points: Int) -> Int {
        teamScore += points
        onTeamScoreChanged?(teamScore)
        return teamScore
    }

    func applySyncedScore(_ score: Int) {
        teamScore = score
        onTeamScoreChanged?(teamScore)
    }
    
    // recipe timer
    func startRecipeTimer() {
        stopRecipeTimer()
        let totalDuration = Double(recipeDuration)
        let startTime = Date()
 
        recipeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let elapsed = Date().timeIntervalSince(startTime)
            let remaining = totalDuration - elapsed
            self.onRecipeTimerChanged?(Float(max(0, remaining) / totalDuration))
 
            if remaining <= 3 { self.onRecipeTimerColor?(.danger) }
            else if remaining <= 6 { self.onRecipeTimerColor?(.warning) }
            else { self.onRecipeTimerColor?(.normal) }
 
            if remaining <= 0 { self.recipeExpired() }
        }
    }
    
    func stopRecipeTimer() {
        recipeTimer?.invalidate()
        recipeTimer = nil
    }

    private func recipeExpired() {
        stopRecipeTimer()
        dishesLost += 1
        teamScore -= currentRecipe.points
        onTeamScoreChanged?(teamScore)
        onStatusChanged?("Too slow! Dish lost.")
        onRecipeExpired?()
    }
    
    func abruptlyEndGame() {
        gameTimer?.invalidate()
        gameTimer = nil
        stopRecipeTimer()
        gameRunning = false
    }
}
