import Foundation

/// Local translation of archived pickup/prize threads; see loot-spawning-reference-v55-WIP.txt.
/// This kernel has no engine assets, controller input, audio, or original map coordinates.
enum SourceLootRandom {
    static func unit(_ value:Double)->Double {value.isFinite ? max(0,min(1.0.nextDown,value)):0}
    static func index(_ count:Int,_ value:Double)->Int {min(count-1,Int(unit(value)*Double(count)))}
}
struct SourceLootEligibility {
    var round=1,roundActive=true,allPlayersDead=false,magicalExit=false,prison=false,turretAvailable=true
    var anyPlayerExclusive=false,groundExclusive=false
    static let exclusive:Set<PickupKind>=[.tank,.helicopter,.orb,.teddy,.barrelShield]
    func allows(_ kind:PickupKind)->Bool {
        let minimum:Int
        switch kind {case .tank:minimum=4;case .monkey:minimum=5;case .turret:minimum=7;case .helicopter:minimum=9;default:minimum=1}
        guard round>=minimum else{return false}
        if kind == .turret && (magicalExit || !turretAvailable) {return false}
        if kind == .monkey && magicalExit {return false}
        if kind == .helicopter && prison && (magicalExit || !roundActive) {return false}
        if Self.exclusive.contains(kind) && (anyPlayerExclusive || groundExclusive) {return false}
        return kind != .life && kind != .treasure && kind != .gem
    }
}
struct SourceLootBag {
    // Repeated chicken/turret entries affect the shuffled first choice; array_remove removes ALL matches.
    static let template:[PickupKind]=[.flamethrower,.deathMachine,.spread,.grenade,.rocket,.ray,.bomb,.boots,.dash,.tank,.turret,.turret,.turret,.monkey,.barrelShield,.orb,.teddy,.chicken,.chicken,.chicken,.helicopter]
    private(set) var remaining:[PickupKind]=[],refills=0,draws=0
    mutating func draw(random:()->Double)->PickupKind {
        if Double(remaining.count)<Double(Self.template.count)/4 {
            remaining=Self.template;refills+=1
            // Source randomize_array swaps each index with a random index in the entire array.
            for i in remaining.indices {remaining.swapAt(i,SourceLootRandom.index(remaining.count,random()))}
        }
        let selected=remaining[0];remaining.removeAll{$0==selected};draws+=1;return selected
    }
}

/// A random wait continues while inactive. Afterwards inactive polls are one second apart.
/// Resuming from a poll skips one outer-loop wait and can spawn immediately, with no fresh delay.
struct SourceLootPulse {
    enum Stage {case randomWait,inactivePoll,retrySelection}
    enum Attempt {case complete(spawned:Bool),retry}
    let upperWait:Double
    private(set) var nextAt:Double,stage:Stage = .randomWait
    private(set) var requests=0,completed=0,retries=0,inactivePolls=0,deadSkips=0
    init(upperWait:Double,random:Double){self.upperWait=upperWait;nextAt=10+(upperWait-10)*SourceLootRandom.unit(random)}
    mutating func fire(at time:Double,context:SourceLootEligibility,random:()->Double,attempt:()->Attempt) {
        if stage != .retrySelection {
            guard context.roundActive else {stage = .inactivePoll;nextAt=time+1;inactivePolls+=1;return}
            if context.allPlayersDead {deadSkips+=1;stage = .randomWait;nextAt=time+10+(upperWait-10)*SourceLootRandom.unit(random());return}
            requests+=1
        }
        switch attempt() {
        case .retry:stage = .retrySelection;retries+=1;nextAt=time+0.1
        case .complete(let spawned):
            if spawned {completed+=1};stage = .randomWait;nextAt=time+10+(upperWait-10)*SourceLootRandom.unit(random())
        }
    }
}
struct SourceLootSite:Equatable {var p:V2,radius:Double}
struct SourceLootEmission:Equatable {
    let clock:Double,kind:PickupKind,p:V2,gemUnits:Int?,untilCleanup:Bool
    var popup:PickupPopup?=nil
}

