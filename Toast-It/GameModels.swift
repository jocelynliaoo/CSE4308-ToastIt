//
//  GameModels.swift
//  Toast-It
//
//  Created by Jocelyn Liao on 4/1/26.
//

import Foundation

struct Ingredient: Equatable {
    let name: String
}

struct Recipe {
    let name: String
    let requiredIngredients: [Ingredient]
    let points: Int
}
