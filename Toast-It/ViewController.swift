//
//  ViewController.swift
//  Toast-It
//
//  Created by Jocelyn Liao on 3/31/26.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var playButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func playClicked(_ sender: Any) {
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
     
        AudioManager.shared.playMusic(trackName: "menu_music")
    }
}
