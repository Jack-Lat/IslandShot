import SwiftUI
import PhotosUI

/// Загруженный скриншот: оригинал для экспорта, уменьшенная копия для превью.
struct Shot: Identifiable {
    let id = UUID()
    let original: UIImage
    let preview: UIImage
    let profile: DeviceProfile
    /// Фон статус-бара в зоне чёлки, найденный автоматически.
    let notchColor: UIColor
}

struct ContentView: View {
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var shots: [Shot] = []
    @State private var currentIndex = 0

    // Настройки запоминаются между запусками.
    @AppStorage("preset") private var presetRaw = IslandPreset.lock.rawValue
    @AppStorage("offsetY") private var offsetY: Double = 0
    @AppStorage("scale") private var scale: Double = 1
    @AppStorage("statusBarShift") private var statusBarShift: Double = Double(IslandMetrics.statusBarShift)
    @AppStorage("clearNotch") private var clearNotch = true

    @State private var values: [IslandPreset: PresetValues] = [:]
    @State private var customTint: Color = IslandColors.green
    @State private var customNotchColor: Color?
    @State private var zoomed = true

    @State private var isBusy = false
    @State private var message: StatusMessage?
    @State private var shareItem: ShareItem?

    private static let maxShots = 20

    private var preset: IslandPreset { IslandPreset(rawValue: presetRaw) ?? .lock }

    private var currentShot: Shot? {
        shots.indices.contains(currentIndex) ? shots[currentIndex] : nil
    }

