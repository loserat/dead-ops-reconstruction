import Foundation

/// Archived DOA Tesla rules. Geometry uses the project's explicit 100 source units / world unit mapping.
/// Native VM/network/body-tag behavior is not authenticated by the third-party script archive.
enum TeslaRules {
    static let gate=2.0,networkFrame=0.1,travel=0.5,minArcDistance=1.28
    static let maximumTargets=20,maximumDepth=4
    static let orbitRadius=0.8,orbitHeight=0.5,triggerRadius=0.18,triggerHeight=0.5,angularSpeed=Double.pi
    static let initialAngles=[Double.pi/2,-Double.pi/2,0,Double.pi]
    static func radius(_ depth:Int)->Double {3-0.2*Double(depth)}
    static func secondaryWait(unit:Double,depth:Int)->Double {
        // Script says RandomFloat(.2,.6), not RandomFloatRange. Interpret its first argument as maximum.
        // Extra-argument semantics in the original T5 VM remain unverified; this distribution is an inference.
        max(0,min(1,unit.isFinite ? unit:0))*0.2*Double(depth)
    }
}
struct TeslaTarget {
    let id:Int,p:V2,headHeight:Double,spineHeight:Double
    var alive=true,boss=false,marked=false
    func headDistance(to other:TeslaTarget)->Double {hypot((p-other.p).length,headHeight-other.headHeight)}
    func spineDistance(to other:TeslaTarget)->Double {hypot((p-other.p).length,spineHeight-other.spineHeight)}
}
enum TeslaEvent {
    case arc(from:TeslaTarget,to:TeslaTarget,at:Double)
    case kill(target:Int,depth:Int,at:Double)
}
private struct TeslaFrame {
    var target:TeslaTarget,source:TeslaTarget,depth:Int,due:Double
    var neighbors:[Int]?=nil,cursor=0
}
private struct TeslaProgram {
    var stack:[TeslaFrame],cachedIDs:[Int]?=nil,admitted=1
}
private enum TeslaJobStage {case delay,choke,arriving}
private struct TeslaJob {
    var target:TeslaTarget,source:TeslaTarget,depth:Int,due:Double,stage:TeslaJobStage = .delay
}

