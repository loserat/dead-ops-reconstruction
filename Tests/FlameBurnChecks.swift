import Foundation

@main struct FlameBurnChecks {
    static func main() {
        var checks=0
        func expect(_ value:Bool,_ message:String){checks+=1;if !value{fatalError("FAIL flame burn: "+message)};print("PASS "+message)}
        func close(_ a:Double,_ b:Double)->Bool {abs(a-b)<1e-7}
        let domain=ReferenceVitality(sourceMaximum:1000,localMaximum:10,exactScriptBase:true)
        var burn=FlameAfterburn(vitality:domain,clock:0)
        expect(close(burn.tickDamage,1.2) && burn.ticks==0 && burn.remaining==8,"archived120 raw damage maps through captured full health")
        expect(burn.advance(0.399)==0 && close(burn.remaining,7.601),"first afterburn damage waits a full four hundred milliseconds")
        expect(burn.advance(0.001)==1 && burn.ticks==1,"exact first interval boundary releases one damage tick")
        expect(burn.advance(0.8)==2 && burn.ticks==3,"large active steps retain both due ticks")
        expect(burn.advance(20)==17 && burn.ticks==20 && burn.remaining==0,"one eight-second thread ends at twenty raw120 ticks")
        expect(burn.advance(20)==0,"completed burning thread never adds a twenty-first tick")
        var one=FlameAfterburn(vitality:domain,clock:0)
        expect(one.advance(8)==20,"one whole interval span agrees with split-step tick count")
        var rounded=FlameAfterburn(vitality:domain,clock:0.05)
        _=rounded.advance(0.399,at:0.449);_=rounded.advance(0.001,at:0.45);_=rounded.advance(7.6,at:8.05)
        expect(rounded.ticks==20 && rounded.remaining==0 && rounded.age==8,"last due tick clears sub-frame floating residue without a twenty-first update")
        for rate in [30,60,120] {
            var value=FlameAfterburn(vitality:domain,clock:0),total=0
            for _ in 0..<(rate*8) {total+=value.advance(1/Double(rate))}
            expect(total==20 && value.ticks==20 && close(value.age,8),"pure burn retains twenty ticks at\(rate) updates")
        }
        var guarded=FlameAfterburn(vitality:domain,clock:10)
        expect(guarded.advance(0.05,at:10)==0 && guarded.age==0,"ignition frame does not prematurely age a newly created burn")
        expect(guarded.advance(0.05,at:10.05)==0 && close(guarded.age,0.05),"following world frame advances only its actual active time")
        expect(guarded.advance(0.05,at:10.05)==0 && close(guarded.age,0.05),"duplicate world-clock delivery cannot age the same burn twice")
        expect(guarded.advance(0.05,at:100)==0 && close(guarded.age,0.10),"long frozen world interval cannot burst queued burn damage on resume")
        let frozen=guarded.age
        expect(guarded.advance(-1)==0 && guarded.advance(.nan)==0 && guarded.advance(.infinity)==0 && guarded.age==frozen,"invalid time never contaminates a live burn")
        expect(guarded.advance(1,at:1)==0 && guarded.age==frozen,"backward world time cannot rewind the thread")
        let late=ReferenceVitality.foe(.zombie,round:37,mini:false,localMaximum:35)
        expect(close(FlameAfterburn(vitality:late,clock:0).tickDamage,120*35/6400),"late ordinary spawn uses its raw6400 maximum rather than a fresh-hit fraction")
        let mini=ReferenceVitality.foe(.prisoner,round:1,mini:true,localMaximum:100)
        expect(close(FlameAfterburn(vitality:mini,clock:0).tickDamage,120*100/4400),"mini-prisoner uses archived full-health addition and modifier")
        let bad=ReferenceVitality(sourceMaximum:0,localMaximum:.infinity,exactScriptBase:false)
        expect(FlameAfterburn(vitality:bad,clock:0).tickDamage==0,"invalid ad-hoc health metadata cannot inject nonfinite damage")

        func fixture(_ count:Int=1,_ kind:FoeKind = .zombie,hp:Double=100,raw:Double=1000)->GameCore {
            let g=GameCore();g.reset(playerCount:count);g.combatSpawningHeld=true;g.sourceLoot=nil;g.foes=[];g.pickups=[];g.shots=[]
            g.hero=V2(x:-3,y:-3);g.invulnerable=999
            var foe=Foe(id:g.id(),p:V2(x:-1,y:-3),hp:hp,speed:0,gait:0,kind:kind)
            foe.referenceVitality=ReferenceVitality(sourceMaximum:raw,localMaximum:hp,exactScriptBase:kind != .hound)
            g.foes=[foe];return g
        }
        func ignite(_ g:GameCore,_ damage:Double=0) {g.fireFlame(from:V2(x:-3,y:-3),direction:V2(x:1,y:0),height:0.53,damage:damage)}
        let live=fixture();ignite(live,0.3)
        expect(close(live.foes[0].hp,99.7) && live.foes[0].burning==8 && live.foes[0].flameAfterburn?.ticks==0,"real flame cone preserves direct damage and creates a separate eight-second thread")
        live.stepBurning(0.399)
        expect(close(live.foes[0].hp,99.7),"real target receives no continuous substitute damage before first tick")
        live.stepBurning(0.001)
        expect(close(live.foes[0].hp,87.7) && live.foes[0].flameAfterburn?.ticks==1,"real target applies one projected raw120 tick at the boundary")
        let originalAge=live.foes[0].flameAfterburn!.age
        ignite(live,0.3)
        expect(close(live.foes[0].hp,87.4) && live.foes[0].flameAfterburn!.age==originalAge,"repeated flame contact adds direct damage without restarting burning")
        let completed=fixture(hp:100,raw:16000);ignite(completed);completed.stepBurning(8)
        expect(close(completed.foes[0].hp,85) && completed.foes[0].burning==0,"high-health survivor receives exactly2400 raw damage across eight seconds")
        ignite(completed,0.1);completed.stepBurning(8)
        expect(close(completed.foes[0].hp,84.9) && completed.foes[0].flameAfterburn?.ticks==20 && completed.foes[0].burning==0,"gas on an already burned survivor cannot start a second thread")
        let wounded=fixture();wounded.foes[0].hp=5;ignite(wounded);wounded.stepBurning(0.4)
        expect(close(wounded.foes[0].hp,-7),"partial health never rescales a stored full-health burn projection")
        for kind in [FoeKind.prisoner,.crawler,.villager,.engineer,.martyr,.sasquatch] {
            let target=fixture(1,kind);ignite(target)
            expect(target.foes[0].flameAfterburn != nil && target.foes[0].burning==8,"mapped humanoid\(kind) uses the ordinary scripted afterburn")
        }
        let dog=fixture(1,.hound);ignite(dog);dog.stepBurning(0.2)
        expect(dog.foes[0].flameAfterburn==nil && close(dog.foes[0].hp,99) && close(dog.foes[0].burning,2.3),"unverified separate dog archetype explicitly retains its old approximation")
        let team=fixture(2,hp:100,raw:1000)
        team.withPlayer(1){ignite(team)};team.stepBurning(0.4);let firstAge=team.foes[0].flameAfterburn!.age
        ignite(team,0.1)
        expect(team.foes[0].burningOwner==1 && team.foes[0].creditSlot==0 && team.foes[0].flameAfterburn!.age==firstAge,"later player's direct hit does not steal or restart the first attacker's burn")
        team.stepBurning(0.4)
        expect(team.foes[0].creditSlot==1,"later damage tick keeps its original player attribution")
        team.withPlayer(1){team.invulnerable=0;team.loseLife()};let beforeDeathTick=team.foes[0].hp;team.stepBurning(0.4)
        expect(team.foes[0].hp<beforeDeathTick && team.foes[0].creditSlot==1,"a funded player return does not cancel an enemy-owned burning thread")
        let credited=fixture(2,hp:10);credited.foes[0].hp=1
        credited.withPlayer(1){ignite(credited)};credited.stepBurning(0.4);credited.resolveDefeatedFoes()
        expect(credited.foes.isEmpty && credited.players[1].score==100 && credited.players[0].score==0,"first afterburn kill resolves once into the first attacker's personal score")
        let otherKill=fixture(2);otherKill.withPlayer(1){ignite(otherKill)};otherKill.foes[0].hp=0;otherKill.foes[0].creditSlot=0;otherKill.stepBurning(8);otherKill.resolveDefeatedFoes()
        expect(otherKill.players[0].score==100 && otherKill.players[1].score==0,"a target killed before its tick keeps the actual killer and grants no duplicate points")
        let blocked=fixture();blocked.round=29;blocked.hero=V2(x:-2,y:-1);blocked.foes[0].p=V2(x:2,y:-1)
        blocked.fireFlame(from:blocked.hero,direction:V2(x:1,y:0),height:0.53,damage:0.3)
        expect(blocked.foes[0].hp==100 && blocked.foes[0].flameAfterburn==nil,"solid fuel tank blocks both initial gas and creation of its afterburn")
        let raised=fixture();raised.foes[0].elevation=2;ignite(raised)
        expect(raised.foes[0].flameAfterburn==nil,"ground flame cannot ignite a different raised level")
        let behind=fixture();behind.foes[0].p=V2(x:-4,y:-3);ignite(behind)
        expect(behind.foes[0].flameAfterburn==nil,"target behind the actual flame direction never starts burning")
        let paused=fixture();ignite(paused);paused.step(0,input:Controls(pause:true));paused.step(3,input:Controls())
        expect(paused.foes[0].hp==100 && paused.foes[0].flameAfterburn!.age==0 && paused.foes[0].burning==8,"actual pause freezes burn clock and health")
        paused.step(0,input:Controls(accept:true));paused.step(0.4,input:Controls())
        expect(close(paused.foes[0].hp,88) && paused.foes[0].flameAfterburn?.ticks==1,"actual resume applies only resumed active time")
        for rate in [30,60,120] {
            let frame=fixture(hp:100,raw:16000);ignite(frame)
            for _ in 0..<(rate*8) {frame.step(1/Double(rate),input:Controls())}
            expect(close(frame.foes[0].hp,85) && frame.foes[0].flameAfterburn?.ticks==20,"production world clock retains the same twenty burn ticks at\(rate)Hz")
        }
        let newFrame=fixture();newFrame.weapon = .flamethrower;newFrame.weaponReserve=50
        newFrame.step(0.05,input:Controls(aim:V2(x:1,y:0)))
        expect(newFrame.foes[0].flameAfterburn?.age==0 && newFrame.foes[0].flameAfterburn?.ticks==0,"actual firing frame cannot charge its own full frame to a new burn")
        let walking=fixture(hp:100,raw:1e9),slowed=fixture(hp:100,raw:1e9)
        walking.foes[0].speed=2;slowed.foes[0].speed=2;ignite(slowed)
        let start=walking.foes[0].p
        walking.step(0.1,input:Controls());slowed.step(0.1,input:Controls())
        expect(close((slowed.foes[0].p-start).length/(walking.foes[0].p-start).length,0.65),"own local locomotion maps the archived gas playback factor0.65")
        slowed.stepBurning(8);let start2=slowed.foes[0].p;slowed.step(0.1,input:Controls())
        expect(close((slowed.foes[0].p-start2).length,0.13),"gas playback setting persists after the one finite burn thread finishes")
        let randomA=fixture(),randomB=fixture();ignite(randomA);ignite(randomB);randomA.stepBurning(8)
        expect(randomA.random()==randomB.random() && randomA.id()==randomB.id(),"afterburn ticks consume neither world randomness nor extra identities")
        live.reset();expect(live.foes.isEmpty && live.flameJets.isEmpty,"reset removes all burning enemies and prior flame models")
        print("\(checks) flame burn checks passed;archived8s/.4s/120raw/once-only/first-owner,own full-health projection and0.65root-motion mapping;dog/boss/native gas weapon/engine FX remain unverified")
    }
}