    private func config(for shot: Shot) -> IslandConfig {
        IslandConfig(
            preset: preset,
            values: values[preset] ?? preset.defaultValues,
            offsetY: offsetY,
            scale: scale,
            statusBarShift: statusBarShift,
            tint: customTint,
            notchFill: clearNotch ? (customNotchColor ?? Color(uiColor: shot.notchColor)) : nil
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let shot = currentShot {
                    editor(shot)
                } else {
                    emptyState
                }
            }
            .navigationTitle("IslandShot")
            .toolbar {
                if !shots.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        picker { Image(systemName: "photo.badge.plus") }
                    }
                }
            }
            .onChange(of: pickerItems) { _, items in
                Task { await load(items) }
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(items: item.urls)
            }
        }
    }

    // MARK: - Экраны

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "iphone")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary)
            Text("Выбери скриншоты")
                .font(.title2.bold())
            Text("Подойдут скриншоты с iPhone X – 14 с чёлкой. Можно выбрать до \(Self.maxShots) штук сразу — оригиналы не изменятся.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            picker {
                Label("Выбрать из Фото", systemImage: "photo.on.rectangle.angled")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
            }
            .padding(.top, 8)
            if isBusy { ProgressView() }
            messageView
        }
        .padding(24)
        .padding(.top, 60)
    }

    private func editor(_ shot: Shot) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Вид", selection: $zoomed) {
                    Text("Крупно").tag(true)
                    Text("Целиком").tag(false)
                }
                .pickerStyle(.segmented)

                PreviewView(image: shot.preview, canvas: shot.profile.pointSize, config: config(for: shot), zoomed: zoomed)

                HStack(spacing: 6) {
                    Image(systemName: shot.profile.isKnown ? "iphone" : "questionmark.circle")
                    Text(shot.profile.isKnown ? shot.profile.name : "Устройство не распознано — подстрой положение вручную")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if shots.count > 1 { thumbnails }
            }

            section("Пресет") { presetGrid }

            if !preset.fields.isEmpty || preset == .custom {
                section("Текст") { fieldsView }
            }

            section("Зона чёлки") { notchView(shot) }

            section("Тонкая настройка") { tuningView }

            actions
            messageView
        }
        .padding()
    }

    // MARK: - Блоки

    private var thumbnails: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(shots.enumerated()), id: \.element.id) { index, item in
                    Button {
                        currentIndex = index
                    } label: {
                        Image(uiImage: item.preview)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 46, height: 100, alignment: .top)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(index == currentIndex ? Color.accentColor : Color.secondary.opacity(0.3),
                                            lineWidth: index == currentIndex ? 2.5 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
        }
    }

    private var presetGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], spacing: 8) {
            ForEach(IslandPreset.allCases) { item in
                let selected = item == preset
                Button {
                    presetRaw = item.rawValue
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: item.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .frame(height: 24)
                        Text(item.title)
                            .font(.caption2.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(selected ? Color.accentColor : Color.primary)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selected ? Color.accentColor.opacity(0.15) : Color(uiColor: .secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var fieldsView: some View {
        VStack(spacing: 8) {
            ForEach(preset.fields) { field in
                HStack {
                    Text(field.label)
                        .foregroundStyle(.secondary)
                    TextField(field.label, text: binding(for: field.key))
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            if preset == .custom {
                ColorPicker("Цвет", selection: $customTint, supportsOpacity: false)
                    .padding(12)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text("Названия символов — в приложении SF Symbols или на сайте sfsymbols.com, например heart.fill, bolt.fill, camera.fill.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func notchView(_ shot: Shot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Закрасить зону чёлки", isOn: $clearNotch)
            if clearNotch {
                ColorPicker(
                    "Цвет заливки",
                    selection: Binding(
                        get: { customNotchColor ?? Color(uiColor: shot.notchColor) },
                        set: { customNotchColor = $0 }
                    ),
                    supportsOpacity: false
                )
                if customNotchColor != nil {
                    Button("Определить цвет автоматически") { customNotchColor = nil }
                        .font(.subheadline)
                }
            }
            Text("Убирает полоски и индикаторы, которые приложения рисуют под чёлкой. Цвет берётся из фона статус-бара.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var tuningView: some View {
        VStack(alignment: .leading, spacing: 14) {
            slider("Сдвиг по вертикали", value: $offsetY, range: -8...24, step: 0.5,
                   display: String(format: "%+.1f pt", offsetY))
            slider("Размер", value: $scale, range: 0.85...1.2, step: 0.01,
                   display: "\(Int((scale * 100).rounded()))%")
            slider("Статус-бар вниз", value: $statusBarShift, range: 0...10, step: 0.5,
                   display: String(format: "%.1f pt", statusBarShift))
            Button("Сбросить") {
                offsetY = 0
                scale = 1
                statusBarShift = Double(IslandMetrics.statusBarShift)
            }
            .font(.subheadline)
            .disabled(offsetY == 0 && scale == 1 && statusBarShift == Double(IslandMetrics.statusBarShift))
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var actions: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    export(.save, all: false)
                } label: {
                    Label("Сохранить", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    export(.share, all: false)
                } label: {
                    Label("Поделиться", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            if shots.count > 1 {
                HStack(spacing: 12) {
                    Button {
                        export(.save, all: true)
                    } label: {
                        Label("Сохранить все (\(shots.count))", systemImage: "square.stack.3d.down.right")
                            .frame(maxWidth: .infinity)
                    }
                    Button {
                        export(.share, all: true)
                    } label: {
                        Label("Отправить все", systemImage: "square.and.arrow.up.on.square")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .controlSize(.large)
        .disabled(isBusy)
        .overlay {
            if isBusy { ProgressView() }
        }
    }

    @ViewBuilder
    private var messageView: some View {
        if let message {
            Label(message.text, systemImage: message.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(message.isError ? Color.red : Color.green)
        }
    }

    // MARK: - Помощники

    private func picker<PickerLabel: View>(@ViewBuilder label: () -> PickerLabel) -> some View {
        let content = label()
        return PhotosPicker(
            selection: $pickerItems,
            maxSelectionCount: Self.maxShots,
            matching: .images,
            preferredItemEncoding: .current
        ) {
            content
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>,
                        step: Double, display: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(display)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
        }
    }

    private func binding(for key: WritableKeyPath<PresetValues, String>) -> Binding<String> {
        Binding(
            get: { (values[preset] ?? preset.defaultValues)[keyPath: key] },
            set: { newValue in
                var current = values[preset] ?? preset.defaultValues
                current[keyPath: key] = newValue
                values[preset] = current
            }
        )
    }

    // MARK: - Действия

    private func load(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        isBusy = true
        message = nil
        defer { isBusy = false }

        var loaded: [Shot] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { continue }
            let profile = DeviceProfile.detect(for: CGSize(width: image.size.width * image.scale,
                                                           height: image.size.height * image.scale))
            loaded.append(Shot(
                original: image,
                preview: image.downsampled(toMaxWidth: 1000),
                profile: profile,
                notchColor: NotchCleaner.backgroundColor(of: image, profile: profile)
            ))
        }

        guard !loaded.isEmpty else {
            message = StatusMessage(text: "Не удалось открыть изображения. Попробуй другие.", isError: true)
            return
        }
        shots = loaded
        currentIndex = 0
        customNotchColor = nil
        if loaded.count < items.count {
            message = StatusMessage(text: "Открыто \(loaded.count) из \(items.count) изображений.", isError: true)
        }
    }

    private func export(_ action: ExportAction, all: Bool) {
        let targets = all ? shots : currentShot.map { [$0] } ?? []
        guard !targets.isEmpty else { return }
        isBusy = true
        message = nil
        let jobs = targets.map { (shot: $0, config: config(for: $0)) }
        Task {
            defer { isBusy = false }
            do {
                var files: [Data] = []
                for job in jobs {
                    files.append(try Exporter.renderPNG(image: job.shot.original, profile: job.shot.profile, config: job.config))
                }
                switch action {
                case .save:
                    for png in files {
                        try await Exporter.saveToPhotos(png)
                    }
                    message = StatusMessage(
                        text: files.count == 1 ? "Сохранено в Фото" : "Сохранено в Фото: \(files.count)",
                        isError: false
                    )
                case .share:
                    let urls = try files.enumerated().map { index, png in
                        try Exporter.temporaryFile(png, index: index)
                    }
                    shareItem = ShareItem(urls: urls)
                }
            } catch {
                message = StatusMessage(text: error.localizedDescription, isError: true)
            }
        }
    }
}

private enum ExportAction {
    case save, share
}

private struct StatusMessage {
    let text: String
    let isError: Bool
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let urls: [URL]
}
