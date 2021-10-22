//
//  ContentView.swift
//  EmojiArt
//
//  Created by Ksenia Surikova on 21.10.2021.
//

import SwiftUI

struct EmojiArtDocumentView: View {
    @ObservedObject var document: EmojiArtDocument
    
    let testEmojis = "😀😷🦠💉👻👀🐶🌲🌎🌞🔥🍎⚽️🚗🚓🚲🛩🚁🚀🛸🏠⌚️🎁🗝🔐❤️⛔️❌❓✅⚠️🎶➕➖🏳️"
    let defaultEmojiFontSize: CGFloat = 40
    
    
    //MARK: view
    var body: some View {
        VStack(spacing: 0) {
            documentBody
            palette
        }
    }
    
    var documentBody: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white.overlay(
                    OptionalImage(uiImage: document.backgroundImage)
                      .scaleEffect(zoomScale)
                   //     .scaleEffect(
                   //         selectedEmojis.count == 0 ? zoomScale : 1)
                     //   .scaleEffect(
                     //       selectedEmojis.count == 0 ? zoomScale : previousBackgroundScale)
                        .position(convertFromEmojiCoordinates((0,0), in: geometry))
                ).gesture( doubleTapToZoom(in: geometry.size).exclusively(before: tapToDeselectAllEmojis()))
                
                if document.backgroundImageFetchStatus == .fetching {
                    ProgressView().scaleEffect(2)
                } else {
                    ForEach(document.emojis) {
                        emoji in
                        Text(emoji.text)
                            .font(.system(size: fontSize(for: emoji)))
                            .padding(.all, 1)
                            .overlay(
                                Circle().stroke(Color.red, lineWidth: selectedEmojis.contains(emoji) ? 1 : 0)
                            )
                            .scaleEffect(zoomScale)
                            //.scaleEffect(selectedEmojis.contains(emoji) ? zoomScale : 1)
                        
                          //  .scaleEffect(selectedEmojis.contains(emoji) ? zoomScale : getPreviousScale(for: emoji))
                            .position(position(for: emoji, in: geometry))
                            .gesture(tapToToggle(emoji: emoji))
                            //.gesture(panGesture().simultaneously(with:tapToToggle(emoji: emoji)))
                    }
                }
            }
            .clipped()
            .onDrop(of: [.plainText, .url, .image], isTargeted: nil){
                providers, location in
                return drop(providers: providers, at: location, in: geometry)
            }
            .gesture(panGesture().simultaneously(with: zoomGesture()))
        }
    }
    

    
    var palette: some View {
        ScrollingEmojisView(emojis: testEmojis)
            .font(.system(size: defaultEmojiFontSize))
    }
    

    
    //MARK: fill document: background and emojis
    private func drop(providers: [NSItemProvider], at location: CGPoint, in geometry: GeometryProxy) -> Bool{
        var found = providers.loadObjects(ofType: URL.self) { url in
            document.setBackground(EmojiArtModel.Background.url(url.imageURL))
        }
        if (!found){
            found = providers.loadObjects(ofType: UIImage.self) { image in
                if let data = image.jpegData(compressionQuality: 1.0) {
                    document.setBackground(.imageData(data))
                }
            }
        }
        if !found {
            found = providers.loadObjects(ofType: String.self) { string in
                if let emoji = string.first, emoji.isEmoji {
                    document.addEmoji(
                        String(emoji),
                        at: convertToEmojiCoordinates(location, in: geometry),
                        size: defaultEmojiFontSize / zoomScale
                    )
                }
            }
        }
        return found
    }
                                     
    //MARK: Positioning
    private func position (for emoji: EmojiArtModel.Emoji, in geometry: GeometryProxy) -> CGPoint {
        convertFromEmojiCoordinates((emoji.x, emoji.y), in: geometry)
    }
                                     
    private func convertToEmojiCoordinates(_ location: CGPoint, in geometry: GeometryProxy) ->  (x: Int, y: Int){
        let center = geometry.frame(in: .local).center
        let location = CGPoint (
            x: (location.x - panOffest.width - center.x) / zoomScale,
            y: (location.y - panOffest.height - center.y) / zoomScale)
        return (Int(location.x), Int(location.y))
        }
    
    private func convertFromEmojiCoordinates(_ location: (x: Int, y: Int), in geometry: GeometryProxy)->
    CGPoint {
        let center = geometry.frame(in: .local).center
        return CGPoint(
            x: center.x + CGFloat(location.x) * zoomScale + panOffest.width,
            y: center.x + CGFloat(location.y) * zoomScale + panOffest.height
            )
    }
    
    private func fontSize(for emoji: EmojiArtModel.Emoji) -> CGFloat {
        CGFloat(emoji.size)
    }
    
    //Mark: TAP GESTURE
    @State private var selectedEmojis = Set<EmojiArtModel.Emoji>()
    @State private var emojisScale = Dictionary<EmojiArtModel.Emoji, CGFloat>()
    @State private var previousBackgroundScale : CGFloat = 1
    
    private func toggleEmoji(_ emoji: EmojiArtModel.Emoji){
        selectedEmojis.toggleMembership(of: emoji)
        if selectedEmojis.count == 1 {
            previousBackgroundScale = zoomScale
        }
    }
    
    private func tapToToggle(emoji: EmojiArtModel.Emoji) -> some Gesture {
        TapGesture(count: 1)
            .onEnded{
                toggleEmoji(emoji)
               
            }
    }
    
    private func doubleTapToZoom(in size: CGSize) -> some Gesture {
        TapGesture(count: 2)
            .onEnded{
                //print("double tap on background")
                withAnimation{
                zoomToFit(document.backgroundImage, in: size)
                }
            }
    }
    
    private func tapToDeselectAllEmojis() -> some Gesture {
        TapGesture(count: 1)
            .onEnded{
                // попробуем запомнить зум
                for key in emojisScale.keys.filter({ emoji in
                    selectedEmojis.contains(emoji)
                }){
                   emojisScale[key] = zoomScale
                }
                //print("we deselect all emojis")
                    selectedEmojis.removeAll()
            }
    }
    
    private func getPreviousScale(for emoji: EmojiArtModel.Emoji) -> CGFloat {
        if let scale =  emojisScale[emoji] {
            return scale
        }
        else {
            return CGFloat(1)
        }
    }
    
    
    // MARK: Drag - moving
    @State private var steadyStatePanOffset: CGSize = CGSize.zero
    @GestureState private var gesturePanOffset: CGSize = CGSize.zero
    
    private var panOffest: CGSize {
        (steadyStatePanOffset + gesturePanOffset) * zoomScale
    }
    
    private func panGesture() -> some Gesture {
        DragGesture()
            .updating($gesturePanOffset) { latestDragGestureValue, gesturePanOffset, _ in
                gesturePanOffset = latestDragGestureValue.translation / zoomScale
            }
            .onEnded {
                finalDragGestureValue in
                steadyStatePanOffset = steadyStatePanOffset + (finalDragGestureValue.translation / zoomScale)
            }
    }
    
    //MARK: Pinch - zoom
    @State private var steadyStateZoomScale: CGFloat = 1
    // didSet?
