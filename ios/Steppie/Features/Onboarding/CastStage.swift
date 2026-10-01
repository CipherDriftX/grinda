import SwiftUI

/// The whole crew on one stage: Steppie front and centre, the cast around him,
/// each introduced by the one job they do in the app.
struct CastStage: View {
    var compact = false
    @State private var shown = 0
    @State private var hop = 0

    private let order: [CastMember] = [.dash, .shelly, .steppie, .pip, .bo]

    var body: some View {
        VStack(spacing: compact ? 12 : 22) {
            if !compact {
                Text("Meet the crew")
                    .font(.system(size: 38, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.top, 30)
            }
            ZStack(alignment: .bottom) {
                ForEach(Array(order.enumerated()), id: \.element) { i, who in
                    let lead = who == .steppie
                    CharacterView(who: who, mood: lead ? .cheer : .happy, pose: lead ? .cheer : (who == .pip ? .wave : .idle),
                                  mane: 3, hop: hop + (lead ? 1 : 0))
                        .frame(width: lead ? 190 : 118, height: lead ? 218 : 136)
                        .offset(x: CGFloat(i - 2) * 72, y: lead ? 0 : -18)
                        .zIndex(lead ? 2 : Double(abs(i - 2) == 1 ? 1 : 0))
                        .opacity(shown > i ? 1 : 0)
                        .offset(y: shown > i ? 0 : 40)
                        .scaleEffect(shown > i ? 1 : 0.7, anchor: .bottom)
                }
            }
            .frame(height: 240)
            if !compact {
                VStack(spacing: 10) {
                    ForEach(CastMember.allCases) { who in
                        HStack(spacing: 12) {
                            CharacterView(who: who, animated: false)
                                .frame(width: 40, height: 46)
                            Text(who.name).font(.system(.headline, weight: .heavy)).foregroundStyle(.white)
                            Text(who.role).font(.subheadline).foregroundStyle(Palette.onFieldSecondary)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: compact ? nil : .infinity, alignment: .top)
        .background { if !compact { ZStack { Palette.field; RaysBackground(opacity: 0.06) }.ignoresSafeArea() } }
        .task {
            for i in 1...order.count {
                withAnimation(Motion.snap) { shown = i }
                Haptics.soft()
                try? await Task.sleep(for: .milliseconds(140))
            }
            hop += 1
        }
    }
}
