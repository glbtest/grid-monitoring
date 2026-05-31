import Foundation

/// Інвертор/пристрій, прив'язаний до станції FSolar.
struct Device: Identifiable, Equatable, Sendable {
    let id: String          // серійний номер (deviceSN)
    let name: String
    let plantId: String
    let isOnline: Bool
}

/// Станція (plant) у кабінеті FSolar.
struct Plant: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
}
