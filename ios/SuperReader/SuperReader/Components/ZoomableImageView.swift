//
//  ZoomableImageView.swift
//  SuperReader
//
//  Created by Claude Code on 24/01/2026.
//

import SwiftUI

struct ZoomableImageView: View {
    let imageUrl: String
    let onClose: () -> Void

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
                Color.black.ignoresSafeArea()

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

                VStack {
                    HStack {
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .shadow(radius: 4)
                        }
                        .padding()
                    }
                    Spacer()
                }
            }
        }
        .onAppear {
            loadImage()
        }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / lastScale
                lastScale = value
                var newScale = scale * delta

                // Limit scale
                newScale = min(max(newScale, minScale), maxScale)
                scale = newScale
            }
            .onEnded { _ in
                lastScale = 1.0

                // Reset if zoomed out beyond minimum
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
                // Only allow panning when zoomed in
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
                    // Calculate boundaries to prevent panning too far
                    let maxOffsetX = (geometry.size.width * (scale - 1)) / 2
                    let maxOffsetY = (geometry.size.height * (scale - 1)) / 2

                    var newOffset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )

                    // Clamp offset to boundaries
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
        guard let url = URL(string: imageUrl) else {
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

#Preview {
    ZoomableImageView(
        imageUrl: "https://example.com/image.jpg",
        onClose: {}
    )
}
