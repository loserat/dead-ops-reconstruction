import Foundation
@main struct TreasureChecks {
    static func main(){
        setbuf(stdout,nil);var count=0
        func expect(_ value:Bool,_ message:String){guard value else{print("FAIL \(message)");exit(1)};count+=1;print("PASS \(message)")}
        func game(_ players:Int=1,_ round:Int=1)->GameCore {
            let g=GameCore();g.reset(playerCount:players);g.round=round;g.beginRound();g.pickups=[];g.foes=[];g.combatSpawningHeld=true
            for p in g.players {p.hero=g.layout.clamped(V2(x:Double(p.slot)*2,y:2));p.heroElevation=g.layout.height(p.hero);p.invulnerable=0}
            return g
        }
        func gem(_ g:GameCore,_ units:Int,_ appearance:LootAppearance = .gem(.blue,.small)){g.apply(.gem,loot:appearance,gemUnits:units)}
        expect(TreasureRules.ordinarySteps==[20,13,9,6,4,3,2,1,1],"coin meter contributions decrease at each multiplier stage")
        expect(TreasureRules.ordinaryUnits(at:-2)==20 && TreasureRules.ordinaryUnits(at:99)==1,"stage lookup stays bounded for malformed external fixtures")
        let boundary=game();gem(boundary,512)
        expect(boundary.multiplier==1 && boundary.multiplierCharge==1 && boundary.score==625,"exactly512 stored units fill the bar and score before promotion")
        boundary.apply(.treasure)
        expect(boundary.multiplier==2 && boundary.multiplierCharge==20.0/512 && boundary.score==750,"the next positive coin crosses a full bar and scores at the previous stage")
        let curve=game();var counts=[Int](),rem=[Int]()
        for target in 2...9 {
            var coins=0;while curve.multiplier<target && coins<600 {curve.apply(.treasure);coins+=1}
            counts.append(coins);rem.append(Int(curve.multiplierCharge*512))
        }
        expect(counts==[26,39,57,85,128,171,255,512],"an uninterrupted coin-only run follows the integer threshold curve through times9")
        expect(rem==[8,3,4,2,2,3,1,1],"coin-only promotions preserve each stage's exact remainder")
        expect(curve.multiplier==9 && curve.multiplierFill==1.0/512,"first reaching times9 does not falsely display an already full final bar")
        for _ in 0..<512 {curve.apply(.treasure)}
        expect(curve.multiplier==9 && curve.multiplierCharge==1,"512 more top-stage coins fill the capped stage")
        curve.apply(.treasure);expect(curve.multiplier==9 && curve.multiplierCharge==1,"a capped bar never overflows into an invisible tenth multiplier")
        let large=game();large.multiplierCharge=1;gem(large,563)
        expect(large.multiplier==2 && large.multiplierCharge==563.0/512,"one over-full gem promotes once and retains its extra units for the next pickup")
        large.apply(.treasure);expect(large.multiplier==3 && large.multiplierCharge==64.0/512,"a later pickup resolves carried overflow using the new stage's coin contribution")
        let chain=game();chain.multiplierCharge=1
        for _ in 0..<3 {gem(chain,563)}
        expect(chain.multiplier==4 && chain.multiplierCharge==665.0/512,"successive over-full gems retain overflow beyond one bar without silently clipping it")
        let colored=GemColor.allCases.flatMap{c in GemSize.allCases.map{LootAppearance.gem(c,$0)}}
        var appearancesEqual=true
        for look in colored {let g=game();g.multiplier=4;gem(g,300,look);appearancesEqual = appearancesEqual && g.score==2500 && g.multiplierCharge==300.0/512}
        expect(appearancesEqual,"all nine visual appearances honor the same stored score and bar value")
        let mixed=game();gem(mixed,153,.gem(.red,.large));gem(mixed,563,.gem(.red,.large))
        expect(mixed.multiplier==2 && mixed.multiplierCharge==204.0/512 && mixed.score==1250,"identical large-looking gems may carry different stored values without rerolling on collection")
        expect(TreasureRules.randomGemUnits(0)==153 && TreasureRules.randomGemUnits(1)==563,"ordinary generated gem values follow the archived0.3-to1.1-bar interval")
        expect([Double.nan,.infinity,-1].allSatisfy{TreasureRules.randomGemUnits($0)==153} && TreasureRules.randomGemUnits(2)==563,"invalid and boundary random inputs cannot create unbounded gem strength")
        expect(TreasureRules.gemScale(128)==1 && TreasureRules.gemScale(512)==2 && TreasureRules.gemScale(563)>2,"visible gem scaling follows stored strength rather than three fixed reward categories")
        let stored=game();stored.addLoot(at:stored.hero,kind:.gem,appearance:.gem(.white,.large),gemUnits:190)
        let item=stored.pickups[0],storedControl=game()
        expect(item.gemUnits==190 && item.loot == .gem(.white,.small),"world creation stores the assigned strength and chooses the matching visual class")
        stored.stepPickupLifetimes(0.5);expect(stored.pickups[0].gemUnits==190 && stored.random()==storedControl.random(),"waiting or flashing cannot redraw a world gem's reward")
        stored.collectNearbyPickups()
        expect(stored.pickups.isEmpty && stored.multiplierCharge==190.0/512 && stored.score==625 && stored.random()==storedControl.random(),"normal proximity collection uses stored strength without consuming another random draw")
        stored.collectNearbyPickups();expect(stored.score==625 && stored.multiplierCharge==190.0/512,"a removed world item cannot award its score or meter twice")
        let generated=game();var values=Set<Int>(),styles=Set<Int>(),colorSizes=Set<String>()
        for i in 0..<1000 {let item=generated.worldPickup(id:i,p:.zero,kind:.gem);values.insert(item.gemUnits!);styles.insert(item.loot!.size!.rawValue);colorSizes.insert("\(item.loot!.gemColor!.rawValue)-\(item.loot!.size!.rawValue)")}
        expect(values.count>300 && values.min()!>=153 && values.max()!<=563 && styles.count==3 && colorSizes.count==9,"ordinary world generation produces varied bounded values and all three visual classes")
        let plain=game(),plainControl=game();_=plain.worldPickup(id:1001,p:.zero,kind:.treasure)
        expect(plain.random()==plainControl.random(),"creating an ordinary coin does not spend a gem random draw")
        let threshold=game();threshold.score=199375;threshold.multiplierCharge=1;gem(threshold,128);threshold.advanceDirectedRewards(1.3);threshold.collectDirectedRewards()
        expect(threshold.score==200000 && threshold.lives==4 && threshold.collectedLives==1 && threshold.nextLifeAt==400000 && threshold.message=="EXTRA-LEBEN","a gem may cross a life and multiplier boundary once with the life notice retaining priority")
        let high=game();high.multiplier=9;high.score=399000;high.nextLifeAt=400000;gem(high,128);high.advanceDirectedRewards(1.3);high.collectDirectedRewards()
        expect(high.score==404625 && high.lives==4 && high.nextLifeAt==600000,"a high-multiplier gem scores5625 and awards only the crossed personal life threshold")
        let team=game(4);team.players[1].hero=team.players[0].hero;team.players[0].score=199375;team.players[1].score=399375
        team.pickups=[team.worldPickup(id:1002,p:team.hero,kind:.gem,gemUnits:256)];let teamControl=game(4)
        team.stepPickupLifetimes(0.5);team.step(0,inputs:[]);team.advanceDirectedRewards(1.3);team.collectDirectedRewards()
        expect(team.players.map(\.score)==[200000,399375,0,0] && team.players.map(\.lives)==[4,3,3,3],"simultaneous visitors award one gem and its extra life to one stable owner")
        expect(team.players.map(\.multiplierCharge)==[0.5,0,0,0] && team.random()==teamControl.random(),"the shared world frame never duplicates gem progress or random consumption per player")
        let down=game(2);down.players[1].isDown=true;down.players[1].lives=0;down.players[1].donationCooldown=999;down.players[1].reviveRemaining=90;down.players[1].score=199375
        down.withPlayer(1){gem(down,128)};down.stepTeamRecovery(2)
        expect(down.players[1].isDown && down.players[1].lives==0 && down.players[0].lives==3 && down.directedLifeRewards.count==1,"score statue stays physical rather than directly returning a downed recipient before collection")
        let death=game();death.multiplier=5;death.multiplierCharge=0.75;death.score=12345;let origin=death.hero
        death.loseLife();let spilled=death.pickups.filter{$0.kind == .gem},sum=spilled.compactMap(\.gemUnits).reduce(0,+)
        expect(death.deaths==1 && death.multiplier==1 && death.multiplierCharge==0 && death.score==12345,"actual death resets meter state and keeps banked score before recovery loot is collected")
        expect((768...1280).contains(sum) && spilled.count>=6 && spilled.count<=10,"death spills a bounded fraction of lost multiplier in quarter-bar chunks")
        expect(spilled.allSatisfy{$0.gemUnits!>0 && $0.gemUnits!<=128 && $0.ttl==PickupLifetime.gem.duration && death.layout.walkable($0.p,clearance:0.28)} && spilled.map(\.id).count==Set(spilled.map(\.id)).count,"all scattered gems have finite lifetime unique IDs and reachable physical locations")
        expect(spilled.contains{($0.p-origin).length<2.2},"recovery gems remain near the actual impact location")
        death.stepTeamRecovery(2);death.stepPickupLifetimes(0.5);let beforePickup=death.score,first=spilled[0];death.hero=first.p;death.heroElevation=death.layout.height(first.p);death.collectNearbyPickups()
        expect(death.score>beforePickup && death.multiplierCharge>0 && death.pickups.count<spilled.count,"the respawned player can physically recover some spilled progress and points")
        for fate in [FateKind?.none,.fortitude] {
            let low=game();low.fate=fate;low.multiplier=fate == nil ? 1:2;low.multiplierCharge=0.75;let lowControl=game();low.loseLife()
            expect(low.pickups.isEmpty && low.random()==lowControl.random() && low.multiplier==(fate == nil ? 1:2),"death at the baseline or Fortitude floor cannot manufacture recovery gems")
        }
        let fortune=game();fortune.fate = .fortitude;fortune.multiplier=3;fortune.loseLife()
        expect((307...512).contains(fortune.pickups.compactMap(\.gemUnits).reduce(0,+)) && fortune.multiplier==2 && fortune.multiplierCharge==0,"Fortitude subtracts its retained stage when calculating recoverable death progress")
        fortune.apply(.treasure);expect(fortune.multiplierCharge==13.0/512,"Fortitude restarts normal treasure gain at the times2 contribution")
        let virtual=game();virtual.godMode=true;virtual.multiplier=7;virtual.multiplierCharge=0.5;let virtualControl=game();virtual.loseLife()
        expect(virtual.pickups.isEmpty && virtual.random()==virtualControl.random() && virtual.multiplier==7 && virtual.multiplierCharge==0.5 && virtual.trainingHits==1,"Godmode damage preserves progress and cannot generate free death gems")
        let guardDeath=game();guardDeath.multiplier=9;guardDeath.invulnerable=3;guardDeath.loseLife()
        expect(guardDeath.pickups.isEmpty && guardDeath.deaths==0,"repeated protected contact cannot spawn a second death cloud")
        let owner=game(2);owner.players[0].multiplier=8;owner.players[1].multiplier=4;owner.players[1].multiplierCharge=0.5
        owner.loseLife();expect(owner.players[1].multiplier==4 && owner.players[1].multiplierCharge==0.5,"one player's death never drains a teammate's personal bar")
        owner.pickups=[];owner.withPlayer(1){gem(owner,128)}
        expect(owner.players[0].multiplierCharge==0 && owner.players[1].multiplierCharge==0.75 && owner.activePlayerSlot==0,"later personal gem collection restores scoped ownership without changing the dead player's meter")
        let paused=game();paused.addLoot(at:paused.hero,kind:.gem,gemUnits:384);let held=paused.pickups[0]
        paused.step(0,inputs:[Controls(pause:true)]);paused.step(100,inputs:[])
        expect(paused.score==0 && paused.pickups[0].ttl==held.ttl && paused.pickups[0].gemUnits==384,"pause freezes gem lifetime and never collects a touching item")
        paused.step(0,inputs:[Controls(accept:true)]);paused.step(0.5,inputs:[])
        expect(paused.score==625 && paused.multiplierCharge==0.75,"resuming collects the same stored item value")
        let rooms=game();rooms.phase = .cleared;rooms.enterSideRoom(SideRoomOffer(kind:.treasure,p:.zero));rooms.finishRoomLootForChecks();let roomGems=rooms.pickups.filter{$0.kind == .gem}
        expect(rooms.pickups.count>=75 && rooms.sourceLoot!.roomProgramsCompleted==1 && roomGems.allSatisfy{$0.gemUnits != nil},"source bonus globs store a reward for any rare gems without guaranteeing four of them")
        let boss=game(1,40);boss.seedBossTreasure(at:boss.hero)
        boss.stepWorldLoot(20)
        expect(boss.sourceLoot!.clusterStarts==25 && (75...175).contains(boss.pickups.count) && boss.pickups.filter{$0.kind == .gem}.allSatisfy{$0.gemUnits != nil},"boss-clear treasure uses twenty-five staggered physical globs with stored values rather than a fixed twelve-gem ring")
        let clear=game();clear.round=2;clear.seedClearedTreasure()
        clear.stepWorldLoot(5)
        expect(clear.sourceLoot!.clusterStarts==3 && (9...21).contains(clear.pickups.count) && clear.pickups.filter{$0.kind == .gem}.allSatisfy{$0.gemUnits != nil},"round-clear rewards use three staggered globs and every generated gem stores its future reward")
        let reset=game();reset.multiplier=8;reset.multiplierCharge=1;reset.addLoot(at:reset.hero,kind:.gem,gemUnits:563);reset.reset()
        expect(reset.multiplier==1 && reset.multiplierCharge==0 && !reset.pickups.contains{$0.kind == .gem},"new runs clear old gem values and capped multiplier progress")
        print("\(count) treasure checks passed;PS3-script behavioral reference,own visuals/placements,not authenticated original binary or hardware acceptance")
    }
}
