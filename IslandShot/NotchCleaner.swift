import UIKit

/// Зона между временем и значками, где на айфонах с чёлкой была чёлка.
/// Приложения иногда рисуют там полоски и индикаторы, которые торчат из-под острова.
enum NotchCleaner {
    /// Доля ширины экрана, которую занимает зона чёлки.
    static let zoneWidthFraction: CGFloat = 0.52

    /// Самый частый цвет в зоне чёлки — обычно это фон статус-бара.
    static func backgroundColor(of image: UIImage, profile: DeviceProfile) -> UIColor {
        guard let cgImage = image.cgImage else { return .black }
        let zoneWidth = CGFloat(cgImage.width) * zoneWidthFraction
        let zoneHeight = IslandMetrics.statusBarBand * profile.scale
        let zone = CGRect(x: (CGFloat(cgImage.width) - zoneWidth) / 2, y: 0,
                          width: zoneWidth, height: zoneHeight).integral
        guard let crop = cgImage.cropping(to: zone) else { return .black }

        let width = 64, height = 16
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else { return false }
            context.interpolationQuality = .none
            context.draw(crop, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return .black }

        var buckets: [Int: Bucket] = [:]
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let r = Int(pixels[i]), g = Int(pixels[i + 1]), b = Int(pixels[i + 2])
            let key = (r >> 4) << 8 | (g >> 4) << 4 | (b >> 4)
            buckets[key, default: Bucket()].add(r, g, b)
        }
        guard let best = buckets.values.max(by: { $0.count < $1.count }) else { return .black }
        let n = CGFloat(best.count) * 255
        return UIColor(red: CGFloat(best.r) / n, green: CGFloat(best.g) / n, blue: CGFloat(best.b) / n, alpha: 1)
    }

    private struct Bucket {
        var count = 0, r = 0, g = 0, b = 0

        mutating func add(_ r: Int, _ g: Int, _ b: Int) {
            count += 1
            self.r += r
            self.g += g
            self.b += b
        }
    }
}
