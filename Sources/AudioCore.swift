import Foundation

enum AudioCue:Int,CaseIterable {case shot,explosion,pickup,hurt,boost,round,boss,victory,life
    case shotgun,rayShot,rocketShot,minigun,grenadeShot,flame,tankShot,helicopterShot,turretShot
    case respawn,shieldWarning,shieldEnd,hazardWarning,hazardZap
    case goldenBull,sentryArrival,sentryLand,sentryDepart
    case bullRoar,bullImpact
    static func weapon(_ kind:PickupKind?)->AudioCue {
        switch kind {case .spread:return .shotgun;case .ray:return .rayShot;case .rocket:return .rocketShot;case .deathMachine:return .minigun;case .grenade:return .grenadeShot;case .flamethrower:return .flame;default:return .shot}
    }
    var priority:Int {switch self {case .hurt,.life,.respawn:return 5;case .boss,.victory,.round,.shieldWarning,.shieldEnd,.goldenBull:return 4;case .sentryArrival,.sentryLand:return 3;case .sentryDepart,.bullRoar,.bullImpact:return 2;case .explosion,.boost:return 3;case .pickup,.hazardWarning,.hazardZap:return 2;case .turretShot,.helicopterShot:return 0;default:return 1}}
    var minimumGap:Double {switch self {case .bullRoar:return 0.45;case .bullImpact:return 0.12;case .shot,.minigun:return 0.04;case .helicopterShot,.turretShot:return 0.075;case .flame:return 0.085;case .pickup:return 0.065;case .hazardWarning,.hazardZap:return 0.35;case .explosion:return 0.12;case .rayShot:return 0.10;case .shotgun:return 0.085;case .rocketShot:return 0.18;case .tankShot:return 0.18;case .grenadeShot:return 0.25;default:return 0.20}}
    var poolSize:Int {switch self {case .shot,.minigun:return 4;case .explosion:return 3;case .pickup,.rayShot,.shotgun,.helicopterShot,.turretShot,.tankShot,.bullRoar,.bullImpact:return 2;default:return 1}}
    var gain:Double {switch self {case .shot:return 0.20;case .minigun,.helicopterShot:return 0.16;case .turretShot:return 0.11;case .flame:return 0.19;case .explosion,.tankShot:return 0.32;case .shotgun,.rocketShot:return 0.29;case .hazardWarning:return 0.15;case .hazardZap:return 0.19;case .bullRoar:return 0.16;case .bullImpact:return 0.20;case .hurt,.life:return 0.28;default:return 0.24}}
}
/// Conservative shared headroom: effects and full-scale external music cannot exhaust the mix.
enum AudioMix {
    static let effectBudget=0.60,musicBudget=0.30,maxVoices=12
    static func bounded(_ gain:Double)->Double {gain.isFinite ? max(0,min(1,gain)):0}
    static func voiceGain(_ cue:AudioCue,totalWeight:Double,level:Double,master:Double)->Float {
        Float(cue.gain*bounded(level)*bounded(master)*min(1,effectBudget/max(0.001,totalWeight)))
    }
    static func musicGain(level:Double,master:Double,returning:Bool)->Float {Float(musicBudget*bounded(level)*bounded(master)*(returning ? 0.5:1))}
    static func loopGain(_ kind:AudioLoopKind,totalWeight:Double,level:Double,master:Double)->Float {
        Float(kind.gain*bounded(level)*bounded(master)*min(1,effectBudget/max(0.001,totalWeight)))
    }
}

