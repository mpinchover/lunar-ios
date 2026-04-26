import Foundation
import AVFoundation

private struct VideoFeedResponse: Decodable {
    let count: Int
    let videos: [VideoItem]
}

private struct VideoItem: Decodable {
    let index: Int
    let storage_url: String
}

class VideoFeedViewModel: ObservableObject {
    @Published private(set) var currentIndex: Int = 0
    @Published var isMuted: Bool = true { didSet { updateAudio(for: currentIndex) } }
    @Published private(set) var isLoadingMore: Bool = false

    private(set) var urls: [URL] = []
    private var lastServerIndex: Int = 0
    private var hasMore: Bool = true
    private var playerItems: [Int: (player: AVQueuePlayer, looper: AVPlayerLooper)] = [:]
    private let windowRadius = 2

    // True when the user is on the last buffered video and the server may have more
    var isAtLastLoaded: Bool {
        hasMore && !urls.isEmpty && currentIndex >= urls.count - 1
    }

    init() {
        fetchMore()
    }

    func player(at index: Int) -> AVQueuePlayer? {
        playerItems[index]?.player
    }

    func advance() {
        guard currentIndex < urls.count - 1 else { return }
        currentIndex += 1
        updateWindow(for: currentIndex)
        updateAudio(for: currentIndex)
        // Pre-fetch next batch when 5 videos from the end (suits 10-video batches)
        if currentIndex >= urls.count - 5 {
            fetchMore()
        }
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

    func seekToStart(at index: Int) {
        player(at: index)?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func fetchMore() {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        let fromIndex = lastServerIndex
        Task { @MainActor [weak self] in
            await self?.loadVideos(fromServerIndex: fromIndex)
        }
    }

    @MainActor
    private func loadVideos(fromServerIndex: Int) async {
        defer { isLoadingMore = false }
        guard let requestURL = URL(string: "http://localhost:5005/videos?video_index=\(fromServerIndex)") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: requestURL)
            let response = try JSONDecoder().decode(VideoFeedResponse.self, from: data)
            if response.videos.isEmpty {
                hasMore = false
                return
            }
            for video in response.videos {
                if let videoURL = URL(string: video.storage_url) {
                    urls.append(videoURL)
                    lastServerIndex = video.index
                }
            }
            updateWindow(for: currentIndex)
        } catch {
            // Will retry on next user action
        }
    }

    private func updateAudio(for center: Int) {
        for (i, item) in playerItems {
            item.player.isMuted = (i == center) ? isMuted : true
        }
    }

    private func updateWindow(for center: Int) {
        let lo = max(0, center - windowRadius)
        let hi = min(urls.count - 1, center + windowRadius)
        guard lo <= hi else { return }
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
            queuePlayer.play()
        }
    }
}
