//
//  GameModels.swift
//  Toast-It
//
//  Created by Jocelyn Liao on 4/1/26.
//

import Foundation

struct Ingredient: Equatable, Codable {
    let name: String
}

struct Recipe: Codable {
    let name: String
    let requiredIngredients: [Ingredient]
    let points: Int
}

enum GameAction: Codable {
    case dropIngredient(name: String)
    case resetGame
    case submitGame
    case setRecipe(recipe: Recipe)
}
