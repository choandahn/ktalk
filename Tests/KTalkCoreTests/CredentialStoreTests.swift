import Testing
@testable import KTalkCore

@Suite("CredentialStore Tests", .serialized)
struct CredentialStoreTests {

    @Test("Service name is com.ktalk.credentials")
    func serviceNameConstant() {
        #expect(CredentialStore.service == "com.ktalk.credentials")
    }

    @Test("Email account key is kakaotalk-email")
    func emailKeyConstant() {
        #expect(CredentialStore.emailAccount == "kakaotalk-email")
    }

    @Test("Password account key is kakaotalk-password")
    func passwordKeyConstant() {
        #expect(CredentialStore.passwordAccount == "kakaotalk-password")
    }

    @Test("Save and read email round-trip")
    func saveAndReadEmail() throws {
        let store = CredentialStore()
        try store.save(email: "testktalk@example.com", password: "testpass123")
        #expect(store.email == "testktalk@example.com")
        store.clear()
    }

    @Test("Save and read password round-trip")
    func saveAndReadPassword() throws {
        let store = CredentialStore()
        try store.save(email: "testktalk@example.com", password: "testpass123")
        #expect(store.password == "testpass123")
        store.clear()
    }

    @Test("Clear removes email and password")
    func clearRemovesCredentials() throws {
        let store = CredentialStore()
        try store.save(email: "testktalk@example.com", password: "testpass123")
        store.clear()
        #expect(store.email == nil)
        #expect(store.password == nil)
    }

    @Test("hasCredentials returns false when empty")
    func hasCredentialsFalseWhenEmpty() {
        let store = CredentialStore()
        store.clear()
        #expect(store.hasCredentials == false)
    }

    @Test("hasCredentials returns true after save")
    func hasCredentialsTrueAfterSave() throws {
        let store = CredentialStore()
        try store.save(email: "testktalk@example.com", password: "testpass123")
        #expect(store.hasCredentials == true)
        store.clear()
    }
}
