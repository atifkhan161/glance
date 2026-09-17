import SwiftUI

// MARK: - Madrid Skeleton

struct MadridSkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle()
                .fill(Theme.Colors.surface2)
                .frame(height: 28)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            HStack(spacing: 8) {
                Rectangle()
                    .fill(Theme.Colors.surface2)
                    .frame(height: 20)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Rectangle()
                    .fill(Theme.Colors.surface2)
                    .frame(height: 20)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            VStack(alignment: .leading, spacing: 8) {
                Rectangle()
                    .fill(Theme.Colors.surface2)
                    .frame(height: 14)
                    .frame(maxWidth: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Rectangle()
                    .fill(Theme.Colors.surface2)
                    .frame(height: 14)
                    .frame(maxWidth: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Rectangle()
                    .fill(Theme.Colors.surface2)
                    .frame(height: 14)
                    .frame(maxWidth: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.surface2)
                        .frame(width: 32, height: 32)
                }
            }
        }
        .padding(Theme.cardPadding)
        .shimmer()
        .accessibilityHidden(true)
    }
}

// MARK: - PoGo Skeleton

struct PoGoSkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.Colors.surface2)
                .frame(height: 120)

            ForEach(0..<5, id: \.self) { _ in
                Rectangle()
                    .fill(Theme.Colors.surface2)
                    .frame(height: 16)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(Theme.cardPadding)
        .shimmer()
        .accessibilityHidden(true)
    }
}

// MARK: - GitHub Skeleton

struct GitHubSkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle()
                        .fill(Theme.Colors.surface2)
                        .frame(height: 16)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            ForEach(0..<6, id: \.self) { _ in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Theme.Colors.surface2)
                        .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 6) {
                        Rectangle()
                            .fill(Theme.Colors.surface2)
                            .frame(height: 14)
                            .frame(maxWidth: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Rectangle()
                            .fill(Theme.Colors.surface2)
                            .frame(height: 12)
                            .frame(maxWidth: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
        }
        .padding(Theme.cardPadding)
        .shimmer()
        .accessibilityHidden(true)
    }
}

// MARK: - AI Intel Skeleton

struct AIIntelSkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.surface2)
                        .frame(width: 60, height: 18)

                    Rectangle()
                        .fill(Theme.Colors.surface2)
                        .frame(height: 16)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    Rectangle()
                        .fill(Theme.Colors.surface2)
                        .frame(height: 12)
                        .frame(maxWidth: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    Rectangle()
                        .fill(Theme.Colors.surface2)
                        .frame(height: 12)
                        .frame(maxWidth: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
        .padding(Theme.cardPadding)
        .shimmer()
        .accessibilityHidden(true)
    }
}

// MARK: - Custom RSS Skeleton

struct CustomRSSSkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Theme.Colors.surface2)
                    .frame(width: 8, height: 8)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.surface2)
                    .frame(width: 50, height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.surface2)
                    .frame(width: 80, height: 12)
                Spacer()
            }
            .padding(.horizontal, Theme.cardPadding)
            .padding(.top, Theme.cardPadding)
            .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 4) {
                        Rectangle()
                            .fill(Theme.Colors.surface2)
                            .frame(height: 12)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Rectangle()
                            .fill(Theme.Colors.surface2)
                            .frame(height: 10)
                            .frame(maxWidth: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
            .padding(.horizontal, Theme.cardPadding)
            .padding(.bottom, 8)
        }
        .shimmer()
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 24) {
        MadridSkeletonView()
        PoGoSkeletonView()
        GitHubSkeletonView()
        AIIntelSkeletonView()
        CustomRSSSkeletonView()
    }
    .padding()
    .background(Theme.canvas)
}
