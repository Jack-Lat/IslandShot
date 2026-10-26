import SwiftUI

/// Редактируемые тексты пресета (процент заряда, время звонка, имя и т. п.).
struct PresetValues: Equatable {
    var primary: String = ""
    var secondary: String = ""
}

struct PresetField: Identifiable {
    let label: String
    let key: WritableKeyPath<PresetValues, String>
    var id: String { label }
}

struct IslandConfig {
    var preset: IslandPreset
    var values: PresetValues
    var offsetY: CGFloat = 0
    var scale: CGFloat = 1
    /// На айфонах с островом время и значки стоят ниже, чем на айфонах с чёлкой.
    var statusBarShift: CGFloat = IslandMetrics.statusBarShift
    /// Цвет иконки и текста для пресета «Свой».
    var tint: Color = IslandColors.green
    /// Чем закрасить зону бывшей чёлки (nil — не закрашивать).
    var notchFill: Color? = nil
}

enum IslandPreset: String, CaseIterable, Identifiable {
    case plain, lock, faceID, charging, lowBattery, silent, ring
    case call, incomingCall, timer, timerMinimal, music, airpods, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plain: "Обычный"
        case .lock: "Блокировка"
        case .faceID: "Face ID"
        case .charging: "Зарядка"
        case .lowBattery: "Мало заряда"
        case .silent: "Бесшумно"
        case .ring: "Со звуком"
        case .call: "Разговор"
        case .incomingCall: "Вх. звонок"
        case .timer: "Таймер"
        case .timerMinimal: "Таймер мини"
        case .music: "Музыка"
        case .airpods: "AirPods"
        case .custom: "Свой"
        }
    }

    var icon: String {
        switch self {
        case .plain: "capsule.fill"
        case .lock: "lock.fill"
        case .faceID: "faceid"
        case .charging: "battery.100.bolt"
        case .lowBattery: "battery.25"
        case .silent: "bell.slash.fill"
        case .ring: "bell.fill"
        case .call: "phone.fill"
        case .incomingCall: "phone.arrow.down.left.fill"
        case .timer: "timer"
        case .timerMinimal: "smallcircle.filled.circle"
        case .music: "music.note"
        case .airpods: "airpodspro"
        case .custom: "wand.and.stars"
        }
    }

    var fields: [PresetField] {
        switch self {
        case .charging, .lowBattery, .airpods:
            [PresetField(label: "Заряд", key: \.primary)]
        case .silent, .ring:
            [PresetField(label: "Надпись", key: \.primary)]
        case .call:
            [PresetField(label: "Длительность", key: \.primary)]
        case .timer:
            [PresetField(label: "Осталось", key: \.primary)]
        case .incomingCall:
            [PresetField(label: "Имя", key: \.primary), PresetField(label: "Подпись", key: \.secondary)]
        case .custom:
            [PresetField(label: "Символ SF", key: \.primary), PresetField(label: "Текст", key: \.secondary)]
        case .plain, .lock, .faceID, .timerMinimal, .music:
            []
        }
    }

    var defaultValues: PresetValues {
        switch self {
        case .charging: PresetValues(primary: "80%")
        case .lowBattery: PresetValues(primary: "10%")
        case .airpods: PresetValues(primary: "80%")
        case .silent: PresetValues(primary: "Бесшумно")
        case .ring: PresetValues(primary: "Звонок")
        case .call: PresetValues(primary: "0:42")
        case .timer: PresetValues(primary: "4:59")
        case .incomingCall: PresetValues(primary: "Мама", secondary: "мобильный")
        case .custom: PresetValues(primary: "star.fill", secondary: "Готово")
        default: PresetValues()
        }
    }
}
