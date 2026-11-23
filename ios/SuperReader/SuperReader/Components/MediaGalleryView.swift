//
//  MediaGalleryView.swift
//  SuperReader
//
//  Full-screen image gallery. Paging and zoom are UIKit-backed
//  (UIPageViewController + one UIScrollView per page), which gives the same
//  fluid swipe / pinch / double-tap behaviour as Photos: a zoomed image pans
//  inside its page and only hands the gesture to the pager at its edges.
//

import SwiftUI
import UIKit
import ImageIO

struct MediaItem: Identifiable, Equatable {
    let id = UUID()
    let url: String
    let type: MediaType

    enum MediaType {
        case image
        case video
    }
}

// MARK: - Gallery

struct MediaGalleryView: View {
    let mediaItems: [MediaItem]
    let initialIndex: Int
    let onClose: () -> Void

    @State private var currentIndex: Int
    @State private var chromeVisible = true

    init(mediaItems: [MediaItem], initialIndex: Int = 0, onClose: @escaping () -> Void) {
        self.mediaItems = mediaItems
        self.initialIndex = initialIndex
        self.onClose = onClose
        let safeIndex = mediaItems.isEmpty ? 0 : min(max(initialIndex, 0), mediaItems.count - 1)
        _currentIndex = State(initialValue: safeIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if mediaItems.isEmpty {
                Text("No images")
                    .foregroundColor(.gray)
            } else {
                GalleryPager(
                    items: mediaItems,
                    currentIndex: $currentIndex,
                    onSingleTap: {
                        withAnimation(.easeInOut(duration: 0.2)) { chromeVisible.toggle() }
                    }
                )
                .ignoresSafeArea()
            }

            if chromeVisible {
                VStack(spacing: 0) {
                    topBar
                    Spacer()
                    if mediaItems.count > 1 {
                        thumbnailStrip
                    }
                }
                .transition(.opacity)
            }
        }
        .statusBar(hidden: true)
        .onAppear { GalleryImageLoader.shared.prefetch(urls(around: currentIndex)) }
        .onChange(of: currentIndex) { _, newValue in
            GalleryImageLoader.shared.prefetch(urls(around: newValue))
        }
    }

    private func urls(around index: Int) -> [String] {
        [index - 1, index + 1, index + 2]
            .filter { mediaItems.indices.contains($0) && mediaItems[$0].type == .image }
            .map { mediaItems[$0].url }
    }

    private var topBar: some View {
        HStack {
            if mediaItems.count > 1 {
                Text("\(currentIndex + 1) / \(mediaItems.count)")
                    .font(.headline.monospacedDigit())
                    .foregroundColor(.white)
                    .padding()
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                    .shadow(radius: 4)
            }
            .accessibilityLabel("Close")
            .padding()
        }
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.6), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var thumbnailStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(Array(mediaItems.enumerated()), id: \.element.id) { index, item in
                        ThumbnailView(mediaItem: item, isSelected: index == currentIndex)
                            .id(index)
                            .onTapGesture { currentIndex = index }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .frame(height: 88)
            .background(
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .onAppear { proxy.scrollTo(currentIndex, anchor: .center) }
            .onChange(of: currentIndex) { _, newValue in
                withAnimation { proxy.scrollTo(newValue, anchor: .center) }
            }
        }
    }
}

// MARK: - Pager (UIPageViewController)

private struct GalleryPager: UIViewControllerRepresentable {
    let items: [MediaItem]
    @Binding var currentIndex: Int
    let onSingleTap: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pager = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: [.interPageSpacing: 20]
        )
        pager.view.backgroundColor = .black
        pager.dataSource = context.coordinator
        pager.delegate = context.coordinator
        if let first = context.coordinator.page(at: currentIndex) {
            pager.setViewControllers([first], direction: .forward, animated: false)
        }
        return pager
    }

    func updateUIViewController(_ pager: UIPageViewController, context: Context) {
        context.coordinator.parent = self
        // Thumbnail taps change the binding: move the pager to match.
        guard let visible = pager.viewControllers?.first as? GalleryPageViewController,
              visible.index != currentIndex,
              let target = context.coordinator.page(at: currentIndex) else { return }
        let direction: UIPageViewController.NavigationDirection = currentIndex > visible.index ? .forward : .reverse
        let jump = abs(currentIndex - visible.index) > 1
        pager.setViewControllers([target], direction: direction, animated: !jump)
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: GalleryPager

        init(_ parent: GalleryPager) { self.parent = parent }

        func page(at index: Int) -> GalleryPageViewController? {
            guard parent.items.indices.contains(index) else { return nil }
            let page = GalleryPageViewController(item: parent.items[index], index: index)
            page.onSingleTap = { [weak self] in self?.parent.onSingleTap() }
            return page
        }

        func pageViewController(_ pageViewController: UIPageViewController,
                                viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let page = viewController as? GalleryPageViewController else { return nil }
            return self.page(at: page.index - 1)
        }

        func pageViewController(_ pageViewController: UIPageViewController,
                                viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let page = viewController as? GalleryPageViewController else { return nil }
            return self.page(at: page.index + 1)
        }

        func pageViewController(_ pageViewController: UIPageViewController,
                                didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController],
                                transitionCompleted completed: Bool) {
            guard completed,
                  let visible = pageViewController.viewControllers?.first as? GalleryPageViewController else { return }
            if parent.currentIndex != visible.index {
                parent.currentIndex = visible.index
            }
            // Leaving a page resets its zoom, like Photos.
            previousViewControllers
                .compactMap { $0 as? GalleryPageViewController }
                .forEach { $0.resetZoom(animated: false) }
        }
    }
}

