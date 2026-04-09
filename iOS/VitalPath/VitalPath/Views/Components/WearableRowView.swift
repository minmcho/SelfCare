//
//  WearableRowView.swift
//  VitalPath - AI Wellness Coaching Platform
//

import SwiftUI
import SwiftData

struct WearableRowView: View {
    let wearable: WearableConnection
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: wearable.deviceType.icon)
                .font(.system(size: 24))
                .foregroundColor(getDeviceColor(wearable.deviceType))
                .frame(width: 40, height: 40)
                .background(getDeviceColor(wearable.deviceType).opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(wearable.deviceType.displayName)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(getStatusColor(wearable.syncStatus))
                        .frame(width: 8, height: 8)
                    
                    Text(wearable.syncStatus.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if wearable.isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func getDeviceColor(_ type: WearableDeviceType) -> Color {
        switch type {
        case .appleWatch: return .blue
        case .fitbit: return .green
        case .garmin: return .purple
        case .oura: return .pink
        case .whoop: return .orange
        case .manual: return .gray
        }
    }
    
    private func getStatusColor(_ status: SyncStatus) -> Color {
        switch status {
        case .disconnected: return .gray
        case .connecting: return .blue
        case .syncing: return .orange
        case .synced: return .green
        case .failed: return .red
        case .permissionDenied: return .yellow
        }
    }
}

#Preview {
    WearableRowView(
        wearable: WearableConnection(
            userId: "user_123",
            deviceType: .appleWatch,
            isConnected: true,
            syncStatus: .synced
        )
    )
    .padding()
}
