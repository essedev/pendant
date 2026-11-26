import PendantKit
import SwiftUI

/// The M5 verification screen: what the pendant exposes, live counts, test actions and the log.
struct ProbeView: View {
  let link: DeviceLink
  let log: ProbeLog

  var body: some View {
    NavigationStack {
      List {
        Section("Ciondolo") {
          row("Stato", link.phase.rawValue)
          row(
            "Collegato da",
            link.connectedSince.map { $0.formatted(date: .omitted, time: .standard) })
          row("Firmware", link.firmware)
          row("Modello", link.model)
          row("Funzioni", link.features?.names.joined(separator: ", "))
          row("Codec", link.codec.map(String.init))
          row("Batteria", link.battery.map { "\($0)%" })
          row("In carica", link.charging.map { $0 ? "sì" : "no" })
          row("Guadagno microfono", link.micGain.map(String.init))
        }
        Section("Audio") {
          row("Pacchetti ricevuti", "\(link.audio.received)")
          row("Persi", "\(link.audio.lost)")
          row("Duplicati", "\(link.audio.duplicates)")
          row("Ripartenze del contatore", "\(link.audio.restarts)")
          row("Byte Opus", "\(link.audio.payloadBytes)")
        }
        Section("Pulsante") {
          if link.buttonCounts.isEmpty {
            Text("Nessun evento").foregroundStyle(.secondary)
          }
          ForEach(link.buttonCounts.sorted(by: { $0.key < $1.key }), id: \.key) { name, count in
            row(name, "\(count)")
          }
        }
        Section("Memoria") {
          if let s = link.storageStatus {
            row(
              "Usati",
              ByteCountFormatter.string(fromByteCount: Int64(s.usedBytes), countStyle: .file))
            row("Pacchetti non letti", "\(s.unreadPackets)")
            row("Orologio valido", s.clockValid ? "sì" : "no")
          }
          if let info = link.ringInfo {
            row("In attesa", "\(info.pendingPackets) pacchetti")
            row("Persi per sovrascrittura", "\(info.droppedPackets)")
          }
          if let read = link.ringRead {
            row("Lettura", "\(read.bytes) B di \(read.expectedPackets) pacchetti")
          }
          Button("Aggiorna info") { link.requestRingInfo() }
          Button("Leggi la memoria in un file") { link.readRing() }
            .disabled(link.ringInfo == nil || link.ringRead != nil)
        }
        Section("Prove") {
          ForEach(Vibration.allCases, id: \.self) { length in
            Button("Vibra \(String(describing: length))") { link.vibrate(length) }
          }
          if link.gainBeforeMuteTest == nil {
            Button("Guadagno a 0 (prova del muto)") { link.startMuteTest() }
              .disabled(link.micGain == nil)
          } else {
            Button("Ripristina il guadagno \(link.gainBeforeMuteTest ?? 0)") { link.endMuteTest() }
              .foregroundStyle(.red)
          }
        }
        Section("Log") {
          ForEach(log.entries.reversed()) { event in
            VStack(alignment: .leading, spacing: 2) {
              Text("\(event.at.formatted(date: .omitted, time: .standard))  \(event.kind)")
                .font(.caption.monospaced())
              if !event.detail.isEmpty {
                Text(event.detail).font(.caption2.monospaced()).foregroundStyle(.secondary)
              }
            }
          }
        }
      }
      .navigationTitle("Pendant")
    }
  }

  private func row(_ label: String, _ value: String?) -> some View {
    LabeledContent(label, value: value ?? "-")
  }
}