/// Merges the two independent global threads and their staggered child jobs by event deadline.
/// Equal-deadline ordering is deterministic locally; the original VM's thread ordering is unverified.
final class SourceLootDirector {
    private struct Cluster {let serial:Int,site:SourceLootSite,untilCleanup:Bool;var left:Int,nextAt:Double}
    private struct Globs {let serial:Int;var left:Int,nextAt:Double}
    private struct PopupGems {let serial:Int,origin:V2;var left:Double,nextAt:Double}
    private enum RoomCommand {case random(Double),specific(PickupKind,Double),treasure(Int),finish}
    private struct RoomJob {
        let serial:Int,commands:[RoomCommand]
        var index=0,nextAt:Double,selectedSite:SourceLootSite?=nil,selecting=false
    }
    private(set) var clock=0.0,powerups:SourceLootPulse,prizes:SourceLootPulse,bag=SourceLootBag()
    private var pendingSite:SourceLootSite?,clusters:[Cluster]=[],globs:[Globs]=[],rooms:[RoomJob]=[],nextSerial=0
    private var popupGems:[PopupGems]=[]
    private(set) var emitted=0,clusterStarts=0,cancelledChildren=0
    private(set) var roomProgramsStarted=0,roomProgramsCompleted=0,roomCommandsCompleted=0,roomFundsEmitted=0,roomRetries=0,roomSpecificSkipped=0
    var pendingTreasureChildren:Int {clusters.count+globs.count}
    var pendingRoomPrograms:Int {rooms.count}
    var pendingPopupGemPrograms:Int {popupGems.count}
    var pendingChildren:Int {pendingTreasureChildren+pendingRoomPrograms+pendingPopupGemPrograms}
    init(random:()->Double) {
        powerups=SourceLootPulse(upperWait:15,random:random());prizes=SourceLootPulse(upperWait:20,random:random())
    }
    private func serial()->Int {nextSerial+=1;return nextSerial}
    /// clear_all_pickups cancels treasure child threads, but not the two global timer loops.
    /// A blocked equipment selection retains its already chosen site, as in the source function.
    // Only spawn_treasures has endon(stop_spawning_pickups). Room equipment and popup-gem threads do not.
    func clearArenaChildren(){cancelledChildren+=pendingTreasureChildren;clusters=[];globs=[]}
    func queueBonusRoom(random:()->Double) {
        let count=1+SourceLootRandom.index(2,random())
        let commands=Array(repeating:RoomCommand.random(0),count:count+1)+[.treasure(25)]
        rooms.append(RoomJob(serial:serial(),commands:commands,nextAt:clock));roomProgramsStarted+=1
    }
    func queueArmory(players:Int) {
        let count=max(1,min(4,players));var commands=[RoomCommand]()
        for _ in 0..<4 {commands += [.random(0.2),.specific(.bomb,0.2),.specific(.dash,0.2)]}
        commands += Array(repeating:.specific(.chicken,0.2),count:count==1 ? 4:1)
        commands += Array(repeating:.random(0.2),count:count)
        commands.append(.finish)
        rooms.append(RoomJob(serial:serial(),commands:commands,nextAt:clock));roomProgramsStarted+=1
    }
    func queueRoundTreasure(boss:Bool){globs.append(Globs(serial:serial(),left:boss ? 25:3,nextAt:clock))}
    func queueCluster(at site:SourceLootSite,count:Int,untilCleanup:Bool=false) {
        guard count>0 else{return}
        clusters.append(Cluster(serial:serial(),site:site,untilCleanup:untilCleanup,left:count,nextAt:clock));clusterStarts+=1
    }
    func queuePopupGems(increments:Double,at origin:V2) {
        guard increments.isFinite,increments>0,origin.x.isFinite,origin.y.isFinite else{return}
        popupGems.append(PopupGems(serial:serial(),origin:origin,left:increments,nextAt:clock))
    }
    func queueGoldenBull(at origin:V2,random:()->Double) {
        // Radius85 is translated explicitly to our own60source-units-per-map-unit scale.
        queueCluster(at:SourceLootSite(p:origin,radius:85/PickupPopup.sourceUnitsPerWorldUnit),count:5+SourceLootRandom.index(5,random()),untilCleanup:true)
        queuePopupGems(increments:Double(TreasureRules.barUnits)*(1+2*SourceLootRandom.unit(random())),at:origin)
    }
    private func point(_ site:SourceLootSite,random:()->Double)->V2 {
        // Own editable coordinate scale. Original map struct radii/grid are not included.
        site.p+V2(x:(SourceLootRandom.unit(random())*2-1)*site.radius,y:(SourceLootRandom.unit(random())*2-1)*site.radius)
    }
    func step(_ dt:Double,context:(Double)->SourceLootEligibility,site:(Double)->SourceLootSite?,random:()->Double,emit:(SourceLootEmission)->Void) {
        guard dt.isFinite,dt>=0,clock+dt<1e12 else{return}
        let end=clock+dt
        while true {
            let clusterIndex=clusters.indices.min{a,b in clusters[a].nextAt==clusters[b].nextAt ? clusters[a].serial<clusters[b].serial:clusters[a].nextAt<clusters[b].nextAt}
            let globIndex=globs.indices.min{a,b in globs[a].nextAt==globs[b].nextAt ? globs[a].serial<globs[b].serial:globs[a].nextAt<globs[b].nextAt}
            let roomIndex=rooms.indices.min{a,b in rooms[a].nextAt==rooms[b].nextAt ? rooms[a].serial<rooms[b].serial:rooms[a].nextAt<rooms[b].nextAt}
            let popupIndex=popupGems.indices.min{a,b in popupGems[a].nextAt==popupGems[b].nextAt ? popupGems[a].serial<popupGems[b].serial:popupGems[a].nextAt<popupGems[b].nextAt}
            let times=[powerups.nextAt,prizes.nextAt,clusterIndex.map{clusters[$0].nextAt} ?? .infinity,globIndex.map{globs[$0].nextAt} ?? .infinity,roomIndex.map{rooms[$0].nextAt} ?? .infinity,popupIndex.map{popupGems[$0].nextAt} ?? .infinity]
            let which=times.indices.min{times[$0]<times[$1]}!,time=times[which]
            guard time<=end+1e-9 else{break}
            let now=context(time)
            switch which {
            case 0:
                var timer=powerups
                timer.fire(at:time,context:now,random:random,attempt:{
                    if self.powerups.stage != .retrySelection {self.pendingSite=site(time)}
                    guard let chosenSite=self.pendingSite else{return .complete(spawned:false)}
                    let kind=self.bag.draw(random:random)
                    guard now.allows(kind) else{return .retry}
                    emit(SourceLootEmission(clock:time,kind:kind,p:self.point(chosenSite,random:random),gemUnits:nil,untilCleanup:false));self.emitted+=1;self.pendingSite=nil
                    return .complete(spawned:true)
                });powerups=timer
            case 1:
                var timer=prizes
                timer.fire(at:time,context:now,random:random,attempt:{
                    guard let chosenSite=site(time) else{return .complete(spawned:false)}
                    self.clusters.append(Cluster(serial:self.serial(),site:chosenSite,untilCleanup:false,left:3+SourceLootRandom.index(5,random()),nextAt:time));self.clusterStarts+=1
                    return .complete(spawned:true)
                });prizes=timer
            case 2:
                let i=clusterIndex!;var job=clusters[i]
                let p=point(job.site,random:random),isGem=SourceLootRandom.unit(random())*100<1
                let units=isGem ? TreasureRules.randomGemUnits(random()):nil
                emit(SourceLootEmission(clock:time,kind:isGem ? .gem:.treasure,p:p,gemUnits:units,untilCleanup:!isGem && job.untilCleanup));emitted+=1
                job.left-=1;job.nextAt=time+0.2+(isGem ? 0.1:0)
                if job.left==0 {clusters.remove(at:i)}else{clusters[i]=job}
            case 3:
                let i=globIndex!;var job=globs[i]
                if let chosenSite=site(time) {
                    clusters.append(Cluster(serial:serial(),site:chosenSite,untilCleanup:false,left:3+SourceLootRandom.index(5,random()),nextAt:time));clusterStarts+=1
                }
                job.left-=1
                if job.left==0 {globs.remove(at:i)}else{job.nextAt=time+0.1+0.7*SourceLootRandom.unit(random());globs[i]=job}
            case 4:
                let i=roomIndex!;var job=rooms[i]
                let delay:Double
                switch job.commands[job.index] {
                case .finish:
                    rooms.remove(at:i);roomProgramsCompleted+=1;continue
                case .treasure(let count):
                    globs.append(Globs(serial:serial(),left:count,nextAt:time));rooms.remove(at:i);roomProgramsCompleted+=1;continue
                case .random(let wait):
                    delay=wait
                    if !job.selecting {job.selectedSite=site(time);job.selecting=true}
                    if let chosen=job.selectedSite {
                        let kind=bag.draw(random:random)
                        if !now.allows(kind) {job.nextAt=time+0.1;rooms[i]=job;roomRetries+=1;continue}
                        emit(SourceLootEmission(clock:time,kind:kind,p:point(chosen,random:random),gemUnits:nil,untilCleanup:false));emitted+=1;roomFundsEmitted+=1
                    }
                case .specific(let kind,let wait):
                    delay=wait
                    if let chosen=site(time),now.allows(kind) {
                        emit(SourceLootEmission(clock:time,kind:kind,p:point(chosen,random:random),gemUnits:nil,untilCleanup:false));emitted+=1;roomFundsEmitted+=1
                    }else{roomSpecificSkipped+=1}
                }
                roomCommandsCompleted+=1;job.index+=1;job.selecting=false;job.selectedSite=nil;job.nextAt=time+delay;rooms[i]=job
            default:
                let i=popupIndex!;var job=popupGems[i]
                let chunk=min(Double(TreasureRules.quarterGemUnits),job.left)
                let popup=PickupPopup(origin:job.origin,random:random)
                emit(SourceLootEmission(clock:time,kind:.gem,p:job.origin,gemUnits:Int(chunk),untilCleanup:false,popup:popup));emitted+=1
                job.left-=chunk
                if job.left<=0 {popupGems.remove(at:i)}else{job.nextAt=time+0.2;popupGems[i]=job}
            }
        };clock=end
    }
}

