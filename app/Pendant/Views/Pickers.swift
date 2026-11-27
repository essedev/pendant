import PendantKit
import SwiftUI

/// One choice of a picker sheet.
struct Choice<Value: Hashable & Sendable>: Identifiable, Sendable {
  let value: Value
  let label: String
  var subtitle: String?
  var disabled = false
  var id: Value { value }
}

/// A row with a value and a chevron that opens a sheet with the choices, each with its line of
/// explanation; the active one has a checkmark and picking closes the sheet.
struct PickerRow<Value: Hashable & Sendable>: View {
  let label: String
  let title: String
  let choices: [Choice<Value>]
  @Binding var selection: Value
  var footer: String?
  var disabled = false
  @State private var open = false

  var body: some View {
    Button {
      open = true
    } label: {
      Row(
        label,
        value: choices.first { $0.value == selection }?.label ?? "",
        chevron: true, disabled: disabled)
    }
    .buttonStyle(.plain)
    .disabled(disabled)
    .sheet(isPresented: $open) {
      PickerSheet(title: title, choices: choices, selection: $selection, footer: footer)
    }
  }
}

/// The sheet of a picker.
struct PickerSheet<Value: Hashable & Sendable>: View {
  let title: String
  let choices: [Choice<Value>]
  @Binding var selection: Value
  var footer: String?
  @Environment(\.dismiss) private var dismiss
  @State private var height: CGFloat = 320

  var body: some View {
    VStack(spacing: 0) {
      SheetHeader(title: title) { dismiss() }
      CellGroup(footer: footer) {
        ForEach(choices) { choice in
          Button {
            selection = choice.value
            dismiss()
          } label: {
            Row(label: choice.label, subtitle: choice.subtitle, disabled: choice.disabled) {
              if choice.value == selection {
                Image(systemName: "checkmark")
                  .font(.system(size: 15, weight: .semibold))
                  .foregroundStyle(Theme.ink)
              }
            }
          }
          .buttonStyle(.plain)
          .disabled(choice.disabled)
        }
      }
      .padding(.top, -8)
    }
    .padding(.bottom, 24)
    .fixedSize(horizontal: false, vertical: true)
    .onGeometryChange(for: CGFloat.self) {
      $0.size.height
    } action: {
      height = $0
    }
    .presentationDetents([.height(height)])
    .presentationDragIndicator(.visible)
  }
}

/// Title and "Fine" of a sheet.
struct SheetHeader: View {
  let title: String
  var done = "Fine"
  let action: () -> Void

  var body: some View {
    HStack {
      Text(title).type(17, 22, .semibold).foregroundStyle(Theme.ink)
      Spacer()
      CapsuleButton(title: done, action: action)
    }
    .padding(.horizontal, 24)
    .padding(.top, 24)
  }
}

/// A row that opens a sheet with a text field.
struct TextFieldRow: View {
  let label: String
  let value: String
  var subtitle: String?
  let title: String
  let footer: String
  var placeholder = ""
  /// Start empty, for a secret that cannot be read back.
  var startEmpty = false
  var secure = false
  var keyboard: UIKeyboardType = .default
  /// Returns false when the text is not valid, keeping the sheet open.
  let save: (String) -> Bool
  @State private var open = false

  var body: some View {
    Button {
      open = true
    } label: {
      Row(label, subtitle: subtitle, value: value, chevron: true)
    }
    .buttonStyle(.plain)
    .sheet(isPresented: $open) {
      TextSheet(
        title: title, footer: footer, initial: startEmpty ? "" : value, placeholder: placeholder,
        secure: secure, keyboard: keyboard, save: save)
    }
  }
}

