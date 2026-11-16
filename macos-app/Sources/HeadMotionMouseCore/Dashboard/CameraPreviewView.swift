import SwiftUI
import CoreVideo
import CoreImage

public struct CameraPreviewView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.85))

            if appState.isPrivacyShutterActive {
                VStack(spacing: 8) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.yellow)
                    Text("Privacy Shutter Active")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Video preview is masked. Mathematical tracking remains operational.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else if let pixelBuffer = appState.latestPixelBuffer,
                      let nsImage = makeNSImage(from: pixelBuffer) {
                GeometryReader { geo in
                    ZStack {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()

                        // Center neutral baseline target reticle
                        Circle()
                            .strokeBorder(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            .frame(width: 50, height: 50)

                        // Headphone Tracking Reticle & Overlay
                        if appState.isHeadphoneLocked {
                            let cx = geo.size.width * appState.headphoneNormalizedPos.x
                            let cy = geo.size.height * appState.headphoneNormalizedPos.y

                            ZStack {
                                Circle()
                                    .stroke(Color.green, lineWidth: 2)
                                    .frame(width: 44, height: 44)
                                Circle()
                                    .fill(Color.green.opacity(0.25))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "headphones")
                                    .foregroundColor(.white)
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .position(x: cx, y: cy)

                            Text("🎧 \(appState.trackingModeName)")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.85))
                                .foregroundColor(.black)
                                .clipShape(Capsule())
                                .position(x: cx, y: max(20, cy - 32))
                        } else {
                            VStack(spacing: 4) {
                                Image(systemName: "headphones")
                                    .font(.system(size: 26))
                                    .foregroundColor(.yellow.opacity(0.85))
                                Text("Hold Headphone in View")
                                    .font(.caption2.bold())
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No Camera Feed")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Top-right Privacy Shutter Button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        appState.isPrivacyShutterActive.toggle()
                    }) {
                        Label(
                            appState.isPrivacyShutterActive ? "Show Video" : "Privacy Shutter",
                            systemImage: appState.isPrivacyShutterActive ? "eye" : "eye.slash"
                        )
                        .font(.caption.bold())
                        .padding(6)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
                Spacer()
            }
        }
        .frame(minHeight: 220)
    }

    private func makeNSImage(from buffer: CVPixelBuffer) -> NSImage? {
        let ciImage = CIImage(cvPixelBuffer: buffer)
        let rep = NSCIImageRep(ciImage: ciImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }
}
