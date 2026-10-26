import SwiftUI

/// Размеры Dynamic Island в поинтах (как на iPhone 14 Pro – 16 Pro).
enum IslandMetrics {
    static let width: CGFloat = 126
    static let height: CGFloat = 37.33
    static let top: CGFloat = 11.33
    /// Средняя часть компактного острова, где стоит камера: контент туда не заходит.
    static let cameraGap: CGFloat = 96
    static let compactInset: CGFloat = 12
    static let minimalGap: CGFloat = 6
    /// Насколько опустить статус-бар, чтобы время встало по центру острова.
    static let statusBarShift: CGFloat = 6
    /// Высота полосы со временем и значками (статус-бар с чёлкой — 44–48 pt, контент ниже не трогаем).
    static let statusBarBand: CGFloat = 40
}

/// Системные цвета iOS в тёмной теме.
enum IslandColors {
    static let green = Color(red: 0.19, green: 0.82, blue: 0.35)
    static let orange = Color(red: 1.0, green: 0.62, blue: 0.04)
    static let red = Color(red: 1.0, green: 0.27, blue: 0.23)
    static let pink = Color(red: 1.0, green: 0.22, blue: 0.37)
}

struct IslandView: View {
    let preset: IslandPreset
    let values: PresetValues
    let screenWidth: CGFloat

    private typealias M = IslandMetrics
    private typealias C = IslandColors

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .top)
            .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var content: some View {
        switch preset {
        case .plain:
            pill

        case .lock:
            compact {
                symbol("lock.fill", .white)
            } trailing: {
                EmptyView()
            }

        case .faceID:
            RoundedRectangle(cornerRadius: 42, style: .continuous)
                .fill(Color.black)
                .frame(width: 120, height: 120)
                .overlay {
                    Image(systemName: "faceid")
                        .font(.system(size: 54, weight: .light))
                        .foregroundStyle(.white)
                }

        case .charging:
            compact {
                islandText("Зарядка", .white)
            } trailing: {
                HStack(spacing: 4) {
                    islandText(values.primary, C.green)
                    symbol("battery.100.bolt", C.green)
                }
            }

        case .lowBattery:
            compact {
                symbol("battery.25", C.red)
            } trailing: {
                islandText(values.primary, C.red)
            }

        case .silent:
            compact {
                bellBadge("bell.slash.fill", C.red)
            } trailing: {
                islandText(values.primary, C.red)
            }

        case .ring:
            compact {
                bellBadge("bell.fill", Color(white: 0.35))
            } trailing: {
                islandText(values.primary, .white)
            }

        case .call:
            compact {
                symbol("phone.fill", C.green)
            } trailing: {
                islandText(values.primary, C.green)
            }

        case .incomingCall:
            expanded(height: 76) {
                HStack(spacing: 10) {
                    avatar
                    VStack(alignment: .leading, spacing: 1) {
                        Text(values.secondary)
                            .font(.system(size: 13))
                            .foregroundStyle(Color(white: 0.6))
                        Text(values.primary)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .lineLimit(1)
                    Spacer(minLength: 8)
                    callButton("phone.down.fill", C.red)
                    callButton("phone.fill", C.green)
                }
                .padding(.horizontal, 14)
            }

        case .timer:
            compact {
                symbol("timer", C.orange)
            } trailing: {
                islandText(values.primary, C.orange)
            }

        case .timerMinimal:
            pill.overlay(alignment: .trailing) {
                Circle()
                    .fill(Color.black)
                    .frame(width: M.height, height: M.height)
                    .overlay { symbol("timer", C.orange, size: 16) }
                    .offset(x: M.height + M.minimalGap)
            }

        case .music:
            compact {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LinearGradient(colors: [C.pink, C.orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 22, height: 22)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
            } trailing: {
                symbol("waveform", C.pink, size: 16)
            }

        case .airpods:
            compact {
                symbol("airpodspro", .white, size: 17)
            } trailing: {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.2), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: percent)
                        .stroke(C.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 19, height: 19)
            }
        }
    }

    // MARK: - Формы

    private var pill: some View {
        Capsule(style: .continuous)
            .fill(Color.black)
            .frame(width: M.width, height: M.height)
    }

    /// Компактный остров: контент слева и справа от камеры.
    /// Обе стороны одной ширины, чтобы камера оставалась строго по центру.
    private func compact<L: View, T: View>(
        @ViewBuilder leading: () -> L,
        @ViewBuilder trailing: () -> T
    ) -> some View {
        let l = leading()
        let t = trailing()
        return HStack(spacing: 0) {
            ZStack(alignment: .leading) { l; t.hidden() }
            Color.clear.frame(width: M.cameraGap)
            ZStack(alignment: .trailing) { t; l.hidden() }
        }
        .padding(.horizontal, M.compactInset)
        .frame(height: M.height)
        .frame(minWidth: M.width)
        .background(Capsule(style: .continuous).fill(Color.black))
    }

    private func expanded<Content: View>(height: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: min(screenWidth - 22, 371), height: height)
            .background(
                RoundedRectangle(cornerRadius: min(height / 2, 44), style: .continuous)
                    .fill(Color.black)
            )
    }

    // MARK: - Элементы

    private func islandText(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize()
    }

    private func symbol(_ name: String, _ color: Color, size: CGFloat = 15) -> some View {
        Image(systemName: name)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(color)
    }

    private func bellBadge(_ name: String, _ color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 22)
            .background(Capsule(style: .continuous).fill(color))
    }

    private var avatar: some View {
        Circle()
            .fill(LinearGradient(colors: [Color(white: 0.62), Color(white: 0.42)], startPoint: .top, endPoint: .bottom))
            .frame(width: 46, height: 46)
            .overlay {
                Text(values.primary.first.map { String($0).uppercased() } ?? "?")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }

    private func callButton(_ name: String, _ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 44, height: 44)
            .overlay {
                Image(systemName: name)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }

    private var percent: CGFloat {
        let number = Double(values.primary.filter(\.isNumber)) ?? 80
        return CGFloat(min(max(number / 100, 0), 1))
    }
}

