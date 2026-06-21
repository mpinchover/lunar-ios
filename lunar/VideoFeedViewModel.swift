import Foundation
import AVFoundation
import FirebaseAuth

private struct VideoFeedResponse: Decodable {
    let count: Int
    let videos: [VideoItem]
}

private struct VideoItem: Decodable {
    let index: Int
    let media_url: String
}

class VideoFeedViewModel: ObservableObject {
    @Published private(set) var currentIndex: Int = 0
    @Published var isMuted: Bool = true {
        didSet {
            configureAudioSession()
            updateAudio(for: currentIndex)
        }
    }
    @Published private(set) var isLoadingMore: Bool = false

    private static let videosEndpoint = "https://lunar-server-286518526012.us-central1.run.app/videos"

    private(set) var urls: [URL] = []
    /// Highest Firestore `index` from the last loaded batch; sent as `last_index` for the next request.
    private var lastServerIndex: Int?
    private var hasMore: Bool = true
    private var playerItems: [Int: (player: AVQueuePlayer, looper: AVPlayerLooper)] = [:]
    private let windowRadius = 2

    // True when the user is on the last buffered video and the server may have more
    var isAtLastLoaded: Bool {
        hasMore && !urls.isEmpty && currentIndex >= urls.count - 1
    }

    /// Last local video with no further server pages (guest / end of catalog).
    var isAtEndOfFeed: Bool {
        !urls.isEmpty && currentIndex >= urls.count - 1 && !hasMore
    }

    init() {
        configureAudioSession()
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
        // Pre-fetch next batch when 5 videos from the end (suits 20-video batches)
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
        let useInitial = urls.isEmpty
        Task { @MainActor [weak self] in
            await self?.loadVideos(initial: useInitial)
        }
    }

    private func videosRequestURL(initial: Bool) -> URL? {
        var components = URLComponents(string: Self.videosEndpoint)
        var queryItems: [URLQueryItem] = []
        if initial {
            queryItems.append(URLQueryItem(name: "initial", value: "true"))
        } else if let last = lastServerIndex {
            queryItems.append(URLQueryItem(name: "last_index", value: String(last)))
        }
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        return components?.url
    }

    private func videosURLRequest(initial: Bool) async throws -> URLRequest? {
        guard let url = videosRequestURL(initial: initial) else { return nil }
        var request = URLRequest(url: url)
        if let user = Auth.auth().currentUser {
            let token = try await user.getIDToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    /// Clears feed state and refetches from the server (e.g. after sign-in with auth).
    @MainActor
    func reload() {
        urls = []
        lastServerIndex = nil
        hasMore = true
        currentIndex = 0
        isLoadingMore = false
        for (_, item) in playerItems {
            item.player.pause()
        }
        playerItems = [:]
        fetchMore()
    }

    @MainActor
    private func loadVideos(initial: Bool) async {
        defer { isLoadingMore = false }
        do {
            guard let request = try await videosURLRequest(initial: initial) else { return }
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(VideoFeedResponse.self, from: data)
            if response.videos.isEmpty {
                hasMore = false
                return
            }
            var maxIndex: Int?
            for video in response.videos {
                if let videoURL = URL(string: video.media_url) {
                    urls.append(videoURL)
                    maxIndex = max(maxIndex ?? video.index, video.index)
                }
            }
            if let maxIndex {
                lastServerIndex = maxIndex
            }
            if Auth.auth().currentUser == nil {
                hasMore = false
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

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            if isMuted {
                try session.setCategory(.ambient, mode: .default)
            } else {
                try session.setCategory(.playback, mode: .default)
            }
            try session.setActive(true)
        } catch {
            // If session setup fails, player mute state still applies in-app.
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
            let asset = AVURLAsset(url: urls[i])
            // Kick off network/metadata loading before the player needs it
            asset.loadValuesAsynchronously(forKeys: ["playable", "tracks"]) { }
            let templateItem = AVPlayerItem(asset: asset)
            // Start playback after 2 s buffered instead of AVFoundation's large default
            templateItem.preferredForwardBufferDuration = 2.0
            let queuePlayer = AVQueuePlayer()
            queuePlayer.isMuted = true
            let looper = AVPlayerLooper(player: queuePlayer, templateItem: templateItem)
            playerItems[i] = (player: queuePlayer, looper: looper)
            queuePlayer.play()
        }
    }
}
