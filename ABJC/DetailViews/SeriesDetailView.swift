//
//  SeriesDetailView.swift
//  ABJC
//
//  Created by Noah Kamara on 31.10.20.
//

import SwiftUI
import abjc_core
import JellyKit
import URLImage

struct SeriesDetailView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var playerStore: PlayerStore
    
    private let item: API.Models.Item
    private let geo: GeometryProxy
    
    public init(_ item: API.Models.Item, _ geo: GeometryProxy) {
        self.item = item
        self.geo = geo
    }
    
    @State var detailItem: API.Models.Series?
    @State var seasons: [API.Models.Season] = []
    @State var episodes: [API.Models.Episode] = []
    
    @State var images: [API.Models.Image] = []
    @State var similarItems: [API.Models.Item] = []
    
    @State var selectedSeason: Int? = nil
    @State var selectedEpisode: API.Models.Episode? = nil
    
    /// Loads Content From API
    func load() {
        // Fetch Item Detail
        session.api.getSeries(self.item.id) { result in
            switch result {
            case .success(let item): self.detailItem = item
            case .failure(let error): session.alert = AlertError("alerts.apierror", error.localizedDescription)
            }
        }
        
        // Fetch Seasons
        session.api.getSeasons(for: self.item.id) { result in
            switch result {
            case .success(let items):
                self.seasons = items.sorted(by: {$0.index == 0 || $0.index < $1.index})
                self.selectedSeason = self.seasons.isEmpty ? nil : self.seasons.startIndex
            case .failure(let error): session.alert = AlertError("alerts.apierror", error.localizedDescription)
            }
        }
        
        // Fetch Episodes
        session.api.getEpisodes(for: self.item.id) { result in
            switch result {
            case .success(let items):
                self.episodes = items.sorted(by: {$0.parentIndex <= $1.parentIndex && $0.index ?? 0 <= $1.index ?? 0})
                self.selectedEpisode = episodes.first(where: {$0.userData.played != true})
                if selectedEpisode != nil {
                    if let currentSeason = seasons.first(where: {$0.index == selectedEpisode!.parentIndex}) {
                        self.selectedSeason = seasons.firstIndex(of: currentSeason)
                    }
                }
            case .failure(let error): session.alert = AlertError("alerts.apierror", error.localizedDescription)
            }
        }
        
        // Fetch Images for Item
        session.api.getImages(for: self.item.id) { result in
            switch result {
            case .success(let images): self.images = images
            case .failure(let error): session.alert = AlertError("alerts.apierror", error.localizedDescription)
            }
        }
        
        // Fetch Similar Items
        session.api.getSimilar(for: self.item.id) { result in
            switch result {
            case .success(let items): self.similarItems = items
            case .failure(let error): session.alert = AlertError("alerts.apierror", error.localizedDescription)
            }
        }
    }
    
    var body: some View {
        ScrollView([.vertical]) {
            headerView
            episodeView
            infoView
            peopleView
            recommendedView
        }
        .fullScreenCover(item: $playerStore.playItem) {_ in
            PlayerView()
        }
        .onAppear(perform: load)
    }
    
    var headerView: some View {
        VStack(alignment: .leading) {
            Spacer()
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    if selectedEpisode != nil {
                        Text(selectedEpisode!.name)
                            .bold()
                            .font(.title2)
                    } else if selectedSeason != nil {
                        Text("\(item.name) • \(seasons[selectedSeason!].name)")
                            .bold()
                            .font(.title2)
                    } else {
                        Text(item.name)
                            .bold()
                            .font(.title2)
                    }
                    
                    HStack {
                        if selectedEpisode != nil {
                            Text("\(item.name) \(item.year != nil ? String("(\(item.year!))") : "")")
                            Text("•")
                            Text("S\(String(format: "%02d", selectedEpisode!.parentIndex)) E\(String(format: "%02d", selectedEpisode!.index ?? 0))")
                            Spacer()
                        } else {
                            Text(item.year != nil ? String("(\(item.year!))") : "")
                            Spacer()
                        }
                    }.foregroundColor(.secondary)
                }
                Spacer()
                Button(action: {
                    if selectedEpisode != nil {
                        playerStore.play(selectedEpisode!)
                    }
                }) {
                    HStack {
                        Text(self.selectedEpisode != nil ? "buttons.continue" : "buttons.play")
                            .bold()
                            .textCase(.uppercase)
                        if self.selectedEpisode != nil {
                            Text("S\(String(format: "%02d", selectedEpisode!.parentIndex)) E\(String(format: "%02d", selectedEpisode!.index ?? 0))")
                                .bold()
                        }
                        
                    }.frame(width: 400)
                        
                }.foregroundColor(.accentColor)
                .padding(.trailing)
            }
            if item.overview != nil || selectedEpisode?.overview != nil {
                Divider()
                HStack() {
                    Text((selectedEpisode?.overview ?? item.overview) ?? "" )
                }
            }
        }
        .frame(height: geo.size.height)
        .padding(.horizontal, 80)
        .padding(.bottom, 80)
    }
    
    var peopleView: some View {
        Group {
            EmptyView()
            if self.detailItem?.people?.count != 0 {
                Divider().padding(.horizontal, 80)
                PeopleRow(self.detailItem?.people ?? [])
            } else {
                EmptyView()
            }
        }.edgesIgnoringSafeArea(.horizontal)
    }
    
    var episodeView: some View {
        VStack(alignment: .leading) {
            Text(selectedSeason != nil ? seasons[selectedSeason!].name : "EMPTY")
                .font(.title3)
                .padding(.horizontal, 80)
            
            ScrollView([.horizontal]) {
                LazyHStack(alignment: .center, spacing: 48) {
                    if selectedSeason != nil && 0 < selectedSeason! {
                        Button(action: {
                            if selectedSeason != nil {
                                selectedSeason = seasons.index(before: selectedSeason!)
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .imageScale(.large)
                                .font(.title3)
                        }.buttonStyle(PlainButtonStyle())
                    }
                        
                        
                    if selectedSeason != nil {
                        ForEach(episodes.filter({$0.parentIndex == seasons[selectedSeason!].index}), id:\.id) { item in
                            VStack {
                                Button(action: {
                                    self.selectedEpisode = item
                                }) {
                                    EpisodeItem(item)
                                }
                                .buttonStyle(PlainButtonStyle())
                                Text("Episode \(item.index ?? 0)")
                                    .font(.callout).foregroundColor(.secondary)
                                Text(item.name).bold()
                                    .padding(.bottom, 5)
                                    .frame(width: 548)
                            }.padding(.vertical)
                        }
                    }
                    
                    if selectedSeason != nil && seasons.indices.last! > selectedSeason! {
                        Button(action: {
                            if selectedSeason != nil {
                                selectedSeason = seasons.index(after: selectedSeason!)
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .imageScale(.large)
                                .font(.title3)
                        }.buttonStyle(PlainButtonStyle())
                        .padding(.trailing, 80)
                    }
                }
                .frame(minHeight: 548*9/16)
                .padding(.leading, 80)
                .padding(.bottom, 50)
                .padding(.top, 40)
            }
        }
    }
    
    var infoView: some View {
        VStack {
            EmptyView()
        }
    }
    
    var recommendedView: some View {
        Group {
            if self.similarItems.count != 0 {
                Divider().padding(.horizontal, 80)
                MediaItemRow("itemdetail.recommended.label", self.similarItems)
            } else {
                EmptyView()
            }
        }
    }
}
