import SwiftUI

struct GamificationDashboardView: View {
    let analytics: GamificationAnalytics

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 12)], spacing: 12) {
                ForEach(analytics.metrics) { metric in
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: metric.icon)
                            .font(.title2)
                            .foregroundColor(Color("WWFGreen"))
                        Text(metric.value)
                            .font(.largeTitle.bold())
                        Text(metric.title)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                }
            }
            .padding()

            VStack(spacing: 14) {
                rankingSection("Badge piu sbloccati", rows: analytics.badges, icon: "rosette")
                rankingSection("Specie piu scoperte", rows: analytics.species, icon: "leaf.fill")
                rankingSection("Percorsi piu completati", rows: analytics.trails, icon: "figure.hiking")
                rankingSection("Eventi completati", rows: analytics.events, icon: "calendar.badge.checkmark")
                suspiciousSection
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func rankingSection(_ title: String, rows: [AnalyticsRankRow], icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
            if rows.isEmpty {
                Text("Nessun dato disponibile.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(rows) { row in
                    HStack {
                        Text(row.title)
                        Spacer()
                        Text("\(row.count)")
                            .font(.headline)
                            .foregroundColor(Color("WWFGreen"))
                    }
                    .font(.subheadline)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var suspiciousSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Log sospetti recenti", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
            if analytics.suspiciousLogs.isEmpty {
                Text("Nessun log warning o rejected.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(analytics.suspiciousLogs.enumerated()), id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(rowString(row, "event_type") ?? "Evento")
                            .font(.subheadline.weight(.semibold))
                        Text(rowString(row, "reason") ?? rowString(row, "status") ?? "Controllo automatico")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

