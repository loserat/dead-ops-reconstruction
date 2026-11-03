import Foundation

@main struct SpecialRoundChecks {
    static func main() {
        setbuf(stdout,nil);var passed=0
        func expect(_ yes:Bool,_ message:String) {guard yes else{fatalError(message)};passed+=1;print("PASS \(message)")}
        func near(_ a:Double,_ b:Double)->Bool {abs(a-b)<1e-8}
        let inactive=SourceLootEligibility(roundActive:false)
        func advance(_ d:SourceLootDirector,_ dt:Double,_ random:()->Double={0.5})->[SourceLootEmission] {
            var result=[SourceLootEmission]()
            d.step(dt,context:{_ in inactive},site:{_ in nil},random:random,emit:{result.append($0)})
            return result
        }
        for roll in 0..<5 {
            let d=SourceLootDirector(random:{0.5});var draws=[Double(roll)/5,0.0]
            d.queueGoldenBull(at:V2(x:4,y:2),random:{draws.removeFirst()})
            let first=advance(d,0)
            expect(first.count==2 && first.filter{$0.kind == .treasure}.count==1 && first.filter{$0.popup != nil}.count==1,"gold roll\(roll) starts one real coin and one popup model without an instant twelve-item ring")
            let all=first+advance(d,3),gold=all.filter{$0.kind == .treasure},gems=all.filter{$0.popup != nil}
            expect(gold.count==5+roll && gems.count==4 && gems.compactMap(\.gemUnits)==[128,128,128,128],"gold roll\(roll) follows5–9treasures plus one full bar split into four quarter gems")
            expect(gold.enumerated().allSatisfy{near($0.element.clock,Double($0.offset)*0.2)} && gems.enumerated().allSatisfy{near($0.element.clock,Double($0.offset)*0.2)},"gold roll\(roll) merges200ms child waits and the two local100ms gem waits")
            expect(gold.allSatisfy{$0.untilCleanup && $0.popup==nil} && gems.allSatisfy{!$0.untilCleanup} && d.pendingChildren==0,"gold roll\(roll) preserves untimed ordinary money and timed popup gems")
        }
        let upper=SourceLootDirector(random:{0.5});var high=[0.999999,1.0.nextDown]
        upper.queueGoldenBull(at:.zero,random:{high.removeFirst()});let upperEvents=advance(upper,3)
        expect(upperEvents.filter{$0.kind == .treasure}.count==9 && upperEvents.filter{$0.popup != nil}.count==12,"upper endpoint stays below three full bars and emits twelve quarter-or-smaller gems")
        let fractional=SourceLootDirector(random:{0.5});fractional.queuePopupGems(increments:1024.25,at:.zero)
        let fractions=advance(fractional,3)
        expect(fractions.compactMap(\.gemUnits)==Array(repeating:128,count:8)+[0],"source int truncation retains a fractional final gem with zero meter units")
        let rare=SourceLootDirector(random:{0.5});rare.queueGoldenBull(at:.zero,random:{0})
        let rareEvents=advance(rare,3,{0})
        expect(rareEvents.count==9 && rareEvents.allSatisfy{$0.kind == .gem && !$0.untilCleanup} && rareEvents.filter{$0.popup==nil}.count==5,"the special treasure branch retains its1percent ordinary-gem substitution rather than forcing every child to gold")
        let clearing=SourceLootDirector(random:{0.5});clearing.queueGoldenBull(at:.zero,random:{0})
        _=advance(clearing,0.1);let deadlines=[clearing.powerups.nextAt,clearing.prizes.nextAt]
        clearing.clearArenaChildren();let afterClear=advance(clearing,2)
        expect(clearing.cancelledChildren==1 && afterClear.count==3 && afterClear.allSatisfy{$0.popup != nil},"stop_spawning_pickups cancels unfinished treasure but not the source popup-prize thread")
        expect([clearing.powerups.nextAt,clearing.prizes.nextAt]==deadlines && clearing.pendingChildren==0,"special cleanup preserves the global source waits and eventually drains its surviving gem program")
        let invalid=SourceLootDirector(random:{0.5})
        for value in [Double.nan,Double.infinity,-1,0] {invalid.queuePopupGems(increments:value,at:.zero)}
        expect(invalid.pendingChildren==0,"invalid popup totals cannot start unbounded or non-finite work")
        func timed(split:Bool)->[SourceLootEmission] {
            var seed:UInt64=87123
            func random()->Double {seed=seed&*6364136223846793005&+1;return Double(seed>>11)/Double(UInt64.max>>11)}
            let d=SourceLootDirector(random:random);d.queueGoldenBull(at:V2(x:2,y:3),random:random)
            if !split {return advance(d,4,random)}
            var out=[SourceLootEmission]();for _ in 0..<240 {out += advance(d,1.0/60,random)};return out
        }
        expect(timed(split:false)==timed(split:true),"one large step and240small frames produce identical special-prize births,values and launch parameters")
        for roll in [0.0,0.5,1.0.nextDown] {
            let popup=PickupPopup(origin:V2(x:3,y:2),random:{roll})
            expect(popup.position(age:0.099)==popup.origin && popup.height(age:0.099)==0 && popup.height(age:0.1)>1,"popup\(roll) exists at its origin before the100ms launch and then starts above ground")
            expect(popup.height(age:0.6)>popup.height(age:0.1) && popup.flightDuration<3 && popup.height(age:3.1)==0,"popup\(roll) has an actual upward arc and reaches own safe ground before the trigger unlocks")
            expect(popup.position(age:10)==popup.position(age:100) && popup.position(age:3.1).x.isFinite,"popup\(roll) stops horizontal travel after landing without long-term position drift")
        }
        func game(_ round:Int=17,_ count:Int=1)->GameCore {
            let g=GameCore();g.reset(playerCount:count);g.round=round;g.beginRound();g.foes=[];g.pickups=[];g.combatSpawningHeld=true
            for p in g.players {p.invulnerable=0;p.hero=g.layout.clamped(V2(x:Double(p.slot)*2-4,y:-2));p.heroElevation=g.layout.height(p.hero)}
            return g
        }
        let world=game();world.bulls=[Bull(id:90001,p:V2(x:5,y:2),direction:V2(x:1,y:0),golden:true)]
        world.explodeBulls(at:V2(x:5,y:2),radius:2)
        expect(world.bulls.isEmpty && world.pickups.count==2 && world.sourceLoot!.pendingChildren==2,"actual golden-bull destruction starts both source programs and two real early models")
        world.stepWorldLoot(2.5)
        let popupFunds=world.pickups.filter{$0.popup != nil},coins=world.pickups.filter{$0.kind == .treasure}
        expect((4...12).contains(popupFunds.count) && (5...9).contains(world.pickups.filter{$0.popup==nil}.count) && popupFunds.allSatisfy{$0.gemUnits!<=128},"actual world materializes the full staggered source reward rather than twelve fixed gifts")
        let first=popupFunds.min{$0.age>$1.age}!,remaining=world.pickups.filter{$0.id==first.id}
        world.pickups=remaining;world.hero=first.p;world.heroElevation=world.layout.height(first.p);let score=world.score
        world.collectNearbyPickups();expect(world.pickups.count==1 && world.score==score,"a physically touching player cannot collect the first popped gem at2.5seconds")
        world.stepPickupLifetimes(0.599);world.collectNearbyPickups()
        expect(world.pickups.count==1 && world.score==score,"popup trigger remains closed just before its3second post-launch deadline")
        world.stepPickupLifetimes(0.001);world.hero=world.pickups[0].p;world.collectNearbyPickups();world.collectNearbyPickups()
        expect(world.pickups.isEmpty && world.score==score+625 && world.multiplierCharge==Double(first.gemUnits!)/512,"unlocked real popup is collected once with its stored score and exact quarter progress")
        let zero=game();zero.apply(.gem,gemUnits:0)
        expect(zero.score==625 && zero.multiplierCharge==0,"a zero-unit remainder gem keeps the source direct points without inventing meter progress")
        let paused=game();paused.bulls=[Bull(id:90002,p:.zero,direction:V2(x:1,y:0),golden:true)];paused.explodeBulls(at:.zero,radius:2)
        let ages=paused.pickups.map(\.age),clock=paused.sourceLoot!.clock
        paused.step(0,input:Controls(pause:true));paused.step(100,input:Controls())
        expect(paused.pickups.map(\.age)==ages && paused.sourceLoot!.clock==clock,"pause freezes both pending popup births and existing physical flight/contact clocks")
        paused.reset();expect(paused.sourceLoot!.pendingChildren==0 && paused.pickups.isEmpty,"new game clears the old popup program rather than emitting into a fresh run")
        let prison=game(9,4)
        prison.withPlayer(0){prison.apply(.helicopter);prison.weapon = .ray;prison.weaponReserve=17}
        prison.withPlayer(1){prison.apply(.tank)}
        prison.withPlayer(2){prison.apply(.helicopter);prison.apply(.chicken)}
        prison.finishCombatSpawning();prison.foes=[Foe(id:90003,p:V2(x:7,y:0),hp:100,speed:0,gait:0)]
        prison.step(0,inputs:[])
        expect(prison.phase == .playing && prison.players[0].vehicle?.kind == .helicopter && prison.players[2].vehicle?.kind == .helicopter,"an inactive spawn flag cannot abort Hinds while a final prison enemy is still alive")
        prison.foes=[];prison.step(0,inputs:[])
        expect(prison.phase == .cleared && prison.players[0].vehicle==nil && prison.players[2].vehicle==nil && prison.players[1].vehicle?.kind == .tank,"actual prison wave completion dismounts both Hind pilots while preserving the tank")
        expect(prison.players.allSatisfy{prison.layout.walkable($0.hero,clearance:0.29) && $0.heroElevation==prison.layout.height($0.hero)},"all four bodies remain on reachable ground after prison round cleanup")
        expect(prison.players[0].weapon == .ray && prison.players[0].weaponReserve==17 && prison.players[2].chickens.count==1 && prison.players.allSatisfy{$0.lives==3 && $0.deaths==0},"Hind abort preserves hand weapons,helpers,reserves and every player's life accounting")
        prison.withPlayer(0){prison.fireVehicleWeapons(0.2,firing:true)}
        expect(prison.shots.isEmpty && prison.helicopterMagnet==nil,"ended Hinds cannot keep firing missiles or retaining the helicopter pursuit magnet")
        for round in [1,5,13,17,21,25,29,33,37,41] {
            let other=game(round);other.apply(.helicopter);other.finishCombatSpawning();other.step(0,input:Controls())
            expect(other.phase == .cleared && other.vehicle?.kind == .helicopter,"ordinary arena\(round) round cleanup retains the active Hind")
        }
        let pauseEnd=game(10);pauseEnd.apply(.helicopter);pauseEnd.finishCombatSpawning();pauseEnd.step(0,input:Controls(pause:true));pauseEnd.step(1,input:Controls())
        expect(pauseEnd.vehicle?.kind == .helicopter && pauseEnd.phase == .paused,"pause at a prison ending cannot execute vehicle cleanup behind the menu")
        pauseEnd.step(0,input:Controls(accept:true));pauseEnd.step(0,input:Controls())
        expect(pauseEnd.phase == .cleared && pauseEnd.vehicle==nil,"resuming executes the actual waiting prison completion once")
        print("\(passed) special round checks passed;source golden-bull treasure/popup scheduling and prison Hind cleanup;own flight scale/physics,not original engine or hardware acceptance")
    }
}
