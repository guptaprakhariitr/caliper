import SwiftUI
import DesignSystem

/// Tiny, testable view-model driving the one-shot launch splash. `showSplash`
/// starts `true`; `dismiss()` flips it to `false`. The splash is shown once per
/// launch via the host gating its `@State`/`@StateObject` on first appear.
@MainActor
public final class SplashModel: ObservableObject {
    /// PicaMac tagline + one-line "what it means" (single source of truth).
    public static let tagline = "Measure anything on screen, to the pixel."
    public static let meaning = "A pixel ruler + color picker that snaps to on-screen UI edges."

    @Published public private(set) var showSplash: Bool

    public init(showSplash: Bool = true) {
        self.showSplash = showSplash
    }

    /// Dismiss the splash (auto-timer, click, or keypress). Idempotent.
    public func dismiss() {
        showSplash = false
    }
}

/// A centered launch card over the app's first window: accent-gradient rounded
/// square with the app glyph, the app name, the tagline, and a one-line
/// "what it means." Auto-dismisses after ~1.2s with a fade+scale (fade-only when
/// Reduce Motion is on); also dismisses on click or keypress.
public struct SplashView: View {
    @ObservedObject var model: SplashModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// PicaMac accent (matches onboarding/About).
    private let accent = Color(red: 0.55, green: 0.35, blue: 0.85)
    private let glyph = "ruler.fill"

    public init(model: SplashModel) {
        self.model = model
    }

    public var body: some View {
        ZStack {
            // Background surface with a subtle accent-tinted gradient.
            LinearGradient(
                colors: [DS.Color.bg, accent.opacity(0.10)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: DS.Space.md) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(LinearGradient(colors: [accent, accent.opacity(0.65)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 104, height: 104)
                    .overlay(Image(systemName: glyph)
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(.white))
                    .shadow(color: accent.opacity(0.35), radius: 16, y: 8)

                Text("PicaMac").font(DS.Font.display)
                Text(SplashModel.tagline)
                    .font(DS.Font.headline)
                    .foregroundStyle(DS.Color.label)
                    .multilineTextAlignment(.center)
                Text(SplashModel.meaning)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DS.Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        // Auto-dismiss after ~1.2s.
        .task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            dismiss()
        }
        // Dismiss on any keypress without trapping focus elsewhere.
        .background(KeyCatcher { dismiss() })
        .transition(reduceMotion
                    ? .opacity
                    : .opacity.combined(with: .scale(scale: 1.04)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("PicaMac. \(SplashModel.tagline)")
    }

    private func dismiss() {
        guard model.showSplash else { return }
        withAnimation(.easeOut(duration: 0.35)) { model.dismiss() }
    }
}

/// Invisible first responder that converts the first keypress into a dismiss,
/// so the splash is dismissible by keyboard as well as click.
private struct KeyCatcher: NSViewRepresentable {
    let onKey: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = KeyView()
        view.onKey = onKey
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class KeyView: NSView {
        var onKey: (() -> Void)?
        override var acceptsFirstResponder: Bool { true }
        override func keyDown(with event: NSEvent) { onKey?() }
    }
}
