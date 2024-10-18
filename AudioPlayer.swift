//
//  AudioPlayer.swift
//  MusicPlayer
//
//  Created by SJ on 18/10/24.
//

import Foundation
import AVFoundation
import MediaPlayer


class AudioPlayer: ObservableObject {
    
    @Published var currentTimeString: String = "00:00"
    
    var player: AVPlayer?
    
    private var timeObserverToken: Any?
    
    
    func play() {
        player?.play()
        self.addTimeObserver()
    }
    
    func pause() {
        player?.pause()
    }
    
    func stop() {
        player?.pause()
        player?.seek(to: CMTime.zero)
    }
    
    func backward() {
        let currentTime = (player?.currentTime().seconds)!
        let newTime = max(0, currentTime-15)
        let timeToSeek = CMTime(seconds: newTime, preferredTimescale: 1)
        
        player?.seek(to: timeToSeek)
    }
    
    func forward() {
        let currentTime = (player?.currentTime().seconds)!
        let newTime = max(0, currentTime+15)
        let timeToSeek = CMTime(seconds: newTime, preferredTimescale: 1)
        
        player?.seek(to: timeToSeek)
    }
    
    func setUpRemoteTransportControls() {
        let remoteCommandCentre = MPRemoteCommandCenter.shared()
        
        remoteCommandCentre.playCommand.addTarget { [unowned self] event in
            self.play()
            return .success
        }
        
        remoteCommandCentre.pauseCommand.addTarget { [unowned self] event in
            self.pause()
            return .success
        }
        
        remoteCommandCentre.stopCommand.addTarget { [unowned self] event in
            self.stop()
            return .success
        }
    }
    
    
    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        timeObserverToken = player?
            .addPeriodicTimeObserver(forInterval: interval, queue: DispatchQueue.main, using: { [weak self] time in
                guard let self = self else { return }
                
                let currentTime = time.seconds
                let minutes     = Int(currentTime/60)
                let seconds    = Int(currentTime.truncatingRemainder(dividingBy: 60))
                
                self.currentTimeString = String(format: "%02d:%02d", minutes, seconds)
            })
    }
    
    private func removeTimeObserver() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
}
