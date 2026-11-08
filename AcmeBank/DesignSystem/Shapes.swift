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
/// Reused in the top strip and the footer.
struct OktaMarkView: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.acmeNavy, lineWidth: 2.5)
            Circle()
                .fill(Color.acmeNavy)
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
    }
    .padding()
    .background(Color.acmeBackground)
}
