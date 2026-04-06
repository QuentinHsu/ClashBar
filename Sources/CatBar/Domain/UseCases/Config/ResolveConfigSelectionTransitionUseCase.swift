import Foundation

enum ConfigSelectionValidationTiming {
    case beforeSelection
    case afterSelection
}

struct ConfigSelectionValidationRequest: Equatable {
    let targetSelectedURL: URL
    let staleSelectionCanonicalPath: String?
}

struct ConfigSelectionTransition: Equatable {
    let previousSelectedPath: String?
    let nextSelectedPath: String?
    let validationRequest: ConfigSelectionValidationRequest?
}

struct ResolveConfigSelectionTransitionUseCase {
    func execute(
        previousSelectedURL: URL?,
        nextSelectedURL: URL?,
        coreIsRunning: Bool,
        validationTiming: ConfigSelectionValidationTiming) -> ConfigSelectionTransition
    {
        let previousCanonicalPath = self.canonicalPath(previousSelectedURL)
        let nextCanonicalPath = self.canonicalPath(nextSelectedURL)

        let validationRequest: ConfigSelectionValidationRequest?
        if coreIsRunning,
           let nextSelectedURL,
           previousCanonicalPath != nextCanonicalPath
        {
            let staleSelectionCanonicalPath = switch validationTiming {
            case .beforeSelection:
                previousCanonicalPath
            case .afterSelection:
                nextCanonicalPath
            }

            validationRequest = ConfigSelectionValidationRequest(
                targetSelectedURL: nextSelectedURL,
                staleSelectionCanonicalPath: staleSelectionCanonicalPath)
        } else {
            validationRequest = nil
        }

        return ConfigSelectionTransition(
            previousSelectedPath: previousSelectedURL?.path,
            nextSelectedPath: nextSelectedURL?.path,
            validationRequest: validationRequest)
    }

    private func canonicalPath(_ url: URL?) -> String? {
        url?.standardizedFileURL.resolvingSymlinksInPath().path
    }
}
