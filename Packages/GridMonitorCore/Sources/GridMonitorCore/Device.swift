import Foundation

/// Інвертор/пристрій, прив'язаний до станції FSolar.
public struct Device: Identifiable, Equatable, Sendable {
    public let id: String          // серійний номер (deviceSN)
    public let name: String
    public let plantId: String
    public let isOnline: Bool

    public init(id: String, name: String, plantId: String, isOnline: Bool) {
        self.id = id
        self.name = name
        self.plantId = plantId
        self.isOnline = isOnline
    }
}

/// Станція (plant) у кабінеті FSolar.
public struct Plant: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}
