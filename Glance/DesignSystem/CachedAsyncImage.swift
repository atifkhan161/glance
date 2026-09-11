import SwiftUI

// MARK: - Image Cache

actor ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSString, UIImage>()
    private let maxMemoryCost: Int = 50 * 1_024 * 1_024 // 50 MB

    init() {
        cache.totalCostLimit = maxMemoryCost
        cache.countLimit = 200
    }

    func get(_ url: URL) -> UIImage? {
        cache.object(forKey: url.absoluteString as NSString)
    }

    func set(_ image: UIImage, for url: URL) {
        let cost = Int(image.size.width * image.size.height * image.scale * 4)
        cache.setObject(image, forKey: url.absoluteString as NSString, cost: cost)
    }

    func clear() {
        cache.removeAllObjects()
    }
}

// MARK: - Cached Async Image

struct CachedAsyncImage<Placeholder: View, Content: View>: View {
    private let url: URL?
    @ViewBuilder private let content: (Image) -> Content
    @ViewBuilder private let placeholder: () -> Placeholder

    @State private var loadedImage: UIImage?
    @State private var isLoading = false

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let uiImage = loadedImage {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
                    .task {
                        await loadImage()
                    }
            }
        }
    }

    private func loadImage() async {
        guard let url, !isLoading else { return }
        isLoading = true

        // Check cache first
        if let cached = await ImageCache.shared.get(url) {
            loadedImage = cached
            isLoading = false
            return
        }

        // Download
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let uiImage = UIImage(data: data) else { return }
            await ImageCache.shared.set(uiImage, for: url)
            loadedImage = uiImage
        } catch {
            // Silent fail — placeholder stays visible
        }
    }
}

// MARK: - Shimmer placeholder

struct ShimmerPlaceholder: View {
    var body: some View {
        Rectangle()
            .fill(Theme.Colors.surface2)
            .shimmer()
    }
}

// MARK: - Cached image with shimmer placeholder

struct CachedShimmerImage: View {
    let url: URL?
    var contentMode: ContentMode = .fit

    var body: some View {
        CachedAsyncImage(url: url) { image in
            image.resizable().aspectRatio(contentMode: contentMode)
        } placeholder: {
            ShimmerPlaceholder()
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CachedShimmerImage(url: URL(string: "https://via.placeholder.com/100"))
            .frame(width: 100, height: 100)
            .clipShape(.circle)

        Text("Image cache with shimmer loading")
            .font(Theme.Fonts.manrope(14))
            .foregroundStyle(Theme.Colors.textMuted)
    }
    .padding()
    .background(Theme.canvas)
}
