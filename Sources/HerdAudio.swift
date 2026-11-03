import Foundation

struct AudioQueuedEvent {let cue:AudioCue,position:V2?}
struct AudioPlacement:Equatable {var pan:Double=0,gain:Double=1}
struct SpatialAudioFrame {let cues:[AudioCue],placements:[AudioCue:AudioPlacement]}
enum SoundSpace {
    static func placement(_ p:V2,centerX:Double,centerY:Double,halfWidth:Double,halfDepth:Double,sign:Double)->AudioPlacement {
        guard p.x.isFinite,p.y.isFinite else{return AudioPlacement(gain:0)}
        let x=centerX.isFinite ? centerX:0,y=centerY.isFinite ? centerY:0
        let width=halfWidth.isFinite ? max(1,halfWidth):11,depth=halfDepth.isFinite ? max(1,halfDepth):8
        let dx=(p.x-x)/width,dy=(p.y-y)/depth
        let pan=max(-1,min(1,dx*sign)),gain=max(0,min(0.9,(1.8-hypot(dx,dy))/1.5))
        return AudioPlacement(pan:(pan*20).rounded()/20,gain:(gain*20).rounded()/20)
    }
    static func frame(_ events:[AudioQueuedEvent],centerX:Double,centerY:Double,halfWidth:Double,halfDepth:Double,sign:Double)->SpatialAudioFrame {
        var placements=[AudioCue:AudioPlacement](),cues=[AudioCue]()
        for e in events {
            let p=e.position.map{placement($0,centerX:centerX,centerY:centerY,halfWidth:halfWidth,halfDepth:halfDepth,sign:sign)} ?? AudioPlacement()
            guard p.gain>0 else{continue}
            cues.append(e.cue)
            if placements[e.cue]==nil || p.gain>placements[e.cue]!.gain {placements[e.cue]=p}
        }
        return SpatialAudioFrame(cues:cues,placements:placements)
    }
}
/// Sound-only deterministic stream. It never consumes gameplay/drop randomness or world IDs.
struct HerdVoiceTimeline {
    private(set) var nextRoar=0.0
    private var seed:UInt64=0
    mutating func roars(through age:Double,id:Int)->[Double] {
        guard age.isFinite,age >= -1e-9,id>0 else{return []}
        if seed==0 {seed=UInt64(id) &* 87123 &+ 9257}
        var events=[Double]()
        while nextRoar<=min(10,max(0,age))+1e-9 {
            events.append(nextRoar)
            seed=seed &* 6364136223846793005 &+ 1442695040888963407
            let roll=Double(seed>>11)/Double(UInt64.max>>11)
            nextRoar+=AudioSynth.duration(.bullRoar)+1+3.5*roll
        }
        return events
    }
}
extension GameCore {
    func herdLoopAudioRequests(centerX:Double,centerY:Double,halfWidth:Double,halfDepth:Double)->[AudioLoopRequest] {
        guard layout.kind == .marketplace,phase == .playing || phase == .cleared else{return []}
        return bulls.compactMap { b -> AudioLoopRequest? in
            guard b.id>0,b.age >= -1e-9,b.age<10,b.speed>0 else{return nil}
            let p=SoundSpace.placement(b.p,centerX:centerX,centerY:centerY,halfWidth:halfWidth,halfDepth:halfDepth,sign:viewOrientation.sign)
            guard p.gain>0 else{return nil}
            return AudioLoopRequest(key:AudioLoopKey(bullID:b.id),pan:p.pan,gain:p.gain)
        }.sorted {a,b in a.gain==b.gain ? a.key.worldID!<b.key.worldID!:a.gain>b.gain}.prefix(AudioLoopPolicy.maximumWorld).map{$0}
    }
}