/// Скриншот + остров в координатах экрана (поинтах).
/// Один и тот же вид используется и для превью, и для экспорта в полном разрешении.
struct CompositeView: View {
    let image: UIImage
    let canvas: CGSize
    let config: IslandConfig

    var body: some View {
        ZStack(alignment: .top) {
            screenshot

            if config.statusBarShift > 0 {
                // Полоса статус-бара, опущенная вниз.
                screenshot
                    .frame(width: canvas.width, height: IslandMetrics.statusBarBand, alignment: .top)
                    .clipped()
                    .offset(y: config.statusBarShift)

                // Освободившуюся полоску сверху заполняем растянутой верхней строкой пикселей.
                screenshot
                    .frame(width: canvas.width, height: 1, alignment: .top)
                    .clipped()
                    .scaleEffect(x: 1, y: config.statusBarShift + 0.5, anchor: .top)
            }

            IslandView(preset: config.preset, values: config.values, screenWidth: canvas.width)
                .scaleEffect(config.scale, anchor: .top)
                .padding(.top, IslandMetrics.top + config.offsetY)
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .top)
        .clipped()
    }

    private var screenshot: some View {
        Image(uiImage: image)
            .resizable()
            .interpolation(.high)
            .frame(width: canvas.width, height: canvas.height)
    }
}

/// Превью: весь скриншот или увеличенный верх экрана.
struct PreviewView: View {
    let image: UIImage
    let canvas: CGSize
    let config: IslandConfig
    let zoomed: Bool

    private var visibleRect: CGRect {
        guard zoomed else { return CGRect(origin: .zero, size: canvas) }
        let width = canvas.width * 0.8
        return CGRect(x: canvas.width * 0.1, y: 0, width: width, height: width * 0.5)
    }

    var body: some View {
        let rect = visibleRect
        Color.clear
            .aspectRatio(rect.width / rect.height, contentMode: .fit)
            .overlay(alignment: .topLeading) {
                GeometryReader { geo in
                    let s = geo.size.width / rect.width
                    CompositeView(image: image, canvas: canvas, config: config)
                        .scaleEffect(s, anchor: .topLeading)
                        .offset(x: -rect.minX * s, y: -rect.minY * s)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.secondary.opacity(0.25))
            )
    }
}
