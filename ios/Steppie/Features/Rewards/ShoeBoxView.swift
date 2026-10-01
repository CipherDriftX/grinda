import SwiftUI

/// The box: a cobalt shoebox with a volt lid and the stride slashes on the side.
struct ShoeBoxArt: View {
    var open = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .bottom) {
                // body
                RoundedRectangle(cornerRadius: w * 0.06, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0x2B5CE8), Palette.cobalt], startPoint: .top, endPoint: .bottom))
                    .frame(width: w, height: h * 0.68)
                HStack(spacing: w * 0.04) {
                    ForEach(0..<2, id: \.self) { _ in
                        Rectangle().fill(Palette.volt).frame(width: w * 0.07, height: h * 0.32).rotationEffect(.degrees(28))
                    }
                }
                .offset(x: w * 0.22, y: -h * 0.16)
                // lid
                RoundedRectangle(cornerRadius: w * 0.06, style: .continuous)
                    .fill(Palette.volt)
                    .frame(width: w * 1.08, height: h * 0.24)
                    .overlay(alignment: .center) {
                        StrideShape().fill(Palette.onVolt).frame(width: h * 0.12, height: h * 0.2)
                    }
                    .rotationEffect(.degrees(open ? -24 : 0), anchor: .bottomLeading)
                    .offset(x: open ? -w * 0.08 : 0, y: -h * 0.62 - (open ? h * 0.22 : 0))
            }
            .frame(width: w, height: h, alignment: .bottom)
        }
        .accessibilityHidden(true)
    }
}

/// Opening a Shoe Box: anticipation (the box shakes harder and harder), the
/// burst, then the pair with its rarity. Cosmetic only; odds depend on the
/// race's length, never on money.
struct ShoeBoxSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var stage = 0 // 0 closed, 1 shaking, 2 open
    @State private var shakes = 0
    @State private var shoe: ShoeStyle?
    var preview: ShoeStyle? = nil

    var body: some View {
        ZStack {
            Palette.field.ignoresSafeArea()
            RaysBackground(color: shoe.map { $0.rarity.color } ?? .white, opacity: stage == 2 ? 0.16 : 0.05)
            if stage == 2 { ConfettiBurst(count: (shoe?.rarity ?? ShoeRarity.common) >= ShoeRarity.epic ? 140 : 80, origin: UnitPoint(x: 0.5, y: 0.45)) }
            SparkleField(count: 14, color: shoe?.rarity.color ?? .white)
            VStack(spacing: 18) {
                Spacer()
                if stage == 2, let shoe {
                    Text(shoe.rarity.title.uppercased())
                        .font(BrandFont.label(16)).kerning(2)
                        .foregroundStyle(shoe.rarity.color)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(.black.opacity(0.25), in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                    SteppieView(mood: .cheer, pose: .cheer, mane: model.maneLevel, shoes: shoe, hop: 1)
                        .frame(height: 280)
                        .transition(.scale(scale: 0.4, anchor: .bottom).combined(with: .opacity))
                    Text(shoe.name)
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundStyle(.white)
                    Text("New kicks for Steppie. You earned these by finishing.")
                        .font(.body)
                        .foregroundStyle(Palette.onFieldSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text(stage == 0 ? "Your Shoe Box" : "Here it comes…")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundStyle(.white)
                        .contentTransition(.opacity)
                    ShoeBoxArt(open: false)
                        .frame(width: 200, height: 176)
                        .shake(shakes)
                        .scaleEffect(stage == 1 ? 1.08 : 1)
                        .onTapGesture { Task { await open() } }
                    Text("Finish longer races for better odds at Epic and Legendary pairs.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.onFieldSecondary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
                if stage == 2, let shoe {
                    Button("Wear them") { model.wear(shoe); dismiss() }
                        .buttonStyle(.volt)
                    Button("Keep the old pair") { dismiss() }
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(minHeight: 44)
                } else {
                    Button("Open it") { Task { await open() } }
                        .buttonStyle(.onField)
                        .disabled(stage != 0)
                        .shimmer(stage == 0)
                }
            }
            .padding(24)
        }
        .animation(Motion.snap, value: stage)
        .task {
            if let preview { shoe = preview; stage = 2 }
        }
    }

    private func open() async {
        guard stage == 0 else { return }
        stage = 1
        if !reduceMotion {
            for i in 0..<4 {
                withAnimation(.linear(duration: 0.32 - Double(i) * 0.05)) { shakes += 1 }
                Haptics.pin()
                try? await Task.sleep(for: .milliseconds(330 - i * 50))
            }
        }
        shoe = model.openShoeBox() ?? ShoeBox.roll(days: 7, owned: model.shoesOwned)
        Haptics.success()
        stage = 2
    }
}
