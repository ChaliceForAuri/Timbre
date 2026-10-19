import SwiftUI

/// Press, speak, release — the Mac's held key, as a button (GDR-0026). The
/// press starts listening, the release ends it; a finger that slides off
/// still ends it. A long press does the same for VoiceOver.
struct HoldToTalkButton: View {
    let title: String
    let heldTitle: String
    let tint: Color
    let isHeld: Bool
    let onPress: () -> Void
    let onRelease: () -> Void

    var body: some View {
        Text(isHeld ? heldTitle : title)
            .font(.title3.weight(.semibold))
            .foregroundStyle(isHeld ? Color.white : Color.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(isHeld ? tint : tint.opacity(0.25), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(tint, lineWidth: 2))
            .scaleEffect(isHeld ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: isHeld)
            .contentShape(RoundedRectangle(cornerRadius: 22))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if !isHeld { onPress() } }
                    .onEnded { _ in onRelease() }
            )
            .sensoryFeedback(.impact(weight: .medium), trigger: isHeld)
            .accessibilityElement()
            .accessibilityLabel(title)
            .accessibilityHint("Press and hold while you speak")
            .accessibilityAddTraits(.isButton)
    }
}
