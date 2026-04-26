import SwiftUI
import AVFoundation

struct VideoPlayerView: UIViewRepresentable {
    let player: AVQueuePlayer

    func makeUIView(context: Context) -> PlayerUIView {
        PlayerUIView(player: player)
    }

    func updateUIView(_ view: PlayerUIView, context: Context) {
        // Each VideoPlayerView owns exactly one player for its lifetime —
        // no reassignment, so no stale-frame flash from AVPlayerLayer.
    }
}

final class PlayerUIView: UIView {
    let playerLayer = AVPlayerLayer()

    init(player: AVQueuePlayer) {
        super.init(frame: .zero)
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}
