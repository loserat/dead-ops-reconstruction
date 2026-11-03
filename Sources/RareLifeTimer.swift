import Foundation

/// powerup_timeout:12s steady,then40alternating waits including the local100ms network wait.
enum SourcePowerupTimeout {
    static let steady=12.0,gemSteady=24.0,blinkDuration=15.5
    static let lifetime=steady+blinkDuration,gemLifetime=gemSteady+blinkDuration
    static func opacity(remaining:Double,steady:Double=Self.steady)->Double {
        guard remaining.isFinite,remaining>0,steady.isFinite,steady>=0 else{return 0}
        let age=(steady+blinkDuration-remaining)*1000+0.0000001
        if age<steady*1000 {return 1}
        let blink=age-steady*1000,index:Int
        if blink<9000 {index=Int(blink/600)}
        else if blink<12500 {index=15+Int((blink-9000)/350)}
        else {index=min(39,25+Int((blink-12500)/200))}
        return index%2==0 ? 1:0
    }
}

/// Timed ordinary funds and gems are distinct from the source's untimed special-event money.
/// Custom durations exist only for explicit developer fixtures; normal production uses source profiles.
enum PickupLifetime:CaseIterable {
    case custom,powerup,gem,untilCleanup
    var steady:Double? {switch self {case .powerup:return SourcePowerupTimeout.steady;case .gem:return SourcePowerupTimeout.gemSteady+0.1;case .custom,.untilCleanup:return nil}}
    // Gems create their trigger and timeout after one local100ms network frame.
    var duration:Double? {steady.map{$0+SourcePowerupTimeout.blinkDuration}}
    var contactDelay:Double {switch self {case .custom:return 0;case .gem:return 0.5;case .powerup,.untilCleanup:return 0.4}}
    static func source(for kind:PickupKind)->Self {kind == .gem ? .gem:.powerup}
}

/// Archived extra-life thread:240–540s,then ten seconds per team reserve,in five-second waits.
/// A wait already started while active completes even if the round-active flag changes.
struct RareLifeTimer {
    enum Stage {case base,reserves}
    private enum Wait {case ready,inactiveRetry,counting}
    private(set) var clock=0.0,remaining:Double,stage:Stage = .base,drops=0
    private var wait:Wait = .ready,nextBoundary=0.0
    init(baseWait:Double){remaining=max(240,min(540,baseWait))}
    mutating func step(_ dt:Double,activeAt:(Double)->Bool,reserves:()->Int,random:()->Double,spawn:()->Void) {
        guard dt.isFinite,dt>0,clock+dt<1e12 else{return}
        let end=clock+dt
        while nextBoundary<=end+1e-9 {
            let event=nextBoundary
            if wait == .counting {remaining=max(0,remaining-5)}
            wait = .ready
            if remaining<=0 {
                if stage == .base {stage = .reserves;remaining=Double(max(0,reserves()))*10}
                if remaining<=0 {
                    spawn();drops+=1;stage = .base
                    let roll=random();remaining=240+300*(roll.isFinite ? max(0,min(1,roll)):0)
                }
            }
            wait=activeAt(event) ? .counting:.inactiveRetry
            nextBoundary=event+5
        };clock=end
    }
}
extension GameCore {
    func stepRareLifeTimer(_ dt:Double,combatStartClock:Double?=nil,activeWindows:[Range<Double>]?=nil) {
        guard var timer=rareLifeTimer,dt.isFinite,dt>0 else{return}
        let timerStart=timer.clock,flow=combatSpawnFlow
        timer.step(dt,activeAt:{event in
            if let windows=activeWindows {
                let offset=max(0,event-timerStart)
                if abs(offset-dt)<1e-9 {return self.phase == .playing && (self.combatSpawnFlow?.roundActive ?? false)}
                return windows.contains{$0.contains(offset)}
            }
            guard let start=combatStartClock,let flow,!flow.forcedFinished else{return false}
            return start+max(0,event-timerStart)<flow.sequenceEndsAt
        },reserves:{self.players.reduce(0){$0+$1.lives}},random:{self.random()},spawn:{
            guard self.phase != .gameOver else{return}
            let sites=self.layout.treasurePileCenters
            guard !sites.isEmpty else{return}
            let p=sites[min(sites.count-1,Int(self.random()*Double(sites.count)))]
            var life=self.worldPickup(id:self.id(),p:self.layout.clamped(p),kind:.life,ttl:SourcePowerupTimeout.lifetime)
            life.sourcePowerupTimeout=true;self.pickups.append(life)
        });rareLifeTimer=timer
    }
}
