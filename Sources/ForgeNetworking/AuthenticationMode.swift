import Foundation

public enum AuthenticationMode: Sendable {
    case inherit
    case none
    case override(any AuthProvider)
}
