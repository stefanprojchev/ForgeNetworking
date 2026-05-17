import Foundation
import ForgeNetworking

public enum StubResponse<R: Sendable>: Sendable {
    case success(R)
    case failure(NetworkError)
    case sequence([StubResponse<R>])
}
