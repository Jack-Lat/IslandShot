import SwiftUI
import Photos

enum ExportError: LocalizedError {
    case renderFailed
    case noAccess

    var errorDescription: String? {
        switch self {
        case .renderFailed: "Не удалось отрисовать изображение."
        case .noAccess: "Разреши IslandShot добавлять фото: Настройки → Конфиденциальность → Фото."
        }
    }
}

@MainActor
enum Exporter {
    /// Рендерит скриншот с островом в исходном разрешении и возвращает PNG.
    static func renderPNG(image: UIImage, profile: DeviceProfile, config: IslandConfig) throws -> Data {
        let renderer = ImageRenderer(
            content: CompositeView(image: image, canvas: profile.pointSize, config: config)
        )
        renderer.scale = profile.scale
        renderer.isOpaque = true
        guard let data = renderer.uiImage?.pngData() else { throw ExportError.renderFailed }
        return data
    }

    static func saveToPhotos(_ png: Data) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw ExportError.noAccess }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .photo, data: png, options: nil)
        }
    }

    static func temporaryFile(_ png: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("IslandShot-\(Int(Date().timeIntervalSince1970)).png")
        try png.write(to: url, options: .atomic)
        return url
    }
}

extension UIImage {
    /// Уменьшенная копия для быстрого превью.
    func downsampled(toMaxWidth maxWidth: CGFloat) -> UIImage {
        let pixelWidth = size.width * scale
        guard pixelWidth > maxWidth else { return self }
        let ratio = maxWidth / pixelWidth
        let target = CGSize(width: size.width * scale * ratio, height: size.height * scale * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
