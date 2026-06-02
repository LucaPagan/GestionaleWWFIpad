import SwiftData
import SwiftUI

struct GamificationBadgeRow: View {
    let badge: GamificationBadge
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        GamificationBaseRow(
            icon: GamificationAdminTab.badges.icon,
            title: badge.title,
            isActive: badge.isActive,
            subtitle: badge.badgeDescription,
            detail: "\(badge.categoryRawValue) - \(badge.rarityRawValue) - \(badge.xpReward) XP",
            onEdit: onEdit,
            onDelete: onDelete,
            onActiveChange: { badge.isActive = $0 }
        )
    }
}

struct GamificationSpeciesRow: View {
    let species: GamificationSpecies
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        GamificationBaseRow(
            icon: GamificationAdminTab.species.icon,
            title: species.name,
            isActive: species.isActive,
            subtitle: species.scientificName,
            detail: "\(species.categoryRawValue) - \(species.rarityRawValue)",
            onEdit: onEdit,
            onDelete: onDelete,
            onActiveChange: { species.isActive = $0 }
        )
    }
}

struct GamificationLevelRow: View {
    let level: GamificationLevel
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        GamificationBaseRow(
            icon: GamificationAdminTab.levels.icon,
            title: level.title,
            isActive: level.isActive,
            subtitle: level.levelDescription,
            detail: "Livello \(level.levelNumber) - \(level.requiredXP) XP",
            onEdit: onEdit,
            onDelete: onDelete,
            onActiveChange: { level.isActive = $0 }
        )
    }
}

struct GamificationRuleRow: View {
    let rule: GamificationRule
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        GamificationBaseRow(
            icon: GamificationAdminTab.rules.icon,
            title: rule.title,
            isActive: rule.isActive,
            subtitle: rule.ruleDescription,
            detail: "\(rule.triggerTypeRawValue) - audience \(rule.audienceRawValue)",
            onEdit: onEdit,
            onDelete: onDelete,
            onActiveChange: { rule.isActive = $0 }
        )
    }
}

struct GamificationCampaignRow: View {
    let campaign: GamificationCampaign
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        GamificationBaseRow(
            icon: GamificationAdminTab.campaigns.icon,
            title: campaign.title,
            isActive: campaign.isActive,
            subtitle: campaign.campaignDescription,
            detail: "\(campaign.startsAt.formatted(date: .abbreviated, time: .omitted)) - \(campaign.endsAt.formatted(date: .abbreviated, time: .omitted))",
            onEdit: onEdit,
            onDelete: onDelete,
            onActiveChange: { campaign.isActive = $0 }
        )
    }
}

struct GamificationBaseRow: View {
    let icon: String
    let title: String
    let isActive: Bool
    let subtitle: String
    let detail: String
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onActiveChange: (Bool) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color("WWFGreen"))
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                    if !isActive {
                        Text("Inattivo")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("Attivo", isOn: Binding(
                get: { isActive },
                set: { onActiveChange($0) }
            ))
            .labelsHidden()
            Menu {
                Button("Modifica", systemImage: "pencil", action: onEdit)
                Button("Elimina", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
            }
            .accessibilityLabel("Azioni")
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
    }
}
