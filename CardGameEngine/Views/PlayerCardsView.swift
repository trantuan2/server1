import SwiftUI

public struct PlayerCardsView: View {
    @ObservedObject var viewModel: GameViewModel
    var scale: CGFloat = 1.0
    @State private var isShowingRenameDialog = false
    @State private var editingIndex: Int = 0
    @State private var editingName: String = ""
    
    public var body: some View {
        let s = scale
        let fs = max(0.72, scale)

        VStack(alignment: .leading, spacing: max(3, 6 * s)) {
            // Community Cards (If applicable)
            if viewModel.gameType.communityCardsCount > 0 {
                let allPlayersFull = viewModel.players.indices.allSatisfy { viewModel.players[$0].cards.count >= viewModel.targetCards(for: $0) }
                let commNeedsCards = viewModel.communityCards.count < viewModel.gameType.communityCardsCount
                let isCommSelected = commNeedsCards && !viewModel.hasCalculatedResults && (viewModel.isSelectingCommunity || allPlayersFull)
                
                VStack(alignment: .leading, spacing: max(2, 3 * s)) {
                    HStack {
                        Label("Bài Chung", systemImage: "rectangle.stack.fill")
                            .font(.system(size: 12 * fs, weight: .bold))
                            .foregroundColor(.orange)
                        
                        if isCommSelected {
                            Text("▶ Đang chọn")
                                .font(.system(size: 9 * fs, weight: .bold))
                                .foregroundColor(.green)
                                .padding(.horizontal, max(3, 5 * s))
                                .padding(.vertical, 1)
                                .background(Color.green.opacity(0.15))
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                        
                        if !viewModel.communityCards.isEmpty {
                            Button(action: {
                                viewModel.clearCommunityCards()
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 11 * fs, weight: .bold))
                                    Text("Xóa hết")
                                        .font(.system(size: 10 * fs, weight: .bold))
                                }
                                .foregroundColor(.red)
                                .padding(.horizontal, max(4, 6 * s))
                                .padding(.vertical, max(1, 2 * s))
                                .background(Color.red.opacity(0.12))
                                .cornerRadius(5)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        Text("\(viewModel.communityCards.count)/\(viewModel.gameType.communityCardsCount) lá")
                            .font(.system(size: 10 * fs, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: max(2, 4 * s)) {
                            ForEach(viewModel.communityCards) { card in
                                MiniCardView(card: card, scale: s) {
                                    viewModel.removeCard(card)
                                }
                            }
                            
                            // Placeholders
                            let remaining = max(0, viewModel.gameType.communityCardsCount - viewModel.communityCards.count)
                            if remaining > 0 {
                                ForEach(0..<remaining, id: \.self) { _ in
                                    CardPlaceholderView(scale: s)
                                }
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }
                .padding(.horizontal, max(5, 8 * s))
                .padding(.vertical, max(2.5, 4 * s))
                .background(isCommSelected ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isCommSelected ? Color.green : Color.orange.opacity(0.3), lineWidth: isCommSelected ? 1.5 : 1)
                )
                .onTapGesture {
                    viewModel.isSelectingCommunity = true
                }
            }
            
            // Player mats
            let allPlayersFull = viewModel.players.indices.allSatisfy { viewModel.players[$0].cards.count >= viewModel.targetCards(for: $0) }
            let commNeedsCards = viewModel.gameType.communityCardsCount > 0 && viewModel.communityCards.count < viewModel.gameType.communityCardsCount
            let isCommActive = commNeedsCards && !viewModel.hasCalculatedResults && (viewModel.isSelectingCommunity || allPlayersFull)

            VStack(spacing: max(3, 5 * s)) {
                ForEach(0..<viewModel.players.count, id: \.self) { idx in
                    let player = viewModel.players[idx]
                    let target = viewModel.targetCards(for: idx)
                    let isWinner = viewModel.hasCalculatedResults && player.rankOrder == 1
                    let isCurrentRoundRobin = viewModel.inputMode == .roundRobin && viewModel.roundRobinPointer == idx && !viewModel.hasCalculatedResults && !allPlayersFull
                    let isManualSelected = viewModel.inputMode == .manual && viewModel.selectedPlayerIndex == idx && !viewModel.isSelectingCommunity && !viewModel.hasCalculatedResults && !isCommActive
                    let isHighlight = isCurrentRoundRobin || isManualSelected || isWinner
                    
                    VStack(alignment: .leading, spacing: max(2, 3 * s)) {
                        HStack {
                            Circle()
                                .fill(isWinner ? Color.yellow : (isHighlight ? Color.green : Color.gray.opacity(0.4)))
                                .frame(width: max(6, 8 * s), height: max(6, 8 * s))
                            
                            Button(action: {
                                editingIndex = idx
                                editingName = player.name
                                isShowingRenameDialog = true
                            }) {
                                HStack(spacing: 3) {
                                    Text(player.name)
                                        .font(.system(size: 13 * fs, weight: .bold))
                                        .foregroundColor(isWinner ? .orange : (isHighlight ? .primary : .secondary))
                                    Image(systemName: "pencil")
                                        .font(.system(size: 9 * fs))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())

                            if viewModel.gameType == .phom9 && idx == 0 {
                                Text("🎴 10 lá")
                                    .font(.system(size: 9 * fs, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, max(3, 5 * s))
                                    .padding(.vertical, max(1, 2 * s))
                                    .background(Color.orange)
                                    .cornerRadius(4)
                            }

                            if player.cards.contains(where: { $0.isHidden }) || player.resultTitle == "???" {
                                HStack(spacing: max(3, 5 * s)) {
                                    Text("???")
                                        .font(.system(size: 11 * fs, weight: .black))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, max(5, 7 * s))
                                        .padding(.vertical, max(1.5, 2.5 * s))
                                        .background(Color.red)
                                        .cornerRadius(5)
                                        .shadow(color: Color.red.opacity(0.4), radius: 2, x: 0, y: 1)
                                    
                                    Text("Không thấy")
                                        .font(.system(size: 11 * fs, weight: .bold))
                                        .foregroundColor(.red)
                                }
                            } else if let rank = player.rankOrder {
                                PlayerRankBadgeView(player: player, rank: rank, isWinner: isWinner, allPlayers: viewModel.players, scale: fs)
                            } else if isHighlight {
                                Text(viewModel.inputMode == .roundRobin ? "▶ Lượt" : "▶ Đang chọn")
                                    .font(.system(size: 9 * fs, weight: .bold))
                                    .foregroundColor(.green)
                                    .padding(.horizontal, max(3, 5 * s))
                                    .padding(.vertical, 1)
                                    .background(Color.green.opacity(0.15))
                                    .cornerRadius(4)
                            }
                            
                            Spacer()
                            
                            // Card counter
                            Text("\(player.cards.count)/\(target)")
                                .font(.system(size: 11 * fs, weight: .semibold))
                                .foregroundColor(player.cards.count == target ? .blue : .secondary)
                        }
                        
                        // Cards display
                        if viewModel.gameType == .chan19 {
                            let columns = [GridItem(.adaptive(minimum: max(18, 28 * s), maximum: max(24, 36 * s)), spacing: max(2, 3 * s))]
                            LazyVGrid(columns: columns, alignment: .leading, spacing: max(2, 3 * s)) {
                                ForEach(player.cards) { card in
                                    MiniCardView(card: card, scale: s) {
                                        viewModel.removeCard(card)
                                    }
                                }
                                let missing = target - player.cards.count
                                if missing > 0 {
                                    ForEach(0..<missing, id: \.self) { _ in
                                        CardPlaceholderView(scale: s)
                                    }
                                }
                            }
                            .padding(.vertical, max(1, 2 * s))
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                if viewModel.gameType == .samLoc10 && player.cards.count == 10 {
                                    let result = SamLocEvaluator.arrange(cards: player.cards)
                                    HStack(spacing: max(3, 6 * s)) {
                                        ForEach(result.groups) { group in
                                            VStack(spacing: max(1, 2 * s)) {
                                                Text(group.title)
                                                    .font(.system(size: 9.5 * fs, weight: .bold))
                                                    .foregroundColor(colorForSamLocGroup(group.type))
                                                
                                                HStack(spacing: max(2, 3 * s)) {
                                                    ForEach(group.cards) { card in
                                                        MiniCardView(card: card, scale: s) {
                                                            viewModel.removeCard(card)
                                                        }
                                                    }
                                                }
                                                .padding(max(2, 3 * s))
                                                .background(Color(.systemBackground).opacity(0.6))
                                                .cornerRadius(6)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .stroke(colorForSamLocGroup(group.type).opacity(0.35), lineWidth: 1)
                                                )
                                            }
                                        }
                                    }
                                    .padding(.vertical, 1)
                                } else if viewModel.gameType == .binh9 {
                                    let chiCount = 3
                                    HStack(spacing: max(4, 8 * s)) {
                                        ForEach(0..<chiCount, id: \.self) { chiIdx in
                                            let startIndex = chiIdx * 3
                                            let chiCards: [Card] = (startIndex < player.cards.count) ?
                                                Array(player.cards[startIndex..<min(startIndex + 3, player.cards.count)]) : []
                                            let missingInChi = 3 - chiCards.count
                                            
                                            VStack(spacing: max(1.5, 3 * s)) {
                                                Text("Chi \(chiIdx + 1)")
                                                    .font(.system(size: 10 * fs, weight: .bold))
                                                    .foregroundColor(.blue)
                                                
                                                HStack(spacing: max(2, 3 * s)) {
                                                    ForEach(chiCards) { card in
                                                        MiniCardView(card: card, scale: s) {
                                                            viewModel.removeCard(card)
                                                        }
                                                    }
                                                    if missingInChi > 0 {
                                                        ForEach(0..<missingInChi, id: \.self) { _ in
                                                            CardPlaceholderView(scale: s)
                                                        }
                                                    }
                                                }
                                                .padding(max(2, 3 * s))
                                                .background(Color(.systemBackground).opacity(0.6))
                                                .cornerRadius(6)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                                                )
                                            }
                                        }
                                    }
                                    .padding(.vertical, 1)
                                } else {
                                    let isLargeCard = (target <= 3 || viewModel.gameType == .xiTo2)
                                    HStack(spacing: max(3, 5 * s)) {
                                        ForEach(player.cards) { card in
                                            MiniCardView(card: card, isLarge: isLargeCard, scale: s) {
                                                viewModel.removeCard(card)
                                            }
                                        }
                                        
                                        // Placeholders (show up to 6 placeholders to save space)
                                        let missing = target - player.cards.count
                                        let showCount = max(0, min(missing, 6))
                                        if showCount > 0 {
                                            ForEach(0..<showCount, id: \.self) { _ in
                                                CardPlaceholderView(isLarge: isLargeCard, scale: s)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 1)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, max(5, 8 * s))
                    .padding(.vertical, max(2.5, 4 * s))
                    .background(
                        isWinner ? Color.yellow.opacity(0.12) :
                        (isHighlight ? Color.accentColor.opacity(0.08) : Color(.secondarySystemBackground))
                    )
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isWinner ? Color.yellow : (isHighlight ? Color.accentColor : Color.clear), lineWidth: 1.5)
                    )
                    .onTapGesture {
                        viewModel.isSelectingCommunity = false
                        if viewModel.inputMode == .manual {
                            viewModel.selectedPlayerIndex = idx
                        }
                    }
                }
            }
        }
        .alert("Đổi Tên Người Chơi", isPresented: $isShowingRenameDialog) {
            TextField("Nhập tên mới", text: $editingName)
            Button("Lưu") {
                viewModel.renamePlayer(at: editingIndex, to: editingName)
            }
            Button("Hủy", role: .cancel) {}
        } message: {
            Text("Nhập tên hiển thị mới cho tụ này:")
        }
    }
    
    private func colorForSamLocGroup(_ type: SamLocGroupType) -> Color {
        switch type {
        case .trash: return .secondary
        case .pair: return .blue
        case .straight: return .green
        case .threeOfAKind: return .purple
        case .fourOfAKind: return .orange
        }
    }
}

struct PlayerRankBadgeView: View {
    let player: Player
    let rank: Int
    let isWinner: Bool
    let allPlayers: [Player]
    var scale: CGFloat = 1.0
    
    private var isTie: Bool {
        allPlayers.filter({ $0.rankOrder == rank }).count > 1
    }
    
    private var badgeText: String {
        switch rank {
        case 1: return isTie ? "👑 Đ.Hạng 1" : "👑 Nhất"
        case 2: return isTie ? "🥈 Đ.Hạng 2" : "🥈 Nhì"
        case 3: return isTie ? "🥉 Đ.Hạng 3" : "🥉 Ba"
        default: return isTie ? "Đ.Hạng \(rank)" : "Hạng \(rank)"
        }
    }
    
    private var badgeBgColor: Color {
        switch rank {
        case 1: return Color(red: 0.95, green: 0.2, blue: 0.2) // Đỏ tươi nổi bật
        case 2: return Color(red: 0.0, green: 0.48, blue: 1.0) // Xanh dương đậm
        case 3: return Color(red: 1.0, green: 0.58, blue: 0.0) // Cam hổ phách
        default: return Color(white: 0.35) // Xám đen đậm
        }
    }
    
    var body: some View {
        HStack(spacing: max(3, 5 * scale)) {
            Text(badgeText)
                .font(.system(size: 11 * scale, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, max(4, 7 * scale))
                .padding(.vertical, max(1.5, 2.5 * scale))
                .background(badgeBgColor)
                .cornerRadius(5)
                .shadow(color: Color.black.opacity(0.18), radius: 1.5, x: 0, y: 1)
            
            if !player.resultTitle.isEmpty {
                Text(player.resultTitle)
                    .font(.system(size: 11 * scale, weight: .bold))
                    .foregroundColor(isWinner ? .orange : .primary)
                    .lineLimit(1)
            }
        }
    }
}

struct MiniCardView: View {
    let card: Card
    var isLarge: Bool = false
    var scale: CGFloat = 1.0
    let onRemove: () -> Void
    
    var body: some View {
        Button(action: onRemove) {
            let baseWidth: CGFloat = isLarge ? 38 : (card.isRankOnly ? 34 : 30)
            let baseHeight: CGFloat = isLarge ? 50 : 42
            let width: CGFloat = baseWidth * scale
            let height: CGFloat = baseHeight * scale
            let rankSize: CGFloat = (isLarge ? 17 : (card.isRankOnly ? 16 : 14)) * scale
            let suitSize: CGFloat = (isLarge ? 13 : 11) * scale
            let radius: CGFloat = max(4, 6 * scale)
            
            if card.isHidden {
                VStack(spacing: 0) {
                    Text("?")
                        .font(.system(size: (isLarge ? 20 : 16) * scale, weight: .black))
                        .foregroundColor(.purple)
                    Text("Ẩn")
                        .font(.system(size: (isLarge ? 10 : 8) * scale, weight: .bold))
                        .foregroundColor(.purple.opacity(0.85))
                }
                .frame(width: width, height: height)
                .background(Color.white)
                .cornerRadius(radius)
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [3]))
                        .foregroundColor(Color.purple.opacity(0.6))
                )
                .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
            } else if card.isRankOnly {
                Text(card.rank.displaySymbol)
                    .font(.system(size: rankSize, weight: .bold))
                    .foregroundColor(card.rank == .ace ? .red : (card.rank == .jack || card.rank == .queen || card.rank == .king ? .blue : .black))
                    .frame(width: width, height: height)
                    .background(Color.white)
                    .cornerRadius(radius)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius)
                            .stroke(Color.gray.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
            } else {
                VStack(spacing: 0) {
                    Text(card.rank.displaySymbol)
                        .font(.system(size: rankSize, weight: .bold))
                        .foregroundColor(card.suit.isRed ? .red : .black)
                    Text(card.suit.rawValue)
                        .font(.system(size: suitSize))
                        .foregroundColor(card.suit.isRed ? .red : .black)
                }
                .frame(width: width, height: height)
                .background(Color.white)
                .cornerRadius(radius)
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CardPlaceholderView: View {
    var isLarge: Bool = false
    var scale: CGFloat = 1.0
    
    var body: some View {
        let width: CGFloat = (isLarge ? 38 : 30) * scale
        let height: CGFloat = (isLarge ? 50 : 42) * scale
        let radius: CGFloat = max(4, 6 * scale)
        RoundedRectangle(cornerRadius: radius)
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [2]))
            .foregroundColor(Color.gray.opacity(0.35))
            .frame(width: width, height: height)
            .overlay(
                Image(systemName: "plus")
                    .font(.system(size: (isLarge ? 12 : 9) * scale))
                    .foregroundColor(Color.gray.opacity(0.4))
            )
    }
}
