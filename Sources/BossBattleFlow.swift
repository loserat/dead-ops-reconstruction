import Foundation

/// Timing transcribed from the archived scripts. No original animations or engine threads.
/// The 100ms setup wait precedes the five-second HUD introduction.
struct BossArrivalClock {
    enum Event:Equatable {case brother(Int),startBattle}
    let brotherCount:Int
    private(set) var clock=0.0,spawned=0,battleStarted=false
    private var milliseconds=0.0,compensation=0.0
    init?(round:Int) {
        guard round>0,round%40==0 else{return nil}
        brotherCount=round/40
    }
    var firstArrivalAt:Double {5.1}
    var battleStartsAt:Double {firstArrivalAt+Double(brotherCount)*10}
    var nextEventAt:Double? {battleStarted ? nil:spawned<brotherCount ? firstArrivalAt+Double(spawned)*10:battleStartsAt}
    var introductionOpacity:Double {
        let t=clock-0.1
        if t<0 || t>=5 {return 0}
        return t<2 ? t/2:t<3 ? 1:(5-t)/2
    }
    var subtitleOpacity:Double {
        let t=clock-0.1
        if t<0 || t>=5 {return 0}
        return t<2.5 ? t/2.5:t<3 ? 1:(5-t)/2
    }
    mutating func step(_ dt:Double,paused:Bool=false)->[Event] {
        guard !paused,dt.isFinite,dt>0 else{return []}
        let increment=dt*1000-compensation,next=milliseconds+increment
        guard increment.isFinite,next.isFinite else{return []}
        compensation=(next-milliseconds)-increment;milliseconds=next;clock=next/1000
        var events=[Event]()
        while let due=nextEventAt,due*1000<=milliseconds+0.0000001 {
            if spawned<brotherCount {events.append(.brother(spawned));spawned+=1}
            else {events.append(.startBattle);battleStarted=true}
        }
        return events
    }
}

/// Source RandomIntRange is represented with an excluded upper bound. The archived
/// engine executable is unauthenticated; these local integer semantics are explicit.
enum BossSourceRandom {
    static func unit(_ roll:Double)->Double {roll.isFinite ? max(0,min(1.0.nextDown,roll)):0}
    static func integer(_ lower:Int,_ upper:Int,roll:Double)->Int {
        lower+min(upper-lower-1,Int(unit(roll)*Double(upper-lower)))
    }
}

/// The health monitor attaches to the LAST spawned brother, after the last ten-second
/// wait. Its baseline is the health at attachment, not max health or all brothers' sum.
struct BossHealthBurstClock {
    struct Band:Equatable {let kind:FoeKind,lower:Int,upper:Int}
    struct Attempt:Equatable {let time:Double,kind:FoeKind}
    let baselineHealth:Double
    private(set) var clock=0.0,attempts=0,admitted=0,rejected=0,isCancelled=false
    private var milliseconds=0.0,compensation=0.0,nextMilliseconds=0.0
    private enum Task {case evaluate,burst(FoeKind,Int),cooldown}
    private var task:Task = .evaluate
    init?(health:Double) {
        guard health.isFinite,health>0 else{return nil}
        baselineHealth=health
    }
    static func band(fraction:Double)->Band? {
        guard fraction.isFinite,fraction>0 else{return nil}
        switch fraction {
        case ..<0.20:return Band(kind:.hound,lower:3,upper:6)
        case ..<0.35:return Band(kind:.engineer,lower:10,upper:20)
        case ..<0.50:return Band(kind:.martyr,lower:3,upper:10) // moss_big, not ordinary moss.
        case ..<0.65:return Band(kind:.villager,lower:10,upper:15)
        case ..<0.80:return Band(kind:.crawler,lower:10,upper:16)
        case ..<0.95:return Band(kind:.prisoner,lower:10,upper:15)
        default:return nil
        }
    }
    var nextEventAt:Double? {isCancelled ? nil:nextMilliseconds/1000}
    mutating func cancel(){isCancelled=true}
    /// The health accessor and actual admission run at their event times. Failed engine
    /// admission consumes one attempt. The final 50ms wait precedes the cooldown draw.
    mutating func step(_ dt:Double,paused:Bool=false,processCurrentEvents:Bool=false,health:()->Double,random:()->Double,admit:(Attempt)->Bool) {
        guard !isCancelled,!paused,dt.isFinite,dt>0 || (dt==0 && processCurrentEvents) else{return}
        let increment=dt*1000-compensation,target=milliseconds+increment
        guard increment.isFinite,target.isFinite else{return}
        let hp=health()
        guard hp.isFinite,hp>0 else{cancel();return}
        compensation=(target-milliseconds)-increment;milliseconds=target;clock=target/1000
        while nextMilliseconds<=target+0.0000001 {
            let current=health()
            guard current.isFinite,current>0 else{cancel();break}
            switch task {
            case .evaluate:
                if let band=Self.band(fraction:current/baselineHealth) {
                    task = .burst(band.kind,BossSourceRandom.integer(band.lower,band.upper,roll:random()))
                }else {task = .cooldown}
            case .burst(let kind,let count):
                attempts+=1
                if admit(Attempt(time:nextMilliseconds/1000,kind:kind)) {admitted+=1}else{rejected+=1}
                task=count>1 ? .burst(kind,count-1):.cooldown
                nextMilliseconds+=50
            case .cooldown:
                nextMilliseconds+=Double(BossSourceRandom.integer(5,12,roll:random()))*1000
                task = .evaluate
            }
        }
    }
}

