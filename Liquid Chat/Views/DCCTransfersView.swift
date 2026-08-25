//
//  DCCTransfersView.swift
//  Liquid Chat
//
//  Popover listing DCC transfers with accept/decline/cancel controls
//

import SwiftUI
import AppKit

struct DCCTransfersView: View {
    let manager: DCCManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("File Transfers")
                    .font(.headline)
                Spacer()
                if manager.transfers.contains(where: { isFinished($0) }) {
                    Button("Clear Finished") {
                        manager.removeFinished()
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(12)

            Divider()

            if manager.transfers.isEmpty {
                ContentUnavailableView {
                    Label("No Transfers", systemImage: "arrow.down.circle")
                } description: {
                    Text("Files other users offer over DCC appear here for you to accept or decline.")
                }
                .frame(height: 180)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(manager.transfers) { transfer in
                            DCCTransferRow(transfer: transfer, manager: manager)
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
        .frame(width: 360)
    }

    private func isFinished(_ transfer: DCCTransfer) -> Bool {
        switch transfer.state {
        case .completed, .declined, .failed: return true
        default: return false
        }
    }
}

struct DCCTransferRow: View {
    let transfer: DCCTransfer
    let manager: DCCManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(transfer.offer.filename)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text(transfer.formattedSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("from \(transfer.sender) on \(transfer.serverName)")
                .font(.caption)
                .foregroundStyle(.secondary)

            switch transfer.state {
            case .offered:
                HStack {
                    Button("Accept") { manager.accept(transfer) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    Button("Decline") { manager.decline(transfer) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Spacer()
                    Text("Only accept files you expect")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

            case .connecting:
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Connecting…").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel") { manager.cancel(transfer) }
                        .buttonStyle(.plain).font(.caption).foregroundStyle(.red)
                }

            case .transferring:
                VStack(alignment: .leading, spacing: 4) {
                    if let progress = transfer.progress {
                        ProgressView(value: progress)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                    }
                    HStack {
                        Text(ByteCountFormatter.string(fromByteCount: transfer.bytesTransferred, countStyle: .file))
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Cancel") { manager.cancel(transfer) }
                            .buttonStyle(.plain).font(.caption).foregroundStyle(.red)
                    }
                }

            case .completed:
                HStack {
                    Label("Complete", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Spacer()
                    if let destination = transfer.destination {
                        Button("Show in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([destination])
                        }
                        .buttonStyle(.plain).font(.caption)
                    }
                }

            case .declined:
                Label("Declined", systemImage: "xmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)

            case .failed(let reason):
                Label(reason, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }
        }
        .padding(12)
    }
}
