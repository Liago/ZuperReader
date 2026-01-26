//
//  MediaGalleryView.swift
//  SuperReader
//
//  Created by Claude Code on 24/01/2026.
//

import SwiftUI

struct MediaItem: Identifiable, Equatable {
    let id = UUID()
    let url: String
    let type: MediaType

    enum MediaType {
        case image
        case video
    }
}

struct MediaGalleryView: View {
    let mediaItems: [MediaItem]
    let initialIndex: Int
    let onClose: () -> Void

    @State private var currentIndex: Int
    @State private var showThumbnails = true

    init(mediaItems: [MediaItem], initialIndex: Int = 0, onClose: @escaping () -> Void) {
        self.mediaItems = mediaItems
        self.initialIndex = initialIndex
        self.onClose = onClose
        _currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar with counter and close button
                HStack {
                    Text("\(currentIndex + 1) / \(mediaItems.count)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()

                    Spacer()

                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    }
                    .padding()
                }
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.6), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Spacer()

                // Main media viewer with swipe gesture
                TabView(selection: $currentIndex) {
                    ForEach(Array(mediaItems.enumerated()), id: \.element.id) { index, item in
                        ZoomableMediaItemView(mediaItem: item)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()

                Spacer()

                // Thumbnail navigation strip
                if showThumbnails && mediaItems.count > 1 {
                    thumbnailStrip
                        .transition(.move(edge: .bottom))
                }
            }

            // Toggle thumbnails button (only show if there are multiple items)
            if mediaItems.count > 1 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation {
                                showThumbnails.toggle()
                            }
                        }) {
                            Image(systemName: showThumbnails ? "photo.stack.fill" : "photo.stack")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .padding()
                                .background(Circle().fill(Color.black.opacity(0.6)))
                                .shadow(radius: 4)
                        }
                        .padding()
                        .padding(.bottom, showThumbnails ? 120 : 20)
                    }
                }
            }
        }
        .statusBar(hidden: true)
    }

    private var thumbnailStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(mediaItems.enumerated()), id: \.element.id) { index, item in
                        ThumbnailView(mediaItem: item, isSelected: index == currentIndex)
                            .id(index)
                            .onTapGesture {
                                withAnimation {
                                    currentIndex = index
                                }
                            }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .frame(height: 100)
            .background(
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .onChange(of: currentIndex) { _, newValue in
                withAnimation {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }
}

struct ZoomableMediaItemView: View {
    let mediaItem: MediaItem

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isLoading = true
    @State private var image: UIImage?

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if mediaItem.type == .video {
                    // Placeholder for video - can be enhanced later
                    VStack(spacing: 16) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                        Text("Video playback")
                            .foregroundColor(.white)
                        Text(mediaItem.url)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    // Image viewer with zoom
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    } else if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(magnificationGesture)
                            .gesture(dragGesture(in: geometry))
                            .onTapGesture(count: 2) {
                                withAnimation(.spring(response: 0.3)) {
                                    if scale > 1.0 {
                                        resetZoom()
                                    } else {
                                        scale = 2.0
                                        lastScale = 2.0
                                    }
                                }
                            }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "photo")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("Failed to load image")
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            if mediaItem.type == .image {
                loadImage()
            }
        }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / lastScale
                lastScale = value
                var newScale = scale * delta
                newScale = min(max(newScale, minScale), maxScale)
                scale = newScale
            }
            .onEnded { _ in
                lastScale = 1.0
                if scale < minScale {
                    withAnimation(.spring(response: 0.3)) {
                        resetZoom()
                    }
                }
            }
    }

    private func dragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1.0 {
                    let newOffset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                    offset = newOffset
                }
            }
            .onEnded { value in
                if scale > 1.0 {
                    let maxOffsetX = (geometry.size.width * (scale - 1)) / 2
                    let maxOffsetY = (geometry.size.height * (scale - 1)) / 2

                    var newOffset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )

                    newOffset.width = min(max(newOffset.width, -maxOffsetX), maxOffsetX)
                    newOffset.height = min(max(newOffset.height, -maxOffsetY), maxOffsetY)

                    withAnimation(.spring(response: 0.3)) {
                        offset = newOffset
                        lastOffset = newOffset
                    }
                }
            }
    }

    private func resetZoom() {
        scale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
    }

    private func loadImage() {
        guard let url = URL(string: mediaItem.url) else {
            isLoading = false
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                if let data = data, let loadedImage = UIImage(data: data) {
                    self.image = loadedImage
                }
                self.isLoading = false
            }
        }.resume()
    }
}

struct ThumbnailView: View {
    let mediaItem: MediaItem
    let isSelected: Bool

    @State private var thumbnailImage: UIImage?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            if mediaItem.type == .video {
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }
            } else {
                if isLoading {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if let thumbnailImage = thumbnailImage {
                    Image(uiImage: thumbnailImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .frame(width: 80, height: 80)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.white : Color.clear, lineWidth: 3)
        )
        .shadow(radius: 4)
        .onAppear {
            if mediaItem.type == .image {
                loadThumbnail()
            } else {
                isLoading = false
            }
        }
    }

    private func loadThumbnail() {
        guard let url = URL(string: mediaItem.url) else {
            isLoading = false
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                if let data = data, let loadedImage = UIImage(data: data) {
                    self.thumbnailImage = loadedImage
                }
                self.isLoading = false
            }
        }.resume()
    }
}

#Preview {
    MediaGalleryView(
        mediaItems: [
            MediaItem(url: "https://example.com/image1.jpg", type: .image),
            MediaItem(url: "https://example.com/image2.jpg", type: .image),
            MediaItem(url: "https://example.com/video.mp4", type: .video)
        ],
        initialIndex: 0,
        onClose: {}
    )
}
