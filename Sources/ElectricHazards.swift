import Foundation

enum TrapState {case safe,warning,active}
struct ElectricTrap {
    let p:V2,offset:Double
    let id:Int,elevation:Double,seed:UInt64
    // Source trigger20/50; actor hulls and100:1 world conversion remain our own mapping.
    static let solidRadius=0.12,triggerRadius=0.20,triggerHeight=0.50
    var radius:Double {Self.triggerRadius+0.29}
    private let timeline:ElectricTrapTimeline
    init(p:V2,offset:Double,id:Int=0,elevation:Double=0,seed:UInt64=0) {
        self.p=p;self.offset=offset;self.id=id;self.elevation=elevation;self.seed=seed;timeline=ElectricTrapTimeline(seed:seed)
    }
    private func phase(at time:Double)->(state:TrapState,until:Double) {
        guard time.isFinite else{return (.safe,.infinity)}
        let sample=timeline.sample(max(0,time+offset))
        return (sample.state,sample.until-offset)
    }
    var timingTransitionsEvaluated:Int {timeline.transitions}
    func state(at time:Double)->TrapState {phase(at:time).state}
    func activeWindows(from start:Double,to end:Double)->[ClosedRange<Double>] {
        guard start.isFinite,end.isFinite,end>=start else{return []}
        var clock=start,result=[ClosedRange<Double>]()
        repeat {
            let sample=phase(at:clock),stop=min(end,sample.until)
            if sample.state == .active {result.append(clock...max(clock,stop))}
            if stop>=end {break}
            clock=stop>clock ? stop:clock.nextUp
        }while clock<=end
        return result
    }
    func intersects(from a:V2,height ha:Double,to b:V2,height hb:Double,bodyRadius:Double)->Bool {
        var lo=0.0,hi=1.0
        let dh=hb-ha
        if abs(dh)<1e-9 {guard abs(ha-elevation)<=Self.triggerHeight else{return false}}
        else {
            let t0=(elevation-Self.triggerHeight-ha)/dh,t1=(elevation+Self.triggerHeight-ha)/dh
            lo=max(lo,min(t0,t1));hi=min(hi,max(t0,t1));if lo>hi {return false}
        }
        return p.distance(toSegmentFrom:a+(b-a)*lo,to:a+(b-a)*hi)<Self.triggerRadius+bodyRadius
    }
    func contacts(_ point:V2,height:Double,bodyRadius:Double)->Bool {
        (point-p).length<Self.triggerRadius+bodyRadius && abs(height-elevation)<=Self.triggerHeight
    }
}

/// Cached on the simulation/render owner. Past-time diagnostic queries reset deterministically;
/// normal frames consume each phase boundary only once, without replaying an ever-growing history.
private final class ElectricTrapTimeline {
    let seed:UInt64
    private(set) var transitions=0
    var rng:UInt64,stage=0,start=0.0,end=0.5,state:TrapState = .warning
    init(seed:UInt64){self.seed=seed;rng=seed}
    private func roll()->Double {rng=rng &* 6364136223846793005 &+ 1442695040888963407;return Double(rng>>11)/Double(UInt64.max>>11)}
    func sample(_ time:Double)->(state:TrapState,until:Double) {
        if time<start {rng=seed;stage=0;start=0;end=0.5;state = .warning}
        while time>=end {
            transitions+=1;start=end
            switch stage {
            case 0:stage=1;state = .safe;end+=10
            case 1,4:stage=2;state = .warning;end+=1.2
            case 2:stage=3;state = .active;end+=4+6*roll()
            default:stage=4;state = .safe;end+=3+3*roll()
            }
        }
        return (state,end)
    }
}

