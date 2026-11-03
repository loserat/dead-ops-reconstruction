import Foundation
@main struct BlastChecks {
    static func main(){
        setbuf(stdout,nil);var count=0
        func expect(_ value:Bool,_ message:String){guard value else{print("FAIL \(message)");exit(1)};count+=1;print("PASS \(message)")}
        func settle(_ g:GameCore){if g.players.contains(where:{$0.respawnRemaining != nil}){g.stepTeamRecovery(2)}}
        func close(_ a:Double,_ b:Double)->Bool {abs(a-b)<0.000001}
        func game(_ players:Int=1,_ round:Int=25)->GameCore {
            let g=GameCore();g.reset(playerCount:players);g.round=round;g.beginRound();g.foes=[];g.pickups=[]
            g.combatSpawningHeld=true;g.barrelClock=999
            for p in g.players {p.invulnerable=0;p.hero=V2(x:Double(p.slot)*3,y:0);p.heroElevation=0}
            return g
        }
        func barrel(_ g:GameCore,_ point:V2=V2(x:1.85,y:0),height:Double=0,damage:Bool=true){
            let id=g.id();g.barrels.append(FlamingBarrel(id:id,p:point,v:.zero,elevation:height,ttl:100))
            g.detonateBarrels([id],canDamageHero:damage);settle(g)
        }
        func martyr(_ g:GameCore,_ point:V2=V2(x:-2,y:0),damage:Bool=true){
            g.detonateMartyr(Foe(id:g.id(),p:point,hp:0,speed:0,gait:0,kind:.martyr),canDamageHero:damage);settle(g)
        }
        for source in [BlastSource.barrel,.martyr] {
            let p=source.profile
            expect(p.impact(distance:p.inner-0.001) == .lethal && p.impact(distance:p.inner)==p.fringe,"blast profiles distinguish the direct core from the survivable edge")
            expect(p.impact(distance:p.outer-0.001)==p.fringe && p.impact(distance:p.outer) == .none,"the outer radius has one explicit damage boundary")
            expect([Double.nan,.infinity,-1].allSatisfy{p.impact(distance:$0) == .none},"invalid or negative blast distances cannot create damage")
        }
        let rim=game();rim.apply(.ray);let origin=rim.hero
        barrel(rim)
        expect(rim.lives==3 && rim.players[0].barrelWounds==0 && rim.barrelDamagePending,"real barrel detonation defers player damage until after array iteration")
        rim.resolveBarrelDamage()
        expect(rim.lives==3 && rim.deaths==0 && rim.weapon == .ray && rim.hero==origin && rim.players[0].barrelWounds==1,"a barrel fringe hurts without discarding the body weapon or position")
        expect(close(rim.woundFraction,0.5) && rim.playerWoundText=="DRUCKWELLE" && rim.woundRecoveryActive,"the visible injury describes a recoverable blast wound")
        rim.invulnerable=0;rim.resolveDeferredBlasts()
        expect(rim.players[0].barrelWounds==1 && rim.deaths==0 && !rim.barrelDamagePending,"resolving an already consumed burst cannot wound twice")
        rim.stepPlayerWoundRecovery(PlayerDamageRules.barrelRecoverySeconds/2)
        expect(rim.players[0].barrelWounds==1 && close(rim.players[0].barrelRecoveryClock,3),"barrel recovery retains partial elapsed time")
        rim.stepPlayerWoundRecovery(PlayerDamageRules.barrelRecoverySeconds/2)
        expect(!rim.hasPlayerWounds && rim.players[0].barrelRecoveryClock==0 && !rim.woundRecoveryActive,"the barrel wound heals and clears its warning without giving a life")
        let twice=game();barrel(twice);twice.resolveDeferredBlasts();twice.invulnerable=0;barrel(twice);twice.resolveDeferredBlasts()
        settle(twice);expect(twice.deaths==1 && twice.lives==2 && !twice.hasPlayerWounds,"a second separated fringe before recovery causes one real death")
        let timed=game();timed.barrels=[FlamingBarrel(id:timed.id(),p:V2(x:1.85,y:0),v:.zero,elevation:0,ttl:0)]
        timed.step(0.01,inputs:[])
        expect(timed.players[0].barrelWounds==1 && timed.deaths==0 && timed.barrels.isEmpty,"timed explosions in the actual world frame reach the fringe damage path")
        let direct=game();barrel(direct,.zero);direct.resolveDeferredBlasts()
        settle(direct);expect(direct.deaths==1 && direct.lives==2 && !direct.hasPlayerWounds,"the barrel's direct core remains immediately lethal")
        let high=game();barrel(high,.zero,height:4);high.resolveDeferredBlasts()
        expect(!high.hasPlayerWounds && high.deaths==0 && !high.barrelDamagePending,"a high airborne blast does not hit a full storey below")
        let wall=game(1,30);wall.hero=V2(x:1.8,y:2.2);let blocked=V2(x:0.4,y:1)
        expect((wall.hero-blocked).length<BlastSource.barrel.profile.outer && !wall.layout.lineClear(blocked,wall.hero,clearance:0.02),"the cover fixture is actually inside blast range behind a solid tank")
        barrel(wall,blocked);wall.resolveDeferredBlasts()
        expect(!wall.hasPlayerWounds && wall.deaths==0,"a solid tank blocks barrel damage as well as martyr damage")
        let m=game(1,30);m.apply(.deathMachine);martyr(m)
        expect(m.martyrDamagePending && m.players[0].martyrWounds==0,"martyr edge damage is also deferred")
        m.resolveMartyrDamage()
        expect(m.players[0].martyrWounds==1 && m.deaths==0 && m.weapon == .deathMachine && close(m.woundFraction,0.75),"a martyr edge wound preserves equipment and leaves a reduced damage budget")
        expect(m.hasPlayerWounds && !m.woundRecoveryActive && m.playerWoundText=="DRUCKWELLE","the persistent martyr wound does not falsely advertise healing")
        m.stepPlayerWoundRecovery(1000)
        expect(m.players[0].martyrWounds==1,"a persistent martyr wound does not vanish after the barrel healing interval")
        m.invulnerable=0;martyr(m);m.resolveDeferredBlasts()
        settle(m);expect(m.deaths==1 && m.lives==2 && !m.hasPlayerWounds,"two separated martyr edge blasts kill through the common death path")
        for slot in 0..<2 {
            let mixed=game(2,34);mixed.withPlayer(slot){mixed.fate = .friendship;mixed.applyBlastDamage(.martyrFringe);mixed.invulnerable=0;mixed.houndHit()}
            settle(mixed);expect(mixed.players[slot].deaths==1 && mixed.players[slot].lives==2 && mixed.players[1-slot].deaths==0,"a persistent martyr wound makes the next bite lethal even for the original Friendship role")
        }
        let reverse=game(1,34);reverse.houndHit();reverse.invulnerable=0;reverse.applyBlastDamage(.martyrFringe)
        expect(reverse.deaths==1 && !reverse.hasPlayerWounds,"mixed damage also combines when the bite happens before the martyr blast")
        let blend=game(1,34);blend.applyBlastDamage(.barrelFringe);blend.stepPlayerWoundRecovery(3);blend.invulnerable=0;blend.houndHit()
        expect(blend.dogWounds==1 && blend.players[0].barrelWounds==1 && blend.deaths==0 && blend.players[0].barrelRecoveryClock==0,"a nonlethal mixed wound restarts the shared recovery delay")
        blend.invulnerable=0;blend.houndHit()
        expect(blend.deaths==1 && !blend.hasPlayerWounds,"additional bites can exhaust the remaining budget after a barrel fringe")
        let partial=game(1,34);partial.deaths=1;partial.applyBlastDamage(.barrelFringe);partial.invulnerable=0;partial.houndHit();partial.stepPlayerWoundRecovery(6)
        expect(partial.players[0].barrelWounds==0 && partial.dogWounds==1 && close(partial.woundFraction,1.0/3),"barrel recovery can clear its part while ordinary persistent bite damage remains")
        for reversed in [false,true] {
            let burst=game()
            if reversed {burst.queueBlast(.martyr,distance:0.5);burst.queueBlast(.barrel,distance:1.85)}
            else {burst.queueBlast(.barrel,distance:1.85);burst.queueBlast(.martyr,distance:0.5)}
            burst.resolveDeferredBlasts()
            settle(burst);expect(burst.deaths==1 && burst.lives==2 && !burst.hasPlayerWounds,"a direct blast wins over a fringe in the same burst independent of source order")
        }
        let strongest=game();strongest.queueBlast(.barrel,distance:1.85);strongest.queueBlast(.martyr,distance:2);strongest.resolveDeferredBlasts()
        expect(strongest.players[0].martyrWounds==1 && strongest.players[0].barrelWounds==0 && strongest.deaths==0,"one protection window applies the strongest fringe of a combined burst")
        let biteBurst=game(1,65);biteBurst.hero=V2(x:-4,y:0);biteBurst.barrels=[FlamingBarrel(id:biteBurst.id(),p:biteBurst.hero+V2(x:1,y:0),v:.zero,elevation:0,ttl:100)]
        biteBurst.foes=[Foe(id:biteBurst.id(),p:biteBurst.hero,hp:100,speed:0,gait:0,kind:.hound)]
        biteBurst.shots=[Shot(id:biteBurst.id(),p:biteBurst.hero+V2(x:0.55,y:0),v:V2(x:100,y:0),ttl:1,damage:1,kind:nil)]
        biteBurst.step(0.01,inputs:[])
        expect(biteBurst.deaths==1 && biteBurst.dogWounds==0 && !biteBurst.collectingPlayerDamage && !biteBurst.players[0].pendingHoundBite,"an actual same-frame bite cannot hide a direct barrel explosion behind fresh bite protection")
        let lateBlast=game(1,34);lateBlast.hero=V2(x:-4,y:0);lateBlast.dogWounds=2
        lateBlast.foes=[Foe(id:lateBlast.id(),p:lateBlast.hero,hp:100,speed:0,gait:0,kind:.hound),Foe(id:lateBlast.id(),p:V2(x:-3,y:0),hp:0,speed:0,gait:0,kind:.martyr)]
        lateBlast.step(0.01,inputs:[])
        expect(lateBlast.deaths==1 && !lateBlast.hasPlayerWounds && !lateBlast.collectingPlayerDamage,"a deferred lethal bite and later martyr core resolve exactly one death without mutating a live foe iteration")
        let loneBite=game(1,34);loneBite.hero=V2(x:-4,y:0);loneBite.foes=[Foe(id:loneBite.id(),p:loneBite.hero,hp:100,speed:0,gait:0,kind:.hound)];loneBite.step(0,inputs:[])
        expect(loneBite.dogWounds==1 && loneBite.deaths==0 && !loneBite.players[0].pendingHoundBite,"an ordinary world-frame bite is applied once and leaves no pending event")
        let chain=game();let a=chain.id(),b=chain.id();chain.barrels=[FlamingBarrel(id:a,p:V2(x:1.85,y:0),v:.zero,elevation:0),FlamingBarrel(id:b,p:V2(x:0.1,y:0),v:.zero,elevation:0)]
        chain.detonateBarrels([a]);chain.resolveDeferredBlasts()
        settle(chain);expect(chain.barrels.isEmpty && chain.deaths==1 && chain.lives==2,"a real barrel chain retains its lethal core while processing each barrel once")
        let protect=game();protect.invulnerable=2;barrel(protect,.zero);martyr(protect,.zero);protect.invulnerable=0;protect.resolveDeferredBlasts()
        expect(protect.deaths==0 && !protect.hasPlayerWounds,"protected actors do not retain stale pending damage until their protection ends")
        for armor in [VehicleKind.tank,.helicopter] {
            let g=game();g.beginVehicle(armor);g.queueBlast(.barrel,distance:0);g.queueBlast(.martyr,distance:2);g.resolveDeferredBlasts()
            expect(!g.hasPlayerWounds && g.deaths==0 && !g.barrelDamagePending && !g.martyrDamagePending,"vehicle armor rejects both direct and fringe blast queues")
        }
        let boost=game();boost.dashTime=0.2;boost.queueBlast(.barrel,distance:0);boost.resolveDeferredBlasts()
        expect(boost.deaths==0 && !boost.hasPlayerWounds,"boost protection also rejects blast damage")
        let training=game();training.godMode=true;training.apply(.ray);let oldHero=training.hero
        training.applyBlastDamage(.barrelFringe)
        expect(training.trainingHits==0 && training.players[0].barrelWounds==1,"a survivable fringe is not a virtual life loss in Godmode")
        training.invulnerable=0;training.applyBlastDamage(.barrelFringe)
        expect(training.trainingHits==1 && training.deaths==0 && training.hero==oldHero && training.weapon == .ray && !training.hasPlayerWounds,"a lethal mixed budget counts one virtual life and resets wounds while preserving resources")
        let team=game(4);team.players[1].hero=V2(x:2,y:0);team.players[2].hero=V2(x:5,y:0);team.players[3].hero=V2(x:-2,y:0)
        barrel(team,.zero);team.resolveDeferredBlasts()
        expect(team.players.map(\.deaths)==[1,0,0,0] && team.players.map(\.barrelWounds)==[0,1,0,1],"one real explosion applies direct fringe and out-of-range results per teammate")
        expect(team.activePlayerSlot==0 && team.players.allSatisfy{$0.score==0},"team damage does not leak actor selection or invent points")
        let clocks=game(4);for slot in 0..<4 {clocks.withPlayer(slot){clocks.applyBlastDamage(.barrelFringe)}}
        clocks.players[1].deaths=1;clocks.players[3].isDown=true;clocks.players[3].lives=0;clocks.players[3].reviveRemaining=90;clocks.players[3].donationCooldown=90
        for p in clocks.players {p.lives=0}
        clocks.step(0.1,inputs:[])
        expect(clocks.players.prefix(3).allSatisfy{close($0.barrelRecoveryClock,0.1)} && clocks.players[3].barrelRecoveryClock==0,"shared frames advance each living barrel recovery once including actors with previous deaths")
        clocks.step(0,inputs:[Controls(systemPause:true)]);clocks.step(10,inputs:[])
        expect(clocks.players.prefix(3).allSatisfy{close($0.barrelRecoveryClock,0.1)},"actual team pause freezes all partial blast recovery clocks")
        let room=game();room.applyBlastDamage(.barrelFringe);room.phase = .cleared;room.enterSideRoom(SideRoomOffer(kind:.treasure,p:room.layout.sideRoute(onLeft:true)));room.stepSideRoom(3,inputs:[])
        expect(room.players[0].barrelWounds==1 && close(room.players[0].barrelRecoveryClock,3),"safe room exploration advances barrel recovery through the real room frame")
        room.stepSideRoom(3,inputs:[])
        expect(!room.hasPlayerWounds,"safe rooms finish temporary blast recovery without clearing unrelated rules")
        let carry=game(1,30);carry.applyBlastDamage(.martyrFringe);carry.beginVehicle(.tank);carry.endVehicle();carry.round=31;carry.beginRound()
        expect(carry.players[0].martyrWounds==1,"vehicle changes and new rounds do not erase persistent martyr damage")
        carry.stepTeamRecovery(RecoveryRules.shortShield);carry.invulnerable=0;carry.loseLife()
        expect(!carry.hasPlayerWounds && carry.players[0].barrelRecoveryClock==0,"other lethal damage resets every wound type and recovery clock")
        let defensive=game(1,30);barrel(defensive,.zero,damage:false);martyr(defensive,.zero,damage:false);defensive.resolveDeferredBlasts()
        expect(!defensive.hasPlayerWounds && defensive.deaths==0,"explicit defensive detonation suppresses both blast damage paths")
        let cleared=game();cleared.phase = .cleared;barrel(cleared,.zero);cleared.resolveDeferredBlasts()
        expect(cleared.deaths==1 && cleared.phase == .cleared,"a shot-triggered direct explosion remains dangerous between rounds")
        let reset=game(4);reset.players[2].barrelWounds=1;reset.players[1].martyrWounds=1;reset.players[0].barrelRecoveryClock=3;reset.players[3].pendingMartyrBlast = .lethal;reset.reset()
        expect(reset.players.allSatisfy{$0.barrelWounds==0 && $0.martyrWounds==0 && $0.barrelRecoveryClock==0 && !$0.pendingHoundBite && !$0.martyrDamagePending && !$0.barrelDamagePending},"new attempts clear wound histories clocks and deferred queues for every owner")
        print("\(count) blast checks passed;direct/fringe/mixed damage,personal recovery,burst ordering and safe deferred resolution;fractions/radii/timing provisional,not original hardware acceptance")
    }
}
