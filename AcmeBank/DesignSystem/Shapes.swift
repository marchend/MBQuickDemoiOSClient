import SwiftUI

/// A regular, pointy-top-and-bottom hexagon inscribed in the given rect —
/// used for the navy "A" logo. Drawn as a vector `Shape`; no image asset
/// per the acceptance criteria.
struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        var path = Path()
        for index in 0..<6 {
            let angleRadians = Angle(degrees: Double(index) * 60 - 90).radians
            let point = CGPoint(
                x: center.x + radius * CGFloat(cos(angleRadians)),
                y: center.y + radius * CGFloat(sin(angleRadians))
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

/// The Okta "ring + dot" mark, composed from two `Circle`s — no image asset.
/// Reused in the top strip and the footer, which the mockup renders in two
/// different colours: navy (`#16223C`) in the top strip, and the same muted
/// grey (`#6D727F`) as the surrounding "Secured by okta" text in the footer.
/// The colour is therefore a parameter — filling navy unconditionally put a
/// navy mark in the middle of grey footer text.
struct OktaMarkView: View {
    /// Fill/stroke colour for the ring and dot. Defaults to the top strip's
    /// navy; the footer passes `.acmeMutedText`.
    var color: Color = .acmeNavy

    var body: some View {
        ZStack {
            Circle()
                .stroke(color, lineWidth: 2.5)
            Circle()
                .fill(color)
                .padding(5)
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        HexagonShape()
            .fill(Color.acmeNavy)
            .frame(width: 84, height: 84)
            .overlay(
                Text("A")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
            )
        OktaMarkView()
            .frame(width: 32, height: 32)
        OktaMarkView(color: .acmeMutedText)
            .frame(width: 32, height: 32)
    }
    .padding()
    .background(Color.acmeBackground)
}
