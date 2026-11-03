import Foundation
import AVFoundation

/// Music files remain separate from effect pools. File I/O, decoding and transport run off the render thread.
final class ArcadeMusic:NSObject,AVAudioPlayerDelegate {
    let allowed:Bool,masterGain:Double,folder:URL?,bundleFolder:URL?
    private let queue=DispatchQueue(label:"deadops.music",qos:.utility),lock=NSLock()
    private var tracks:[MusicTrack]=[],transport=MusicTransport(),player:AVAudioPlayer?,loadedURL:URL?
    private var lastRequest:MusicRequest?,request:MusicRequest?,displayState=MusicDisplay(),plays=0
    private var failures=Set<URL>()
    private var applicationActive=true
    var isApplicationActive:Bool {lock.lock();defer{lock.unlock()};return applicationActive}
    func setApplicationActive(_ active:Bool){
        lock.lock();applicationActive=active;lastRequest=nil;lock.unlock()
        if !active,allowed {queue.async{[weak self] in self?.player?.pause();self?.player?.volume=0}}
    }
    var display:MusicDisplay {lock.lock();defer{lock.unlock()};return displayState}
    var playedCount:Int {lock.lock();defer{lock.unlock()};return plays}
    init(allowed:Bool,masterGain:Double=1,folder:URL?=nil,bundleFolder:URL?=nil){
        self.allowed=allowed;self.masterGain=AudioMix.bounded(masterGain)
        self.folder=folder;self.bundleFolder=bundleFolder
        super.init()
        if allowed {reload()}
    }
    static var userFolder:URL? {
        FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask).first?.appendingPathComponent("DeadOpsReconstruction/Music",isDirectory:true)
    }
    static let extensions=Set(["wav","mp3","m4a","aif","aiff","caf"])
    static func scan(_ folders:[URL])->[MusicTrack] {
        let fm=FileManager.default
        return folders.flatMap{folder in (try? fm.contentsOfDirectory(at:folder,includingPropertiesForKeys:[.isRegularFileKey,.isSymbolicLinkKey],options:[.skipsHiddenFiles])) ?? []}
            .filter{url in guard Self.extensions.contains(url.pathExtension.lowercased()),let v=try? url.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey]) else{return false};return v.isRegularFile==true && v.isSymbolicLink != true}
            .sorted{$0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending}
            .prefix(100).map{MusicTrack(url:$0,title:$0.deletingPathExtension().lastPathComponent)}
    }
    func reload(){guard allowed else{return};queue.async{[weak self] in self?.reloadOnQueue(notice:"")}}
    private func reloadOnQueue(notice:String){
        let before=tracks,selected=loadedURL
        tracks=Self.scan([folder,bundleFolder].compactMap{$0});failures=[];transport.replace(count:tracks.count)
        if let selected,let i=tracks.firstIndex(where:{$0.url==selected}) {while transport.index != i {transport.select(1)}}
        if tracks != before {player?.stop();player=nil;loadedURL=nil}
        publish(notice:notice);apply()
    }
    func select(_ delta:Int){guard allowed else{return};queue.async{[weak self] in guard let self else{return};self.transport.select(delta);self.player?.stop();self.player=nil;self.loadedURL=nil;self.publish(notice:"");self.apply()}}
    func update(_ request:MusicRequest){
        guard allowed else{return};lock.lock();let changed=lastRequest != request;lastRequest=request;lock.unlock();guard changed else{return}
        queue.async{[weak self] in guard let self else{return};self.request=request;self.transport.update(arena:request.arena);self.apply()}
    }
    private func apply(){
        guard let request else{return}
        guard isApplicationActive else{player?.pause();player?.volume=0;publish();return}
        guard transport.shouldPlay(request) else{player?.pause();publish();return}
        // Invalid files are skipped once per reload instead of retried every frame.
        var attempts=0
        while attempts<tracks.count {
            let track=tracks[transport.index]
            if loadedURL==track.url,player != nil {break}
            player?.stop();player=nil;loadedURL=nil
            if !failures.contains(track.url),let p=try? AVAudioPlayer(contentsOf:track.url),p.duration.isFinite,p.duration>0 {
                p.volume=0;p.numberOfLoops = -1;p.delegate=self;p.prepareToPlay();player=p;loadedURL=track.url;break
            }
            failures.insert(track.url);transport.select(1);attempts+=1
        }
        guard let player else{publish(notice:"Musikdateien konnten nicht geladen werden.");return}
        if !player.isPlaying {
            player.volume=0
            if player.play(){lock.lock();plays+=1;lock.unlock()}
            else{publish(notice:"Musikwiedergabe nicht verfügbar.");return}
        }
        player.setVolume(AudioMix.musicGain(level:request.gain,master:masterGain,returning:request.returning),fadeDuration:0.35)
        publish()
    }
    func stop(){guard allowed else{return};queue.async{[weak self] in self?.player?.stop();self?.player?.volume=0}}
    /// Called only after the user chooses files in the native import dialog. Never downloads music.
    func importFiles(_ urls:[URL]){guard allowed,let folder else{return};queue.async{[weak self] in
        guard let self else{return};let fm=FileManager.default;var imported=0,rejected=0
        do{try fm.createDirectory(at:folder,withIntermediateDirectories:true)}catch{self.publish(notice:"Musikordner konnte nicht angelegt werden.");return}
        for source in urls.prefix(100) {
            #if os(macOS)
            let scoped=source.startAccessingSecurityScopedResource();defer{if scoped {source.stopAccessingSecurityScopedResource()}}
            #endif
            guard let attributes=try? source.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey]),attributes.isRegularFile==true,attributes.isSymbolicLink != true,
                  Self.extensions.contains(source.pathExtension.lowercased()),let probe=try? AVAudioFile(forReading:source),probe.length>0,probe.processingFormat.sampleRate>0 else{rejected+=1;continue}
            let ext=source.pathExtension.lowercased(),name=source.deletingPathExtension().lastPathComponent
            var target=folder.appendingPathComponent(name).appendingPathExtension(ext),suffix=2
            while fm.fileExists(atPath:target.path){target=folder.appendingPathComponent("\(name) (\(suffix))").appendingPathExtension(ext);suffix+=1}
            let staging=folder.appendingPathComponent(".import-\(UUID().uuidString).\(ext)")
            do{try fm.copyItem(at:source,to:staging);try fm.moveItem(at:staging,to:target);imported+=1}
            catch{try? fm.removeItem(at:staging);rejected+=1}
        }
        self.reloadOnQueue(notice:"\(imported) Titel hinzugefügt"+(rejected>0 ? " · \(rejected) nicht lesbar":""))
    }}
    private func publish(notice:String?=nil){
        lock.lock();displayState.count=tracks.count;displayState.title=tracks.isEmpty ? "Keine Musik geladen":tracks[transport.index].title
        if let notice {displayState.notice=notice};lock.unlock()
    }
    func audioPlayerDecodeErrorDidOccur(_ player:AVAudioPlayer,error:Error?){skipFailedPlayer(player)}
    func audioPlayerDidFinishPlaying(_ player:AVAudioPlayer,successfully flag:Bool){if !flag {skipFailedPlayer(player)}}
    private func skipFailedPlayer(_ failed:AVAudioPlayer){
        queue.async{[weak self] in
            guard let self,self.player === failed else{return}
            if let url=self.loadedURL {self.failures.insert(url)}
            self.player?.stop();self.player=nil;self.loadedURL=nil;self.transport.select(1)
            self.publish(notice:"Ein Musiktitel konnte nicht weitergespielt werden.");self.apply()
        }
    }
    /// Silent diagnostics only; never called from the rendering callback.
    func diagnostic()->(playing:Bool,position:TimeInterval,volume:Float){queue.sync{(player?.isPlaying ?? false,player?.currentTime ?? 0,player?.volume ?? 0)}}
    func waitForPendingWork(){queue.sync{}}
}
