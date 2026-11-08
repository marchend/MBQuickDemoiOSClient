import SwiftUI

/// The app's entire colour palette: navy, white, and greys only (per the
/// Okta-styled mockup — no other hues appear anywhere in the login screen).
extension Color {
    /// Primary navy brand colour — logo, headings, buttons. `#16223C`.
    static let acmeNavy = Color(red: 0x16 / 255.0, green: 0x22 / 255.0, blue: 0x3C / 255.0)

    /// App background. `#F3F4F6`.
    static let acmeBackground = Color(red: 0xF3 / 255.0, green: 0xF4 / 255.0, blue: 0xF6 / 255.0)

    /// Border colour for input fields and the checkbox.
    static let acmeBorder = Color(red: 0xD9 / 255.0, green: 0xDC / 255.0, blue: 0xE1 / 255.0)

    /// Grey used for placeholder text and small chrome icons (lock, eye).
    static let acmeGreyText = Color(red: 0x8A / 255.0, green: 0x8F / 255.0, blue: 0x98 / 255.0)

    /// Muted grey used for subtitles and footer text.
    static let acmeMutedText = Color(red: 0x6D / 255.0, green: 0x72 / 255.0, blue: 0x7F / 255.0)
}