extension GameCore {
    /// Bridge for source-timed emissions, called after aging existing world funds in a frame.
    /// World frame integration advances to each event and uses the actual birth as frameEnd here.
    @discardableResult func materializeSourceLoot(_ event:SourceLootEmission,frameEnd:Double)->Int? {
        guard frameEnd.isFinite,event.clock.isFinite,frameEnd+1e-9>=event.clock else{return nil}
        var fund=worldPickup(id:id(),p:layout.clamped(event.p,clearance:0.4),kind:event.kind,gemUnits:event.gemUnits,lifetime:event.untilCleanup ? .untilCleanup:.source(for:event.kind))
        if var popup=event.popup {popup.origin=fund.p;fund.popup=popup}
        fund.age=max(0,frameEnd-event.clock)
        if let popup=fund.popup {fund.p=layout.clamped(popup.position(age:fund.age),clearance:0.4)}
        if !fund.hasNoTimeout {fund.ttl-=fund.age;if fund.ttl<=1e-9 {return nil}}
        pickups.append(fund);return fund.id
    }
}

/// Own editable map data, deliberately distinct from unavailable original pickup structs.
struct SourceLootMapDesign {
    var sites:[SourceLootSite]
    var turretCapacity:Int
}
extension ArenaLayout {
    var sourceLootMap:SourceLootMapDesign {
        let radius=kind == .prison ? 1.0:kind == .cave ? 1.1:1.35
        return SourceLootMapDesign(sites:treasurePileCenters.map{SourceLootSite(p:$0,radius:radius)},turretCapacity:kind == .prison || kind == .cave ? 2:4)
    }
}
extension GameCore {
    func clearWorldLoot(){sourceLoot?.clearArenaChildren();pickups=[]}
    private var sourceLootRoundActive:Bool {
        guard let flow=combatSpawnFlow,!flow.held,!flow.forcedFinished,flow.roundActive else{return false}
        if phase == .playing {return true}
        return phase == .transition && arenaTransit?.committed != true && sideRoom==nil
    }
    func sourceLootEligibility(roundActive:Bool)->SourceLootEligibility {
        let exclusive=players.contains{$0.vehicle != nil || $0.orbRemaining>0 || $0.teddyRemaining>0 || !$0.shieldBarrels.isEmpty}
        let ground=pickups.contains{SourceLootEligibility.exclusive.contains($0.kind)}
        return SourceLootEligibility(round:round,roundActive:roundActive,allPlayersDead:!hasRecoverablePlayer,magicalExit:sideRoom != nil,prison:layout.kind == .prison,turretAvailable:players.reduce(0){$0+$1.sentries.count}<layout.sourceLootMap.turretCapacity,anyPlayerExclusive:exclusive,groundExclusive:ground)
    }
    /// Advances actual grounded items to each source event before its eligibility query.
    /// This exposes newly emitted/expired exclusive funds to subsequent events in the same frame.
    /// Gameplay/equipment actions still use the game's existing frame ordering, not an original VM.
    func stepWorldLoot(_ dt:Double,activeWindows:[Range<Double>]=[]) {
        guard dt.isFinite,dt>=0 else{return}
        guard let director=sourceLoot else{stepPickupLifetimes(dt);return}
        let start=director.clock,end=start+dt
        var aged=start
        func age(to event:Double) {
            let point=max(aged,min(end,event))
            if point>aged {stepPickupLifetimes(point-aged);aged=point}
        }
        director.step(dt,context:{event in
            age(to:event)
            let offset=event-start
            let active=abs(offset-dt)<1e-9 ? self.sourceLootRoundActive:activeWindows.contains{$0.contains(offset)} && !self.combatSpawningHeld
            return self.sourceLootEligibility(roundActive:active)
        },site:{_ in
            let sites=self.layout.sourceLootMap.sites
            guard !sites.isEmpty else{return nil}
            return sites[SourceLootRandom.index(sites.count,self.random())]
        },random:{self.random()},emit:{event in
            // Item starts at its actual birth; the final age(to:end) applies only its own frame tail.
            self.materializeSourceLoot(event,frameEnd:event.clock)
        })
        age(to:end)
    }
}