//        didSet {
//        }
    
    @GestureState private var gestureZoomScale: CGFloat = 1
    
    private var zoomScale: CGFloat {
        steadyStateZoomScale * gestureZoomScale
    }
    
    @State private var previousZoomScaleBackground: CGFloat = 1
    @State private var previousZoomScaleEmojis: CGFloat = 1
    
    private func zoomToFit(_ image : UIImage?, in size: CGSize){
        if let image = image, image.size.width > 0, image.size.height > 0, size.width > 0, size.height > 0 {
            let hZoom = size.width / image.size.width
            let vZoom = size.height / image.size.height
            steadyStatePanOffset = .zero
            steadyStateZoomScale = min(hZoom, vZoom)
        }
    }
    
    private func zoomGesture() -> some Gesture {
        MagnificationGesture()
            .updating($gestureZoomScale) { latestGestureScale, gestureZoomScale, _ in
                gestureZoomScale = latestGestureScale
            }
            .onEnded {
                gestureScaleAtEnd in
                steadyStateZoomScale *= gestureScaleAtEnd
            }
    }
}

struct ScrollingEmojisView: View {
    
    let emojis: String
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(emojis.map{String($0)}, id: \.self) {
                    emoji in Text(emoji)
                        .onDrag {
                        NSItemProvider(object: emoji as NSString)
                    }
                }
                
            }
        }
    }
}






struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        EmojiArtDocumentView(document: EmojiArtDocument())
    }
}