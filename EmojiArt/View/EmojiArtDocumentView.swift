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
                        .scaleEffect(zoomBackgroundScale)
                        .position(convertFromEmojiCoordinates((0,0), offset: panBackgroundOffset, zoomScale: zoomBackgroundScale, in: geometry))
                ).gesture( doubleTapToZoom(in: geometry.size).exclusively(before: tapToDeselectAllEmojis()))
                
                if document.backgroundImageFetchStatus == .fetching {
                    ProgressView().scaleEffect(2)
                } else {
                    ForEach(document.emojis) {
                        emoji in
                        if selectedEmojis.contains(emoji){
                            geEmojiView(for: emoji, in: geometry, withSelection: true)
                                .gesture(panSelectedEmojiGesture())
                        }
                        else {
                            geEmojiView(for: emoji, in: geometry, withSelection: false)
                        }
                    }
                }
            }
            .clipped()
            .onDrop(of: [.plainText, .url, .image], isTargeted: nil){
                providers, location in
                return drop(providers: providers, at: location, in: geometry)
            }
            .gesture(panBackgroundGesture().simultaneously(with: zoomGesture()))
        }
    }
    
    
    private func geEmojiView(for emoji: EmojiArtModel.Emoji, in geometry: GeometryProxy, withSelection: Bool)-> some View  {

        Text(emoji.text)
            .font(.system(size: fontSize(for: emoji)))
            .padding(.all, 1)
            .overlay(
                Circle().stroke(Color.red, lineWidth: withSelection ? 1 : 0)
            )
            .scaleEffect(getScaleForEmoji(emoji: emoji))
            .position(position(for: emoji, in: geometry))
            .gesture(tapToToggle(emoji: emoji).simultaneously(with: longPressToDelete(emoji: emoji)))
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
                    let newEmoji = document.addEmoji(
                        String(emoji),
                        at: convertToEmojiCoordinates(location, offset: CGSize.zero, zoomScale: zoomBackgroundScale, in: geometry),
                        size: defaultEmojiFontSize / zoomBackgroundScale
                    )
                  //  emojisCurrentOffset[newEmoji] = panBackgroundOffset
                    emojisCurrentScale[newEmoji] = zoomBackgroundScale
                }
            }
        }
        return found
    }
                                     
    //MARK: Positioning
    private func position (for emoji: EmojiArtModel.Emoji, in geometry: GeometryProxy) -> CGPoint {
        //print("pos \(emoji.text) x and y : \(emoji.x) \(emoji.y)")
        let position = convertFromEmojiCoordinates((emoji.x, emoji.y),
                                           offset: getOffsetForEmoji(emoji: emoji),
                                           zoomScale: getScaleForEmoji(emoji: emoji),
                                           in: geometry)
        //print("pos \(emoji.text) \(position.x) \(position.y) offset \(getOffsetForEmoji(emoji: emoji)) scale \(getScaleForEmoji(emoji: emoji))")
        return position
    }
                                     
    private func convertToEmojiCoordinates(_ location: CGPoint, offset: CGSize, zoomScale: CGFloat,  in geometry: GeometryProxy) ->  (x: Int, y: Int){
        let center = geometry.frame(in: .local).center
        //print("location for new emoji: \(location.x) \(location.y)")
        let location = CGPoint (
            x: (location.x - center.x - offset.width) / zoomScale ,
            y: (location.y - center.y - offset.height) / zoomScale)
        //print("x and y : \(location.x) \(location.y)")
        return (Int(location.x), Int(location.y))
        }
    
    
    private func convertFromEmojiCoordinates(_ location: (x: Int, y: Int), offset: CGSize, zoomScale: CGFloat,  in geometry: GeometryProxy)->
    CGPoint {
        let center = geometry.frame(in: .local).center
        return CGPoint(
            x: center.x + CGFloat(location.x) * zoomScale + offset.width,
            y: center.y + CGFloat(location.y) * zoomScale + offset.height
            )
    }
    
    private func fontSize(for emoji: EmojiArtModel.Emoji) -> CGFloat {
        CGFloat(emoji.size)
    }
    
    // MARK: Tap gesture
    @State private var selectedEmojis = Set<EmojiArtModel.Emoji>()
    
    private func toggleEmoji(_ emoji: EmojiArtModel.Emoji){
        selectedEmojis.toggleMembership(of: emoji)
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
                withAnimation{
                zoomToFit(document.backgroundImage, in: size)
                }
            }
    }
    
    private func tapToDeselectAllEmojis() -> some Gesture {
        TapGesture(count: 1)
            .onEnded{
                    selectedEmojis.removeAll()
            }
    }
    
    //MARK: Long press gesture to delete emoji
    private func longPressToDelete(emoji: EmojiArtModel.Emoji) -> some Gesture {
        LongPressGesture(minimumDuration: 1).onEnded{ _ in
            document.removeEmoji(emoji)
        }
    }

    
    
    // MARK: Current offset for emojis
    @State var emojisCurrentOffset: Dictionary<EmojiArtModel.Emoji, CGSize> = Dictionary<EmojiArtModel.Emoji, CGSize>()
   
    
    private func getOffsetForEmoji(emoji: EmojiArtModel.Emoji) -> CGSize {
        let zoomScale = getScaleForEmoji(emoji: emoji)
        let currentOffset = emojisCurrentOffset[emoji] ?? CGSize.zero
        if selectedEmojis.contains(emoji) {
            return (currentOffset + (gestureSelectedEmojiPanOffset[emoji] ?? CGSize.zero)) * zoomScale
        }
        else {
            return (currentOffset + gesturePanBackgroundOffset) * zoomScale
        }
    }
    
    
    // MARK: Drag - moving background and unselected emojis
    @State private var steadyStatePanBackgroundOffset: CGSize = CGSize.zero
    @GestureState private var gesturePanBackgroundOffset: CGSize = CGSize.zero
    
    

    private var panBackgroundOffset: CGSize {
        (steadyStatePanBackgroundOffset + gesturePanBackgroundOffset) * zoomBackgroundScale
    }

    private func panBackgroundGesture() -> some Gesture {
        DragGesture()
            .updating($gesturePanBackgroundOffset) { latestDragGestureValue, gesturePanOffset, _ in
                gesturePanOffset = latestDragGestureValue.translation / zoomBackgroundScale
            }
            .onEnded {
                finalDragGestureValue in
                steadyStatePanBackgroundOffset = steadyStatePanBackgroundOffset + finalDragGestureValue.translation/zoomBackgroundScale
                document.emojis.filter{!selectedEmojis.contains($0)}.forEach  {
                    let previousOffset =  emojisCurrentOffset[$0] ?? CGSize.zero
                    emojisCurrentOffset[$0] = previousOffset + finalDragGestureValue.translation/zoomBackgroundScale
                }
            }
    }

    // MARK: Drag - movind only selected emojis
    @GestureState private var gestureSelectedEmojiPanOffset: Dictionary<EmojiArtModel.Emoji, CGSize> = Dictionary<EmojiArtModel.Emoji, CGSize>()

    private func panSelectedEmojiGesture() -> some Gesture {
        DragGesture()
            .updating($gestureSelectedEmojiPanOffset) { latestDragGestureValue, gesturePanOffset, _ in
                
                selectedEmojis.forEach {
                    gesturePanOffset[$0] = latestDragGestureValue.translation / (emojisCurrentScale[$0] ?? 1)
                }
       
            }
            .onEnded {
                finalDragGestureValue in
                selectedEmojis.forEach {
                    let previousOffset =  emojisCurrentOffset[$0] ?? CGSize.zero
                    let emojisCurrentScale = emojisCurrentScale[$0] ?? 1
                    emojisCurrentOffset[$0] = previousOffset + finalDragGestureValue.translation / emojisCurrentScale
                }
            }
    }
    
    //MARK: Pinch - zoom
    @State var emojisCurrentScale = Dictionary<EmojiArtModel.Emoji, CGFloat>()
    
    
    @State private var steadyStateZoomScale: CGFloat = 1
    @GestureState private var gestureZoomScale: CGFloat = 1
    
    
    private func getScaleForEmoji(emoji: EmojiArtModel.Emoji) -> CGFloat {
        let currentScale = emojisCurrentScale[emoji] ?? 1
        if selectedEmojis.contains(emoji) {
            return currentScale * gestureZoomScale
        }
        else {
            return selectedEmojis.count == 0 ? currentScale * gestureZoomScale : currentScale
        }
    }
    

    private var zoomBackgroundScale: CGFloat {
        selectedEmojis.count == 0 ?
        steadyStateZoomScale * gestureZoomScale :
        steadyStateZoomScale
    }

    
    private func zoomToFit(_ image : UIImage?, in size: CGSize){
        if let image = image, image.size.width > 0, image.size.height > 0, size.width > 0, size.height > 0 {
            let hZoom = size.width / image.size.width
            let vZoom = size.height / image.size.height
            steadyStatePanBackgroundOffset = .zero
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
                if selectedEmojis.count == 0 {
                    steadyStateZoomScale *= gestureScaleAtEnd
                    // all emojis - same zoom
                    document.emojis.forEach {
                        emojisCurrentScale[$0] = (emojisCurrentScale[$0] ?? 1) * gestureScaleAtEnd
                    }
                }
                // else zoom for selected emojis
                else {
                    selectedEmojis.forEach {
                        emojisCurrentScale[$0] = (emojisCurrentScale[$0] ?? 1) * gestureScaleAtEnd
                    }
                }
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
