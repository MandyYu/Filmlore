import SwiftUI

enum StyleCameraTheme {
    static let primary = Color(red: 1.00, green: 0.36, blue: 0.54)
    static let coral = Color(red: 1.00, green: 0.48, blue: 0.42)
    static let orange = Color(red: 1.00, green: 0.61, blue: 0.29)
    static let deepPurple = Color(red: 0.35, green: 0.29, blue: 0.54)
    static let deepNavy = Color(red: 0.18, green: 0.15, blue: 0.31)
    static let cyan = Color(red: 0.20, green: 0.84, blue: 0.90)
    static let accentBlue = Color(red: 0.27, green: 0.43, blue: 0.94)
    static let palePink = Color(red: 1.00, green: 0.89, blue: 0.91)
    static let grayPurple = Color(red: 0.60, green: 0.56, blue: 0.70)

    static let screenBackground = Color(red: 0.11, green: 0.09, blue: 0.18)
    static let panelBackground = Color(red: 0.16, green: 0.14, blue: 0.24)
    static let elevatedBackground = Color(red: 0.22, green: 0.19, blue: 0.31)
    static let divider = Color(red: 0.34, green: 0.31, blue: 0.44)
    static let secondaryText = Color(red: 0.73, green: 0.70, blue: 0.79)

    static let primaryGradient = LinearGradient(
        colors: [primary, coral],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let warmGradient = LinearGradient(
        colors: [coral, orange],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let shutterRingGradient = AngularGradient(
//        gradient: Gradient(stops: [
//            .init(color: primary, location: 0.00),
//            .init(color: coral, location: 0.44),
//            .init(color: primary, location: 0.66),
//            .init(color: deepPurple, location: 0.84),
//            .init(color: accentBlue, location: 1.00),
//            .init(color: deepPurple, location: 1.00),
//        ]),
//        startPoint: .topLeading,
//        endPoint: .bottomTrailing
        gradient: Gradient(colors: [
            Color(red: 1.00, green: 0.87, blue: 0.92),
            Color(red: 0.98, green: 0.45, blue: 0.74),
            Color(red: 0.92, green: 0.20, blue: 0.62),
            Color(red: 0.74, green: 0.32, blue: 0.97),
            Color(red: 0.40, green: 0.24, blue: 0.95),
            Color(red: 1.00, green: 0.87, blue: 0.92)
        ]),
        center: .center
    )

    static let screenGradient = LinearGradient(
        colors: [deepNavy, screenBackground],
        startPoint: .top,
        endPoint: .bottom
    )
}
