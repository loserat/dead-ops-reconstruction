import Foundation
import AVFoundation

struct AudioStatus {var voiceCount=0,playingVoiceCount=0,playedCount=0,loopVoiceCount=0,playingLoopVoiceCount=0,preparedLoopKinds=0;var volumesAreZero=true}
/// All synthesis, decoding and audio-player mutations belong to this queue, never the render callback.
final class ArcadeAudio {
    let allowed:Bool,masterGain:Float
    private let queue=DispatchQueue(label:"deadops.effects",qos:.userInitiated),lock=NSLock()
    private var voices:[AudioCue:[AVAudioPlayer]]=[:],lastPlay:[AudioCue:Double]=[:]
    private var voiceAttenuation=[ObjectIdentifier:Double](),loopAttenuation=[AudioLoopKey:Double]()
    private var loopPayloads:[AudioLoopKind:Data]=[:],loopPlayers:[AudioLoopKey:AVAudioPlayer]=[:]
    private struct RetiringLoop {let key:AudioLoopKey,player:AVAudioPlayer,until:TimeInterval,attenuation:Double}
    private var retiringLoops=[RetiringLoop](),loopTransport=AudioLoopTransport()
    private var loopMixTimer:DispatchSourceTimer?
    private var lastLoops=[AudioLoopRequest]()
    private var state=AudioStatus(),lastEnabled=false,lastLevel = -1.0
    private var lastPhase:RunPhase?
    private var applicationActive=true
    private var enabled=false,level=1.0,plays=0
    var voiceCount:Int {status.voiceCount}
    var playingVoiceCount:Int {status.playingVoiceCount}
    var playedCount:Int {status.playedCount}
    var loopVoiceCount:Int {status.loopVoiceCount}
    var volumesAreZero:Bool {status.volumesAreZero}
    var status:AudioStatus {lock.lock();defer{lock.unlock()};return state}
    var isApplicationActive:Bool {lock.lock();defer{lock.unlock()};return applicationActive}
    /// Lifecycle callbacks can silence output even if SceneKit stops requesting frames.
    func setApplicationActive(_ active:Bool){
        lock.lock();applicationActive=active;lastEnabled=false;lastLevel = -1;lastLoops=[];lastPhase=nil;lock.unlock()
        if !active,allowed {queue.async{[weak self] in self?.stopVoices()}}
    }
    init(allowed:Bool,masterGain:Float=1){
        self.allowed=allowed;self.masterGain=Float(AudioMix.bounded(Double(masterGain)))
        if allowed {queue.async{[weak self] in self?.prepare()}}
    }
    deinit {loopMixTimer?.cancel()}
    private func prepare(){
        #if !os(macOS)
        try? AVAudioSession.sharedInstance().setCategory(.ambient,mode:.default)
        #endif
        for cue in AudioCue.allCases {
            let data=AudioSynth.wav(cue)
            voices[cue]=(0..<cue.poolSize).compactMap{_ in
                guard let p=try? AVAudioPlayer(data:data,fileTypeHint:AVFileType.wav.rawValue) else{return nil}
                p.volume=0;p.prepareToPlay();return p
            }
        }
        for kind in AudioLoopKind.allCases {loopPayloads[kind]=AudioLoopSynth.wav(kind)}
        publish()
    }
    func stop(){
        guard allowed else{return}
        lock.lock();lastEnabled=false;lastLevel = -1;lastLoops=[];lastPhase=nil;lock.unlock()
        queue.async{[weak self] in self?.stopVoices()}
    }
    private func stopVoices(){
        for p in voices.values.flatMap({$0})+Array(loopPlayers.values)+retiringLoops.map(\.player) {p.stop();p.volume=0}
        loopMixTimer?.cancel();loopMixTimer=nil
        loopPlayers=[:];loopAttenuation=[:];voiceAttenuation=[:];retiringLoops=[];_=loopTransport.update([]);lastPlay=[:];publish()
    }
    func play(_ cues:[AudioCue],enabled:Bool,phase:RunPhase,now:Double,effectsGain:Double=1,loops:[AudioLoopRequest]=[],placements:[AudioCue:AudioPlacement]=[:]){
        guard allowed else{return}
        let active=enabled && isApplicationActive && phase != .paused && phase != .title,level=AudioMix.bounded(effectsGain)
        let wanted=AudioLoopPolicy.normalized(loops,enabled:enabled,phase:phase,level:level)
        lock.lock();let changed=active != lastEnabled || level != lastLevel || wanted != lastLoops || phase != lastPhase;lastEnabled=active;lastLevel=level;lastLoops=wanted;lastPhase=phase;lock.unlock()
        guard changed || !cues.isEmpty else{return}
        queue.async{[weak self] in
            guard let self else{return};self.enabled=active;self.level=level
            guard active,level>0,self.isApplicationActive else{self.stopVoices();return}
            self.syncLoops(wanted,immediate:![RunPhase.playing,.cleared,.bonusRoom,.transition].contains(phase),stopWorldImmediately:phase == .transition)
            // Preparation or a stalled app must not replay a backlog of old shots.
            let fresh=ProcessInfo.processInfo.systemUptime-now<0.15
            if fresh {
                for cue in Set(cues).sorted(by:{$0.priority == $1.priority ? $0.rawValue<$1.rawValue:$0.priority>$1.priority}) {
                    let placement=placements[cue] ?? AudioPlacement(),attenuation=AudioMix.bounded(placement.gain)
                    guard attenuation>0 else{continue}
                    guard now-(self.lastPlay[cue] ?? -100)>=cue.minimumGap,let group=self.voices[cue] else{continue}
                    let playing=self.voices.flatMap{key,players in players.filter{$0.isPlaying}.map{(key,$0)}}
                    if playing.count>=AudioMix.maxVoices {
                        guard let victim=playing.min(by:{$0.0.priority<$1.0.priority}),victim.0.priority<=cue.priority else{continue}
                        victim.1.stop()
                    }
                    guard let p=group.first(where:{!$0.isPlaying}) ?? group.first else{continue}
                    p.stop();p.currentTime=0;p.volume=0
                    p.pan=Float(placement.pan.isFinite ? max(-1,min(1,placement.pan)):0);self.voiceAttenuation[ObjectIdentifier(p)]=attenuation
                    // Compute the budget INCLUDING this new voice before its first output sample.
                    let activeWeight=self.totalWeight()+cue.gain
                    self.mix(weight:activeWeight)
                    p.volume=AudioMix.voiceGain(cue,totalWeight:activeWeight,level:level,master:Double(self.masterGain))*Float(attenuation)
                    if p.play(){self.plays+=1;self.lastPlay[cue]=now}
                }
            }
            self.mix();self.syncLoopMixTimer();self.publish()
        }
    }
    private func syncLoops(_ requests:[AudioLoopRequest],immediate:Bool,stopWorldImmediately:Bool){
        let delta=loopTransport.update(requests),now=ProcessInfo.processInfo.systemUptime
        if immediate || stopWorldImmediately {
            for item in retiringLoops where immediate || item.key.worldID != nil {item.player.stop();item.player.volume=0}
            retiringLoops.removeAll{immediate || $0.key.worldID != nil}
        }
        for key in delta.stopped {
            guard let p=loopPlayers.removeValue(forKey:key) else{continue}
            let attenuation=loopAttenuation.removeValue(forKey:key) ?? 1
            if immediate || (stopWorldImmediately && key.worldID != nil) || !p.isPlaying {p.stop();p.volume=0;continue}
            while retiringLoops.count>=AudioLoopPolicy.maximumRetiring {
                let old=retiringLoops.removeFirst();old.player.stop();old.player.volume=0
            }
            let fade=key.kind.fadeOut,deadline=now+fade
            retiringLoops.append(RetiringLoop(key:key,player:p,until:deadline,attenuation:attenuation))
            queue.asyncAfter(deadline:.now()+fade){[weak self] in
                guard let self,let index=self.retiringLoops.firstIndex(where:{$0.key==key && $0.until==deadline}) else{return}
                let old=self.retiringLoops.remove(at:index);old.player.stop();old.player.volume=0;self.mix();self.publish()
            }
        }
        for request in requests {
            let key=request.key
            if loopPlayers[key]==nil {
                if let index=retiringLoops.firstIndex(where:{$0.key==key}) {
                    loopPlayers[key]=retiringLoops.remove(at:index).player
                }else if let data=loopPayloads[key.kind],let p=try? AVAudioPlayer(data:data,fileTypeHint:AVFileType.wav.rawValue) {
                    p.volume=0;p.numberOfLoops = -1;p.prepareToPlay();loopPlayers[key]=p
                }
            }
            guard let p=loopPlayers[key] else{continue}
            p.pan=Float(request.pan);loopAttenuation[key]=request.gain
            if !p.isPlaying {
                // Include every planned loop before the first sample of any new voice.
                let weight=effectWeight()+requests.reduce(0.0){$0+$1.key.kind.gain}+retiringLoops.reduce(0.0){$0+$1.key.kind.gain}
                mix(weight:weight);p.volume=AudioMix.loopGain(key.kind,totalWeight:weight,level:level,master:Double(masterGain))*Float(request.gain)
                if p.play(){plays+=1}
            }
        }
    }
    private func effectWeight()->Double {voices.reduce(0.0){$0+Double($1.value.filter{$0.isPlaying}.count)*$1.key.gain}}
    /// Recover loop headroom after a shot ends even when no movement/new event arrives.
    /// One20Hz queue timer exists only while actual loop voices are playing or fading.
    private func syncLoopMixTimer(){
        let needed=loopPlayers.values.contains{$0.isPlaying} || retiringLoops.contains{$0.player.isPlaying}
        if needed,loopMixTimer==nil {
            let timer=DispatchSource.makeTimerSource(queue:queue)
            timer.schedule(deadline:.now()+0.05,repeating:0.05,leeway:.milliseconds(5))
            timer.setEventHandler{[weak self] in
                guard let self,self.loopMixTimer != nil else{return}
                self.mix();self.publish();self.syncLoopMixTimer()
            }
            loopMixTimer=timer;timer.resume()
        }else if !needed {loopMixTimer?.cancel();loopMixTimer=nil}
    }
    private func totalWeight()->Double {
        effectWeight()+loopPlayers.reduce(0.0){$0+($1.value.isPlaying ? $1.key.kind.gain:0)}+retiringLoops.reduce(0.0){$0+($1.player.isPlaying ? $1.key.kind.gain:0)}
    }
    private func mix(weight:Double?=nil){
        let total=weight ?? totalWeight()
        for (cue,group) in voices {for p in group {p.volume=p.isPlaying ? AudioMix.voiceGain(cue,totalWeight:total,level:level,master:Double(masterGain))*Float(voiceAttenuation[ObjectIdentifier(p)] ?? 1):0}}
        for (key,p) in loopPlayers {p.volume=p.isPlaying ? AudioMix.loopGain(key.kind,totalWeight:total,level:level,master:Double(masterGain))*Float(loopAttenuation[key] ?? 1):0}
        let now=ProcessInfo.processInfo.systemUptime
        for item in retiringLoops {
            let remaining=max(0,item.until-now),fraction=min(1,remaining/item.key.kind.fadeOut)
            item.player.volume=AudioMix.loopGain(item.key.kind,totalWeight:total,level:level,master:Double(masterGain))*Float(fraction*item.attenuation)
            item.player.setVolume(0,fadeDuration:remaining)
        }
    }
    private func publish(){
        let loops=Array(loopPlayers.values)+retiringLoops.map(\.player),all=voices.values.flatMap{$0}+loops
        let next=AudioStatus(voiceCount:all.count,playingVoiceCount:all.filter{$0.isPlaying}.count,playedCount:plays,loopVoiceCount:loops.count,playingLoopVoiceCount:loops.filter{$0.isPlaying}.count,preparedLoopKinds:loopPayloads.count,volumesAreZero:all.allSatisfy{$0.volume==0})
        lock.lock();state=next;lock.unlock()
    }
    /// For silent diagnostics; production never waits on audio work from its rendering callback.
    func waitForPendingWork(){queue.sync{}}
}
