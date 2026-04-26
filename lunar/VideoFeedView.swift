import SwiftUI

struct VideoFeedView: View {
    @StateObject private var viewModel = VideoFeedViewModel()
    @State private var dragOffset: CGFloat = 0
    @State private var isAnimating = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                videoStack(geo: geo)
                muteButton
            }
            .gesture(dragGesture(screenHeight: geo.size.height))
        }
        .ignoresSafeArea()
        .onAppear { viewModel.playCurrentVideo() }
    }

    // Each video index gets its own persistent VideoPlayerView identified by
    // index. Views slide via offset math — no player is ever reassigned to a
    // different layer, eliminating the stale-frame flash from AVPlayerLayer.
    //
    // Offset identity at transition boundary:
    //   end of animation  : (i - idx)   * h + (−h) = (i − idx − 1) * h
    //   after advance+reset: (i − idx−1) * h + 0   = (i − idx − 1) * h  ✓
    @ViewBuilder
    private func videoStack(geo: GeometryProxy) -> some View {
        let w = geo.size.width
        let h = geo.size.height
        let idx = viewModel.currentIndex
        let lo = max(0, idx - 2)
        let hi = min(viewModel.urls.count - 1, idx + 2)

        if lo <= hi {
            ForEach(lo...hi, id: \.self) { i in
                if let player = viewModel.player(at: i) {
                    VideoPlayerView(player: player)
                        .frame(width: w, height: h)
                        .offset(y: CGFloat(i - idx) * h + dragOffset)
                }
            }
        }
    }

    private var muteButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    viewModel.isMuted.toggle()
                } label: {
                    Image(systemName: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.white)
                        .padding(14)
                        .background(.black.opacity(0.55))
                        .clipShape(Circle())
                }
                .padding(.trailing, 20)
                .padding(.bottom, 50)
            }
        }
    }

    private func dragGesture(screenHeight: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isAnimating else { return }
                let dy = value.translation.height
                let atStart = viewModel.currentIndex == 0
                let atEnd = viewModel.currentIndex == viewModel.urls.count - 1
                if (dy > 0 && atStart) || (dy < 0 && atEnd) {
                    dragOffset = dy * 0.12
                } else {
                    dragOffset = dy
                }
            }
            .onEnded { value in
                guard !isAnimating else { return }
                let dy = value.translation.height
                let threshold = screenHeight / 3

                if dy < -threshold && viewModel.currentIndex < viewModel.urls.count - 1 {
                    isAnimating = true
                    withAnimation(.easeInOut(duration: 0.25)) { dragOffset = -screenHeight }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        viewModel.advance()
                        dragOffset = 0
                        isAnimating = false
                    }
                } else if dy > threshold && viewModel.currentIndex > 0 {
                    isAnimating = true
                    withAnimation(.easeInOut(duration: 0.25)) { dragOffset = screenHeight }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        viewModel.retreat()
                        dragOffset = 0
                        isAnimating = false
                    }
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                }
            }
    }
}
