import SwiftUI

public struct ResultModalView: View {
    @ObservedObject var viewModel: GameViewModel
    @Environment(\.presentationMode) var presentationMode
    @AppStorage("server1_result_scale") private var resultScale: Double = 1.0
    
    public var body: some View {
        let s = CGFloat(resultScale)
        let fs = max(0.72, s)
        
        NavigationView {
            GeometryReader { geo in
                ZStack {
                    VStack(spacing: 0) {
                        // Thanh kéo to/nhỏ bảng kết quả (ghim gọn trên đầu)
                        HStack(spacing: 8) {
                            Image(systemName: "textformat.size.smaller")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            Slider(value: $resultScale, in: 0.55...1.30, step: 0.05)
                                .tint(.blue)
                            Image(systemName: "textformat.size.larger")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.blue)
                            Text("\(Int(round(resultScale * 100)))%")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.blue)
                                .frame(width: 38, alignment: .trailing)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color(.systemBackground))
                        
                        Divider()
                        
                        ScrollView {
                            VStack(spacing: max(6, 14 * s)) {
                                // Winner Banner
                                VStack(spacing: max(3, 8 * s)) {
                                    Text(viewModel.showdownSummary)
                                        .font(.system(size: 17 * fs, weight: .bold))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                    
                                    Text(viewModel.gameType.rawValue)
                                        .font(.system(size: 14 * fs))
                                        .foregroundColor(.white.opacity(0.85))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, max(8, 16 * s))
                                .background(
                                    LinearGradient(
                                        colors: [Color.blue, Color.purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(max(8, 14 * s))
                                .padding(.horizontal)
                                
                                // Rankings List
                                VStack(alignment: .leading, spacing: max(4, 10 * s)) {
                                    Text("Bảng Xếp Hạng & Đánh Giá Bài")
                                        .font(.system(size: 16 * fs, weight: .bold))
                                        .padding(.horizontal)
                                    
                                    ForEach(sortedPlayers) { player in
                                        PlayerResultRowView(player: player, allPlayers: viewModel.players, scale: s)
                                    }
                                }
                                
                                Spacer().frame(height: 70) // Khoảng trống cuộn tránh che khuất bởi nút nổi
                            }
                            .padding(.vertical, max(6, 12 * s))
                        }
                    }
                    
                    // Nút Đóng Thứ 2 (Floating Close Button)
                    if viewModel.isFloatingCloseButtonEnabled {
                        let btnX = geo.size.width * viewModel.floatingCloseButtonRatioX
                        let btnY = geo.size.height * viewModel.floatingCloseButtonRatioY
                        let btnSize = viewModel.floatingCloseButtonSize
                        
                        Button(action: {
                            viewModel.isShowResultModal = false
                            if viewModel.isVoiceMode {
                                viewModel.resetTable()
                            }
                        }) {
                            VStack(spacing: 2) {
                                Image(systemName: "xmark")
                                    .font(.system(size: btnSize * 0.36, weight: .black))
                                if btnSize >= 50 {
                                    Text("ĐÓNG")
                                        .font(.system(size: max(8, btnSize * 0.18), weight: .black))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(width: btnSize, height: btnSize)
                            .background(
                                Circle().fill(
                                    LinearGradient(
                                        colors: [Color.red, Color(red: 0.9, green: 0.2, blue: 0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.85), lineWidth: 2.5)
                            )
                            .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .position(x: btnX, y: btnY)
                    }
                }
            }
            .navigationTitle("Kết Quả So Bài")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.isShowResultModal = false
                        if viewModel.isVoiceMode {
                            viewModel.resetTable()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20, weight: .bold))
                            Text("Đóng")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
    }
    
    private var sortedPlayers: [Player] {
        viewModel.players.sorted { ($0.rankOrder ?? 999) < ($1.rankOrder ?? 999) }
    }

    private func rankBadgeColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color.yellow
        case 2: return Color.gray
        case 3: return Color.brown
        default: return Color.blue.opacity(0.6)
        }
    }
}

struct PlayerResultRowView: View {
    let player: Player
    let allPlayers: [Player]
    var scale: CGFloat = 1.0
    
    private var isUnknown: Bool {
        player.rankOrder == nil || player.resultTitle == "???" || player.cards.contains(where: { $0.isHidden })
    }
    
    private var isTie: Bool {
        guard !isUnknown, let rank = player.rankOrder else { return false }
        return allPlayers.filter({ $0.rankOrder == rank }).count > 1
    }
    
    private func rankBadgeColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color.yellow
        case 2: return Color.gray
        case 3: return Color.brown
        default: return Color.blue.opacity(0.6)
        }
    }
    
    var body: some View {
        let s = scale
        let fs = max(0.72, scale)
        let badgeSize = max(24, 36 * s)
        
        HStack(alignment: .top, spacing: max(6, 12 * s)) {
            // Medal / Rank badge
            if isUnknown {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: badgeSize, height: badgeSize)
                    Text("?")
                        .font(.system(size: 16 * fs, weight: .black))
                        .foregroundColor(.white)
                }
            } else {
                ZStack {
                    Circle()
                        .fill(rankBadgeColor(player.rankOrder ?? 0))
                        .frame(width: badgeSize, height: badgeSize)
                    
                    Text("\(player.rankOrder ?? 0)")
                        .font(.system(size: 16 * fs, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            VStack(alignment: .leading, spacing: max(2, 4 * s)) {
                HStack(spacing: max(4, 6 * s)) {
                    Text(player.name)
                        .font(.system(size: 16 * fs, weight: .semibold))
                    
                    if isUnknown {
                        Text("LOẠI KHỎI BXH")
                            .font(.system(size: 10 * fs, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, max(4, 6 * s))
                            .padding(.vertical, max(1, 2 * s))
                            .background(Color.red)
                            .cornerRadius(4)
                    } else if isTie {
                        Text("ĐỒNG HẠNG")
                            .font(.system(size: 10 * fs, weight: .bold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, max(4, 6 * s))
                            .padding(.vertical, max(1, 2 * s))
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(4)
                    }
                    
                    if player.isLung {
                        Text("LỦNG")
                            .font(.system(size: 10 * fs, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, max(4, 6 * s))
                            .padding(.vertical, max(1, 2 * s))
                            .background(Color.red)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                }
                
                Text(player.resultTitle)
                    .font(.system(size: 14 * fs, weight: .bold))
                    .foregroundColor(isUnknown ? .red : .blue)
                
                Text(player.resultDetail)
                    .font(.system(size: 12 * fs))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                if !player.cards.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: max(2, 4 * s)) {
                            ForEach(player.cards) { card in
                                MiniCardView(card: card, scale: s) { }
                            }
                        }
                    }
                    .padding(.top, max(1, 2 * s))
                }
            }
        }
        .padding(max(6, 12 * s))
        .background(Color(.secondarySystemBackground))
        .cornerRadius(max(8, 12 * s))
        .padding(.horizontal)
    }
}