// MARK: - Single page (zoomable image)

final class GalleryPageViewController: UIViewController, UIScrollViewDelegate {
    let item: MediaItem
    let index: Int
    var onSingleTap: (() -> Void)?

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let spinner = UIActivityIndicatorView(style: .large)
    private let errorStack = UIStackView()
    private var loadTask: Task<Void, Never>?
    private var lastLayoutSize: CGSize = .zero

    init(item: MediaItem, index: Int) {
        self.item = item
        self.index = index
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { loadTask?.cancel() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.decelerationRate = .fast
        view.addSubview(scrollView)

        imageView.contentMode = .scaleAspectFit
        imageView.isAccessibilityElement = true
        imageView.accessibilityTraits = .image
        scrollView.addSubview(imageView)

        spinner.color = .white
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)

        setupErrorView()

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
        ])

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        singleTap.require(toFail: doubleTap)
        scrollView.addGestureRecognizer(singleTap)

        if item.type == .image {
            load()
        } else {
            showError(message: "Video not supported in the gallery", retry: false)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Re-fit on rotation / first layout.
        if view.bounds.size != lastLayoutSize {
            lastLayoutSize = view.bounds.size
            layoutImage()
        }
    }

    private func setupErrorView() {
        errorStack.axis = .vertical
        errorStack.alignment = .center
        errorStack.spacing = 12
        errorStack.translatesAutoresizingMaskIntoConstraints = false
        errorStack.isHidden = true
        view.addSubview(errorStack)
    }

    private func showError(message: String, retry: Bool) {
        errorStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let icon = UIImageView(image: UIImage(systemName: "photo"))
        icon.tintColor = .gray
        icon.preferredSymbolConfiguration = .init(pointSize: 44)
        errorStack.addArrangedSubview(icon)

        let label = UILabel()
        label.text = message
        label.textColor = .gray
        label.numberOfLines = 0
        label.textAlignment = .center
        errorStack.addArrangedSubview(label)

        if retry {
            var config = UIButton.Configuration.tinted()
            config.title = "Retry"
            config.baseForegroundColor = .white
            config.baseBackgroundColor = .white
            let button = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
                self?.load()
            })
            errorStack.addArrangedSubview(button)
        }
        errorStack.isHidden = false
    }

    private func load() {
        errorStack.isHidden = true
        if let cached = GalleryImageLoader.shared.cachedImage(for: item.url) {
            display(cached)
            return
        }
        spinner.startAnimating()
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            let image = await GalleryImageLoader.shared.image(for: self.item.url)
            guard !Task.isCancelled else { return }
            self.spinner.stopAnimating()
            if let image {
                self.display(image)
            } else {
                self.showError(message: "Failed to load image", retry: true)
            }
        }
    }

    private func display(_ image: UIImage) {
        imageView.image = image
        imageView.alpha = 0
        layoutImage()
        UIView.animate(withDuration: 0.15) { self.imageView.alpha = 1 }
    }

    /// Sizes the image view to aspect-fit the page and centers it.
    private func layoutImage() {
        guard let image = imageView.image, image.size.width > 0, image.size.height > 0 else { return }
        let bounds = scrollView.bounds.size
        guard bounds.width > 0, bounds.height > 0 else { return }

        scrollView.zoomScale = 1
        let ratio = min(bounds.width / image.size.width, bounds.height / image.size.height)
        let fitted = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        imageView.frame = CGRect(origin: .zero, size: fitted)
        scrollView.contentSize = fitted

        // Let small images be zoomed at least up to their native pixel size (and never less than 3x).
        let nativeScale = (image.size.width * image.scale) / max(fitted.width * UIScreen.main.scale, 1)
        scrollView.maximumZoomScale = max(3, min(nativeScale, 8))
        centerImage()
    }

    private func centerImage() {
        let bounds = scrollView.bounds.size
        let content = scrollView.contentSize
        let insetX = max((bounds.width - content.width) / 2, 0)
        let insetY = max((bounds.height - content.height) / 2, 0)
        scrollView.contentInset = UIEdgeInsets(top: insetY, left: insetX, bottom: insetY, right: insetX)
    }

    func resetZoom(animated: Bool) {
        guard isViewLoaded, scrollView.zoomScale != 1 else { return }
        scrollView.setZoomScale(1, animated: animated)
    }

    @objc private func handleSingleTap() {
        onSingleTap?()
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard imageView.image != nil else { return }
        if scrollView.zoomScale > scrollView.minimumZoomScale + 0.01 {
            scrollView.setZoomScale(1, animated: true)
        } else {
            // Zoom into the tapped point.
            let point = gesture.location(in: imageView)
            let targetScale = min(2.5, scrollView.maximumZoomScale)
            let size = CGSize(width: scrollView.bounds.width / targetScale,
                              height: scrollView.bounds.height / targetScale)
            let rect = CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
                              width: size.width, height: size.height)
            scrollView.zoom(to: rect, animated: true)
        }
    }

    // MARK: UIScrollViewDelegate

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    func scrollViewDidZoom(_ scrollView: UIScrollView) { centerImage() }
}

