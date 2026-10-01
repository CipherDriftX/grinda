import SwiftUI

/// The Steppie symbol, the Stride S: an S cut in two by a forward stride, every
/// cut on the same 58° angle. Generated from brand/logo/stride-s.json
/// (brand/tools/stride.py), in a unit box, so it scales to any size.
struct StrideShape: Shape {
    static let aspect: CGFloat = 0.58651
    static let angle: Double = 58
    private static let d = "M0.4546,0.5855 L0.5121,0.5869 L0.5360,0.5886 L0.5594,0.5918 L0.5875,0.5982 L0.6086,0.6050 L0.6328,0.6154 L0.6502,0.6252 L0.6689,0.6390 L0.6840,0.6542 L0.6932,0.6673 L0.7009,0.6843 L0.7043,0.7018 L0.7038,0.7160 L0.6993,0.7334 L0.6904,0.7502 L0.6774,0.7661 L0.6642,0.7780 L0.6446,0.7913 L0.6266,0.8007 L0.6017,0.8106 L0.5802,0.8168 L0.5517,0.8225 L0.5221,0.8257 L0.4921,0.8263 L0.4622,0.8243 L0.4388,0.8209 L0.4109,0.8144 L0.3899,0.8075 L0.3658,0.7969 L0.3487,0.7871 L0.3302,0.7732 L0.3161,0.7587 L0.1489,0.9156 L0.1925,0.9380 L0.2410,0.9576 L0.2931,0.9737 L0.3382,0.9843 L0.3950,0.9935 L0.4532,0.9987 L0.5077,1.0000 L0.5665,0.9974 L0.6142,0.9923 L0.6666,0.9833 L0.7116,0.9725 L0.7508,0.9606 L0.7964,0.9430 L0.8341,0.9251 L0.8727,0.9024 L0.9007,0.8824 L0.9256,0.8610 L0.9491,0.8361 L0.9668,0.8123 L0.9837,0.7819 L0.9939,0.7540 L0.9998,0.7222 L1.0000,0.6937 L0.9961,0.6679 L0.9893,0.6449 L0.9811,0.6257 L0.9686,0.6035 L0.9556,0.5851 L0.9377,0.5643 L0.9203,0.5473 L0.8974,0.5281 L0.8759,0.5128 L0.8485,0.4959 L0.8234,0.4826 L0.7920,0.4682 L0.7639,0.4572 L0.7292,0.4456 L0.6986,0.4372 L0.6614,0.4288 L0.6291,0.4230 L0.6279,0.4228 Z M0.8512,0.0841 L0.8077,0.0617 L0.7680,0.0453 L0.7204,0.0297 L0.6758,0.0184 L0.6238,0.0088 L0.5762,0.0031 L0.5323,0.0003 L0.4777,0.0000 L0.4337,0.0023 L0.3859,0.0075 L0.3336,0.0164 L0.2926,0.0261 L0.2494,0.0392 L0.2038,0.0567 L0.1693,0.0730 L0.1345,0.0928 L0.0995,0.1173 L0.0746,0.1388 L0.0530,0.1614 L0.0333,0.1874 L0.0165,0.2178 L0.0063,0.2457 L0.0004,0.2775 L0.0000,0.3034 L0.0040,0.3318 L0.0142,0.3633 L0.0266,0.3881 L0.0445,0.4146 L0.0698,0.4430 L0.0965,0.4667 L0.1312,0.4915 L0.1624,0.5098 L0.1882,0.5227 L0.2117,0.5330 L0.2618,0.5513 L0.3152,0.5659 L0.3429,0.5718 L0.3723,0.5769 L0.5456,0.4143 L0.4701,0.4118 L0.4465,0.4089 L0.4237,0.4044 L0.4020,0.3983 L0.3767,0.3888 L0.3542,0.3771 L0.3348,0.3636 L0.3189,0.3487 L0.3070,0.3325 L0.2993,0.3154 L0.2962,0.3014 L0.2963,0.2838 L0.3009,0.2663 L0.3098,0.2495 L0.3198,0.2367 L0.3359,0.2218 L0.3514,0.2110 L0.3689,0.2013 L0.3933,0.1910 L0.4200,0.1829 L0.4427,0.1781 L0.4721,0.1744 L0.5021,0.1733 L0.5321,0.1748 L0.5613,0.1788 L0.5893,0.1853 L0.6103,0.1922 L0.6343,0.2028 L0.6515,0.2127 L0.6700,0.2266 L0.6841,0.2410 Z"

    func path(in rect: CGRect) -> Path {
        MascotPaths.path(Self.d)
            .applying(CGAffineTransform(scaleX: rect.width, y: rect.height))
            .offsetBy(dx: rect.minX, dy: rect.minY)
    }
}

/// Live logo. When animated, the two halves stride in from opposite sides and
/// snap together on the cut, like two steps landing.
struct StrideMark: View {
    var color: Color = .white
    var animated = false
    @State private var landed = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack {
                StrideShape().fill(color)
                    .mask(StrideHalf(upper: true))
                    .offset(x: landed ? 0 : -w * 0.5, y: landed ? 0 : -w * 0.3)
                StrideShape().fill(color)
                    .mask(StrideHalf(upper: false))
                    .offset(x: landed ? 0 : w * 0.5, y: landed ? 0 : w * 0.3)
            }
            .opacity(landed ? 1 : 0)
        }
        .aspectRatio(StrideShape.aspect, contentMode: .fit)
        .onAppear {
            guard animated, !reduceMotion else { return }
            landed = false
            withAnimation(Motion.snap.delay(0.25)) { landed = true }
        }
        .accessibilityLabel("Steppie")
    }
}

/// One side of the stride cut: the half-plane on either side of the line
/// through the centre at the stride angle.
private struct StrideHalf: Shape {
    let upper: Bool

    func path(in rect: CGRect) -> Path {
        let a = StrideShape.angle * .pi / 180
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let far = (rect.width + rect.height) * 2
        let d = CGPoint(x: cos(a) * far, y: -sin(a) * far)
        let n = CGPoint(x: sin(a) * far, y: cos(a) * far) // points down-right, away from the upper half
        let s: CGFloat = upper ? -1 : 1
        var p = Path()
        p.move(to: CGPoint(x: c.x - d.x, y: c.y - d.y))
        p.addLine(to: CGPoint(x: c.x + d.x, y: c.y + d.y))
        p.addLine(to: CGPoint(x: c.x + d.x + s * n.x, y: c.y + d.y + s * n.y))
        p.addLine(to: CGPoint(x: c.x - d.x + s * n.x, y: c.y - d.y + s * n.y))
        p.closeSubpath()
        return p
    }
}
