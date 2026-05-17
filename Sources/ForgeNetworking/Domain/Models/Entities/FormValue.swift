public enum FormValue: Sendable {
    case string(String)
    case array([String])
    case nested([String: FormValue])
}