/// Reuses the ordinary source group's already-sampled templates. Before the final
/// index, a living boss rolls the cursor back by RandomIntRange(4,10). Old overlapping
/// group threads retain their own start/deadline. There is no finite replacement budget.
struct BossAttackWaves {
    struct Attempt:Equatable {let occurrence:Int,group:Int,ordinal:Int,side:EntrySide,time:Double}
    struct Start:Equatable {let occurrence:Int,group:Int,time:Double}
    private struct Thread {
        let occurrence:Int,group:Int,startMilliseconds:Double
        var ordinal:Int
        var nextMilliseconds:Double {startMilliseconds+Double(ordinal)*700}
    }
    let templates:[TimedAttackWaves.Group]
    private(set) var clock=0.0,mainSequenceEndsAt:Double?,mainFunctionReturnsAt:Double?
    private(set) var currentGroup:TimedAttackWaves.Group?,currentGroupStartedAt:Double?
    private(set) var groupsStarted=0,rollbacks=0,isCancelled=false
    private(set) var totals=TimedAttackWaves.Result()
    private var milliseconds=0.0,compensation=0.0,nextStartMilliseconds:Double?=0,cursor=0
    private var threads=[Thread]()
    init?(templates:[TimedAttackWaves.Group]) {
        guard templates.count>=2,templates.count<=4096,
              templates.enumerated().allSatisfy({i,g in
                  g.index==i && g.durationMilliseconds.isFinite && g.durationMilliseconds>0 &&
                  g.nextGroupMilliseconds.isFinite && g.nextGroupMilliseconds>=1000
              }) else{return nil}
        self.templates=templates
    }
    var roundActiveFlag:Bool {!isCancelled && (mainSequenceEndsAt.map{clock<$0} ?? true)}
    var mainFunctionHasReturned:Bool {!isCancelled && (mainFunctionReturnsAt.map{clock+1e-9 >= $0} ?? false)}
    var activeThreadCount:Int {threads.count}
    var pendingAttemptCount:Int {threads.reduce(0){$0+templates[$1.group].attemptCount-$1.ordinal}}
    var nextEventAt:Double? {
        guard !isCancelled else{return nil}
        return ([nextStartMilliseconds]+threads.map{Optional($0.nextMilliseconds)}).compactMap{$0}.min().map{$0/1000}
    }
    mutating func cancel(){isCancelled=true;nextStartMilliseconds=nil;threads=[]}
    @discardableResult mutating func step(_ dt:Double,paused:Bool=false,processCurrentEvents:Bool=false,bossDead:Bool,rollbackRandom:()->Double,
                                         started:(Start)->Void={_ in},admit:(Attempt)->Bool)->TimedAttackWaves.Result {
        guard !isCancelled,!paused,dt.isFinite,dt>0 || (dt==0 && processCurrentEvents) else{return .init()}
        let increment=dt*1000-compensation,target=milliseconds+increment
        guard increment.isFinite,target.isFinite else{return .init()}
        compensation=(target-milliseconds)-increment;milliseconds=target;clock=target/1000
        var result=TimedAttackWaves.Result()
        while true {
            let dueThread=threads.indices.min {a,b in
                let x=threads[a],y=threads[b]
                return x.nextMilliseconds != y.nextMilliseconds ? x.nextMilliseconds<y.nextMilliseconds:x.occurrence<y.occurrence
            }
            let attemptTime=dueThread.map{threads[$0].nextMilliseconds} ?? .infinity
            let groupTime=nextStartMilliseconds ?? .infinity
            let due=min(attemptTime,groupTime)
            guard due.isFinite,due<=target+0.0000001 else{break}
            if attemptTime<=groupTime,let index=dueThread {
                var thread=threads[index]
                // Source group checks boss_is_dead after its wait, before another spawn.
                if bossDead {threads.remove(at:index);continue}
                let group=templates[thread.group]
                result.attempts+=1
                if admit(Attempt(occurrence:thread.occurrence,group:thread.group,ordinal:thread.ordinal,side:group.side,time:due/1000)) {result.admitted+=1}else{result.rejected+=1}
                thread.ordinal+=1
                if thread.ordinal<group.attemptCount {threads[index]=thread}else{threads.remove(at:index)}
            }else {
                if bossDead {
                    mainSequenceEndsAt=due/1000;mainFunctionReturnsAt=due/1000+1;nextStartMilliseconds=nil
                    continue
                }
                if cursor==templates.count-1 {
                    cursor=max(0,cursor-BossSourceRandom.integer(4,10,roll:rollbackRandom()));rollbacks+=1
                }
                let group=templates[cursor]
                currentGroup=group;currentGroupStartedAt=due/1000
                started(Start(occurrence:groupsStarted,group:cursor,time:due/1000))
                threads.append(Thread(occurrence:groupsStarted,group:cursor,startMilliseconds:due,ordinal:0))
                groupsStarted+=1;cursor+=1;nextStartMilliseconds=due+group.nextGroupMilliseconds
            }
        }
        totals.attempts+=result.attempts;totals.admitted+=result.admitted;totals.rejected+=result.rejected
        return result
    }
}