// MARK: - Image loading

/// Loads gallery images with an in-memory cache, request de-duplication and
/// downsampling (very large article images decode slowly and can blow memory).
@MainActor
final class GalleryImageLoader {
    static let shared = GalleryImageLoader()

    private let cache = NSCache<NSString, UIImage>()
    private var inFlight: [String: Task<UIImage?, Never>] = [:]
    private let session: URLSession

    private init() {
        cache.countLimit = 60
        cache.totalCostLimit = 200 * 1024 * 1024
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(memoryCapacity: 20 * 1024 * 1024, diskCapacity: 150 * 1024 * 1024)
        config.timeoutIntervalForRequest = 20
        session = URLSession(configuration: config)
    }

    /// Cleans up URLs as they appear in article HTML: entity-encoded `&amp;`,
    /// protocol-relative `//cdn…`, and plain `http://` (blocked by ATS → upgraded).
    nonisolated static func normalizedURLs(for raw: String) -> [URL] {
        var string = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#038;", with: "&")
            .replacingOccurrences(of: "&#38;", with: "&")
        if string.hasPrefix("//") { string = "https:" + string }
        if string.hasPrefix("http://") { string = "https://" + string.dropFirst("http://".count) }

        let url = URL(string: string)
            ?? string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed).flatMap(URL.init(string:))
        return url.map { [$0] } ?? []
    }

    func cachedImage(for raw: String) -> UIImage? {
        cache.object(forKey: raw as NSString)
    }

    func prefetch(_ raws: [String]) {
        for raw in raws where cachedImage(for: raw) == nil && inFlight[raw] == nil {
            Task { _ = await image(for: raw) }
        }
    }

    func image(for raw: String) async -> UIImage? {
        if let cached = cachedImage(for: raw) { return cached }
        if let running = inFlight[raw] { return await running.value }

        let session = self.session
        let task = Task<UIImage?, Never>.detached(priority: .userInitiated) {
            for url in Self.normalizedURLs(for: raw) {
                if let image = await Self.fetch(url, session: session) { return image }
            }
            return nil
        }
        inFlight[raw] = task
        let image = await task.value
        inFlight[raw] = nil
        if let image {
            let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
            cache.setObject(image, forKey: raw as NSString, cost: cost)
        }
        return image
    }

    nonisolated private static func fetch(_ url: URL, session: URLSession) async -> UIImage? {
        if url.scheme == "data" {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return decode(data)
        }
        var request = URLRequest(url: url)
        // Some CDNs reject requests without a browser UA / with an unknown Referer.
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
                         forHTTPHeaderField: "User-Agent")
        request.setValue("image/avif,image/webp,image/png,image/jpeg,image/*;q=0.8,*/*;q=0.5", forHTTPHeaderField: "Accept")
        if let scheme = url.scheme, let host = url.host {
            request.setValue("\(scheme)://\(host)/", forHTTPHeaderField: "Referer")
        }
        guard let (data, response) = try? await session.data(for: request) else { return nil }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { return nil }
        return decode(data)
    }

    /// Downsamples to at most 4096 px on the long side (sharp even at 3x zoom on
    /// any iPhone/iPad) and decodes off the main thread.
    nonisolated private static func decode(_ data: Data) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        if let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) {
            let options = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: 4096,
            ] as CFDictionary
            if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) {
                return UIImage(cgImage: cgImage)
            }
        }
        return UIImage(data: data)?.preparingForDisplay()
    }
}

// MARK: - Thumbnail

struct ThumbnailView: View {
    let mediaItem: MediaItem
    let isSelected: Bool

    @State private var thumbnailImage: UIImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            Rectangle().fill(Color.gray.opacity(0.3))

            if mediaItem.type == .video {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.white)
            } else if let thumbnailImage {
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if failed {
                Image(systemName: "photo")
                    .foregroundColor(.gray)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2.5)
        )
        .opacity(isSelected ? 1 : 0.7)
        .task(id: mediaItem.url) {
            guard mediaItem.type == .image, thumbnailImage == nil else { return }
            if let image = await GalleryImageLoader.shared.image(for: mediaItem.url) {
                thumbnailImage = image
            } else {
                failed = true
            }
        }
    }
}

#Preview {
    MediaGalleryView(
        mediaItems: [
            MediaItem(url: "https://picsum.photos/id/10/2000/1400", type: .image),
            MediaItem(url: "https://picsum.photos/id/20/1200/1800", type: .image),
            MediaItem(url: "https://example.com/missing.jpg", type: .image)
        ],
        initialIndex: 0,
        onClose: {}
    )
}
