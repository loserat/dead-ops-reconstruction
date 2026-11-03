import Foundation
@main struct LootRoomChecks {
    final class RNG {var seed:UInt64;init(_ seed:UInt64){self.seed=seed};func next()->Double{seed=seed &* 6364136223846793005 &+ 1442695040888963407;return Double(seed>>11)/Double(UInt64.max>>11)}}
    static func main(){
        var checks=0
        func expect(_ yes:Bool,_ text:String){if !yes{print("FAIL \(text)");exit(1)};checks+=1;print("PASS \(text)")}
        func near(_ a:Double,_ b:Double)->Bool {abs(a-b)<1e-7}
        let site=SourceLootSite(p:V2(x:4,y:2),radius:0),plain=SourceLootEligibility(round:40,roundActive:false),magical=SourceLootEligibility(round:40,roundActive:false,magicalExit:true)
        for players in 1...4 {
            let d=SourceLootDirector(random:{0.5});d.queueArmory(players:players);var events=[SourceLootEmission]()
            d.step(5,context:{_ in plain},site:{_ in site},random:{0.5},emit:{events.append($0)})
            let chickens=players==1 ? 4:1,total=12+chickens+players
            expect(events.count==total && d.roomCommandsCompleted==total && d.roomProgramsCompleted==1 && d.pendingRoomPrograms==0,"source armory\(players) executes\(total) instructions and finishes its final wait")
            for i in 0..<4 {
                expect(events[i*3+1].kind == .bomb && events[i*3+2].kind == .dash && near(events[i*3].clock,Double(i)*0.6),"armory\(players) block\(i) emits random/bomb/boost in its source order")
            }
            expect(events[12..<(12+chickens)].allSatisfy{$0.kind == .chicken},"armory\(players) emits\(chickens) explicit chicken gifts")
            expect(events.enumerated().allSatisfy{near($0.element.clock,Double($0.offset)*0.2)},"unblocked armory\(players) uses200ms between every actual emitted instruction")
            expect(d.bag.draws==4+players,"armory\(players) random instructions consume the common equipment bag;fixed supplies do not")
        }
        let delayed=SourceLootDirector(random:{0});delayed.queueArmory(players:1);var delayedEvents=[SourceLootEmission](),chosen=0
        delayed.step(0,context:{_ in SourceLootEligibility(round:3,roundActive:false,magicalExit:true)},site:{_ in chosen+=1;return SourceLootSite(p:V2(x:Double(chosen)*10,y:0),radius:0)},random:{0},emit:{delayedEvents.append($0)})
        expect(delayedEvents.isEmpty && delayed.roomRetries==1 && delayed.pendingRoomPrograms==1,"gated first Hind choice waits100ms rather than inventing an immediate armory item")
        delayed.step(0.1,context:{_ in SourceLootEligibility(round:3,roundActive:false,magicalExit:true)},site:{_ in chosen+=1;return SourceLootSite(p:V2(x:Double(chosen)*10,y:0),radius:0)},random:{0},emit:{delayedEvents.append($0)})
        expect(delayedEvents.count==1 && delayedEvents[0].kind == .flamethrower && delayedEvents[0].p.x==10 && near(delayedEvents[0].clock,0.1),"rejected room choice retains its selected site and retries the same shared bag")
        delayed.step(0.2,context:{_ in magical},site:{_ in site},random:{0},emit:{delayedEvents.append($0)})
        expect(delayedEvents.count==2 && delayedEvents[1].kind == .bomb && near(delayedEvents[1].clock,0.3),"a random rejection delays the following fixed armory command as well")
        let blocked=SourceLootDirector(random:{0});blocked.queueArmory(players:4);var blockedEvents=[SourceLootEmission](),reserved=magical;reserved.groundExclusive=true
        blocked.step(8,context:{_ in reserved},site:{_ in site},random:{0},emit:{blockedEvents.append($0)})
        expect(blockedEvents.count==17 && blockedEvents.allSatisfy{!SourceLootEligibility.exclusive.contains($0.kind) && $0.kind != .monkey && $0.kind != .turret} && blocked.roomRetries>0,"room random requests respect actual magical/exclusive gates without losing the fixed supplies")
        let missing=SourceLootDirector(random:{0.5});missing.queueArmory(players:1);var missingCount=0
        missing.step(5,context:{_ in plain},site:{_ in nil},random:{0.5},emit:{_ in missingCount+=1})
        expect(missingCount==0 && missing.roomCommandsCompleted==17 && missing.roomSpecificSkipped==12 && missing.bag.draws==0 && missing.roomProgramsCompleted==1,"missing map sites skip gifts but preserve armory waits without invented fallback positions")
        for roll in [0.0,0.999999] {
            let d=SourceLootDirector(random:{0.5});d.queueBonusRoom(random:{roll});var events=[SourceLootEmission]()
            d.step(12,context:{_ in plain},site:{_ in site},random:{0.5},emit:{events.append($0)})
            let expected=roll==0 ? 2:3,equipment=events.filter{$0.kind != .treasure && $0.kind != .gem},money=events.filter{$0.kind == .treasure || $0.kind == .gem}
            expect(equipment.count==expected && d.roomFundsEmitted==expected && d.bag.draws==expected,"source bonus upper-exclusive weapon count yields\(expected) general-bag gifts including the extra random pickup")
            expect(equipment.allSatisfy{$0.clock==0} && d.roomProgramsCompleted==1 && d.clusterStarts==25 && money.count==125,"bonus equipment precedes twenty-five staggered five-item globs without an invented one-hour or four-gem preset")
        }
        // A weapon-named source function uses the general bag. It can validly choose a vehicle.
        let general=SourceLootDirector(random:{0.5});general.queueBonusRoom(random:{0});var generalEvents=[SourceLootEmission]()
        general.step(0,context:{_ in plain},site:{_ in site},random:{0},emit:{generalEvents.append($0)})
        expect(generalEvents.first?.kind == .helicopter,"spawn_random_weapon_pickup is not incorrectly restricted to guns when its source bag selects Hind")
        let crossing=SourceLootDirector(random:{0.5});crossing.queueArmory(players:1);crossing.queueRoundTreasure(boss:true)
        let deadlines=[crossing.powerups.nextAt,crossing.prizes.nextAt];crossing.clearArenaChildren()
        expect(crossing.pendingTreasureChildren==0 && crossing.pendingRoomPrograms==1 && crossing.cancelledChildren==1 && [crossing.powerups.nextAt,crossing.prizes.nextAt]==deadlines,"arena stop notification cancels treasure jobs but not room-equipment threads or global waits")
        var crossed=[SourceLootEmission]();crossing.step(5,context:{_ in plain},site:{_ in site},random:{0.5},emit:{crossed.append($0)})
        expect(crossed.count==17 && crossing.roomProgramsCompleted==1,"an already started armory source sequence can finish after an arena cleanup")
        func run(_ chunk:Double)->([SourceLootEmission],UInt64) {
            let rng=RNG(73),d=SourceLootDirector(random:{rng.next()});d.queueArmory(players:4);d.queueBonusRoom(random:{rng.next()});var events=[SourceLootEmission](),left=9.0,exclusiveUntil=0.0
            while left>1e-9 {
                let dt=min(chunk,left)
                d.step(dt,context:{time in var c=magical;c.groundExclusive=time<exclusiveUntil;return c},site:{_ in site},random:{rng.next()},emit:{e in events.append(e);if SourceLootEligibility.exclusive.contains(e.kind){exclusiveUntil=e.clock+2}});left-=dt
            };return(events,rng.seed)
        }
        let once=run(9),frames=run(1.0/60)
        expect(once.0==frames.0 && once.1==frames.1 && once.0.count>80,"merged armory/bonus/shared bag/temporary reservations produce the same real emissions in one9s step and540frames")
        func game(_ count:Int,_ round:Int=5)->GameCore {let g=GameCore();g.reset(playerCount:count);g.round=round;g.beginRound();g.foes=[];g.combatSpawningHeld=true;g.phase = .cleared;return g}
        for count in 1...4 {
            let g=game(count);g.enterSideRoom(SideRoomOffer(kind:.armory,p:g.layout.sideRoute(onLeft:true)))
            expect(g.sideRoom?.kind == .armory && g.pickups.count<=1 && g.sourceLoot!.pendingRoomPrograms==1,"real armory entry\(count) starts the source sequence rather than spawning fifteen simultaneous fixed gifts")
            g.stepSideRoom(8,inputs:[])
            let expected=12+(count==1 ? 4:1)+count
            expect(g.sourceLoot!.roomFundsEmitted==expected && g.sourceLoot!.roomProgramsCompleted==1 && g.pickups.count+g.collectedRoomFunds==expected,"actual\(count)-role room emits\(expected) physical gifts,accounting separately for real contact collection")
            expect(g.pickups.allSatisfy{$0.sourcePowerupTimeout && $0.kind != .life && $0.kind != .turret && $0.kind != .monkey && g.layout.walkable($0.p,clearance:0.24)},"actual armory\(count) uses source lifetime/gates and reachable own-map positions")
        }
        let bonus=game(1);bonus.enterSideRoom(SideRoomOffer(kind:.treasure,p:bonus.layout.sideRoute(onLeft:true)));bonus.stepSideRoom(20,inputs:[])
        let money=bonus.pickups.filter{$0.kind == .treasure || $0.kind == .gem}
        expect(bonus.sourceLoot!.roomProgramsCompleted==1 && (2...3).contains(bonus.sourceLoot!.roomFundsEmitted) && bonus.sourceLoot!.clusterStarts==25 && (75...175).contains(money.count+bonus.collectedRoomFunds),"actual bonus room combines general equipment gifts and25source treasure globs")
        expect(bonus.pickups.allSatisfy{$0.sourcePowerupTimeout && (!$0.kind.isOrdinaryLoot || $0.loot != nil)},"actual bonus funds retain normal source timers and stored treasure appearance/value data")
        let pause=game(1);pause.enterSideRoom(SideRoomOffer(kind:.armory,p:pause.layout.sideRoute(onLeft:true)));pause.step(1,input:Controls());let clock=pause.sourceLoot!.clock,emitted=pause.sourceLoot!.roomFundsEmitted,held=pause.pickups
        pause.step(0,input:Controls(pause:true));pause.step(100,input:Controls())
        expect(pause.sourceLoot!.clock==clock && pause.sourceLoot!.roomFundsEmitted==emitted && pause.pickups.map(\.ttl)==held.map(\.ttl),"real pause stops room sequence and physical expiry together")
        pause.step(0,input:Controls(accept:true));pause.step(1,input:Controls())
        expect(near(pause.sourceLoot!.clock,clock+1) && pause.sourceLoot!.roomFundsEmitted>emitted,"real resume continues the pending source room sequence without catch-up")
        let early=game(1);early.enterSideRoom(SideRoomOffer(kind:.armory,p:early.layout.sideRoute(onLeft:true)));let director=early.sourceLoot!;early.startNextCombatRound();early.stepWorldLoot(6)
        expect(early.sourceLoot === director && director.roomProgramsCompleted==1 && director.roomFundsEmitted==17 && early.pickups.count>0,"real early arena change retains source armory thread lifetime and emits remaining gifts in the current world")
        print("\(checks) loot room checks passed;source room command sequences/shared bag/retries/gates/physical world/pause/cleanup,not original map coordinates or VM thread ordering/hardware")
    }
}
private extension PickupKind {var isOrdinaryLoot:Bool {self == .treasure || self == .gem}}
