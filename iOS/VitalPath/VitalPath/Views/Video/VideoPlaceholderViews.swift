//
//  VideoPlaceholderViews.swift
//  VitalPath - AI Wellness Coaching Platform
//

import SwiftUI
import AVKit

struct VideoUploadPlaceholderView: View {
    let onSelect: (URL) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.teal)
            
            Text(String(localized: "Upload Activity Video"))
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(String(localized: "Record yourself doing yoga, walking, or any wellness activity for AI analysis"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {}) {
                HStack {
                    Image(systemName: "arrow.up.doc.fill")
                    Text(String(localized: "Select Video"))
                }
                .fontWeight(.semibold)
                .padding()
                .background(Color.teal)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .border(Color.teal.opacity(0.3), width: 2, dash: [10, 5])
    }
}

struct VideoPreviewView: View {
    let videoURL: URL
    
    var body: some View {
        VStack {
            VideoPlayer(player: AVPlayer(url: videoURL))
                .aspectRatio(16/9, contentMode: .fit)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            
            HStack(spacing: 20) {
                Label("Qwen 3.5 VL", systemImage: "brain.head.profile")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Label("Multi-modal Analysis", systemImage: "eye.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
    }
}

struct AnalysisResultView: View {
    let result: VideoAnalysisResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Summary Card
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "Analysis Summary"))
                    .font(.headline)
                
                Text(result.analysisSummary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.teal.opacity(0.1))
            .cornerRadius(12)
            
            // Activities
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "Detected Activities"))
                    .font(.headline)
                
                FlowLayout(spacing: 8) {
                    ForEach(result.detectedActivities, id: \.self) { activity in
                        Text(activity)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                }
            }
            
            // Wellness Score
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(String(localized: "Wellness Score"))
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(result.scorePercentage)%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(getScoreColor(result.wellnessScore))
                }
                
                ProgressView(value: result.wellnessScore)
                    .tint(getScoreColor(result.wellnessScore))
            }
            
            // AI Model Info
            HStack(spacing: 8) {
                Image(systemName: "cpu.fill")
                    .foregroundColor(.purple)
                Text(String(localized: "Analyzed by Qwen 3.5 VL (256K context)"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private func getScoreColor(_ score: Double) -> Color {
        if score >= 0.8 { return .green }
        if score >= 0.6 { return .yellow }
        return .red
    }
}

// Simple Flow Layout for activity tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

#Preview {
    VideoUploadPlaceholderView(onSelect: { _ in })
        .padding()
}
