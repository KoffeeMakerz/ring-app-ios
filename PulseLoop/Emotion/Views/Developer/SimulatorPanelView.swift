import SwiftUI

/// 6.2 Ring simulator panel (debug).
struct SimulatorPanelView: View {
    @Environment(EmotionServices.self) private var services
    @State private var touch: Feeling = .gratitude

    var body: some View {
        let sim = services.simulator
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 14) {
                    Circle().strokeBorder(sim.isBuzzing ? EColor.debug : (sim.connected ? Color(hex: "#4A4160") : EColor.cardRaised), lineWidth: 16)
                        .frame(width: 112, height: 112)
                        .shadow(color: sim.isBuzzing ? EColor.debug : .clear, radius: 20)
                    Text(sim.connected ? (sim.isBuzzing ? "Buzzing" : "Simulated ring connected") : "Disconnected").font(EFont.body(16, .bold))
                    Text("\(sim.connected ? "Battery \(sim.batteryPercent)%" : "Reconnecting…") · profile \(sim.profile.name)").font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                    FlowLayout(spacing: 6) {
                        ForEach([Feeling.gratitude, .love, .joy, .calm]) { f in
                            Chip(title: f.name, selected: touch == f, selectedColor: EColor.debug) { touch = f }
                        }
                    }
                    HStack(spacing: 8) {
                        Button("Play touch") { services.haptics.play(touch.touch) }.buttonStyle(PrimaryButtonStyle(color: EColor.debug, height: 44))
                        Button("One buzz") { services.haptics.playSingle() }.buttonStyle(SecondaryButtonStyle(height: 44))
                        Button("Stop") { services.haptics.stop() }.buttonStyle(SecondaryButtonStyle(height: 44))
                    }
                    HStack(spacing: 16) {
                        Toggle("Vibrate phone", isOn: Bindable(sim).mirrorToPhoneHaptics).font(EFont.body(13))
                        Toggle("Overlay", isOn: Bindable(sim).showOverlay).font(EFont.body(13))
                    }
                    .tint(EColor.debug)
                }
                .padding(16).eCard(radius: 22)

                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text("Ring profile").font(EFont.body(15, .bold)); Spacer(); Text("values from Phase 0").font(EFont.body(12)).foregroundStyle(EColor.textMuted) }
                    Picker("Profile", selection: Bindable(sim).profile) {
                        ForEach(RingCapabilityProfile.all) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: sim.profile) { _, p in sim.log("PROFILE \(p.name)") }
                    HStack(spacing: 8) {
                        stat("Buzz length", sim.profile.buzzMs.map { "\($0) ms" } ?? "any")
                        stat("Min gap", "\(sim.profile.minGapMs) ms")
                        stat("Stop cmd", sim.profile.supportsStop ? "yes" : "no")
                    }
                }
                .padding(16).eCard(radius: 22)

                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text("Heart data").font(EFont.body(15, .bold)); Spacer(); Text(sim.currentBPM.map { "\($0) bpm" } ?? "— bpm").font(EFont.mono(15)) }
                    FlowLayout(spacing: 6) {
                        ForEach(HeartScenario.allCases) { s in
                            Chip(title: s.name, selected: sim.scenario == s, selectedColor: Color(hex: "#7FB2F0")) { sim.scenario = s }
                        }
                    }
                    Text(sim.scenario.note).font(EFont.body(12)).foregroundStyle(EColor.textMuted)
                }
                .padding(16).eCard(radius: 22)

                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Connection").font(EFont.body(15, .semibold))
                            Text(sim.connected ? "Connected · drops on demand" : "Disconnected · app should retry").font(EFont.body(12)).foregroundStyle(EColor.textSecondary)
                        }
                        Spacer()
                        Button(sim.connected ? "Disconnect" : "Reconnect") { sim.setConnected(!sim.connected) }
                            .font(EFont.body(13, .semibold)).foregroundStyle(EColor.text).padding(.horizontal, 14).frame(height: 36).background(EColor.cardRaised, in: Capsule())
                    }
                    .frame(minHeight: 56)
                    Divider().overlay(EColor.line)
                    ToggleRow(title: "Low battery (9%)", isOn: Bindable(sim).lowBattery)
                    Divider().overlay(EColor.line)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Extra command delay").font(EFont.body(15, .semibold))
                        Picker("Delay", selection: Bindable(sim).extraDelayMs) { ForEach([0, 200, 400, 800], id: \.self) { Text("+\($0)").tag($0) } }
                            .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 10)
                    Divider().overlay(EColor.line)
                    ToggleRow(title: "Drop 1 in 5 commands", isOn: Bindable(sim).dropOneInFive)
                }
                .padding(.horizontal, 16).eCard(radius: 22)
                .tint(EColor.debug)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Command log").font(EFont.body(15, .bold))
                        Spacer()
                        Button("Clear") { sim.clearLog() }.font(EFont.body(13, .semibold)).foregroundStyle(EColor.textSecondary)
                        ShareLink(item: sim.log.reversed().map { "\($0.time) \($0.text)" }.joined(separator: "\n")) { Text("Export").font(EFont.body(13, .semibold)) }
                    }
                    ForEach(sim.log.prefix(40)) { line in
                        HStack(alignment: .top, spacing: 10) {
                            Text(line.time).foregroundStyle(EColor.textMuted)
                            Text(line.text).foregroundStyle(color(line.kind))
                        }
                        .font(EFont.mono(11.5))
                    }
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "#08060C"), in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(EColor.line))
            }
            .padding(.horizontal, 20).padding(.bottom, 32)
        }
        .emotionScreen()
        .navigationTitle("Ring simulator").navigationBarTitleDisplayMode(.inline)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(EFont.body(11)).foregroundStyle(EColor.textSecondary)
            Text(value).font(EFont.mono(14))
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading).background(EColor.cardRaised, in: RoundedRectangle(cornerRadius: 12))
    }

    private func color(_ kind: SimulatedRing.LogLine.Kind) -> Color {
        switch kind {
        case .buzz: EColor.debug
        case .error: EColor.danger
        case .warning: EColor.warning
        case .heart: Color(hex: "#7FB2F0")
        case .connect: EColor.success
        case .info: EColor.textSecondary
        }
    }
}
