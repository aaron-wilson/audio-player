//
//  Store.swift
//  MultimediaPlayer
//
//  Created by admin on 6/7/20.
//  Copyright © 2020 Admin. All rights reserved.
//

import Foundation
import AVKit

class Store: ObservableObject {
    @Published var title: String? = nil
    @Published var videoPlayer: VideoPlayer? = nil
    @Published var playbacks: [Playback]? = nil
}
