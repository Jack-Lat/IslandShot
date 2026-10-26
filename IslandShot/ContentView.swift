import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var pickerItem: PhotosPickerItem?
    @State private var original: UIImage?
    @State private var preview: UIImage?
    @State private var profile: DeviceProfile?

    @State private var preset: IslandPreset = .lock
    @State private var values: [IslandPreset: PresetValues] = [:]
    @State private var offsetY: Double = 0
    @State private var scale: Double = 1
    @State private var statusBarShift: Double = IslandMetrics.statusBarShift
    @State private var zoomed = true

    @State private var isBusy = false
    @State private var message: StatusMessage?
    @State private var shareItem: ShareItem?

    private var config: IslandConfig {
        IslandConfig(
            preset: preset,
            values: values[preset] ?? preset.defaultValues,
            offsetY: offsetY,
            scale: scale,
            statusBarShift: statusBarShift
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let preview, let profile {
                    editor(preview: preview, profile: profile)
                } else {
                    emptyState
                }
            }
            .navigationTitle("IslandShot")
            .toolbar {
                if original != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        PhotosPicker(selection: $pickerItem, matching: .images, preferredItemEncoding: .current) {
                            Image(systemName: "photo.badge.plus")
                        }
                    }
                }
            }
            .onChange(of: pickerItem) { _, item in
                Task { await load(item) }
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(items: [item.url])
            }
        }
    }

    // MARK: - Экраны

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "iphone")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary)
            Text("Выбери скриншот")
                .font(.title2.bold())
            Text("Подойдут скриншоты с iPhone X – 14 с чёлкой. Остров добавится в статус-бар, оригинал не изменится.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            PhotosPicker(selection: $pickerItem, matching: .images, preferredItemEncoding: .current) {
                Label("Выбрать из Фото", systemImage: "photo.on.rectangle.angled")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
            }
            .padding(.top, 8)
            messageView
        }
        .padding(24)
        .padding(.top, 60)
    }

    private func editor(preview: UIImage, profile: DeviceProfile) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Вид", selection: $zoomed) {
                    Text("Крупно").tag(true)
                    Text("Целиком").tag(false)
                }
                .pickerStyle(.segmented)

                PreviewView(image: preview, canvas: profile.pointSize, config: config, zoomed: zoomed)

                HStack(spacing: 6) {
                    Image(systemName: profile.isKnown ? "iphone" : "questionmark.circle")
                    Text(profile.isKnown ? profile.name : "Устройство не распознано — подстрой положение вручную")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            section("Пресет") { presetGrid }

            if !preset.fields.isEmpty {
                section("Текст") { fieldsView }
            }

            section("Тонкая настройка") { tuningView }

            actions
            messageView
        }
        .padding()
    }

    // MARK: - Блоки

    private var presetGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], spacing: 8) {
            ForEach(IslandPreset.allCases) { item in
                let selected = item == preset
                Button {
                    preset = item
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
                }
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
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
                statusBarShift = IslandMetrics.statusBarShift
            }
            .font(.subheadline)
            .disabled(offsetY == 0 && scale == 1 && statusBarShift == IslandMetrics.statusBarShift)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                export(.save)
            } label: {
                Label("Сохранить", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                export(.share)
            } label: {
                Label("Поделиться", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
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

    private func load(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        message = nil
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            message = StatusMessage(text: "Не удалось открыть изображение. Попробуй другое.", isError: true)
            return
        }
        original = image
        preview = image.downsampled(toMaxWidth: 1000)
        profile = DeviceProfile.detect(for: CGSize(width: image.size.width * image.scale,
                                                   height: image.size.height * image.scale))
    }

    private func export(_ action: ExportAction) {
        guard let original, let profile else { return }
        isBusy = true
        message = nil
        let snapshot = self.config
        Task {
            defer { isBusy = false }
            do {
                let png = try Exporter.renderPNG(image: original, profile: profile, config: snapshot)
                switch action {
                case .save:
                    try await Exporter.saveToPhotos(png)
                    message = StatusMessage(text: "Сохранено в Фото", isError: false)
                case .share:
                    shareItem = ShareItem(url: try Exporter.temporaryFile(png))
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
    let url: URL
}
