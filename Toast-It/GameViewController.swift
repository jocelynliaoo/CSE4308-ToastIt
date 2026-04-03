//
//  GameViewController.swift
//  Toast-It
//
//  Created by Jocelyn Liao on 4/1/26.
//

import UIKit
import MultipeerConnectivity

class GameViewController: UIViewController {

    @IBOutlet weak var recipeLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var plateImageView: UIImageView!
    @IBOutlet weak var toastImageView: UIImageView!

    @IBOutlet weak var butterImageView: UIImageView!
    @IBOutlet weak var strawberryImageView: UIImageView!
    @IBOutlet weak var sugarImageView: UIImageView!

    var addedIngredients: [Ingredient] = []
    var butterPlaced = false

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

    override func viewDidLoad() {
        super.viewDidLoad()

        recipeLabel.text = "Recipe: \(currentRecipe.name)"
        statusLabel.text = "Drag butter onto the toast first"

        setupDraggableIngredient(butterImageView)
        setupDraggableIngredient(strawberryImageView)
        setupDraggableIngredient(sugarImageView)

        originalCenters[butterImageView] = butterImageView.center
        originalCenters[strawberryImageView] = strawberryImageView.center
        originalCenters[sugarImageView] = sugarImageView.center
        
        ConnectionManager.shared.onDataReceived = { [weak self] data in
                    if let action = try? JSONDecoder().decode(GameAction.self, from: data) {
                        self?.receiveRemoteMove(ingredientName: action.ingredientName)
                    }
                }
            
    }

    func setupDraggableIngredient(_ imageView: UIImageView) {
        imageView.isUserInteractionEnabled = true
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        imageView.addGestureRecognizer(panGesture)
    }

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let draggedView = gesture.view as? UIImageView else { return }

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

        snapIngredientToToast(imageView)
        if let ingredientName = ingredientNameForImageView(imageView) {
                    let action = GameAction(ingredientName: ingredientName)
                    if let data = try? JSONEncoder().encode(action) {
                        try? ConnectionManager.shared.session.send(data, toPeers: ConnectionManager.shared.session.connectedPeers, with: .reliable)
                    }
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

    @IBAction func submitTapped(_ sender: UIButton) {
        let addedSet = Set(addedIngredients.map { $0.name })
        let recipeSet = Set(currentRecipe.requiredIngredients.map { $0.name })

        if addedSet == recipeSet {
            statusLabel.text = "Correct!"
        } else {
            statusLabel.text = "Not quite right. Try again!"
        }
    }

    @IBAction func resetTapped(_ sender: UIButton) {
        addedIngredients.removeAll()
        butterPlaced = false

        returnToOriginalPosition(butterImageView)
        returnToOriginalPosition(strawberryImageView)
        returnToOriginalPosition(sugarImageView)

        statusLabel.text = "Drag butter onto the toast first"
    }
}
