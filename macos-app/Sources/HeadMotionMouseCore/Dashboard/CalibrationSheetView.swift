import SwiftUI

public struct CalibrationSheetView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 24) {
            Text("Neutral Pose Calibration")
                .font(.title2.bold())

            Text("Look straight ahead at the center reticle in your natural, comfortable seated posture.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 3)
                    .frame(width: 140, height: 140)

                Circle()
                    .trim(from: 0.0, to: appState.calibrationProgress)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: appState.calibrationProgress)

                VStack(spacing: 4) {
                    Image(systemName: "scope")
                        .font(.system(size: 32))
                        .foregroundColor(appState.isCalibrating ? .blue : .secondary)

                    Text("\(Int(appState.calibrationProgress * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
            }

            VStack(spacing: 6) {
                Text(appState.isCalibrating ? "Hold steady..." : "Ready to calibrate")
                    .font(.headline)
                    .foregroundColor(appState.isCalibrating ? .primary : .secondary)

                Text("Filters out involuntary micro-tremors and outliers via MAD statistics.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 16) {
                Button("Cancel") {
                    appState.cancelCalibration()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(action: {
                    if appState.isCalibrating {
                        appState.cancelCalibration()
                    } else {
                        appState.startCalibration()
                    }
                }) {
                    Text(appState.isCalibrating ? "Stop" : "Begin Calibration")
                        .bold()
                        .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(32)
        .frame(width: 440, height: 380)
    }
}
