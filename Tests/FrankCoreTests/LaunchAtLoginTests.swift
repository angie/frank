import FrankCore
import Testing

@Suite("Launch at login")
struct LaunchAtLoginTests {
    @Test("reports enabled when the service says so")
    func enabledFromService() {
        let model = LaunchAtLogin(service: FakeLoginItemService(status: .enabled))

        #expect(model.isEnabled)
    }

    @Test("reports disabled when not registered")
    func disabledFromService() {
        let model = LaunchAtLogin(service: FakeLoginItemService(status: .notRegistered))

        #expect(!model.isEnabled)
    }

    @Test("awaiting approval in System Settings reads as disabled")
    func requiresApprovalReadsDisabled() {
        let model = LaunchAtLogin(service: FakeLoginItemService(status: .requiresApproval))

        #expect(!model.isEnabled)
    }

    @Test("enabling registers with the service")
    func enablingRegisters() {
        let service = FakeLoginItemService(status: .notRegistered)
        let model = LaunchAtLogin(service: service)

        model.setEnabled(true)

        #expect(service.calls == [.register])
        #expect(model.isEnabled)
    }

    @Test("disabling unregisters from the service")
    func disablingUnregisters() {
        let service = FakeLoginItemService(status: .enabled)
        let model = LaunchAtLogin(service: service)

        model.setEnabled(false)

        #expect(service.calls == [.unregister])
        #expect(!model.isEnabled)
    }

    @Test("enabling when already enabled does not re-register")
    func enablingTwiceIsANoOp() {
        let service = FakeLoginItemService(status: .enabled)
        let model = LaunchAtLogin(service: service)

        model.setEnabled(true)

        #expect(service.calls.isEmpty)
        #expect(model.isEnabled)
    }

    @Test("a failed registration leaves it disabled")
    func failedRegistrationStaysDisabled() {
        let service = FakeLoginItemService(status: .notRegistered, failing: true)
        let model = LaunchAtLogin(service: service)

        model.setEnabled(true)

        #expect(!model.isEnabled)
    }

    @Test("a registration gated on approval leaves it disabled")
    func approvalGatedRegistrationStaysDisabled() {
        let service = FakeLoginItemService(status: .notRegistered, registrationLandsAt: .requiresApproval)
        let model = LaunchAtLogin(service: service)

        model.setEnabled(true)

        #expect(!model.isEnabled)
    }

    @Test("a failed unregistration leaves it enabled")
    func failedUnregistrationStaysEnabled() {
        let service = FakeLoginItemService(status: .enabled, failing: true)
        let model = LaunchAtLogin(service: service)

        model.setEnabled(false)

        #expect(model.isEnabled)
    }
}

private final class FakeLoginItemService: LoginItemService {
    enum Call: Equatable {
        case register
        case unregister
    }

    private(set) var status: LoginItemStatus
    private(set) var calls: [Call] = []
    private let failing: Bool
    private let registrationLandsAt: LoginItemStatus

    init(
        status: LoginItemStatus,
        failing: Bool = false,
        registrationLandsAt: LoginItemStatus = .enabled
    ) {
        self.status = status
        self.failing = failing
        self.registrationLandsAt = registrationLandsAt
    }

    struct ServiceFailure: Error {}

    func register() throws {
        calls.append(.register)
        if failing { throw ServiceFailure() }
        status = registrationLandsAt
    }

    func unregister() throws {
        calls.append(.unregister)
        if failing { throw ServiceFailure() }
        status = .notRegistered
    }
}
