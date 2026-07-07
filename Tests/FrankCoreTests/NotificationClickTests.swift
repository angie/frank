import Foundation
import FrankCore
import Testing

@Suite("Notification click")
struct NotificationClickTests {
    @Test("the PR url rides out of a banner's userInfo")
    func extractsURL() {
        let url = NotificationClick.url(from: ["url": "https://github.com/angie/frank/pull/1"])

        #expect(url == URL(string: "https://github.com/angie/frank/pull/1"))
    }

    @Test("missing or malformed userInfo yields nothing")
    func missingOrMalformedYieldsNil() {
        #expect(NotificationClick.url(from: [:]) == nil)
        #expect(NotificationClick.url(from: ["url": 42]) == nil)
        #expect(NotificationClick.url(from: ["link": "https://github.com"]) == nil)
        #expect(NotificationClick.url(from: ["url": ""]) == nil)
    }
}
