enum IndependentFlowStyle: Hashable {
    case sheet
    case overlay
    case fullScreen

    var title: String {
        switch self {
        case .sheet: "Sheet Flow"
        case .overlay: "Overlay Flow"
        case .fullScreen: "Full-Screen Flow"
        }
    }

    var symbolName: String {
        switch self {
        case .sheet: "rectangle.bottomthird.inset.filled"
        case .overlay: "rectangle.on.rectangle"
        case .fullScreen: "rectangle.fill"
        }
    }
}
