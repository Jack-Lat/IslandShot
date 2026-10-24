import SwiftUI
import PhotosUI
import Photos

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var sourceImage: UIImage?
    @State private var islandWidth: Double = 0.325
    @State private var islandHeight: Double = 0.043
    @State private var islandTop: Double = 0.068
    @State private var showSaved = false
    @State private var errorMessage: String?

    private var processedImage: UIImage? {
        guard let sourceImage else { return nil }
        return IslandRenderer.render(
            sourceImage,
            widthFraction: islandWidth,
            heightFraction: islandHeight,
            topFraction: islandTop
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("IslandShot")
                            .font(.largeTitle.bold())
                        Text("Добавь Dynamic Island к скриншоту в пару нажатий.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label(sourceImage == nil ? "Выбрать скриншот" : "Выбрать другой скриншот",
                              systemImage: "photo.on.rectangle.angled")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue, in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(.white)
                    }

                    if let image = processedImage {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Предпросмотр").font(.headline)
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.secondary.opacity(0.25)))
                            Text("Настройка положения")
                                .font(.headline)
                            settingSlider("Ширина", value: $islandWidth, range: 0.24...0.42)
                            settingSlider("Высота", value: $islandHeight, range: 0.028...0.065)
                            settingSlider("Отступ сверху", value: $islandTop, range: 0.035...0.105)

                            Button {
                                saveImage()
                            } label: {
                                Label("Сохранить в Фото", systemImage: "square.and.arrow.down")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(.green, in: RoundedRectangle(cornerRadius: 16))
                                    .foregroundStyle(.white)
                            }
                        }
                    } else {
                        ContentUnavailableView(
                            "Скриншот ещё не выбран",
                            systemImage: "iphone",
                            description: Text("Выбери изображение из Фото — здесь появится результат.")
                        )
                        .padding(.top, 12)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    if showSaved {
                        Label("Сохранено в Фото", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.subheadline.weight(.semibold))
                    }

                    Text("Обрабатывается только выбранное изображение. Оригинал не изменяется.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedItem) { _, item in
                showSaved = false
                errorMessage = nil
                Task {
                    guard let data = try? await item?.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else {
                        errorMessage = "Не удалось открыть изображение. Попробуй выбрать другой скриншот."
                        return
                    }
                    sourceImage = image
                }
            }
        }
    }

    @ViewBuilder
    private func settingSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }

    private func saveImage() {
        guard let image = processedImage else { return }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    errorMessage = "Разреши приложению добавлять изображения в Фото в настройках iPhone."
                }
                return
            }
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            DispatchQueue.main.async {
                showSaved = true
                errorMessage = nil
            }
        }
    }
}

enum IslandRenderer {
    static func render(_ image: UIImage, widthFraction: Double, heightFraction: Double, topFraction: Double) -> UIImage? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: size))

            let w = size.width * widthFraction
            let h = size.height * heightFraction
            let x = (size.width - w) / 2
            let y = size.height * topFraction
            let rect = CGRect(x: x, y: y, width: w, height: h)

            // Soft shadow for a more natural, hardware-like pill.
            context.cgContext.setShadow(
                offset: CGSize(width: 0, height: 1),
                blur: max(2, h * 0.08),
                color: UIColor.black.withAlphaComponent(0.28).cgColor
            )
            UIColor.black.setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: h / 2).fill()
            context.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
        }
    }
}
