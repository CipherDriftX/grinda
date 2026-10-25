import SwiftUI
import PhotosUI

/// A day was marked missed but you walked it. Send a screenshot of Apple
/// Health for that day; a person checks it. You stay in while they look.
struct DisputeSheet: View {
    let race: Race
    let day: DayRecord
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var item: PhotosPickerItem?
    @State private var image: Data?
    @State private var note = ""
    @State private var working = false
    @State private var sent = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 14) {
                        CharacterView(who: .shelly, mood: sent ? .cheer : .calm, pose: sent ? .cheer : .hold, hop: sent ? 1 : 0)
                            .frame(width: 80, height: 92)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(sent ? "Got it" : "Steps didn't sync?")
                                .font(.system(.title2, weight: .heavy))
                            Text(sent
                                 ? "A person will check it, usually within a few hours. You stay in the race while they look."
                                 : "It happens: a phone in a drawer, a watch that didn't hand over. Show us Apple Health for \(day.date.formatted(.dateTime.weekday(.wide).day().month(.wide))).")
                                .font(.subheadline)
                                .foregroundStyle(Palette.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if !sent {
                        PhotosPicker(selection: $item, matching: .screenshots) {
                            ZStack {
                                if let image, let ui = UIImage(data: image) {
                                    Image(uiImage: ui)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxHeight: 320)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                } else {
                                    VStack(spacing: 10) {
                                        Image(systemName: "photo.badge.plus")
                                            .font(.system(size: 34))
                                        Text("Choose the screenshot")
                                            .font(.system(.headline, weight: .semibold))
                                        Text("Health › Steps › Day, showing the date and the total")
                                            .font(.footnote)
                                            .foregroundStyle(Palette.inkSecondary)
                                    }
                                    .foregroundStyle(Palette.cobalt)
                                    .frame(maxWidth: .infinity, minHeight: 180)
                                }
                            }
                            .padding(10)
                            .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Palette.hairline, style: StrokeStyle(lineWidth: 1.5, dash: image == nil ? [6, 4] : []))
                            }
                        }
                        .buttonStyle(.pressable)
                        .onChange(of: item) { _, new in
                            Task { image = try? await new?.loadTransferable(type: Data.self) }
                        }

                        TextField("Anything we should know? (optional)", text: $note, axis: .vertical)
                            .lineLimit(2...4)
                            .padding(14)
                            .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                        if let error {
                            Text(error).font(.footnote).foregroundStyle(Palette.risk)
                        }

                        Button {
                            Task { await send() }
                        } label: {
                            if working { ProgressView().tint(.white) } else { Text("Send for review") }
                        }
                        .buttonStyle(.primary)
                        .disabled(image == nil || working)

                        VStack(alignment: .leading, spacing: 10) {
                            RuleLine(symbol: "clock.arrow.circlepath", text: "Late syncs count on their own for 24 hours after a day closes. Opening Health often fixes it.")
                            RuleLine(symbol: "person.fill.checkmark", text: "Screenshots are checked by a person, not a bot, and deleted once the race settles.")
                            RuleLine(symbol: "exclamationmark.shield", text: "Edited screenshots or added steps get the account removed and the entry kept.")
                        }
                    } else {
                        Button("Done") { dismiss() }.buttonStyle(.primary)
                    }
                }
                .padding(20)
            }
            .background(Palette.ground)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button(sent ? "Done" : "Cancel") { dismiss() } }
            }
        }
    }

    private func send() async {
        working = true
        defer { working = false }
        do {
            try await model.dispute(race: race, day: day, note: note, image: shrink(image))
            Haptics.success()
            withAnimation(Motion.snap) { sent = true; error = nil }
        } catch {
            withAnimation(Motion.standard) { self.error = error.localizedDescription }
        }
    }

    /// Screenshots can be several MB; a 1400px JPEG is plenty to read numbers.
    private func shrink(_ data: Data?) -> Data? {
        guard let data, let ui = UIImage(data: data) else { return data }
        let scale = min(1, 1400 / max(ui.size.width, ui.size.height))
        let size = CGSize(width: ui.size.width * scale, height: ui.size.height * scale)
        let out = UIGraphicsImageRenderer(size: size).image { _ in ui.draw(in: CGRect(origin: .zero, size: size)) }
        return out.jpegData(compressionQuality: 0.8)
    }
}