enum AudioLoopKind:Int,CaseIterable,Hashable {
    case boots,barrels,orbs,teddy,tank,hind,buffalo
    var priority:Int {switch self {case .tank,.hind:return 3;case .orbs,.buffalo:return 2;case .barrels,.teddy:return 1;case .boots:return 0}}
    var gain:Double {switch self {case .tank,.hind:return 0.085;case .orbs:return 0.055;case .barrels:return 0.06;case .teddy:return 0.05;case .boots:return 0.045;case .buffalo:return 0.055}}
    var fadeOut:Double {self == .buffalo ? 1:0.5}
}
struct AudioLoopKey:Hashable {
    let slot:Int,kind:AudioLoopKind,worldID:Int?
    init(slot:Int,kind:AudioLoopKind){self.slot=slot;self.kind=kind;worldID=nil}
    init(bullID:Int){slot = -1;kind = .buffalo;worldID=bullID}
    var valid:Bool {worldID.map{$0>0 && slot == -1 && kind == .buffalo} ?? ((0..<4).contains(slot) && kind != .buffalo)}
}
struct AudioLoopRequest:Equatable {let key:AudioLoopKey;var pan:Double=0,gain:Double=1}
struct AudioLoopDelta {let started:[AudioLoopKey],stopped:[AudioLoopKey]}
enum AudioLoopPolicy {
    static let maximumActive=8,maximumRetiring=8,maximumWorld=4,fadeOut=0.5
    static func normalized(_ requests:[AudioLoopRequest],enabled:Bool,phase:RunPhase,level:Double)->[AudioLoopRequest] {
        guard enabled,AudioMix.bounded(level)>0,[RunPhase.playing,.cleared,.bonusRoom,.transition].contains(phase) else{return []}
        var byKey=[AudioLoopKey:AudioLoopRequest]()
        for request in requests where request.key.valid && AudioMix.bounded(request.gain)>0 {
            if request.key.worldID != nil && phase != .playing && phase != .cleared {continue}
            let pan=request.pan.isFinite ? max(-1,min(1,request.pan)):0
            let gain=(AudioMix.bounded(request.gain)*20).rounded()/20
            guard gain>0 else{continue}
            byKey[request.key]=AudioLoopRequest(key:request.key,pan:(pan*20).rounded()/20,gain:gain)
        }
        var worldCount=0
        return Array(byKey.values.sorted{a,b in
            if a.key.kind.priority != b.key.kind.priority {return a.key.kind.priority>b.key.kind.priority}
            if a.key.worldID != nil && b.key.worldID != nil {return a.gain==b.gain ? a.key.worldID!<b.key.worldID!:a.gain>b.gain}
            if a.key.slot != b.key.slot {return a.key.slot<b.key.slot}
            return a.key.kind.rawValue<b.key.kind.rawValue
        }.filter {request in
            if request.key.worldID != nil {worldCount+=1;return worldCount<=maximumWorld};return true
        }.prefix(maximumActive))
    }
}
/// Pure lifecycle policy: moving a voice or changing volume never restarts its waveform.
struct AudioLoopTransport {
    private(set) var active:[AudioLoopRequest]=[]
    mutating func update(_ requests:[AudioLoopRequest])->AudioLoopDelta {
        let old=Set(active.map(\.key)),new=Set(requests.map(\.key))
        let delta=AudioLoopDelta(started:requests.map(\.key).filter{!old.contains($0)},stopped:active.map(\.key).filter{!new.contains($0)})
        active=requests;return delta
    }
}
/// Own periodic sound design. Integer oscillator cycles keep the one-second files loopable.
/// No samples, melody or instrument recording from the original game is included.
enum AudioLoopSynth {
    static func samples(_ kind:AudioLoopKind)->[Double] {
        let rate=AudioSynth.rate
        let raw=(0..<rate).map { index -> Double in
            let t=Double(index)/Double(rate),tau=2*Double.pi
            func wave(_ f:Double)->Double {sin(tau*f*t)}
            let air=[137.0,223,367,487,631,887].enumerated().reduce(0.0){$0+wave($1.element)/Double($1.offset+2)}
            switch kind {
            case .boots:return air*(0.65+0.15*wave(3))+wave(251)*0.08
            case .barrels:return (wave(74)*0.36+wave(151)*0.23+wave(317)*0.12)*(0.65+0.25*wave(7))
            case .orbs:return (wave(220)*0.26+wave(660)*0.12+wave(880)*0.04)*(0.75+0.2*wave(13))
            case .teddy:return (wave(51)*0.42+wave(92)*0.18+wave(173)*0.07)*(0.7+0.2*wave(4))
            case .tank:return (wave(40)*0.44+wave(80)*0.18+wave(121)*0.12+air*0.08)*(0.8+0.1*wave(5))
            case .hind:return (wave(67)*0.35+wave(134)*0.16+air*0.13)*(0.35+0.65*pow(wave(24),2))
            case .buffalo:
                let hoof=pow(max(0,wave(5)),12)*(0.75+0.25*wave(2))
                return (wave(82)*0.5+wave(164)*0.16+air*0.3)*hoof+wave(43)*0.035
            }
        }
        let peak=max(0.001,raw.map{abs($0)}.max() ?? 1)
        return raw.map{$0*0.65/peak}
    }
    static func wav(_ kind:AudioLoopKind)->Data {AudioSynth.wav(samples:samples(kind))}
}

