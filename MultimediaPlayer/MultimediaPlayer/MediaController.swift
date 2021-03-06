//
//  MediaController.swift
//  MultimediaPlayer
//
//  Created by admin on 6/6/20.
//  Copyright © 2020 Admin. All rights reserved.
//

import AVKit
import MediaPlayer
import SwiftUI

struct MediaController {
    
    var player: AVPlayer?
    var currentFilename: String?
    let commandCenter: MPRemoteCommandCenter = MPRemoteCommandCenter.shared()
    let infoCenter: MPNowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
    
    func playMedia(filename: String) {
        player?.play()
        player?.rate = 1.0
        
        update(filename: filename)
    }
    
    func pauseMedia(filename: String) {
        player?.pause()
        player?.rate = 0.0
        
        update(filename: filename)
    }
    
    func playInfoCenterHandler(filename: String?) {
        // handler for InfoCenter play
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.playCommand.addTarget { _ in
            self.player?.play()
            self.player?.rate = 1.0
            
            self.update(filename: filename)
            
            return .success
        }
    }
    
    func pauseInfoCenterHandler(filename: String?) {
        // handler for InfoCenter pause
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.pauseCommand.addTarget { _ in
            self.player?.pause()
            self.player?.rate = 0.0
            
            self.update(filename: filename)
            
            return .success
        }
    }
    
    func seekInfoCenterHandler(filename: String?) {
        // handler for InfoCenter seek
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        
        // commented out section worked, but had following problems:
        //   1. seek bubble flashed from original position to new position on release
        //   2. result was always .commandFailed, could not modify from callback
        //
        // commandCenter.changePlaybackPositionCommand.addTarget { event -> MPRemoteCommandHandlerStatus in
        //     var result: MPRemoteCommandHandlerStatus = .commandFailed
        //
        //     let wasPlaying = (self.player!.rate > 0.0) ? true : false
        //
        //     let seconds = (event as? MPChangePlaybackPositionCommandEvent)?.positionTime ?? 0
        //     let playerTimescale = self.player?.currentItem?.asset.duration.timescale ?? 1
        //     let time = CMTime(seconds: seconds, preferredTimescale: playerTimescale)
        //
        //     if (wasPlaying) {
        //         self.player?.pause()
        //         self.player?.rate = 0.0
        //     }
        //     self.player?.seek(to: time, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero, completionHandler: { (finish: Bool) in
        //         if (finish) {
        //             if (wasPlaying) {
        //                 self.player?.play()
        //                 self.player?.rate = 1.0
        //             }
        //             result = .success
        //         }
        //         self.update(filename: filename)
        //     })
        //
        //     return result
        // }
        
        commandCenter.changePlaybackPositionCommand.addTarget { remoteEvent -> MPRemoteCommandHandlerStatus in
            if let player = self.player {
                let playerRate = player.rate
                if let event = remoteEvent as? MPChangePlaybackPositionCommandEvent {
                    player.seek(to: CMTime(seconds: event.positionTime, preferredTimescale: CMTimeScale(1000)), completionHandler: { (success) in
                        if success {
                            self.player?.rate = playerRate
                            self.update(filename: filename)
                        }
                    })
                    return .success
                }
            }
            return .commandFailed
        }
    }
    
    mutating func loadMedia(url: URL?) -> String? {
        player?.pause()
        
        let sharedInstance = AVAudioSession.sharedInstance()
        
        do {
            try sharedInstance.setMode(.default)
            try sharedInstance.setActive(true, options: .notifyOthersOnDeactivation)
            try sharedInstance.setCategory(AVAudioSession.Category.playback)
            
            player = AVPlayer(url: url!)
            
            let filename = url?.lastPathComponent
            update(filename: filename)
            playInfoCenterHandler(filename: filename)
            pauseInfoCenterHandler(filename: filename)
            seekInfoCenterHandler(filename: filename)
            
            currentFilename = filename
            
            return filename
        } catch {
            print("error")
        }
        
        return nil
    }
    
    mutating func loadMedia(fileURLWithPath: String, ofType: String?) -> String? {
        let media = Bundle.main.url(forResource: fileURLWithPath, withExtension: ofType)
        
        return loadMedia(url: media)
    }
    
    func update(filename: String?) {
        var nowPlayingInfo = [String : Any]()
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = filename
        if let image = UIImage(named: "lockscreen") {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in
                return image
            }
        }
        
        let position = player?.currentTime().seconds
        let duration = player?.currentItem?.asset.duration.seconds
        let rate = player?.rate
        
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = rate
        
        infoCenter.nowPlayingInfo = nowPlayingInfo
        
        if position ?? 0 > 0 {
            updatePlaybacks(filename: filename!, position: position!, duration: duration!)
        }
        
        // print(infoCenter.nowPlayingInfo!)
    }
    
    func update() {
        if (currentFilename != nil) {
            update(filename: currentFilename)
        }
    }
    
    func updatePlaybacks() {
        // fetch playbacks from UserDefaults
        var userDefaultsPlaybacks: [Playback]? = nil
        if let data = UserDefaults.standard.object(forKey: "playbacks") as? Data {
            if let decodedData = try? JSONDecoder().decode([Playback].self, from: data) {
//                print("Fetching playbacks from UserDefaults: \(decodedData)")
                userDefaultsPlaybacks = decodedData
            }
        }
        
        // update store.playbacks to match UserDefaults
        store.playbacks = userDefaultsPlaybacks
    }
    
    func updatePlaybacks(filename: String, position: Double, duration: Double) {
        updatePlaybacks()
        
        // create updatedPlaybacks with new Playback on top of store.playbacks
        let filteredPlaybacks = store.playbacks?.filter {
            $0.filename.lowercased() != filename.lowercased()
        }
        let updatedPlaybacks = [Playback(filename: filename, position: position, duration: duration)] + (filteredPlaybacks ?? [])
        
        // save updatedPlaybacks to UserDefaults
        if let encodedData = try? JSONEncoder().encode(updatedPlaybacks) {
            UserDefaults.standard.set(encodedData, forKey: "playbacks")
        }
        
        // save updatedPlaybacks to store.playbacks
        store.playbacks = updatedPlaybacks
    }
    
    func loadVideoPlayer() -> VideoPlayer {
        return VideoPlayer(player: player!)
    }
    
}

struct VideoPlayer: UIViewControllerRepresentable {
    
    var player: AVPlayer
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<VideoPlayer>) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: UIViewControllerRepresentableContext<VideoPlayer>) {
        
    }
    
}
