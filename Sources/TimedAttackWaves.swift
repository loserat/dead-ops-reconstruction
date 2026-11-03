import Foundation

/// Behavioral transcription of the archived spawn-group timers, not original engine code.
/// Local play waits 0.6s plus wait_network_frame's 0.1s. Remote ACK timing is not modeled.
/// Production ordinary-wave clock;boss-specific orchestration is handled separately.
struct TimedAttackWaves {
    enum PlanningError:Error {case invalidRound,tooManyGroups}
    struct Group {
        let index:Int,side:EntrySide,startMilliseconds:Double,durationMilliseconds:Double,nextGroupMilliseconds:Double
        var startsAt:Double {startMilliseconds/1000}
        var duration:Double {durationMilliseconds/1000}
        var endsAt:Double {(startMilliseconds+durationMilliseconds)/1000}
        var nextGroupDelay:Double {nextGroupMilliseconds/1000}
        var attemptCount:Int {
            var count=Int(ceil(durationMilliseconds/700))
            // Compare group-relative milliseconds: .7 * 3 must not invent an attempt at 2.1s.
            while count>0 && Double(count-1)*700>=durationMilliseconds {count-=1}
            while Double(count)*700<durationMilliseconds {count+=1}
            return count
        }
    }
    struct Attempt:Equatable {
        let group:Int,ordinal:Int,side:EntrySide,time:Double
    }
    struct Result:Equatable {
        var attempts=0,admitted=0,rejected=0
    }
    private struct Ticket {let group:Int,ordinal:Int,milliseconds:Double}
    let groups:[Group]
    let mainSequenceEndsAt:Double,mainFunctionReturnsAt:Double,lastGroupEndsAt:Double
    private(set) var clock=0.0,pendingAttemptCount:Int,isCancelled=false
    private(set) var totals=Result()
    private var milliseconds=0.0,compensation=0.0,heap:[Ticket]=[]

    /// Reject an unrepresentable program explicitly instead of quietly reducing the original count.
    static func groupCount(round:Int)throws->Int {
        guard round>0 else{throw PlanningError.invalidRound}
        let lap=(round-1)/40,limit=(lap+1).multipliedReportingOverflow(by:30)
        guard !limit.overflow else{throw PlanningError.tooManyGroups}
        return min(round>Int.max-6 ? Int.max:round+6,limit.partialValue)
    }
    init(round:Int,random:()->Double)throws {
        let count=try Self.groupCount(round:round)
        guard count<=4096 else{throw PlanningError.tooManyGroups}
        func roll()->Double {let x=random();return x.isFinite ? min(1.0.nextDown,max(0,x)):0}
        var planned=[Group](),start=0.0
        for index in 0..<count {
            let duration=1+roll()*(1+Double(index)*0.3)+roll()*(1+Double(round)*0.2)
            let side:[EntrySide]=[.north,.south,.west,.east]
            let front=side[min(3,Int(roll()*4))],gap=1+roll()*duration
            planned.append(Group(index:index,side:front,startMilliseconds:start,durationMilliseconds:duration*1000,nextGroupMilliseconds:gap*1000))
            start+=gap*1000
        }
        groups=planned;mainSequenceEndsAt=start/1000;mainFunctionReturnsAt=mainSequenceEndsAt+1
        lastGroupEndsAt=planned.map(\.endsAt).max() ?? 0
        pendingAttemptCount=planned.reduce(0){$0+$1.attemptCount}
        for group in planned {push(Ticket(group:group.index,ordinal:0,milliseconds:group.startMilliseconds))}
    }
    /// These are distinct in the source. Never infer round clear just from an empty event heap.
    var roundActiveFlag:Bool {!isCancelled && clock<mainSequenceEndsAt}
    var mainFunctionHasReturned:Bool {!isCancelled && clock>=mainFunctionReturnsAt}
    var allGroupTimersExpired:Bool {clock>=lastGroupEndsAt}
    var currentGroup:Group? {groups.last(where:{$0.startsAt<=clock})}
    var nextAttemptAt:Double? {heap.first.map{$0.milliseconds/1000}}

    /// A rejected engine admission consumes that timed attempt; it is never queued for later.
    /// The caller must still select its spawn point and perform the actual shared AI admission.
    mutating func step(_ dt:Double,paused:Bool=false,admit:(Attempt)->Bool)->Result {
        guard !isCancelled,!paused,dt.isFinite,dt>0 else{return Result()}
        let increment=dt*1000-compensation,next=milliseconds+increment
        guard increment.isFinite,next.isFinite else{return Result()}
        compensation=(next-milliseconds)-increment;milliseconds=next;clock=milliseconds/1000
        var result=Result()
        while let ticket=heap.first,ticket.milliseconds<=milliseconds+0.0000001 {
            _=pop();let group=groups[ticket.group]
            let event=Attempt(group:ticket.group,ordinal:ticket.ordinal,side:group.side,time:ticket.milliseconds/1000)
            result.attempts+=1;pendingAttemptCount-=1
            if admit(event) {result.admitted+=1}else{result.rejected+=1}
            let ordinal=ticket.ordinal+1
            if ordinal<group.attemptCount {push(Ticket(group:ticket.group,ordinal:ordinal,milliseconds:group.startMilliseconds+Double(ordinal)*700))}
        }
        totals.attempts+=result.attempts;totals.admitted+=result.admitted;totals.rejected+=result.rejected
        return result
    }
    mutating func cancel(){isCancelled=true;heap.removeAll(keepingCapacity:false);pendingAttemptCount=0}
    private func precedes(_ a:Ticket,_ b:Ticket)->Bool {
        a.milliseconds != b.milliseconds ? a.milliseconds<b.milliseconds:a.group != b.group ? a.group<b.group:a.ordinal<b.ordinal
    }
    private mutating func push(_ ticket:Ticket) {
        heap.append(ticket);var i=heap.count-1
        while i>0 {let parent=(i-1)/2;if !precedes(heap[i],heap[parent]) {break};heap.swapAt(i,parent);i=parent}
    }
    private mutating func pop()->Ticket? {
        guard let first=heap.first else{return nil}
        let last=heap.removeLast();guard !heap.isEmpty else{return first};heap[0]=last
        var i=0
        while i*2+1<heap.count {
            let left=i*2+1,right=left+1,child=right<heap.count && precedes(heap[right],heap[left]) ? right:left
            if !precedes(heap[child],heap[i]) {break};heap.swapAt(i,child);i=child
        };return first
    }
}