extension GameCore {
    /// A bounded value snapshot; no decoding, sound output or gameplay random draws here.
    func loopAudioRequests(centerX:Double=0,halfWidth:Double=11,centerY:Double=0,halfDepth:Double=8)->[AudioLoopRequest] {
        let center=centerX.isFinite ? centerX:0,width=halfWidth.isFinite ? max(1,halfWidth):11
        var out=[AudioLoopRequest]()
        for player in players where !player.isDown {
            var kinds=[AudioLoopKind]()
            if player.boots>0 {kinds.append(.boots)}
            if player.shieldBarrelRemaining>0 && !player.shieldBarrels.isEmpty {kinds.append(.barrels)}
            if player.orbRemaining>0 && !player.orbShields.isEmpty {kinds.append(.orbs)}
            if player.teddyRemaining>0 {kinds.append(.teddy)}
            if let vehicle=player.vehicle {kinds.append(vehicle.kind == .tank ? .tank:.hind)}
            let pan=player.hero.x.isFinite ? max(-1,min(1,(player.hero.x-center)*viewOrientation.sign/width)):0
            out += kinds.map{AudioLoopRequest(key:AudioLoopKey(slot:player.slot,kind:$0),pan:pan)}
        }
        out += herdLoopAudioRequests(centerX:centerX,centerY:centerY,halfWidth:halfWidth,halfDepth:halfDepth)
        return out
    }
}

