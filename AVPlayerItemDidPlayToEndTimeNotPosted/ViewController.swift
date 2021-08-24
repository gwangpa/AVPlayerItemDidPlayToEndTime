//
//  ViewController.swift
//  AVPlayerItemDidPlayToEndTimeNotPosted
//
//  Created by Daniel Kim on 24/8/21.
//

import UIKit
import AVFoundation
import SnapKit

// This is simplified version of the issue.
//
// Step to reproduce
//   1. Build and run on iOS 14.5 or higher
//   2. Once the video start play then move the slider to almost end, about 90%
//   3. Turn on and off the UISwitch
//   4. Wait till the video play reaches to the end
//   5. Check debug console print out.
//   6. Got some debug out instead expected one
//      2021-08-25 09:42:35.155130+1000 AVPlayerItemDidPlayToEndTimeNotPosted[7052:3052664] [Symptoms] {
//        "transportType" : "HTTP Live Stream",
//        "mediaType" : "HTTP Live Stream",
//        "BundleID" : "AVPlayerItemDidPlayToEndTimeNot",
//        "name" : "MEDIA_PLAYBACK_STALL",
//        "interfaceType" : "Wifi"
//      }

class ViewController: UIViewController {
    
    private let player = AVQueuePlayer()
    private let scrubber = UISlider()
    private let ccToggler = UISwitch()
    private var observer: Any?

    override func viewDidLoad() {
        super.viewDidLoad()
        configurePlayer()
        configureControls()
    }
    
    private func configurePlayer() {
        // Periodic observer
        let interval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        observer = player.addPeriodicTimeObserver(forInterval: interval, queue:DispatchQueue.main) { [weak self] time in
            if let duration = self?.player.currentItem?.duration.seconds, !duration.isNaN {
                self?.scrubber.maximumValue = Float(duration)
            }
            self?.scrubber.value = Float(time.seconds)
        }
        
        // AVPlayerItem
        let urlString = "https://d3rlna7iyyu8wu.cloudfront.net/skip_armstrong/skip_armstrong_stereo_subs.m3u8"
        guard let url = URL(string: urlString) else { return }
        let playerItem = AVPlayerItem(url: url)
        player.removeAllItems()
        player.insert(playerItem, after: nil)
        
        // AVPlayerItem observer
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidPlayEnd), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)

        // AVPlayerLayer
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = self.view.bounds
        view.layer.addSublayer(playerLayer)
        player.play()
    }
    
    private func configureControls() {
        view.addSubview(ccToggler)
        ccToggler.snp.makeConstraints { make in
            make.right.equalToSuperview().inset(20)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).inset(80)
        }
        ccToggler.addTarget(self, action: #selector(ccTogglerDidChange), for: .valueChanged)
        
        view.addSubview(scrubber)
        scrubber.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(20)
            make.right.equalTo(ccToggler.snp.left).inset(-20)
            make.centerY.equalTo(ccToggler)
        }
        scrubber.addTarget(self, action: #selector(scrubberDidChange), for: .touchUpInside)
    }
    
    @objc private func ccTogglerDidChange() {
        guard
            let item = player.currentItem,
            let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible)
        else {
            return
        }
        let options = AVMediaSelectionGroup.mediaSelectionOptions(from: group.options, filteredAndSortedAccordingToPreferredLanguages: NSLocale.preferredLanguages)
        guard let option = options.first else {
            return
        }
        if ccToggler.isOn {
            item.select(option, in: group)
        } else {
            if group.allowsEmptySelection {
                // This line causes unexpected behaviour!
                // NSNotification.Name.AVPlayerItemDidPlayToEndTime is not posted if this code line is executed at last moment of playback time
                item.select(nil, in: group)
            }
        }
    }
    
    @objc private func scrubberDidChange() {
        let time = CMTime(seconds: Double(scrubber.value), preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: time)
    }
    
    @objc private func playerItemDidPlayEnd() {
        print(">>>>> notification posted!!")
    }
}