extension GameCore {
    private func hazardRandom()->Double {
        hazardSeed=hazardSeed &* 6364136223846793005 &+ 1442695040888963407
        return Double(hazardSeed>>11)/Double(UInt64.max>>11)
    }
    func prepareElectricHazards() {
        electricTraps=[];hazardObstacles=[];hazardKind=nil;hazardClock=0;hazardRequestedCount=0;hazardRevision &+= 1
        let base=layout
        guard sideRoom==nil,!base.hazardSites.isEmpty else{return}
        let count=1+Int(hazardRandom()*Double(2+(max(4,round)-4)/3))
        hazardRequestedCount=count
        var placed=[ElectricTrap]()
        for _ in 0..<count {
            let center=base.hazardSites[Int(hazardRandom()*Double(base.hazardSites.count))]
            var chosen:V2?
            // Original map hazard structs are absent; jitter our own editable safe sites.
            func legal(_ p:V2)->Bool {
                base.walkable(p,clearance:0.20) && placed.allSatisfy{($0.p-p).length>=0.24} &&
                    EntrySide.allCases.allSatisfy{(base.playerExit(on:$0)-p).length>0.85}
            }
            for _ in 0..<32 {
                let p=center+V2(x:hazardRandom()*1.7-0.85,y:hazardRandom()*1.7-0.85)
                if legal(p) {chosen=p;break}
            }
            if chosen==nil {
                // Own deterministic fallback across all editable sites preserves the requested
                // count when one jitter region is crowded or blocked by our different scenery.
                search:for site in base.hazardSites {for x in -3...3 {for y in -3...3 {
                    let p=site+V2(x:Double(x)*0.25,y:Double(y)*0.25)
                    if legal(p) {chosen=p;break search}
                }}}
            }
            guard let p=chosen else{continue} // Finite own-map capacity remains an explicit limit.
            let trap=ElectricTrap(p:p,offset:0,id:id(),elevation:base.height(p),seed:hazardSeed)
            placed.append(trap);_=hazardRandom()
        }
        electricTraps=placed;hazardKind=base.kind
        hazardObstacles=base.staticObstacles+placed.map{ArenaObstacle($0.p,radius:ElectricTrap.solidRadius,elevation:$0.elevation,height:1.2)}
    }
    func clearElectricHazards() {
        electricTraps=[];hazardObstacles=[];hazardKind=nil;hazardClock=0;hazardRequestedCount=0;hazardRevision &+= 1
    }
    func stepElectricHazards(_ dt:Double,from playerStarts:[V2]?=nil,heights playerHeights:[Double]?=nil,foeStarts:[Int:(V2,Double)]?=nil) {
        guard dt.isFinite,dt>=0,phase == .playing || phase == .cleared else{return}
        let previous=hazardClock;hazardClock+=dt
        for trap in electricTraps {
            let old=trap.state(at:previous)
            let windows=trap.activeWindows(from:previous,to:hazardClock)
            let new=trap.state(at:hazardClock)
            if old != new && new == .warning {emitAudio(.hazardWarning)}
            if old != new && new == .active {emitAudio(.hazardZap)}
            guard !windows.isEmpty else{continue}
            func touching(from a:V2,height ha:Double,to b:V2,height hb:Double,radius:Double)->Bool {
                windows.contains { interval in
                    let lo=dt>0 ? (interval.lowerBound-previous)/dt:1,hi=dt>0 ? (interval.upperBound-previous)/dt:1
                    return trap.intersects(from:a+(b-a)*lo,height:ha+(hb-ha)*lo,to:a+(b-a)*hi,height:ha+(hb-ha)*hi,bodyRadius:radius)
                }
            }
            forEachLivingPlayer {
                let slot=activePlayerSlot,a=playerStarts?[slot] ?? hero,ha=playerHeights?[slot] ?? heroElevation
                if touching(from:a,height:ha,to:hero,height:heroElevation,radius:0.29) {loseLife(allowAfterRound:true)}
            }
            for i in foes.indices where foes[i].hp>0 {
                let foe=foes[i],start=foeStarts?[foe.id] ?? (foe.p,foe.elevation)
                if touching(from:start.0,height:start.1,to:foe.p,height:foe.elevation,radius:foe.hitRadius) {
                    foes[i].hp=0;foes[i].creditSlot=nil;foes[i].environmentKill=true
                }
            }
        }
    }
}
