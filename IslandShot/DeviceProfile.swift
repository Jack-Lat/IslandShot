import CoreGraphics

/// Геометрия экрана, с которого сделан скриншот.
/// Остров задаётся в поинтах, поэтому важно знать, сколько пикселей в одном поинте.
struct DeviceProfile: Equatable {
    let name: String
    let pointSize: CGSize
    let scale: CGFloat
    let isKnown: Bool

    static func detect(for pixelSize: CGSize) -> DeviceProfile {
        let w = Int(pixelSize.width.rounded())
        let h = Int(pixelSize.height.rounded())

        if let model = models.first(where: { $0.w == w && $0.h == h }) {
            let scale = pixelSize.width / model.pointWidth
            return DeviceProfile(
                name: model.name,
                pointSize: CGSize(width: model.pointWidth, height: pixelSize.height / scale),
                scale: scale,
                isKnown: true
            )
        }

        // Неизвестный размер (например, сжатый мессенджером): считаем, что ширина экрана 390 pt.
        let scale = max(pixelSize.width / 390, 0.1)
        return DeviceProfile(
            name: "Неизвестное устройство",
            pointSize: CGSize(width: 390, height: pixelSize.height / scale),
            scale: scale,
            isKnown: false
        )
    }

    private static let models: [(w: Int, h: Int, pointWidth: CGFloat, name: String)] = [
        (1125, 2436, 375, "iPhone X / XS / 11 Pro"),
        (1242, 2688, 414, "iPhone XS Max / 11 Pro Max"),
        (828, 1792, 414, "iPhone XR / 11"),
        (1080, 2340, 375, "iPhone 12 mini / 13 mini"),
        (1170, 2532, 390, "iPhone 12 / 12 Pro / 13 / 13 Pro / 14 / 16e"),
        (1284, 2778, 428, "iPhone 12 Pro Max / 13 Pro Max / 14 Plus"),
    ]
}
