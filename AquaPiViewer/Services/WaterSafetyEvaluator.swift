import Foundation

struct WaterSafetyEvaluator {
    static let warningMarginCelsius = 2.0

    static func evaluate(
        temperatureC: Double?,
        minC: Double?,
        maxC: Double?,
        crcOk: Bool?
    ) -> WaterSafetyStatus {
        guard crcOk != false else {
            return .unknown
        }

        guard let temperatureC, let minC, let maxC else {
            return .unknown
        }

        guard temperatureC.isFinite, minC.isFinite, maxC.isFinite, minC <= maxC else {
            return .unknown
        }

        if minC...maxC ~= temperatureC {
            return .safety
        }

        if temperatureC >= minC - warningMarginCelsius && temperatureC < minC {
            return .warning
        }

        if temperatureC > maxC && temperatureC <= maxC + warningMarginCelsius {
            return .warning
        }

        return .danger
    }
}