/// A local deterministic coroutine scheduler, per player. Target marks live on shared world bodies.
/// Planning is depth-first with sibling reservation; damage jobs keep their owner after planning finishes.
final class TeslaDischarge {
    private(set) var clock=0.0,lastWorldClock=0.0,availableAt=0.0,arcCount=0
    private var programs:[TeslaProgram]=[],jobs:[TeslaJob]=[]
    var gateRemaining:Double {max(0,availableAt-clock)}
    var ready:Bool {clock+1e-9>=availableAt}
    var pendingPrograms:Int {programs.count}
    var pendingDamage:Int {jobs.count}
    var pendingNodes:Int {programs.reduce(0){$0+$1.stack.count}+jobs.count}
    @discardableResult func begin(_ target:TeslaTarget,mark:(Int,Bool)->Void)->Bool {
        guard ready,!target.marked else{return false}
        availableAt=clock+TeslaRules.gate;arcCount=0
        guard !target.boss else{return true}
        mark(target.id,true)
        programs.append(TeslaProgram(stack:[TeslaFrame(target:target,source:target,depth:1,due:clock+TeslaRules.networkFrame)]))
        return true
    }
    /// Map/room removal invalidates target threads, but does not gift a new discharge gate.
    func clearTargets(){programs=[];jobs=[];arcCount=0}
    /// Own physical-death interpretation: cancel player-death-bound planning, retain disconnect-only damage jobs.
    /// The native engine's "death" versus script "player_died" delivery is not established.
    func cancelPlanning(){programs=[]}
    func advance(_ dt:Double,at worldClock:Double?=nil,targets:()->[TeslaTarget],lookup:(Int)->TeslaTarget?,mark:(Int,Bool)->Void,visible:(TeslaTarget,TeslaTarget)->Bool,random:()->Double,emit:(TeslaEvent)->Void) {
        guard dt.isFinite,dt>=0 else{return}
        let worldEnd=worldClock ?? lastWorldClock+dt
        guard worldEnd.isFinite else{return}
        let used=min(dt,max(0,worldEnd-lastWorldClock));lastWorldClock=max(lastWorldClock,worldEnd)
        let end=clock+used
        // Every event either consumes a job/frame or schedules a later bounded node. No frame-rate polling.
        while true {
            let pi=programs.indices.filter{programs[$0].stack.last != nil}.min {programs[$0].stack.last!.due < programs[$1].stack.last!.due}
            let ji=jobs.indices.min {jobs[$0].due < jobs[$1].due}
            let pt=pi.map{programs[$0].stack.last!.due} ?? .infinity
            let jt=ji.map{jobs[$0].due} ?? .infinity
            let next=min(pt,jt)
            guard next.isFinite,next<=end+1e-9 else{break}
            clock=max(clock,next)
            if pt<=jt,let index=pi {
                var program=programs.remove(at:index)
                var frame=program.stack.removeLast()
                let node=lookup(frame.target.id) ?? frame.target
                if program.cachedIDs==nil {
                    program.cachedIDs=targets().sorted {a,b in
                        let da=node.headDistance(to:a),db=node.headDistance(to:b)
                        return abs(da-db)<1e-9 ? a.id<b.id:da<db
                    }.map(\.id)
                }
                // Reserve ALL siblings before descending, including bosses. Boss reservations stay marked.
                let neighbors=(program.cachedIDs ?? []).compactMap(lookup).filter {
                    $0.alive && !$0.marked && node.headDistance(to:$0)<=TeslaRules.radius(frame.depth)+1e-9 && visible(node,$0)
                }
                for target in neighbors {mark(target.id,true)}
                frame.target=node;frame.neighbors=neighbors.map(\.id)
                let wait=frame.depth>1 ? TeslaRules.secondaryWait(unit:random(),depth:frame.depth):0
                jobs.append(TeslaJob(target:node,source:frame.source,depth:frame.depth,due:clock+wait))
                program.stack.append(frame)
                // Resume synchronous callers immediately until one child enters its .1-second wait.
                while !program.stack.isEmpty {
                    var parent=program.stack.removeLast()
                    var descended=false
                    let list=parent.neighbors ?? []
                    while parent.cursor<list.count {
                        let id=list[parent.cursor];parent.cursor+=1
                        guard let child=lookup(id),child.alive,child.id != parent.target.id else{continue}
                        if child.boss {continue}
                        let depth=parent.depth+1
                        if depth>TeslaRules.maximumDepth || program.admitted>=TeslaRules.maximumTargets || TeslaRules.radius(depth)<=0 {mark(id,false);continue}
                        program.admitted+=1
                        mark(id,true)
                        program.stack.append(parent)
                        program.stack.append(TeslaFrame(target:child,source:parent.target,depth:depth,due:clock+TeslaRules.networkFrame))
                        descended=true;break
                    }
                    if descended {break}
                }
                if !program.stack.isEmpty {programs.insert(program,at:index)}
            }else if let index=ji {
                var job=jobs.remove(at:index)
                guard let target=lookup(job.target.id),target.alive else{continue}
                if job.stage == .arriving {emit(.kill(target:target.id,depth:job.depth,at:clock));continue}
                if job.depth==1 {emit(.kill(target:target.id,depth:job.depth,at:clock));continue}
                if job.stage == .delay && arcCount>3 {
                    job.stage = .choke;job.due=clock+TeslaRules.networkFrame;jobs.append(job);continue
                }
                if job.stage == .choke {arcCount=0}
                arcCount+=1
                // Own entities discard dead bodies promptly; retain the selected parent's last tag point.
                // Original corpse animation/tag motion is unavailable, not replaced by the living player.
                let source=lookup(job.source.id) ?? job.source
                if source.spineDistance(to:target)<TeslaRules.minArcDistance {
                    emit(.kill(target:target.id,depth:job.depth,at:clock))
                }else {
                    emit(.arc(from:source,to:target,at:clock))
                    job.stage = .arriving;job.due=clock+TeslaRules.travel;jobs.append(job)
                }
            }
        }
        clock=end
    }
}
