//
//  AudioManager.swift
//  Toast-It
//
//  Created by user286461 on 4/18/26.
//



import Foundation
import AVFoundation

class AudioManager {
    static let shared = AudioManager()
    
    private let musicVolumeKey = "musicVolume"
    private let sfxVolumeKey = "sfxVolume"
    
    var bgmPlayer: AVAudioPlayer?
    var currentTrack: String?
    
  
    var sfxPlayers: [AVAudioPlayer] = []
    
    var musicVolume: Float {
        get {
            if UserDefaults.standard.object(forKey: musicVolumeKey) == nil {
                return 0.5
            }
            return UserDefaults.standard.float(forKey: musicVolumeKey)
        }
        set {
            let clamped = max(0.0, min(newValue, 1.0))
            UserDefaults.standard.set(clamped, forKey: musicVolumeKey)
            bgmPlayer?.volume = clamped
        }
    }

    var sfxVolume: Float {
        get {
            if UserDefaults.standard.object(forKey: sfxVolumeKey) == nil {
                return 0.5
            }
            return UserDefaults.standard.float(forKey: sfxVolumeKey)
        }
        set {
            let clamped = max(0.0, min(newValue, 1.0))
            UserDefaults.standard.set(clamped, forKey: sfxVolumeKey)

            for player in sfxPlayers {
                player.volume = clamped
            }
        }
    }
    
    private init() { }
    

    func playMusic(trackName: String, extensionName: String = "mp3") {
        if currentTrack == trackName && bgmPlayer?.isPlaying == true {
            return
        }

        guard let url = Bundle.main.url(forResource: trackName, withExtension: extensionName) else {
            print("Could not find music file: \(trackName).\(extensionName)")
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            bgmPlayer = try AVAudioPlayer(contentsOf: url)
            bgmPlayer?.numberOfLoops = -1
            bgmPlayer?.volume = musicVolume
            bgmPlayer?.prepareToPlay()
            bgmPlayer?.play()

            currentTrack = trackName
        } catch {
            print("Error playing music: \(error.localizedDescription)")
        }
    }
    
    func stopMusic() {
        bgmPlayer?.stop()
        currentTrack = nil
    }
    
  
    func playSFX(fileName: String, extensionName: String = "mp3") {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: extensionName) else {
            print("Could not find SFX file: \(fileName).\(extensionName)")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = sfxVolume
            player.prepareToPlay()
            player.play()

            sfxPlayers.append(player)
            sfxPlayers.removeAll { $0.isPlaying == false }

        } catch {
            print("Error playing SFX: \(error.localizedDescription)")
        }
    }
    func setMusicVolume(_ value: Float) {
        musicVolume = value
    }

    func setSFXVolume(_ value: Float) {
        sfxVolume = value
    }
}
