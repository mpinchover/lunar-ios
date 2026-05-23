import SwiftUI

private let videoLimit = 20

struct VideoFeedView: View {
    @StateObject private var viewModel = VideoFeedViewModel()
    @State private var dragOffset: CGFloat = 0
    @State private var isAnimating = false
    @State private var isGrayscale = false
    @State private var showControls = true
    @State private var isLoggedIn = false
    @State private var showLoginPrompt = false
    @State private var showAccountView = false

    private var isLocked: Bool { !isLoggedIn && viewModel.currentIndex >= videoLimit - 1 }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                if viewModel.urls.isEmpty {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.5)
                } else {
                    videoStack(geo: geo)
                        .grayscale(isGrayscale ? 1.0 : 0.0)
                }

                controls.opacity(showControls ? 1 : 0)

                if showLoginPrompt {
                    LoginOverlayView(isLoggedIn: $isLoggedIn, isPresented: $showLoginPrompt)
                        .transition(.opacity)
                        .zIndex(1)
                }

                if showAccountView {
                    AccountOverlayView(isLoggedIn: $isLoggedIn, isPresented: $showAccountView)
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
        .statusBarHidden(true)
        .onAppear { viewModel.playCurrentVideo() }
        .onChange(of: viewModel.isLoadingMore) { _, isLoading in
            // If new videos arrive while the loading card is visible, snap back
            // immediately so the freshly added next video doesn't peek into frame.
            guard !isLoading, dragOffset < 0, isAnimating else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { dragOffset = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isAnimating = false }
        }
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

        // Loading card: anchored so its top edge sits at the screen bottom
        // when dragOffset == 0, and slides up as the user drags.
        // Offset formula: top_of_card = ZStack_center + offset - card_height/2 = screen_bottom
        //   => offset = h/2 + 0.15h = h * 0.65
        if viewModel.isAtLastLoaded {
            LoadingCardView()
                .frame(width: w, height: h * 0.3)
                .offset(y: h * 0.65 + dragOffset)
        }
    }

    private var controls: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isLoggedIn { showAccountView = true } else { showLoginPrompt = true }
                        }
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

                if dy > 0 && atStart {
                    dragOffset = dy * 0.12
                } else if dy < 0 && isLocked {
                    dragOffset = dy * 0.12
                } else if dy < 0 && viewModel.isAtLastLoaded {
                    // Clamp to 40% so the loading card peeks into view
                    dragOffset = max(-screenHeight * 0.4, dy)
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
                    } else if viewModel.isAtLastLoaded {
                        viewModel.fetchMore()
                        isAnimating = true
                        withAnimation(.easeOut(duration: 0.2)) { dragOffset = -screenHeight * 0.4 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { dragOffset = 0 }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { isAnimating = false }
                        }
                    } else if viewModel.currentIndex < viewModel.urls.count - 1 {
                        viewModel.seekToStart(at: viewModel.currentIndex + 1)
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
                    viewModel.seekToStart(at: viewModel.currentIndex - 1)
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