/// Small original synthesized effects. No recorded or extracted original-game audio.
enum AudioSynth {
    static let rate=22050
    static func duration(_ cue:AudioCue)->Double {
        switch cue {case .shot:return 0.085;case .shotgun:return 0.16;case .rayShot:return 0.20;case .rocketShot:return 0.30;case .minigun:return 0.065;case .grenadeShot:return 0.21;case .flame:return 0.15;case .tankShot:return 0.34;case .helicopterShot:return 0.075;case .turretShot:return 0.07;case .explosion:return 0.55;case .pickup:return 0.18;case .hurt:return 0.24;case .boost:return 0.24;case .round:return 0.50;case .boss:return 0.85;case .victory:return 1.05;case .life:return 0.40;case .respawn:return 0.32;case .shieldWarning:return 0.18;case .shieldEnd:return 0.22;case .hazardWarning:return 0.23;case .hazardZap:return 0.38;case .goldenBull:return 0.62;case .sentryArrival:return 0.40;case .sentryLand:return 0.24;case .sentryDepart:return 0.42;case .bullRoar:return 0.72;case .bullImpact:return 0.19}
    }
    static func samples(_ cue:AudioCue)->[Double] {
        let count=Int(duration(cue)*Double(rate));var data=[Double]();data.reserveCapacity(count)
        var seed=UInt64(cue.rawValue+1)*87123,low=0.0
        for i in 0..<count {
            let t=Double(i)/Double(rate),attack=min(1,t/0.003),release=min(1,Double(count-1-i)/Double(rate)/0.012)
            seed=seed&*6364136223846793005&+1442695040888963407
            let noise=Double(seed>>11)/Double(UInt64.max>>11)*2-1
            low+=(noise-low)*0.16
            let value:Double
            switch cue {
            case .shot:value=0.65*noise*exp(-t*90)+0.35*sin(2*Double.pi*145*t)*exp(-t*40)
            case .shotgun:value=(noise*0.75+low*1.2)*exp(-t*30)+0.35*sin(2*Double.pi*91*t)*exp(-t*28)
            case .rayShot:value=(sin(2*Double.pi*(1350*t-1900*t*t))+0.24*sin(2*Double.pi*2100*t))*exp(-t*19)*0.65
            case .rocketShot:value=(low*2.1+noise*exp(-t*50)*0.35+sin(2*Double.pi*72*t)*0.25)*exp(-t*11)
            case .minigun:value=(noise*0.55+sin(2*Double.pi*235*t)*0.22+sin(2*Double.pi*470*t)*0.18)*exp(-t*75)
            case .grenadeShot:value=(sin(2*Double.pi*(170*t-220*t*t))*0.75+low*0.9)*exp(-t*19)
            case .flame:value=(low*1.7+noise*0.16)*(0.68+0.14*sin(2*Double.pi*38*t))*sin(Double.pi*t/duration(cue))
            case .tankShot:value=(low*2.5+sin(2*Double.pi*(58*t-35*t*t))*0.46+noise*exp(-t*55)*0.5)*exp(-t*10)
            case .helicopterShot:value=(noise*0.6+sin(2*Double.pi*290*t)*0.18)*exp(-t*68)
            case .turretShot:value=(noise*0.50+sin(2*Double.pi*380*t)*0.26)*exp(-t*75)
            case .explosion:value=(low*2.5+0.22*sin(2*Double.pi*(65*t-30*t*t)))*exp(-t*7)
            case .pickup:value=(sin(2*Double.pi*880*t)+0.35*sin(2*Double.pi*1320*t))*exp(-t*19)*0.55
            case .hurt:value=(sin(2*Double.pi*(135*t-120*t*t))*0.55+low*1.3)*exp(-t*12)
            case .boost:value=(low*1.7+sin(2*Double.pi*(200*t+1100*t*t))*0.25)*sin(Double.pi*t/duration(cue))
            case .round:
                let notes=[392.0,523.25,659.25],n=min(2,Int(t/0.16)),local=t-Double(n)*0.16
                value=sin(2*Double.pi*notes[n]*local)*exp(-local*16)*0.6
            case .boss:value=(low*1.8+sin(2*Double.pi*48*t)*0.45+sin(2*Double.pi*73*t)*0.15)*exp(-t*3)
            case .victory:
                let notes=[392.0,493.88,587.33,783.99,987.77],n=min(4,Int(t/0.17)),local=t-Double(n)*0.17
                value=(sin(2*Double.pi*notes[n]*local)+sin(2*Double.pi*notes[n]*2*local)*0.2)*exp(-local*10)*0.55
            case .life:value=(sin(2*Double.pi*(660*t+550*t*t))+0.25*sin(2*Double.pi*1320*t))*exp(-t*8)*0.55
            case .respawn:
                let progress=t/duration(cue)
                value=(low*0.5+sin(2*Double.pi*(280*t+900*t*t))*0.45+sin(2*Double.pi*(560*t+1800*t*t))*0.12)*sin(Double.pi*progress)*exp(-2*progress)
            case .shieldWarning:value=(sin(2*Double.pi*740*t)+sin(2*Double.pi*1110*t)*0.16)*sin(Double.pi*t/duration(cue))*0.40
            case .hazardWarning:value=(sin(2*Double.pi*(980*t+250*t*t))*0.27+sin(2*Double.pi*1470*t)*0.08)*sin(Double.pi*t/duration(cue))
            case .hazardZap:value=(noise*0.20+low*0.65+sin(2*Double.pi*120*t)*0.18)*(0.55+0.45*sin(2*Double.pi*52*t))*sin(Double.pi*t/duration(cue))
            case .shieldEnd:value=sin(2*Double.pi*(520*t-650*t*t))*sin(Double.pi*t/duration(cue))*exp(-t*5)*0.45
            case .goldenBull:
                let notes=[784.0,1176,1568,1960],step=0.065
                value=notes.enumerated().reduce(0.0){sum,note in
                    let local=t-Double(note.offset)*step
                    return sum+(local>=0 ? (sin(2*Double.pi*note.element*local)+0.22*sin(2*Double.pi*note.element*2*local))*exp(-local*13)*0.25:0)
                }
            case .sentryArrival:value=(sin(2*Double.pi*(1100*t-950*t*t))*0.42+low*0.55)*sin(Double.pi*t/duration(cue))
            case .sentryLand:value=(sin(2*Double.pi*(82*t-95*t*t))*0.72+low*1.4+noise*exp(-t*80)*0.18)*exp(-t*21)
            case .sentryDepart:value=(sin(2*Double.pi*(260*t+760*t*t))*0.32+low*0.8)*sin(Double.pi*t/duration(cue))
            case .bullRoar:
                let phase=2*Double.pi*(108*t-36*t*t+0.12*sin(2*Double.pi*9*t))
                value=(sin(phase)*0.40+sin(phase*2)*0.18+sin(phase*3)*0.08+low*0.75)*pow(sin(Double.pi*t/duration(cue)),0.7)
            case .bullImpact:value=(sin(2*Double.pi*86*t)*0.75+low*1.2+noise*exp(-t*75)*0.3)*exp(-t*25)

            }
            data.append(max(-0.9,min(0.9,value*attack*release*0.7)))
        }
        return data
    }
    static func wav(_ cue:AudioCue)->Data {
        wav(samples:samples(cue))
    }
    static func wav(samples pcm:[Double])->Data {
        let size=UInt32(pcm.count*2);var out=Data()
        func word<T:FixedWidthInteger>(_ v:T){var value=v.littleEndian;withUnsafeBytes(of:&value){out.append(contentsOf:$0)}}
        out.append(contentsOf:Array("RIFF".utf8));word(UInt32(36)+size);out.append(contentsOf:Array("WAVEfmt ".utf8));word(UInt32(16));word(UInt16(1));word(UInt16(1));word(UInt32(rate));word(UInt32(rate*2));word(UInt16(2));word(UInt16(16));out.append(contentsOf:Array("data".utf8));word(size)
        for sample in pcm {word(Int16((sample*32767).rounded()))}
        return out
    }
}
