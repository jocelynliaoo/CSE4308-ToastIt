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
    
    var audioPlayer: AVAudioPlayer?
    var currentTrack: String?
    
    private init() { }
    
    func playMusic(trackName: String, extensionName: String = "mp3") {
       
        if currentTrack == trackName && audioPlayer?.isPlaying == true {
            return
        }
        
        guard let url = Bundle.main.url(forResource: trackName, withExtension: extensionName) else {
            print("Could not find audio file: \(trackName).\(extensionName)")
            return
        }
        
        do {
          
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1 
            audioPlayer?.play()
            
            currentTrack = trackName
        } catch {
            print("Error playing audio: \(error.localizedDescription)")
        }
    }
    
    func stopMusic() {
        audioPlayer?.stop()
        currentTrack = nil
    }
}
