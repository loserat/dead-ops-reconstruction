import Foundation

@main struct LootDirectorChecks {
    final class RNG {var seed:UInt64;init(_ seed:UInt64){self.seed=seed};func next()->Double{seed=seed &* 6364136223846793005 &+ 1442695040888963407;return Double(seed>>11)/Double(UInt64.max>>11)}}
    static func main(){
        var checks=0
        func expect(_ yes:Bool,_ text:String){if !yes{print("FAIL \(text)");exit(1)};checks+=1;print("PASS \(text)")}
        func near(_ a:Double,_ b:Double)->Bool {abs(a-b)<1e-7}
        let available=SourceLootEligibility(round:40)
        expect(SourceLootBag.template.count==21 && SourceLootBag.template.filter{$0 == .turret}.count==3 && SourceLootBag.template.filter{$0 == .chicken}.count==3,"source bag contains21 entries,including three turret and three chicken entries")
        expect(!SourceLootBag.template.contains(.life) && !SourceLootBag.template.contains(.treasure) && !SourceLootBag.template.contains(.gem),"life statues and treasure are independent producers,not ordinary equipment draws")
        for (kind,minimum) in [(PickupKind.tank,4),(.monkey,5),(.turret,7),(.helicopter,9)] {
            expect(!SourceLootEligibility(round:minimum-1).allows(kind) && SourceLootEligibility(round:minimum).allows(kind),"\(kind) unlocks exactly at source round\(minimum)")
        }
        var context=available;context.magicalExit=true
        expect(!context.allows(.turret) && !context.allows(.monkey) && context.allows(.chicken),"magical exits reject turret/monkey while allowing chickens")
        context=available;context.turretAvailable=false;expect(!context.allows(.turret),"deployed map turret capacity prevents another sentry fund")
        context=available;context.prison=true;context.roundActive=false
        expect(!context.allows(.helicopter) && context.allows(.tank),"inactive prison specifically rejects helicopter generation")
        context.roundActive=true;expect(context.allows(.helicopter),"active prison permits an otherwise eligible helicopter")
        context.magicalExit=true;expect(!context.allows(.helicopter),"prison magical-exit state independently rejects helicopter generation")
        for occupied in [false,true] {
            context=available;context.anyPlayerExclusive=occupied;context.groundExclusive = !occupied
            for kind in SourceLootEligibility.exclusive {expect(!context.allows(kind),"\(kind) is blocked by \(occupied ? "another role's equipped":"an existing ground") exclusive item")}
            expect(context.allows(.chicken) && context.allows(.spread),"exclusive reservations leave ordinary companions and weapons available")
        }
        // Literal source shuffle oracle: twenty-one full-array swaps with zero selects template[20] first.
        var bag=SourceLootBag();let first=bag.draw(random:{0})
        expect(first == .helicopter && bag.remaining.count==20 && bag.refills==1,"source full-array swap shuffle differs from a shrinking-range Fisher-Yates shuffle")
        var choseRepeated=false
        for _ in 0..<15 {
            let kind=bag.draw(random:{0.5})
            if kind == .chicken || kind == .turret {choseRepeated=true;expect(!bag.remaining.contains(kind),"drawing \(kind) removes every duplicate as source array_remove does")}
        }
        expect(choseRepeated && bag.refills>=2,"depleted bag refills before exhausting its last quarter")
        for invalid in [Double.nan,.infinity,-1,2] {expect(SourceLootRandom.index(21,invalid)>=0 && SourceLootRandom.index(21,invalid)<21,"invalid/random endpoint\(invalid) cannot index outside the source bag")}
        var pulse=SourceLootPulse(upperWait:15,random:0),inactive=available,attempts=0
        inactive.roundActive=false
        pulse.fire(at:10,context:inactive,random:{0},attempt:{attempts+=1;return .complete(spawned:true)})
        expect(pulse.nextAt==11 && attempts==0 && pulse.inactivePolls==1,"an elapsed10s wait polls an inactive round after one second without spawning")
        pulse.fire(at:11,context:available,random:{0},attempt:{attempts+=1;return .complete(spawned:true)})
        expect(pulse.nextAt==21 && attempts==1 && pulse.completed==1,"active resume from an inactive poll spawns immediately;stall does not draw another initial delay")
        pulse.fire(at:21,context:available,random:{0},attempt:{attempts+=1;return .retry})
        expect(near(pulse.nextAt,21.1) && pulse.stage == .retrySelection,"ineligible type selection retries after one local100ms network frame")
        var dead=inactive;dead.allPlayersDead=true
        pulse.fire(at:21.1,context:dead,random:{0},attempt:{attempts+=1;return .complete(spawned:true)})
        expect(attempts==3 && pulse.completed==2 && near(pulse.nextAt,31.1),"an already blocked spawn function continues its selection after round activity changes")
        dead.roundActive=true;pulse.fire(at:31.1,context:dead,random:{0},attempt:{attempts+=1;return .complete(spawned:true)})
        expect(attempts==3 && pulse.deadSkips==1 && near(pulse.nextAt,41.1),"all-dead guard skips a fresh request and starts its next random wait")
        let site=SourceLootSite(p:V2(x:4,y:2),radius:1)
        let low=SourceLootDirector(random:{0}),high=SourceLootDirector(random:{1})
        expect(low.powerups.nextAt==10 && low.prizes.nextAt==10 && near(high.powerups.nextAt,15) && near(high.prizes.nextAt,20),"independent equipment and treasure timers use source10–15 and10–20 ranges")
        var emissions=[SourceLootEmission](),selectedSites=0
        let retry=SourceLootDirector(random:{0})
        // Shuffle-zero draws gated Hind first. The next eligible item appears at10.1 at the initial site.
        retry.step(10.15,context:{_ in SourceLootEligibility(round:1)},site:{_ in selectedSites+=1;return SourceLootSite(p:V2(x:Double(selectedSites)*10,y:0),radius:0)},random:{0},emit:{emissions.append($0)})
        let equipment=emissions.filter{$0.kind != .treasure && $0.kind != .gem}
        expect(equipment.count==1 && near(equipment[0].clock,10.1) && equipment[0].p.x==10,"a rejected gated draw retries at100ms and retains its originally selected world site")
        expect(retry.powerups.retries==1 && retry.powerups.completed==1,"rejected source draws are not credited as spawned funds")
        let noSite=SourceLootDirector(random:{0});var noSiteEvents=0
        noSite.step(20,context:{_ in available},site:{_ in nil},random:{0},emit:{_ in noSiteEvents+=1})
        expect(noSiteEvents==0 && noSite.powerups.completed==0 && noSite.prizes.completed==0 && noSite.powerups.requests==2,"missing map pickup sites skip a request rather than inventing a fallback pickup")
        let cluster=SourceLootDirector(random:{0.5});var coins=[SourceLootEmission]()
        cluster.queueCluster(at:site,count:3)
        cluster.step(0,context:{_ in available},site:{_ in site},random:{0.5},emit:{coins.append($0)})
        expect(coins.count==1 && coins[0].clock==0 && cluster.pendingChildren==1,"a treasure cluster emits its first actual item immediately")
        cluster.step(0.199,context:{_ in available},site:{_ in site},random:{0.5},emit:{coins.append($0)});expect(coins.count==1,"ordinary cluster children remain separated by their200ms source wait")
        cluster.step(0.201,context:{_ in available},site:{_ in site},random:{0.5},emit:{coins.append($0)})
        expect(coins.map(\.kind)==[.treasure,.treasure,.treasure] && near(coins[1].clock,0.2) && near(coins[2].clock,0.4) && cluster.pendingChildren==0,"ordinary three-item cluster completes at0/0.2/0.4 seconds")
        let gems=SourceLootDirector(random:{0.5});var gemEvents=[SourceLootEmission]()
        gems.queueCluster(at:site,count:3,untilCleanup:true)
        gems.step(0.6,context:{_ in available},site:{_ in site},random:{0},emit:{gemEvents.append($0)})
        expect(gemEvents.count==3 && gemEvents.allSatisfy{$0.kind == .gem && $0.gemUnits==153 && !$0.untilCleanup} && near(gemEvents[1].clock,0.3) && near(gemEvents[2].clock,0.6),"gem initialization adds its100ms wait before the next child;even untimed special gold clusters keep timed gems")
        let untimed=SourceLootDirector(random:{0.5});var gold=[SourceLootEmission]()
        untimed.queueCluster(at:site,count:2,untilCleanup:true);untimed.step(0.2,context:{_ in available},site:{_ in site},random:{0.5},emit:{gold.append($0)})
        expect(gold.count==2 && gold.allSatisfy{$0.kind == .treasure && $0.untilCleanup},"special-event ordinary gold retains its explicit until-cleanup profile")
        for boss in [false,true] {
            let clear=SourceLootDirector(random:{0.5});var items=[SourceLootEmission]();clear.queueRoundTreasure(boss:boss)
            clear.step(6,context:{_ in inactive},site:{_ in site},random:{0},emit:{items.append($0)})
            let expected=(boss ? 25:3)*3
            expect(clear.clusterStarts==(boss ? 25:3) && items.count==expected && items.allSatisfy{$0.kind == .gem},"source cleared-round \(boss ? "boss":"ordinary") spawns\(boss ? 25:3) globs,not one fixed treasure ring")
        }
        let cancelled=SourceLootDirector(random:{0.5});cancelled.queueRoundTreasure(boss:true);cancelled.queueCluster(at:site,count:7)
        let deadlines=[cancelled.powerups.nextAt,cancelled.prizes.nextAt];cancelled.clearArenaChildren()
        expect(cancelled.pendingChildren==0 && cancelled.cancelledChildren==2 && [cancelled.powerups.nextAt,cancelled.prizes.nextAt]==deadlines,"map cleanup cancels child treasure jobs while global random waits survive")
        // Merged temporal order must not depend on renderer frame size or consume RNG in frame batches.
        func run(_ chunk:Double)->([SourceLootEmission],UInt64,Int,Int) {
            let rng=RNG(913),d=SourceLootDirector(random:{rng.next()});var out=[SourceLootEmission](),remaining=180.0
            d.queueRoundTreasure(boss:false)
            while remaining>1e-9 {
                let dt=min(chunk,remaining)
                d.step(dt,context:{time in var c=available;c.roundActive = !(time>=30 && time<54);c.allPlayersDead = time>=92 && time<107;return c},site:{_ in site},random:{rng.next()},emit:{out.append($0)});remaining-=dt
            };return(out,rng.seed,d.powerups.completed,d.prizes.completed)
        }
        let single=run(180),framed=run(1.0/60)
        expect(single.0==framed.0 && single.1==framed.1 && single.2==framed.2 && single.3==framed.3,"one180s step and10800actual60Hz steps produce identical ordered funds/RNG through inactive and all-dead windows")
        expect(single.2>6 && single.3>4 && Set(single.0.map(\.kind)).count>8,"source streams actually exercise multiple equipment kinds and independent treasure clusters")
        let occupied=SourceLootDirector(random:{0});var reserved=false,exclusiveCount=0,overlap=false
        occupied.step(200,context:{_ in var c=available;c.groundExclusive=reserved;return c},site:{_ in site},random:{0},emit:{e in
            if SourceLootEligibility.exclusive.contains(e.kind){overlap = overlap || reserved;reserved=true;exclusiveCount+=1}
        })
        expect(exclusiveCount==1 && !overlap && occupied.powerups.retries>0,"later real source requests observe the reservation created by an earlier emitted exclusive fund")
        reserved=false
        occupied.step(200,context:{_ in var c=available;c.groundExclusive=reserved;return c},site:{_ in site},random:{0},emit:{e in
            if SourceLootEligibility.exclusive.contains(e.kind){overlap = overlap || reserved;reserved=true;exclusiveCount+=1}
        })
        expect(exclusiveCount==2 && !overlap,"releasing a ground reservation permits a later exclusive choice without overlapping another reservation")
        let geometry=GameCore();geometry.reset();geometry.combatSpawningHeld=true
        for round in stride(from:1,through:37,by:4) {
            geometry.round=round;geometry.beginRound();geometry.pickups=[];var valid=true
            for center in geometry.layout.treasurePileCenters {for x in [-1.35,0,1.35] {for y in [-1.35,0,1.35] {
                let e=SourceLootEmission(clock:0,kind:.bomb,p:center+V2(x:x,y:y),gemUnits:nil,untilCleanup:false)
                if let n=geometry.materializeSourceLoot(e,frameEnd:0),let p=geometry.pickups.first(where:{$0.id==n}) {valid = valid && geometry.layout.walkable(p.p,clearance:0.24)}else{valid=false}
            }}}
            expect(valid,"source emission bridge clamps actual radius samples onto traversable own arena\(round) geometry")
        }
        let world=GameCore();world.reset();world.foes=[];world.pickups=[];world.combatSpawningHeld=true
        let origin=world.hero
        let event=SourceLootEmission(clock:9.99,kind:.gem,p:origin,gemUnits:256,untilCleanup:false)
        let id=world.materializeSourceLoot(event,frameEnd:10)!
        expect(world.pickups[0].id==id && near(world.pickups[0].age,0.01) && near(world.pickups[0].ttl,39.59),"real world bridge ages a late-frame birth only for its own remaining10ms")
        world.collectNearbyPickups();expect(world.score==0 && world.pickups.count==1,"late-frame source gem retains its real physical warmup")
        world.stepPickupLifetimes(0.49);world.collectNearbyPickups()
        expect(world.score==625 && world.multiplierCharge==0.5 && world.pickups.isEmpty,"source emission becomes an ordinary physical gem with one real stored score/meter reward")
        let expired=SourceLootEmission(clock:0,kind:.ray,p:origin,gemUnits:nil,untilCleanup:false)
        expect(world.materializeSourceLoot(expired,frameEnd:30)==nil && world.pickups.isEmpty,"large-frame historical source emissions do not resurrect expired world items")
        let special=SourceLootEmission(clock:0,kind:.treasure,p:origin,gemUnits:nil,untilCleanup:true)
        expect(world.materializeSourceLoot(special,frameEnd:1000) != nil && world.pickups[0].lifetime == .untilCleanup && world.pickups[0].ttl==0,"real untimed gold survives a large-frame materialization")
        expect(world.materializeSourceLoot(event,frameEnd:9)==nil && world.materializeSourceLoot(event,frameEnd:.nan)==nil,"invalid or future frame endpoints cannot materialize a fund")
        let before=low.clock;low.step(-1,context:{_ in available},site:{_ in site},random:{0},emit:{_ in fatalError("invalid dt emitted")});low.step(.infinity,context:{_ in available},site:{_ in site},random:{0},emit:{_ in fatalError("invalid dt emitted")})
        expect(low.clock==before,"invalid elapsed time cannot advance periodic loot threads")
        print("\(checks) loot director checks passed;source timed threads,shuffle/remove-all bag,eligibility,staggered child jobs,cleanup and late-frame physical reward bridge;kernel-only coverage;live world/room wiring checked separately;original coordinates/VM order/hardware unverified")
    }
}
