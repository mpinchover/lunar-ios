import Foundation
import AVFoundation

class VideoFeedViewModel: ObservableObject {
    @Published private(set) var currentIndex: Int = 0
    @Published var isMuted: Bool = true {
        didSet { updateAudio(for: currentIndex) }
    }

    private(set) var urls: [URL] = []
    private var playerItems: [Int: (player: AVQueuePlayer, looper: AVPlayerLooper)] = [:]
    private let windowRadius = 2

    init() {
        loadURLs()
        guard !urls.isEmpty else { return }
        updateWindow(for: 0)
    }

    func player(at index: Int) -> AVQueuePlayer? {
        playerItems[index]?.player
    }

    func advance() {
        guard currentIndex < urls.count - 1 else { return }
        currentIndex += 1
        updateWindow(for: currentIndex)
        updateAudio(for: currentIndex)
    }

    func retreat() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        updateWindow(for: currentIndex)
        updateAudio(for: currentIndex)
    }

    func playCurrentVideo() {
        player(at: currentIndex)?.play()
    }

    private func updateAudio(for center: Int) {
        for (i, item) in playerItems {
            item.player.isMuted = (i == center) ? isMuted : true
        }
    }

    private func updateWindow(for center: Int) {
        let lo = max(0, center - windowRadius)
        let hi = min(urls.count - 1, center + windowRadius)
        let needed = Set(lo...hi)

        for key in playerItems.keys where !needed.contains(key) {
            playerItems[key]?.player.pause()
            playerItems.removeValue(forKey: key)
        }

        for i in needed where playerItems[i] == nil {
            let templateItem = AVPlayerItem(url: urls[i])
            let queuePlayer = AVQueuePlayer()
            queuePlayer.isMuted = true
            let looper = AVPlayerLooper(player: queuePlayer, templateItem: templateItem)
            playerItems[i] = (player: queuePlayer, looper: looper)
            // Play immediately so frames are decoded before this video becomes current
            queuePlayer.play()
        }
    }

    private func loadURLs() {
        guard
            let path = Bundle.main.path(forResource: "media", ofType: "json"),
            let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
            let strings = try? JSONDecoder().decode([String].self, from: data)
        else { return }
        urls = strings.compactMap { URL(string: $0) }
    }
}
