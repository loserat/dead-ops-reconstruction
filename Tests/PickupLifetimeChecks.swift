import Foundation

@main struct PickupLifetimeChecks {
    static func main(){
        var checks=0
        func expect(_ yes:Bool,_ text:String){if !yes{print("FAIL \(text)");exit(1)};checks+=1;print("PASS \(text)")}
        func near(_ a:Double,_ b:Double)->Bool {abs(a-b)<1e-7}
        func fresh()->GameCore {let g=GameCore();g.reset();g.foes=[];g.pickups=[];g.combatSpawningHeld=true;g.invulnerable=999;return g}
        let g=fresh()
        for kind in PickupKind.allCases {
            let p=g.worldPickup(id:100+kind.rawValue,p:.zero,kind:kind)
            expect(p.lifetime == (kind == .gem ? .gem:.powerup) && near(p.ttl,kind == .gem ? 39.6:27.5) && p.sourcePowerupTimeout,"production \(kind) receives its source timeout profile rather than the old14s/custom30–45s")
        }
        let waits=Array(repeating:0.6,count:15)+Array(repeating:0.35,count:10)+Array(repeating:0.2,count:15)
        for (kind,steady) in [(PickupKind.ray,12.0),(.gem,24.1)] {
            let total=steady+waits.reduce(0,+)
            var age=steady
            for (index,duration) in waits.enumerated() {
                var p=g.worldPickup(id:200,p:.zero,kind:kind,gemUnits:256);p.ttl=total-age-duration/2
                expect(p.opacity(clock:999)==(index%2==0 ? 1:0),"\(kind) blink\(index) matches its own source steady delay and local network wait")
                age+=duration
            }
        }
        g.pickups=[g.worldPickup(id:300,p:g.hero,kind:.life)];g.collectNearbyPickups()
        expect(g.pickups.count==1 && g.lives==3,"new ordinary life cannot be collected before its400ms source warmup")
        g.stepPickupLifetimes(0.399);g.collectNearbyPickups();expect(g.pickups.count==1,"ordinary contact still waits just before400ms")
        g.stepPickupLifetimes(0.001);g.collectNearbyPickups();expect(g.pickups.isEmpty && g.lives==4,"ordinary life becomes physically collectible at400ms without early credit")
        let gem=fresh();gem.pickups=[gem.worldPickup(id:301,p:gem.hero,kind:.gem,gemUnits:256)];gem.stepPickupLifetimes(0.499);gem.collectNearbyPickups()
        expect(gem.score==0 && gem.pickups.count==1,"gem trigger preparation plus pickup wait retains the full local500ms warmup")
        gem.stepPickupLifetimes(0.001);gem.collectNearbyPickups();expect(gem.score==625 && gem.pickups.isEmpty && gem.multiplierCharge==0.5,"prepared gem awards its stored value once at the actual source contact boundary")
        for kind in [PickupKind.ray,.gem] {
            let timed=fresh(),p=timed.worldPickup(id:400,p:V2(x:5,y:0),kind:kind,gemUnits:128)
            timed.pickups=[p]
            let frames=kind == .gem ? 2376:1650
            for _ in 0..<frames-1 {timed.stepPickupLifetimes(1.0/60)}
            expect(timed.pickups.count==1,"\(kind) remains through the final source wait frame")
            timed.stepPickupLifetimes(1.0/60);expect(timed.pickups.isEmpty,"\(kind) expires at its exact local lifetime without an extra floating-point frame")
        }
        for kind in [PickupKind.life,.gem] {
            let dark=fresh();dark.pickups=[dark.worldPickup(id:500,p:dark.hero,kind:kind,gemUnits:128)]
            dark.stepPickupLifetimes(kind == .gem ? 25.0:12.9)
            expect(dark.pickups.count==1 && dark.pickups[0].opacity(clock:0)==0 && dark.pickups[0].expiryWarning,"\(kind) is still a real world item while visibly dark in its expiry blink")
            dark.collectNearbyPickups();let score=dark.score,lives=dark.lives;dark.collectNearbyPickups()
            expect(dark.pickups.isEmpty && (kind == .gem ? score==625:lives==4) && dark.score==score && dark.lives==lives,"dark-phase \(kind) can be touched once without duplicate reward")
        }
        let paused=fresh();paused.pickups=[paused.worldPickup(id:600,p:V2(x:5,y:0),kind:.rocket)];paused.stepPickupLifetimes(12.9)
        let before=paused.pickups[0];paused.step(0,input:Controls(pause:true));paused.step(100,input:Controls())
        expect(paused.pickups[0].ttl==before.ttl && paused.pickups[0].age==before.age && paused.pickups[0].opacity(clock:paused.elapsed)==before.opacity(clock:paused.elapsed),"pause freezes lifetime,warmup and actual source blink together")
        for invalid in [-1.0,Double.nan,Double.infinity] {paused.stepPickupLifetimes(invalid);expect(paused.pickups[0].ttl==before.ttl && paused.pickups[0].age==before.age,"invalid dt\(invalid) cannot age a real fund")}
        let room=fresh();room.round=5;room.beginRound();room.phase = .cleared;room.enterSideRoom(SideRoomOffer(kind:.treasure,p:room.layout.sideRoute(onLeft:true)))
        room.finishRoomLootForChecks()
        expect(room.pickups.count>=75 && room.pickups.allSatisfy{$0.sourcePowerupTimeout},"source bonus-room funds receive normal timed profiles instead of one-hour placeholders")
        let lastOrdinary=room.pickups.filter{$0.kind != .gem}.map(\.ttl).max()!
        room.stepSideRoom(lastOrdinary+0.01,inputs:[])
        expect(room.phase == .bonusRoom && room.pickups.allSatisfy{$0.kind == .gem},"ordinary source bonus funds expire by their own final deadline;only any longer-lived gems can remain")
        room.stepSideRoom(40,inputs:[]);expect(room.pickups.isEmpty,"bonus-room gem clocks continue while exploring that room")
        let armory=fresh();armory.round=5;armory.beginRound();armory.phase = .cleared;armory.enterSideRoom(SideRoomOffer(kind:.armory,p:armory.layout.sideRoute(onLeft:true)))
        armory.finishRoomLootForChecks()
        expect(armory.pickups.count==17 && armory.pickups.allSatisfy{$0.lifetime == .powerup},"armory weapons/resources use the same source timeout as ordinary spawned powerups")
        armory.stepSideRoom(armory.pickups.map(\.ttl).max()!+0.01,inputs:[]);expect(armory.pickups.isEmpty,"uncollected armory funds expire rather than staying indefinitely")
        let bull=fresh();bull.bulls=[Bull(id:700,p:V2(x:6,y:3),direction:V2(x:1,y:0),golden:true)];bull.explodeBulls(at:V2(x:6,y:3),radius:2);bull.stepWorldLoot(3)
        expect(bull.pickups.filter{$0.kind == .treasure}.allSatisfy{$0.lifetime == .untilCleanup && !$0.persistent} && bull.pickups.filter{$0.kind == .gem}.allSatisfy{$0.lifetime == .gem},"golden-bull gold has no source timeout while its gems retain the longer source clock")
        let goldCount=bull.pickups.filter{$0.kind == .treasure}.count;bull.stepPickupLifetimes(1000)
        expect(bull.pickups.count==goldCount && (5...9).contains(goldCount) && bull.pickups.allSatisfy{$0.kind == .treasure && $0.opacity(clock:999)==1},"untimed special-event gold remains visible without a rare-equipment persistence flag")
        let coin=bull.pickups[0];expect(PickupPersistence.rotation(coin,clock:1) != PickupPersistence.rotation(coin,clock:2),"untimed money does not accidentally acquire the non-rotating rare-equipment behavior")
        bull.phase = .cleared;bull.startNextCombatRound();expect(bull.pickups.allSatisfy{$0.id != coin.id},"source cleanup still removes untimed old-arena gold")
        let fade=fresh();fade.phase = .cleared;fade.clearClock=4;fade.prepareArenaExits();let arenaExit=fade.availableExits.first(where:{$0.bonus==nil})!
        fade.hero=arenaExit.p;fade.heroElevation=arenaExit.height;fade.pickups=[fade.worldPickup(id:800,p:fade.hero,kind:.life)]
        let position=fade.hero,bombs=fade.bombs,dashes=fade.dashes;fade.requestArenaExit(arenaExit);fade.step(0.5,input:Controls(move:V2(x:1,y:0),aim:V2(x:1,y:0),dash:true,bomb:true))
        expect(fade.lives==4 && fade.pickups.isEmpty && fade.hero==position && fade.bombs==bombs && fade.dashes==dashes,"stationary fade contact ages and collects a ready fund without executing locked combat input")
        let teamFade=fresh();teamFade.reset(playerCount:2);teamFade.foes=[];teamFade.pickups=[];teamFade.combatSpawningHeld=true
        teamFade.withPlayer(1){teamFade.lives=0;teamFade.invulnerable=0;teamFade.loseLife()}
        teamFade.phase = .cleared;teamFade.clearClock=4;teamFade.prepareArenaExits()
        let teamExit=teamFade.availableExits.first(where:{$0.bonus==nil})!
        teamFade.hero=teamExit.p;teamFade.heroElevation=teamExit.height
        teamFade.pickups=[teamFade.worldPickup(id:801,p:teamFade.hero,kind:.life)];teamFade.requestArenaExit(teamExit)
        teamFade.step(0.5,inputs:[])
        expect(teamFade.players[0].lives==4 && teamFade.players[1].lives==1 && teamFade.players[1].isDown && teamFade.players[1].respawnRemaining==2,"fade team life credits both roles and starts the downed role's actual funded return")
        teamFade.step(2,inputs:[])
        expect(teamFade.phase == .transition && !teamFade.players[1].isDown && teamFade.players[1].lives==0,"funded return from a fade-contact team statue completes once before the black map commit")
        let persistent=fresh();persistent.pickups=[persistent.worldPickup(id:900,p:persistent.hero,kind:.ray,persistent:true)];persistent.stepPickupLifetimes(1000)
        expect(persistent.pickups[0].ttl==27.5 && persistent.pickups[0].readyForContact && persistent.pickups[0].opacity(clock:0)==1,"rare persistent equipment warms up but never blinks or consumes its independent ground lifetime")
        let custom=g.worldPickup(id:901,p:.zero,kind:.gem,ttl:3,gemUnits:128)
        expect(custom.lifetime == .custom && custom.ttl==3 && custom.readyForContact,"explicit developer fixture durations stay distinct from actual production profiles")
        print("\(checks) pickup lifetime checks passed;local source12/24s plus40waits,gem100ms preparation,physical400/500ms contact,room/fade/pause,dark collection,untimed special gold;not original engine trigger races or remote ACK acceptance")
    }
}
