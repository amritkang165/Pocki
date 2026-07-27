import SwiftUI

/// Animated circular progress ring for budget visualization.
struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 14
    var size: CGFloat = 160
    var trackColor: Color = Color.primary.opacity(0.08)
    var progressColor: Color = .pockiAccent

    @State private var animatedProgress: Double = 0

    private var clampedVisual: Double {
        min(max(animatedProgress, 0), 1)
    }

    private var isOverBudget: Bool {
        progress > 1
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            Circle()
                .trim(from: 0, to: clampedVisual)
                .stroke(
                    AngularGradient(
                        colors: isOverBudget
                            ? [.pockiWarning, .pockiWarning.opacity(0.7)]
                            : [progressColor, progressColor.opacity(0.75)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.9, dampingFraction: 0.8), value: animatedProgress)
        }
        .frame(width: size, height: size)
        .onAppear {
            animatedProgress = min(progress, 1.15)
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.9, dampingFraction: 0.8)) {
                animatedProgress = min(newValue, 1.15)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Budget progress")
        .accessibilityValue("\(Int(min(progress, 9.99) * 100)) percent")
    }
}

#Preview {
    ProgressRing(progress: 0.68)
        .padding()
}
