//
//  SettingsViewController.swift
//  Toast-It
//
//  Created by Jocelyn Liao on 4/19/26.
//

import UIKit

class SettingsViewController: UIViewController {

    @IBOutlet weak var musicSlider: UISlider!
    @IBOutlet weak var soundSlider: UISlider!

    override func viewDidLoad() {
        super.viewDidLoad()

        musicSlider.minimumValue = 0.0
        musicSlider.maximumValue = 1.0
        soundSlider.minimumValue = 0.0
        soundSlider.maximumValue = 1.0

        musicSlider.value = AudioManager.shared.musicVolume
        soundSlider.value = AudioManager.shared.sfxVolume
    }

    @IBAction func musicSliderChanged(_ sender: UISlider) {
        AudioManager.shared.setMusicVolume(sender.value)
    }

    @IBAction func soundSliderChanged(_ sender: UISlider) {
        AudioManager.shared.setSFXVolume(sender.value)
    }
}
