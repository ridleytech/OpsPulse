import SwiftUI

struct TelemetryPoint: Identifiable {
    let id = UUID()
    let date: Date
    let pressure: Double
    let flow: Double
    let temperature: Double
}

enum TelemetrySeries: String, CaseIterable, Identifiable {
    case pressure = "Pressure"
    case flow = "Flow"
    case temperature = "Temp"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .pressure: return Color("BrandBlue")
        case .flow: return Color("BrandGray")
        case .temperature: return Color("BrandRed")
        }
    }
}
