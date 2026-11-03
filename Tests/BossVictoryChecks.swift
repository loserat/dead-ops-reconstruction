import Foundation

@main struct BossVictoryChecks {
    static func main(){
        var checks=0
        func expect(_ yes:Bool,_ text:String){if !yes{print("FAIL \(text)");exit(1)};checks+=1;print("PASS \(text)")}
        func near(_ a:Double,_ b:Double)->Bool {abs(a-b)<0.000001}
        for (time,title,subtitle,brother) in [(0.0,0.0,0.0,0.0),(1,0,0,0),(2,0.5,0.4,0),(3,1,0.8,0),(4,1,1,0.4),(5.5,1,1,1),(6,1,1,1),(7,0.5,0.5,0.5),(8,0,0,0)] {
            var clock=BossVictory(fromRound:40);clock.clock=time
            expect(near(clock.titleOpacity,title) && near(clock.subtitleOpacity,subtitle) && near(clock.brotherOpacity,brother),"source victory HUD at\(time)s:1s lead-in,2/2.5s fades,third line starts2s into HUD,all fade5–7s")
        }
        func ready(_ count:Int=1,_ round:Int=40)->GameCore {
            let g=GameCore();g.reset(playerCount:count);g.round=round;g.beginRound();g.fixtureSilverbacks();g.foes=[];g.damageSilverback(999999);g.step(2.1,input:Controls())
            precondition(g.phase == .cleared)
            g.pickups=[];g.directedLifeRewards=[];g.clearClock=4
            for p in g.players {p.invulnerable=999;p.hero=g.suggestedExit;p.heroElevation=g.layout.height(p.hero)}
            _=g.takeAudioEvents();return g
        }
        let g=ready();let map=g.environmentRevision,portal=g.availableExits.first!
        g.requestArenaExit(portal)
        expect(g.phase == .cleared && g.bossVictory?.clock==0 && g.loopReturn==nil && g.arenaTransit==nil,"boss pad opens the live victory HUD without prematurely fading or replacing the map")
        g.requestArenaExit(portal);expect(g.takeAudioEvents().filter{$0 == .victory}.count==1,"repeated boss-pad contact cannot restart victory or repeat its cue")
        let start=g.hero;g.bombs=2;g.dashes=3;g.apply(.ray);g.weaponReserve=20
        g.step(0.1,input:Controls(move:V2(x:1,y:0),aim:V2(x:1,y:0),dash:true,bomb:true))
        expect((g.hero-start).length>0.05 && g.bombs==1 && g.dashes==2 && g.weaponReserve<20,"movement,shots,bombs and boost remain real during the script's unfrozen victory HUD")
        g.pickups=[Pickup(id:99001,p:g.hero,kind:.life)]
        let lives=g.lives;g.step(0,input:Controls());expect(g.lives==lives+1 && g.pickups.isEmpty,"a boss prize can still be physically collected during the victory HUD")
        g.step(0,input:Controls(pause:true));let clock=g.bossVictory!.clock,elapsed=g.elapsed,ammo=g.weaponReserve
        g.step(20,input:Controls(move:V2(x:1,y:0),bomb:true))
        expect(g.phase == .paused && g.bossVictory?.clock==clock && g.elapsed==elapsed && g.weaponReserve==ammo,"pause freezes victory opacity,world time and resources together")
        g.step(0,input:Controls(accept:true));g.step(7.899,input:Controls())
        expect(g.phase == .cleared && g.round==40 && g.bossVictory != nil && g.environmentRevision==map,"victory is still on the old battlefield just before its full eight-second boundary")
        g.step(0.001,input:Controls())
        expect(g.phase == .loopReturn && g.bossVictory==nil && near(g.loopReturn?.clock ?? -1,0) && g.environmentRevision==map,"only after the complete victory HUD does the separate local movie begin")
        let position=g.hero,bombs=g.bombs,dashes=g.dashes,reserve=g.weaponReserve
        g.step(1,input:Controls(move:V2(x:1,y:0),aim:V2(x:1,y:0),dash:true,bomb:true))
        expect(g.hero==position && g.bombs==bombs && g.dashes==dashes && g.weaponReserve==reserve,"local movie freezes combat inputs and inventory after the controllable victory stage")
        g.step(1.8,input:Controls())
        expect(g.phase == .transition && near(g.arenaTransit?.clock ?? -1,0) && near(g.arenaTransit?.darkness ?? -1,0) && g.loopReturn != nil && g.round==40,"movie completes before fade-out and retains its final pose on the old map")
        g.step(0.999,input:Controls());expect(g.round==40 && g.environmentRevision==map && (g.arenaTransit?.darkness ?? 0)>0.99,"return fade cannot swap map before full black")
        g.step(0.001,input:Controls())
        expect(g.round==41 && g.phase == .transition && g.arenaTransit?.darkness==1 && g.loopReturn==nil && g.environmentRevision==map+1,"one black-frame commit creates the next island round and releases the old movie pose")
        g.step(1.7,input:Controls());expect(g.phase == .playing && g.arenaTransit==nil && g.layout.kind == .island,"0.2s hold and1.5s fade-in restore actual controls on the next loop")
        g.step(0,input:Controls());expect(g.round==41,"a completed return never increments the round twice")
        let carry=ready();carry.requestArenaExit(carry.availableExits.first!);let before=carry.elapsed
        carry.step(8.5,input:Controls())
        expect(carry.phase == .loopReturn && near(carry.loopReturn?.clock ?? -1,0.5) && near(carry.elapsed-before,8.5),"time crossing victory's boundary is carried once into the separate movie")
        carry.step(3.3,input:Controls());expect(carry.round==41 && carry.phase == .transition && near(carry.arenaTransit?.clock ?? -1,1),"time crossing movie's boundary carries into the black-frame map commit")
        let framed=ready();framed.requestArenaExit(framed.availableExits.first!)
        for _ in 0..<479 {framed.step(1.0/60,input:Controls())}
        expect(framed.bossVictory != nil && framed.loopReturn==nil,"frame479 still belongs to the8s victory window")
        framed.step(1.0/60,input:Controls())
        expect(framed.phase == .loopReturn && near(framed.loopReturn?.clock ?? -1,0),"480real60Hz simulation frames finish victory without a spurious extra frame")
        for _ in 0..<168 {framed.step(1.0/60,input:Controls())}
        expect(framed.phase == .transition && near(framed.arenaTransit?.clock ?? -1,0),"168real60Hz simulation frames finish the separate2.8s movie without late handoff")
        let pausedMovie=ready();pausedMovie.requestArenaExit(pausedMovie.availableExits.first!);pausedMovie.step(8.4,input:Controls());pausedMovie.step(0,input:Controls(pause:true));pausedMovie.step(9,input:Controls())
        expect(pausedMovie.phase == .paused && near(pausedMovie.loopReturn?.clock ?? -1,0.4),"pause also freezes the movie's visitor and airborne player pose")
        for invalid in [-1.0,Double.nan,Double.infinity] {let before=carry.elapsed;carry.step(invalid,input:Controls());expect(carry.elapsed==before,"invalid return time\(invalid) cannot advance or corrupt the world")}
        let team=ready(4,80);team.players[2].hero=team.suggestedExit;_=team.tryTeamExit()
        expect(team.bossVictory != nil && team.phase == .cleared,"one actual teammate contact starts the shared round80 victory once")
        team.reset();expect(team.bossVictory==nil && team.loopReturn==nil && !team.advancingBossVictory,"new game clears every victory/movie clock and reentrancy guard")
        let dead=ready();dead.beginBossVictory();dead.finishTeamRun();expect(dead.bossVictory==nil && dead.loopReturn==nil && dead.phase == .gameOver,"a real ending cancels any pending victory/movie stage")
        print("\(checks) boss victory checks passed;source7sHUD is separate from own2.8smovie,live pre-movie controls,physical prizes,pause,once-only black-frame return;not original cinematic duration or engine acceptance")
    }
}