private struct TextSheet: View {
  let title: String
  let footer: String
  let initial: String
  let placeholder: String
  let secure: Bool
  let keyboard: UIKeyboardType
  let save: (String) -> Bool
  @State private var text = ""
  @State private var invalid = false
  @FocusState private var focused: Bool
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      SheetHeader(title: title, done: "Salva") {
        if save(text) { dismiss() } else { invalid = true }
      }
      Group {
        if secure {
          SecureField(placeholder, text: $text)
        } else {
          TextField(placeholder, text: $text)
        }
      }
      .type(17, 24)
      .keyboardType(keyboard)
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
      .focused($focused)
      .padding(.horizontal, 16)
      .frame(height: 52)
      .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.cell))
      .padding(.horizontal, 16)
      .padding(.top, 20)
      Text(invalid ? "Non sembra un valore valido. \(footer)" : footer)
        .type(13, 18)
        .foregroundStyle(invalid ? Theme.warn : Theme.ink2)
        .padding(.horizontal, 32)
        .padding(.top, 8)
      Spacer(minLength: 0)
    }
    .onAppear {
      text = initial
      focused = true
    }
    .presentationDetents([.height(240)])
    .presentationDragIndicator(.visible)
  }
}

/// The choices the settings offer, with the words the mock gives them.
enum Choices {
  /// What a gesture can do. "Apri e chiudi nota" comes with the notes (ROADMAP, M10).
  static let gestures: [Choice<GestureAction>] = [
    Choice(
      value: .toggleRecording, label: "Pausa e ripresa",
      subtitle: "Chiude la conversazione, il successivo ne apre una nuova"),
    Choice(
      value: .bookmark, label: "Segna questo momento",
      subtitle: "Un segnalibro nella conversazione in corso"),
    Choice(value: .none, label: "Niente"),
  ]

  /// Short names of the gestures for the Settings root.
  static func short(_ action: GestureAction?) -> String {
    switch action {
    case .toggleRecording: "pausa"
    case .bookmark: "segnalibro"
    case .some(.none), nil: "niente"
    }
  }

  static let led: [Choice<LedPolicy>] = [
    Choice(
      value: .followRecording, label: "Segue la registrazione",
      subtitle: "Accesa quando registra, spenta in pausa"),
    Choice(value: .alwaysOn, label: "Sempre accesa"),
    Choice(
      value: .alwaysOff, label: "Sempre spenta",
      subtitle: "Chi ti sta davanti non vede che stai registrando"),
  ]

  static let offline: [Choice<OfflinePolicy>] = [
    Choice(
      value: .send, label: "Invia al server",
      subtitle: "Non ancora disponibile: serve un aggiornamento del server e dell’app",
      disabled: true),
    Choice(
      value: .clear, label: "Svuota la memoria",
      subtitle: "Butta l’audio registrato lontano dal telefono"),
    Choice(
      value: .keep, label: "Lascia nel ciondolo",
      subtitle: "Non lo tocca: piena la memoria, si sovrascrive il più vecchio"),
  ]

  static let minutes: [Choice<Double>] = [60, 120, 300, 600].map {
    Choice(value: $0, label: DurationFormat.words($0))
  }

  static let idle: [Choice<Double>] = [120, 300, 600, 900].map {
    Choice(value: $0, label: DurationFormat.words($0))
  }

  static let battery: [Choice<Int>] = [10, 15, 20, 30].map { Choice(value: $0, label: "\($0)%") }

  static let signatureDays: [Choice<Int>] = [1, 2, 3].map {
    Choice(value: $0, label: $0 == 1 ? "1 giorno prima" : "\($0) giorni prima")
  }

  static let language: [Choice<String>] = [
    Choice(value: "it", label: "Italiano"),
    Choice(value: "en", label: "Inglese"),
    Choice(value: "", label: "La riconosce il server"),
  ]

  static let ping: [Choice<Double>] = [10, 20, 30, 60].map {
    Choice(value: $0, label: DurationFormat.words($0))
  }

  static let retry: [Choice<Double>] = [10, 30, 60, 120].map {
    Choice(value: $0, label: DurationFormat.words($0))
  }

  /// Queue sizes: Opus is about 4 KB a second.
  static let queue: [Choice<Double>] = [900, 1800, 3600, 7200].map {
    Choice(
      value: $0, label: DurationFormat.words($0),
      subtitle: "Circa \(Int(($0 * 4 / 1000).rounded())) MB")
  }
}

/// Keeps a current value visible in a picker even when it is not among the usual choices, as a
/// value set by an older version or by hand.
func including<Value: Hashable & Sendable>(
  _ choices: [Choice<Value>], _ current: Value, label: (Value) -> String
) -> [Choice<Value>] {
  choices.contains { $0.value == current }
    ? choices : choices + [Choice(value: current, label: label(current))]
}
