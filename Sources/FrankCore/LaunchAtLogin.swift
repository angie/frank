import Observation

public enum LoginItemStatus: Equatable, Sendable {
    case enabled
    case notRegistered
    case requiresApproval
    case notFound
}

public protocol LoginItemService {
    var status: LoginItemStatus { get }
    func register() throws
    func unregister() throws
}

@Observable
public final class LaunchAtLogin {
    private let service: any LoginItemService
    public private(set) var isEnabled: Bool

    public init(service: any LoginItemService) {
        self.service = service
        isEnabled = service.status == .enabled
    }

    public func setEnabled(_ desired: Bool) {
        guard desired != isEnabled else { return }
        if desired {
            try? service.register()
        } else {
            try? service.unregister()
        }
        isEnabled = service.status == .enabled
    }
}
