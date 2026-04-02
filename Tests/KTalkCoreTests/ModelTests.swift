import Foundation
import Testing
@testable import KTalkCore

@Suite("Model Tests")
struct ModelTests {

    @Suite("ChatType")
    struct ChatTypeTests {
        @Test("Raw values")
        func rawValues() {
            #expect(Chat.ChatType.direct.rawValue == "direct")
            #expect(Chat.ChatType.group.rawValue == "group")
            #expect(Chat.ChatType.openChat.rawValue == "open")
            #expect(Chat.ChatType.unknown.rawValue == "unknown")
        }

        @Test("Codable round-trip")
        func codableRoundTrip() throws {
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let original: Chat.ChatType = .direct
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(Chat.ChatType.self, from: data)
            #expect(decoded == original)
        }
    }

    @Suite("MessageType")
    struct MessageTypeTests {
        @Test("Raw values")
        func rawValues() {
            #expect(Message.MessageType.system.rawValue == 0)
            #expect(Message.MessageType.text.rawValue == 1)
            #expect(Message.MessageType.photo.rawValue == 2)
            #expect(Message.MessageType.video.rawValue == 3)
            #expect(Message.MessageType.voice.rawValue == 4)
            #expect(Message.MessageType.sticker.rawValue == 5)
            #expect(Message.MessageType.file.rawValue == 6)
            #expect(Message.MessageType.location.rawValue == 7)
        }

        @Test("Codable round-trip")
        func codableRoundTrip() throws {
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let original: Message.MessageType = .text
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(Message.MessageType.self, from: data)
            #expect(decoded == original)
        }

        @Test("Unknown value decoding")
        func unknownValueDecoding() throws {
            let decoder = JSONDecoder()
            let data = Data("99".utf8)
            let decoded = try decoder.decode(Message.MessageType.self, from: data)
            #expect(decoded == .unknown)
        }
    }

    @Suite("Chat")
    struct ChatTests {
        @Test("Creation with optional fields nil")
        func creation() {
            let chat = Chat(
                id: 1, type: .direct, displayName: "Test",
                memberCount: 2, lastMessageId: nil,
                lastMessageAt: nil, unreadCount: 0
            )
            #expect(chat.id == 1)
            #expect(chat.type == .direct)
            #expect(chat.displayName == "Test")
            #expect(chat.memberCount == 2)
            #expect(chat.lastMessageId == nil)
            #expect(chat.lastMessageAt == nil)
            #expect(chat.unreadCount == 0)
        }

        @Test("Codable round-trip")
        func codableRoundTrip() throws {
            let chat = Chat(
                id: 42, type: .group, displayName: "Group Chat",
                memberCount: 5, lastMessageId: 100,
                lastMessageAt: nil, unreadCount: 3
            )
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let data = try encoder.encode(chat)
            let decoded = try decoder.decode(Chat.self, from: data)
            #expect(decoded.id == chat.id)
            #expect(decoded.type == chat.type)
            #expect(decoded.displayName == chat.displayName)
            #expect(decoded.memberCount == chat.memberCount)
            #expect(decoded.lastMessageId == chat.lastMessageId)
            #expect(decoded.unreadCount == chat.unreadCount)
        }
    }

    @Suite("Message")
    struct MessageTests {
        @Test("Creation")
        func creation() {
            let date = Date(timeIntervalSince1970: 0)
            let msg = Message(
                id: 1, chatId: 2, senderId: 3,
                senderName: "Alice", text: "Hello",
                type: .text, createdAt: date, isFromMe: false
            )
            #expect(msg.id == 1)
            #expect(msg.chatId == 2)
            #expect(msg.senderId == 3)
            #expect(msg.senderName == "Alice")
            #expect(msg.text == "Hello")
            #expect(msg.type == .text)
            #expect(msg.isFromMe == false)
        }

        @Test("isFromMe true")
        func isFromMe() {
            let date = Date(timeIntervalSince1970: 0)
            let msg = Message(
                id: 1, chatId: 2, senderId: 3,
                senderName: nil, text: nil,
                type: .system, createdAt: date, isFromMe: true
            )
            #expect(msg.isFromMe == true)
        }

        @Test("Codable round-trip")
        func codableRoundTrip() throws {
            let date = Date(timeIntervalSince1970: 1000)
            let msg = Message(
                id: 10, chatId: 20, senderId: 30,
                senderName: "Bob", text: "Hi",
                type: .photo, createdAt: date, isFromMe: true
            )
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let data = try encoder.encode(msg)
            let decoded = try decoder.decode(Message.self, from: data)
            #expect(decoded.id == msg.id)
            #expect(decoded.chatId == msg.chatId)
            #expect(decoded.senderId == msg.senderId)
            #expect(decoded.senderName == msg.senderName)
            #expect(decoded.text == msg.text)
            #expect(decoded.type == msg.type)
            #expect(decoded.isFromMe == msg.isFromMe)
        }
    }

    @Suite("Contact")
    struct ContactTests {
        @Test("Creation")
        func creation() {
            let contact = Contact(
                id: 1, name: "Alice",
                profileImageUrl: "https://example.com/photo.jpg",
                statusMessage: "Hello!"
            )
            #expect(contact.id == 1)
            #expect(contact.name == "Alice")
            #expect(contact.profileImageUrl == "https://example.com/photo.jpg")
            #expect(contact.statusMessage == "Hello!")
        }

        @Test("Codable round-trip with nil optionals")
        func codableRoundTrip() throws {
            let contact = Contact(id: 2, name: "Bob", profileImageUrl: nil, statusMessage: nil)
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let data = try encoder.encode(contact)
            let decoded = try decoder.decode(Contact.self, from: data)
            #expect(decoded.id == contact.id)
            #expect(decoded.name == contact.name)
            #expect(decoded.profileImageUrl == contact.profileImageUrl)
            #expect(decoded.statusMessage == contact.statusMessage)
        }
    }
}
