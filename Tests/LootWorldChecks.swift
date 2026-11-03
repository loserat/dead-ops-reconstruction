import Foundation
@main struct LootWorldChecks {
    static func main(){
        var checks=0
        func expect(_ yes:Bool,_ text:String){if !yes{print("FAIL \(text)");exit(1)};checks+=1;print("PASS \(text)")}
        func near(_ a:Double,_ b:Double)->Bool {abs(a-b)<1e-7}
        func game(_ count:Int=1,_ round:Int=10)->GameCore {let g=GameCore();g.reset(playerCount:count);g.round=round;g.beginRound();g.foes=[];for p in g.players {p.invulnerable=999};return g}
        let g=game();let director=g.sourceLoot!
        expect(g.pickups.isEmpty && director.clock==0,"ordinary round start no longer gifts a fixed equipment/treasure ring")
        let due=director.powerups.nextAt
        g.stepWorldLoot(due-0.001,activeWindows:[0..<(due-0.001)])
        expect(director.powerups.requests==0,"actual production bridge does not request equipment before its random source deadline")
        g.stepWorldLoot(0.001,activeWindows:[0..<0.001])
        expect(director.powerups.requests==1 && director.powerups.completed==1,"actual source deadline draws one eligible world equipment item")
        let equipment=g.pickups.filter{$0.kind != .treasure && $0.kind != .gem}
        expect(equipment.count==1 && equipment[0].age<1e-7 && near(equipment[0].ttl,27.5),"late-frame equipment birth has its full source lifetime and physical contact warmup")
        expect(g.pickups.allSatisfy{g.layout.walkable($0.p,clearance:0.24)},"normal equipment/treasure producer places actual funds on traversable map ground")
        let killed=game();let bag=killed.sourceLoot!.bag.draws,clock=killed.sourceLoot!.clock
        for i in 0..<1000 {killed.kill(Foe(id:80000+i,p:V2(x:5,y:0),hp:0,speed:0,gait:0))}
        expect(killed.pickups.isEmpty && killed.sourceLoot!.bag.draws==bag && killed.sourceLoot!.clock==clock && killed.score==100000,"ordinary credited defeats award score without random pickup generation or source-bag consumption")
        let active=game();active.sourceLoot=SourceLootDirector(random:{0});let source=active.sourceLoot!
        for _ in 0..<720 {active.step(1.0/60,input:Controls())}
        expect(near(source.clock,active.elapsed) && near(source.clock,12),"real720production combat frames advance the one shared loot clock exactly once")
        expect(source.powerups.completed>0 && source.prizes.completed>0 && active.pickups.count>0,"real combat frames create both equipment and separate treasure without killing an enemy")
        let pausedClock=source.clock,first=active.pickups.first!
        active.step(0,input:Controls(pause:true));active.step(100,input:Controls())
        expect(source.clock==pausedClock && active.pickups.first!.age==first.age,"actual pause stops source random waits and physical item aging together")
        active.step(0,input:Controls(accept:true));active.step(1.0/60,input:Controls())
        expect(near(source.clock,pausedClock+1.0/60),"actual resume continues the same timer without pause catch-up")
        let clear=game();clear.finishCombatSpawning();clear.step(0,input:Controls())
        expect(clear.phase == .cleared && clear.sourceLoot!.pendingChildren>0 && clear.pickups.count==1,"actual cleared-round branch starts one immediate fund and pending source globs instead of a fixed ring")
        clear.combatSpawningHeld=true;clear.stepWorldLoot(5)
        expect(clear.sourceLoot!.clusterStarts==3 && (9...21).contains(clear.pickups.count) && clear.sourceLoot!.pendingChildren==0,"ordinary clear finishes three source globs with nine-to-twenty-one total funds")
        let old=clear.sourceLoot!,oldClock=old.clock,deadlines=[old.powerups.nextAt,old.prizes.nextAt]
        clear.sourceLoot!.queueRoundTreasure(boss:true);clear.startNextCombatRound()
        expect(clear.sourceLoot === old && old.clock==oldClock && old.pendingChildren==0 && [old.powerups.nextAt,old.prizes.nextAt]==deadlines && clear.pickups.isEmpty,"real round/map change cancels children and old funds while preserving global timer identity and deadlines")
        clear.step(0,input:Controls(pause:true));clear.step(0,input:Controls(accept:true));clear.reset()
        expect(clear.sourceLoot !== old && clear.sourceLoot!.clock==0 && clear.collectedWorldFunds==0,"new run creates new source threads and clears physical collection counters")
        let fade=game();fade.phase = .cleared;fade.clearClock=4;fade.prepareArenaExits();fade.sourceLoot!.queueCluster(at:SourceLootSite(p:V2(x:5,y:2),radius:0),count:5)
        let arenaExit=fade.availableExits.first(where:{$0.bonus==nil})!;fade.requestArenaExit(arenaExit)
        fade.step(0.5,input:Controls(move:V2(x:1,y:0),bomb:true))
        expect(near(fade.sourceLoot!.clock,0.5) && fade.pickups.count>=2 && fade.phase == .transition,"actual fade advances already running source treasure jobs without running locked combat input")
        let side=game(1,5);side.phase = .cleared;side.sourceLoot!.queueRoundTreasure(boss:true)
        let sideDirector=side.sourceLoot!;side.enterSideRoom(SideRoomOffer(kind:.treasure,p:side.layout.sideRoute(onLeft:true)))
        expect(sideDirector.cancelledChildren==1 && sideDirector.roomProgramsStarted==1 && side.sourceLoot === sideDirector,"bonus-room entry cancels old-arena treasure,starts the new room program and preserves global waits")
        side.stepSideRoom(1,inputs:[])
        expect(sideDirector.clock==1 && sideDirector.powerups.requests==0,"bonus-room exploration advances inactive global waits without fresh combat equipment")
        side.finishRoomLootForChecks()
        let before=side.collectedWorldFunds,roomBefore=side.collectedRoomFunds;side.pickups=[side.worldPickup(id:90000,p:side.hero,kind:.treasure)];side.stepPickupLifetimes(0.4);side.collectNearbyPickups();side.collectNearbyPickups()
        expect(side.collectedWorldFunds==before+1 && side.collectedRoomFunds==roomBefore+1,"physical room collection increments each real-world counter once")
        side.pickups=[side.worldPickup(id:90001,p:V2(x:5,y:2),kind:.bomb)];side.stepWorldLoot(28)
        expect(side.collectedWorldFunds==before+1 && side.collectedRoomFunds==roomBefore+1 && side.pickups.isEmpty,"ordinary item expiry is not falsely counted as physical room collection")
        let fate=game(1,15);fate.phase = .cleared;fate.sourceLoot!.queueRoundTreasure(boss:true);let fd=fate.sourceLoot!
        fate.enterFateRoom();fate.stepSideRoom(2,inputs:[])
        expect(fate.sideRoom?.kind == .fate && fd.pendingChildren==0 && fd.clock==2 && fate.pickups.isEmpty,"actual Fate entry cancels ordinary children and keeps global source time during its safe-room scene")
        let team=game(4);team.players[3].orbRemaining=10
        expect(!team.sourceLootEligibility(roundActive:true).allows(.tank),"exclusive power on role four blocks a role-one source vehicle request")
        team.players[3].orbRemaining=0;team.pickups=[team.worldPickup(id:90002,p:V2(x:5,y:2),kind:.tank)]
        expect(!team.sourceLootEligibility(roundActive:true).allows(.orb),"actual uncollected vehicle fund blocks the team's other exclusive source types")
        team.stepPickupLifetimes(28)
        expect(team.sourceLootEligibility(roundActive:true).allows(.orb),"actual physical fund expiry releases its world reservation")
        for p in team.players {for _ in 0..<team.layout.sourceLootMap.turretCapacity {team.withPlayer(p.slot){team.addSentry(at:team.hero)}};break}
        expect(!team.sourceLootEligibility(roundActive:true).allows(.turret),"own editable global map turret capacity is observed by the production eligibility context")
        for round in stride(from:1,through:37,by:4) {let layout=ArenaLayout.forRound(round);expect(!layout.sourceLootMap.sites.isEmpty && layout.sourceLootMap.sites.allSatisfy{$0.radius>0} && layout.sourceLootMap.turretCapacity>0,"own arena\(round) provides explicit editable source fund sites/radii/slot capacity")}
        print("\(checks) loot world checks passed;real normal frames,pause,resume,round/fade/bonus/Fate lifecycle,score-only kills,physical counters and shared eligibility;room content planning/original VM/hardware still separate")
    }
}
