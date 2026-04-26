import SwiftUI

private let videoLimit = 5

struct VideoFeedView: View {
    @StateObject private var viewModel = VideoFeedViewModel()
    @State private var dragOffset: CGFloat = 0
    @State private var isAnimating = false
    @State private var isGrayscale = false
    @State private var showControls = true
    @State private var isLoggedIn = false
    @State private var showLoginPrompt = false

    private var isLocked: Bool { !isLoggedIn && viewModel.currentIndex >= videoLimit - 1 }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                videoStack(geo: geo)
                    .grayscale(isGrayscale ? 1.0 : 0.0)
                controls.opacity(showControls ? 1 : 0)

                if showLoginPrompt {
                    LoginOverlayView(isLoggedIn: $isLoggedIn, isPresented: $showLoginPrompt)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .gesture(dragGesture(screenHeight: geo.size.height))
            .onTapGesture {
                guard !showLoginPrompt else { return }
                withAnimation(.easeInOut(duration: 0.2)) { showControls.toggle() }
            }
        }
        .ignoresSafeArea()
        .onAppear { viewModel.playCurrentVideo() }
    }

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

    private var controls: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showLoginPrompt = true }
                    } label: {
                        Image(systemName: "person.fill")
                            .font(.system(size: 22, weight: .medium))
                            .frame(width: 22, height: 22)
                            .foregroundColor(.white)
                            .padding(14)
                            .background(.black.opacity(0.55))
                            .clipShape(Circle())
                    }

                    Button {
                        isGrayscale.toggle()
                    } label: {
                        Image(systemName: isGrayscale ? "circle.lefthalf.filled" : "circle.fill")
                            .font(.system(size: 22, weight: .medium))
                            .frame(width: 22, height: 22)
                            .foregroundColor(.white)
                            .padding(14)
                            .background(.black.opacity(0.55))
                            .clipShape(Circle())
                    }

                    Button {
                        viewModel.isMuted.toggle()
                    } label: {
                        Image(systemName: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 22, weight: .medium))
                            .frame(width: 22, height: 22)
                            .foregroundColor(.white)
                            .padding(14)
                            .background(.black.opacity(0.55))
                            .clipShape(Circle())
                    }
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
                if (dy > 0 && atStart) || (dy < 0 && (atEnd || isLocked)) {
                    dragOffset = dy * 0.12
                } else {
                    dragOffset = dy
                }
            }
            .onEnded { value in
                guard !isAnimating else { return }
                let dy = value.translation.height
                let threshold = screenHeight / 3

                if dy < -threshold {
                    if isLocked {
                        withAnimation(.easeInOut(duration: 0.2)) { showLoginPrompt = true }
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { dragOffset = 0 }
                    } else if viewModel.currentIndex < viewModel.urls.count - 1 {
                        isAnimating = true
                        withAnimation(.easeInOut(duration: 0.25)) { dragOffset = -screenHeight }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            viewModel.advance()
                            dragOffset = 0
                            isAnimating = false
                        }
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { dragOffset = 0 }
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
