import SwiftUI

public extension Font {
    static func inter(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        .custom("Inter", size: size).weight(weight)
    }

    static func inter(_ style: Font.TextStyle, design: Font.Design = .default, weight: Font.Weight = .regular) -> Font {
        .custom("Inter", size: interBaseSize(for: style), relativeTo: style).weight(weight)
    }

    private static func interBaseSize(for style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 34
        case .title: return 28
        case .title2: return 22
        case .title3: return 20
        case .headline: return 17
        case .subheadline: return 15
        case .body: return 17
        case .callout: return 16
        case .footnote: return 13
        case .caption: return 12
        case .caption2: return 11
        @unknown default:
            return 17
        }
    }
}
