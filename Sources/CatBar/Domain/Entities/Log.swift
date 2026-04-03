import Foundation

enum AppLogSource: String, Codable, Equatable, CaseIterable, Identifiable {
    case catbar
    case mihomo

    var id: String {
        rawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        switch try container.decode(String.self) {
        case "catbar":
            self = .catbar
        case "mihomo":
            self = .mihomo
        default:
            self = .catbar
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

struct AppErrorLogEntry: Codable, Equatable, Identifiable {
    let id: UUID
    let timestamp: Date
    let source: AppLogSource
    let level: String
    let message: String

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        source: AppLogSource = .catbar,
        level: String,
        message: String)
    {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.level = level
        self.message = message
    }
}

struct LogsResponse: Codable, Equatable {
    let logs: [LogLine]?
}

struct LogLine: Codable, Equatable {
    let type: String?
    let payload: String?
}

struct DelayMeasurement: Codable, Equatable {
    let value: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let map = try? container.decode([String: Int].self) {
            self.value = map.values.first
        } else {
            self.value = nil
        }
    }
}

struct GroupDelayMeasurement: Codable, Equatable {
    let values: [String: Int]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.values = (try? container.decode([String: Int].self)) ?? [:]
    }
}

struct NodeDelayMeasurement: Decodable, Equatable {
    let delay: Int

    private enum CodingKeys: String, CodingKey {
        case delay
    }

    init(delay: Int) {
        self.delay = delay
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.delay = (try? container.decode(Int.self, forKey: .delay)) ?? 0
    }
}
