import SwiftUI

struct MusicPlayerView: View {
    @ObservedObject var audio: AudioManager

    var body: some View {
        HStack(spacing: 12) {
            Button(action: { audio.togglePlayPause() }) {
                Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
            }

            VStack(alignment: .leading) {
                ProgressView(value: audio.currentTime, total: max(1, audio.duration))
                    .progressViewStyle(LinearProgressViewStyle())

                HStack {
                    Text(timeString(from: audio.currentTime))
                        .font(.caption)
                    Spacer()
                    Text(timeString(from: audio.duration))
                        .font(.caption)
                }
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .padding()
    }

    private func timeString(from seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "0:00" }
        let int = Int(seconds)
        return String(format: "%d:%02d", int / 60, int % 60)
    }
}

#Preview {
    MusicPlayerView(audio: AudioManager(filename: "background", fileExtension: "m4a", autoplay: false, pauseBetweenLoops: 2.0))
}
