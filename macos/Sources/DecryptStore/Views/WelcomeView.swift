import SwiftUI

struct WelcomeView: View {
    @Bindable var store: Store
    private let columns = [GridItem(.adaptive(minimum: 260), spacing: 18)]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                hero
                if !store.popular.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        heading("Popular right now", subtitle: "A fresh look at Apple’s top free apps.")
                        GlassEffectContainer(spacing: 18) {
                            HStack(spacing: 18) {
                                ForEach(Array(store.popular.prefix(3).enumerated()), id: \.element.id) { rank, item in
                                    featured(item, rank: rank)
                                }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            heading("Top charts", subtitle: "Top free iPhone & iPad apps · United States")
                            Spacer()
                            Button { Task { await store.loadChart() } } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.glass).disabled(store.chartLoading).help("Refresh Apple’s chart")
                        }
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 0) {
                            ForEach(Array(store.popular.enumerated()), id: \.element.id) { rank, item in
                                Button { store.openPopular(item) } label: {
                                    HStack(spacing: 12) {
                                        Text("\(rank + 1)").font(.title3.weight(.semibold)).foregroundStyle(.secondary).frame(width: 24)
                                        AppArtwork(url: item.artworkUrl100, size: 52)
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(item.name).font(.headline).lineLimit(1)
                                            Text(item.artistName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                        }
                                        Spacer(minLength: 4)
                                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                                    }.padding(.vertical, 15).padding(.trailing, 12).contentShape(.rect)
                                }.buttonStyle(.plain).disabled(store.openingPopular != nil)
                                    .overlay(alignment: .bottom) { Divider().padding(.leading, 36) }
                            }
                        }
                        Text("Live chart supplied by Apple. Rankings and availability vary by storefront. Updated \(store.chartUpdated)")
                            .font(.caption2).foregroundStyle(.tertiary).textSelection(.enabled)
                    }
                } else if store.chartLoading {
                    ProgressView("Loading Apple’s latest chart…").frame(maxWidth: .infinity).padding(35)
                } else if let error = store.chartError {
                    HStack { Text(error).foregroundStyle(.secondary); Spacer(); Button("Try again") { Task { await store.loadChart() } } }.padding(22).glassEffect(in: .rect(cornerRadius: 20))
                }
                platforms
            }.padding(.horizontal, 28).padding(.bottom, 32)
        }
        .task { if store.popular.isEmpty { await store.loadChart() } }
        .overlay { if store.openingPopular != nil { ProgressView("Opening app…").padding(24).glassEffect(in: .rect(cornerRadius: 20)) } }
    }
    private var hero: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text("THE APP STORE, ON YOUR TERMS").font(.caption.weight(.semibold)).tracking(1.5).foregroundStyle(.secondary)
                Text("Great apps.\nAll in one place.").font(.system(size: 42, weight: .bold, design: .rounded)).tracking(-1.4).fixedSize(horizontal: false, vertical: true)
                Text("Discover what’s popular. Explore every platform.\nKeep your collection close.").font(.title3).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    Button { store.importIPA() } label: { Label("Open an IPA", systemImage: "plus") }.buttonStyle(.glassProminent)
                    Button { store.section = "Library" } label: { Label("Your library", systemImage: "square.stack.3d.up") }.buttonStyle(.glass)
                }.controlSize(.large).padding(.top, 8)
            }
            Spacer(minLength: 0)
            heroArtwork.frame(width: 235, height: 235)
        }.padding(30).frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 30).fill(.quaternary.opacity(0.25))
                    .overlay {
                        GeometryReader { geometry in
                            Circle().fill(Color.blue.opacity(0.15)).frame(width: 280).blur(radius: 65).offset(x: geometry.size.width - 260, y: -60)
                            Circle().fill(Color.purple.opacity(0.12)).frame(width: 220).blur(radius: 55).offset(x: geometry.size.width - 380, y: 110)
                        }.clipped()
                    }
            }.clipShape(.rect(cornerRadius: 30))
    }
    private var heroArtwork: some View {
        GlassEffectContainer(spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 38).fill(.clear).frame(width: 154, height: 154).glassEffect(.regular, in: .rect(cornerRadius: 38)).rotationEffect(.degrees(-14)).offset(x: -24, y: -25)
                Image(systemName: "square.stack.3d.up.fill").font(.system(size: 75, weight: .light)).foregroundStyle(.blue.gradient).frame(width: 154, height: 154).glassEffect(.regular, in: .rect(cornerRadius: 38)).rotationEffect(.degrees(9)).offset(x: 25, y: 21)
                Image(systemName: "arrow.down").font(.title2.weight(.semibold)).foregroundStyle(.blue).frame(width: 52, height: 52).glassEffect(.regular, in: .circle).offset(x: 80, y: -73)
            }
        }.accessibilityHidden(true)
    }
    private func featured(_ item: PopularApp, rank: Int) -> some View {
        Button { store.openPopular(item) } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("CHART NO. \(rank + 1)").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "arrow.up.right").foregroundStyle(.secondary)
                }
                AppArtwork(url: item.artworkUrl100, size: 70).shadow(color: .black.opacity(0.12), radius: 12, y: 6)
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.name).font(.title3.bold()).lineLimit(2).frame(height: 46, alignment: .top)
                    Text(item.artistName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
        }.buttonStyle(.plain).disabled(store.openingPopular != nil)
    }
    private var platforms: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Beyond one device", subtitle: "Find the right app for every screen.")
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    ForEach(Platform.allCases) { platform in
                        Button { store.platform = platform } label: {
                            VStack(spacing: 10) {
                                Image(systemName: platform.symbol).font(.title2)
                                Text(platform.title).font(.caption.weight(.medium))
                            }.frame(maxWidth: .infinity).padding(.vertical, 20)
                                .glassEffect(.regular.tint(store.platform == platform ? .blue.opacity(0.14) : .clear).interactive(), in: .rect(cornerRadius: 20))
                        }.buttonStyle(.plain).help("Search \(platform.title) apps using the search field above")
                    }
                }
            }
        }
    }
    private func heading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) { Text(title).font(.title2.bold()); Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
    }
}
