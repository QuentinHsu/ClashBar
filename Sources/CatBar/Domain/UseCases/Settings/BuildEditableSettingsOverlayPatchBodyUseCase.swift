import Foundation

enum BuildEditableSettingsOverlayPatchBodyError: Error, Equatable {
    case invalidLogLevel(String)
    case invalidPort(key: String)
}

struct BuildEditableSettingsOverlayPatchBodyUseCase {
    private let resolveOverlayPortFieldsUseCase = ResolveOverlayPortFieldsUseCase()
    private let buildPortPatchBodyUseCase = BuildPortPatchBodyUseCase()

    func execute(
        overlay: EditableSettingsSnapshot,
        fallback: EditableSettingsSnapshot?,
        hasConfiguredTunStack: Bool) throws -> [String: ConfigPatchValue]
    {
        let resolvedLogLevel = self.resolvedLogLevel(overlay.logLevel, fallback: fallback?.logLevel)
        guard ConfigLogLevel(rawValue: resolvedLogLevel) != nil else {
            throw BuildEditableSettingsOverlayPatchBodyError.invalidLogLevel(resolvedLogLevel)
        }

        let resolvedPortFields = self.resolveOverlayPortFieldsUseCase.execute(
            overlay: overlay,
            fallback: fallback)

        let portBody: [String: ConfigPatchValue]
        do {
            portBody = try self.buildPortPatchBodyUseCase.execute(
                fields: resolvedPortFields,
                skipEmptyValues: true)
        } catch let BuildPortPatchBodyError.invalidPort(key) {
            throw BuildEditableSettingsOverlayPatchBodyError.invalidPort(key: key)
        }

        var body: [String: ConfigPatchValue] = [
            "allow-lan": .bool(overlay.allowLan),
            "ipv6": .bool(overlay.ipv6),
            "tcp-concurrent": .bool(overlay.tcpConcurrent),
            "log-level": .string(resolvedLogLevel),
            "tun": .object(self.tunBody(enabled: overlay.tunEnabled, hasConfiguredStack: hasConfiguredTunStack)),
        ]
        if overlay.tunEnabled {
            body["dns"] = .object(["enable": .bool(true)])
        }
        for (key, value) in portBody {
            body[key] = value
        }
        return body
    }

    private func resolvedLogLevel(_ overlayValue: String, fallback: String?) -> String {
        let normalizedOverlayValue = overlayValue.trimmed
        if !normalizedOverlayValue.isEmpty {
            return normalizedOverlayValue
        }
        return fallback?.trimmedNonEmpty ?? ConfigLogLevel.info.rawValue
    }

    private func tunBody(enabled: Bool, hasConfiguredStack: Bool) -> [String: ConfigPatchValue] {
        var body: [String: ConfigPatchValue] = ["enable": .bool(enabled)]
        if enabled, !hasConfiguredStack {
            body["stack"] = .string("mixed")
        }
        return body
    }
}
