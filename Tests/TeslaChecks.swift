import Foundation

private final class TeslaFixture {
    let state=TeslaDischarge()
    var bodies:[Int:TeslaTarget]=[:],killed:[(Int,Double)]=[],arcs:[(Int,Int,Double)]=[]
    var denied=Set<Int>(),roll=0.0,randomCalls=0
    init(_ points:[V2]) {for (i,p) in points.enumerated(){bodies[i+1]=TeslaTarget(id:i+1,p:p,headHeight:1,spineHeight:0.7)}}
    func begin(_ id:Int=1)->Bool {state.begin(bodies[id]!,mark:{self.bodies[$0]?.marked=$1})}
    func step(_ dt:Double,at clock:Double?=nil) {
        state.advance(dt,at:clock,targets:{Array(self.bodies.values)},lookup:{self.bodies[$0]},mark:{self.bodies[$0]?.marked=$1},visible:{_,b in !self.denied.contains(b.id)},random:{self.randomCalls+=1;return self.roll}) {event in
            switch event {
            case .arc(let a,let b,let t):self.arcs.append((a.id,b.id,t))
            case .kill(let id,_,let t):self.killed.append((id,t));self.bodies[id]?.alive=false
            }
        }
    }
}
@main struct TeslaChecks {
    static func main() {
        var count=0
        func expect(_ value:Bool,_ message:String){count+=1;if !value{fatalError("FAIL Tesla: "+message)};print("PASS "+message)}
        func close(_ a:Double,_ b:Double)->Bool {abs(a-b)<1e-7}
        expect(TeslaRules.maximumTargets==20 && TeslaRules.maximumDepth==4 && close(TeslaRules.radius(1),2.8) && close(TeslaRules.radius(4),2.2),"archived cap includes root and recursion stops before depth five")
        expect(close(TeslaRules.angularSpeed,Double.pi) && TeslaRules.initialAngles.count==4 && TeslaRules.orbitRadius==0.8,"four source offsets rotate half a turn per second at mapped radius eighty")
        expect(TeslaRules.secondaryWait(unit:0,depth:2)==0 && close(TeslaRules.secondaryWait(unit:1,depth:4),0.8),"explicit first-argument RandomFloat interpretation stays separate from authenticated constants")
        let single=TeslaFixture([.zero,V2(x:6,y:0)])
        expect(single.begin() && single.bodies[1]!.marked && !single.state.ready,"real chain initialization marks root and closes only its player's gate")
        single.step(0.099)
        expect(single.killed.isEmpty && single.randomCalls==0,"root damage waits a full local network frame without a random draw")
        single.step(0.001)
        expect(single.killed.map{$0.0}==[1] && close(single.killed[0].1,0.1) && single.arcs.isEmpty,"root dies at one hundred milliseconds without an invented root-to-orb beam")
        expect(!single.begin(2) && !single.bodies[2]!.marked,"closed gate rejects another root without reserving or consuming a target")
        single.step(1.899);expect(!single.state.ready,"gate remains shut just before two seconds")
        single.step(0.001);expect(single.state.ready && single.begin(2),"gate reopens exactly two seconds after initialization")
        let many=TeslaFixture((0..<30).map{V2(x:Double($0)*0.06,y:0)})
        _=many.begin();many.step(10)
        expect(many.killed.count==20 && Set(many.killed.map{$0.0}).count==20,"dense source branching kills at most twenty unique bodies including root")
        expect(many.bodies.values.filter{$0.marked}.count==20 && many.bodies.values.filter{$0.alive}.count==10,"rejected cap siblings are unmarked and remain living targets")
        expect(many.state.pendingNodes==0 && many.state.pendingPrograms==0 && many.state.pendingDamage==0,"completed twenty-body program releases all bounded scheduling state")
        let depth=TeslaFixture((0..<6).map{V2(x:Double($0)*2.1,y:0)})
        _=depth.begin();depth.step(10)
        expect(Set(depth.killed.map{$0.0})==Set([1,2,3,4]) && depth.bodies[5]!.alive && !depth.bodies[5]!.marked,"four real recursion levels reach outward and release depth-rejected successors")
        let branch=TeslaFixture([.zero,V2(x:1,y:0),V2(x:0,y:2),V2(x:3.4,y:0)])
        _=branch.begin();branch.step(0.2)
        expect(branch.bodies[3]!.marked && branch.bodies[4]!.marked && branch.killed.map{$0.0}==[1,2],"root siblings are reserved before child discovers its own additional branch")
        branch.step(1)
        expect(branch.killed.map{$0.0}==[1,2,4,3] && close(branch.killed.last!.1,0.9),"depth-first continuation returns to the reserved root sibling after the nested child")
        let cache=TeslaFixture([.zero,V2(x:2.5,y:0),V2(x:2.6,y:1.2),V2(x:3,y:0)])
        _=cache.begin();cache.step(0.1)
        cache.bodies[5]=TeslaTarget(id:5,p:V2(x:2.8,y:0.1),headHeight:1,spineHeight:0.7)
        cache.step(2)
        expect(cache.killed.map{$0.0}==[1,3,4,2],"all descendants retain initial-root distance order rather than re-sorting by their own nearest neighbor")
        expect(cache.bodies[5]!.alive && !cache.bodies[5]!.marked,"AI arriving after initial cached species array is excluded from the existing program")
        let blocked=TeslaFixture([.zero,V2(x:1,y:0),V2(x:0,y:1)])
        blocked.denied=[2];blocked.bodies[3]=TeslaTarget(id:3,p:V2(x:0,y:1),headHeight:5,spineHeight:4.7)
        _=blocked.begin();blocked.step(3)
        expect(blocked.killed.map{$0.0}==[1] && !blocked.bodies[2]!.marked && !blocked.bodies[3]!.marked,"line traces and three-dimensional head distance reject blocked and high targets before marking")
        for (distance,far) in [(1.27,false),(1.28,true),(2.0,true)] {
            let f=TeslaFixture([.zero,V2(x:distance,y:0)]);_=f.begin();f.step(0.2)
            expect(f.arcs.count==(far ? 1:0) && f.killed.count==(far ? 1:2),"arc threshold\(distance) uses strict one hundred twenty-eight source units")
            if far {f.step(0.499);expect(f.killed.count==1,"far Tesla bolt remains in flight for its full half second");f.step(0.001);expect(close(f.killed.last!.1,0.7),"far target dies after the actual moving emitter arrival")}
        }
        let choke=TeslaFixture([.zero]+(0..<5).map{_ in V2(x:1.5,y:0)})
        _=choke.begin();choke.step(2)
        expect(choke.arcs.count==5 && zip(choke.arcs.map{$0.2},[0.2,0.3,0.4,0.5,0.7]).allSatisfy{close($0.0,$0.1)},"fifth child arc yields one local network frame without inventing a four-kill-per-tick ceiling")
        let canceled=TeslaFixture([.zero,V2(x:2,y:0),V2(x:4,y:0)])
        canceled.roll=1;_=canceled.begin();canceled.step(0.2);canceled.state.cancelPlanning();canceled.step(3)
        expect(canceled.killed.map{$0.0}==[1,2] && canceled.bodies[3]!.alive,"physical-death interpretation stops new planning but retains disconnect-only launched damage")
        let cleared=TeslaFixture([.zero,V2(x:2,y:0)]);_=cleared.begin();cleared.step(0.2);cleared.state.clearTargets();let gate=cleared.state.gateRemaining;cleared.step(3)
        expect(cleared.killed.map{$0.0}==[1] && gate>1.7 && cleared.state.pendingNodes==0,"arena cleanup cancels old targets and preserves the existing discharge gate")
        let stolen=TeslaFixture([.zero,V2(x:2,y:0)]);_=stolen.begin();stolen.step(0.2);stolen.bodies[2]?.alive=false;stolen.step(1)
        expect(stolen.killed.map{$0.0}==[1],"another attack killing an in-flight target prevents a second Tesla kill or score")
        let boss=TeslaFixture([.zero,V2(x:1,y:0)]);boss.bodies[1]?.boss=true
        expect(boss.begin() && boss.state.pendingNodes==0 && !boss.bodies[1]!.marked,"boss initialization closes gate without reserving boss or scheduling ordinary chain damage")
        boss.step(3);expect(boss.killed.isEmpty && boss.arcs.isEmpty,"no hidden normal Tesla chain is launched from an initial boss contact")
        let neighborBoss=TeslaFixture([.zero,V2(x:1,y:0)]);neighborBoss.bodies[2]?.boss=true;_=neighborBoss.begin();neighborBoss.step(3)
        expect(neighborBoss.bodies[2]!.marked && neighborBoss.bodies[2]!.alive && neighborBoss.killed.count==1,"neighbor boss is reserved by bulk marking but excluded from descendants and kills")
        let frozen=TeslaFixture([.zero]);frozen.step(0,at:10);_=frozen.begin();frozen.step(0.05,at:100);frozen.step(0.05,at:100)
        expect(frozen.killed.isEmpty && close(frozen.state.clock,0.05),"frozen world gap and duplicate clock delivery cannot age queued damage twice")
        frozen.step(-1);frozen.step(.nan);frozen.step(.infinity);frozen.step(1,at:5)
        expect(close(frozen.state.clock,0.05),"invalid or backward time cannot contaminate Tesla scheduler")
        frozen.step(0.05,at:100.05);expect(frozen.killed.count==1,"next active time resumes the original remaining local wait")
        for rate in [30,60,120] {
            let f=TeslaFixture([.zero,V2(x:2,y:0)]);f.roll=0.5;_=f.begin()
            for _ in 0..<(rate*2){f.step(1/Double(rate))}
            expect(f.killed.map{$0.0}==[1,2] && close(f.killed[1].1,0.9) && f.randomCalls==1,"chronological waits and travel agree at\(rate) updates per second")
        }
        func game(_ count:Int=1)->GameCore {
            let g=GameCore();g.reset(playerCount:count);g.combatSpawningHeld=true;g.sourceLoot=nil;g.foes=[];g.pickups=[];g.hero=V2(x:-4,y:-3);g.invulnerable=999
            return g
        }
        func body(_ g:GameCore,_ p:V2,_ hp:Double=10)->Foe {
            var f=Foe(id:g.id(),p:p,hp:hp,speed:0,gait:0)
            f.referenceVitality=ReferenceVitality(sourceMaximum:1000,localMaximum:10,exactScriptBase:true);return f
        }
        let live=game();live.grantOrbs();let first=live.orbShields[0].p
        live.foes=[body(live,first),body(live,first+V2(x:2,y:0)),body(live,V2(x:7,y:3))]
        live.resolveOrbHits()
        expect(live.orbShields.count==3 && close(live.foes[0].hp,9.99) && live.foes[0].teslaContacted && live.foes[0].teslaMarked && live.score==0,"actual swept orb contact consumes one charge and projects only initial raw1 damage before delayed chain")
        live.stepTesla(0.099);expect(live.foes[0].hp>0,"actual world body survives before first local wait expires")
        live.stepTesla(0.001);live.resolveDefeatedFoes();expect(live.score==100 && live.foes.count==2,"actual first Tesla death uses ordinary personal score exactly once")
        live.stepTesla(2);live.resolveDefeatedFoes();expect(live.score==200 && live.foes.count==1,"actual delayed child kill scores normally and leaves the distant target alive")
        let physical=game();physical.grantOrbs();let o=physical.orbShields[0].p
        physical.foes=[body(physical,o)];physical.foes[0].elevation=2;physical.resolveOrbHits()
        expect(physical.orbShields.count==4 && !physical.foes[0].teslaContacted,"ground orb trigger cannot consume a charge through a non-overlapping elevated body")
        physical.foes[0].elevation=0;physical.heroElevation=3;physical.resolveOrbHits()
        expect(physical.orbShields.count==4,"airborne player's orb trigger cannot hit a ground zombie through vertical projection")
        let sweep=game();sweep.grantOrbs();sweep.orbShields[0].previousP=sweep.hero+V2(x:-1,y:0);sweep.orbShields[0].p=sweep.hero+V2(x:1,y:0);sweep.foes=[body(sweep,sweep.hero)]
        sweep.resolveOrbHits();expect(sweep.orbShields.count==3 && sweep.foes[0].teslaContacted,"fast actual orbit sweep retains a crossed trigger body between endpoints")
        let same=game();same.grantOrbs();same.foes=[body(same,same.orbShields[0].p)];same.resolveOrbHits();let pending=same.playerRoster.current.tesla.pendingPrograms
        same.grantOrbs();same.resolveOrbHits()
        expect(same.orbShields.count==4 && pending==1 && same.playerRoster.current.tesla.pendingPrograms==1 && same.playerRoster.current.tesla.gateRemaining==2,"new pickup replaces physical charges without resetting cooldown or canceling existing chain")
        let pendingBody=game(2);pendingBody.withPlayer(1){pendingBody.grantOrbs()};pendingBody.foes=[body(pendingBody,pendingBody.players[1].orbShields[0].p)];pendingBody.foes[0].teslaMarked=true
        pendingBody.withPlayer(1){pendingBody.resolveOrbHits()}
        expect(pendingBody.players[1].orbShields.count==3 && pendingBody.players[1].tesla.ready && pendingBody.players[1].tesla.pendingNodes==0,"contact on already reserved target consumes raw1 and charge without stealing chain or closing another gate")
        let team=game(2);team.withPlayer(1){team.hero=V2(x:-4,y:-3);team.grantOrbs()};team.foes=[body(team,team.players[1].orbShields[0].p)]
        team.withPlayer(1){team.resolveOrbHits()};team.stepTesla(0.1);team.resolveDefeatedFoes()
        expect(team.players[1].score==100 && team.players[0].score==0 && team.players[0].tesla.ready && !team.players[1].tesla.ready,"shared world kill keeps actual player-two ownership and independent player-one gate")
        let double=game(2);double.grantOrbs();double.foes=[body(double,double.orbShields[0].p)];double.resolveOrbHits();double.stepTesla(0.1);double.foes[0].creditSlot=1;double.resolveDefeatedFoes();double.stepTesla(5);double.resolveDefeatedFoes()
        expect(double.players[1].score==100 && double.players[0].score==0,"ordinary final death resolution never manufactures a second point award from a completed Tesla job")
        let cover=game();cover.round=29;cover.hero=V2(x:0.7,y:-1.8);cover.grantOrbs();cover.foes=[body(cover,cover.orbShields[0].p),body(cover,V2(x:3.3,y:-1))];cover.resolveOrbHits();cover.stepTesla(3)
        expect(cover.foes[0].hp<=0 && cover.foes[1].hp==10 && !cover.foes[1].teslaMarked,"real own-map tank geometry blocks Tesla head trace through solid fuel storage")
        for players in [1,4] {
            let b=game(players);var ape=Silverback();ape.id=b.id();ape.p=b.hero;ape.arrival=nil;b.silverbacks=[ape];b.grantOrbs();b.resolveOrbHits()
            let damage=1200-b.silverbacks[0].hp
            expect(b.orbShields.count==3 && close(damage,1200/(500000*Double(players))) && b.playerRoster.current.tesla.pendingNodes==0,"boss initial raw1 is projected through\(players)-player five-hundred-thousand health without thirty-local-damage substitute")
            b.stepTesla(2);b.resolveOrbHits();expect(b.orbShields.count==3,"already Tesla-contacted boss cannot consume another orb when gate reopens")
        }
        let bossTeam=game(2);var ape=Silverback();ape.id=bossTeam.id();ape.p=bossTeam.hero;bossTeam.silverbacks=[ape];bossTeam.grantOrbs();bossTeam.resolveOrbHits()
        bossTeam.withPlayer(1){bossTeam.damageSilverback(1,id:ape.id)}
        expect(!bossTeam.players[1].tesla.ready && bossTeam.players[1].tesla.pendingNodes==0,"later damage to Tesla-tagged ape follows archived damage handler into attacker's gate only")
        let bossMarked=game(2);var marked=Silverback();marked.id=bossMarked.id();marked.p=bossMarked.hero;marked.teslaMarked=true;bossMarked.silverbacks=[marked];bossMarked.grantOrbs();bossMarked.resolveOrbHits()
        expect(bossMarked.orbShields.count==3 && bossMarked.playerRoster.current.tesla.ready,"bulk-marked boss contact still consumes one physical charge without another discharge gate")
        let paused=game();paused.grantOrbs();paused.foes=[body(paused,paused.orbShields[0].p)];paused.resolveOrbHits();paused.step(0,input:Controls(pause:true));paused.step(10,input:Controls())
        expect(paused.foes[0].hp>0 && paused.playerRoster.current.tesla.clock==0,"actual game pause freezes pending Tesla damage and cooldown")
        paused.step(0,input:Controls(accept:true));paused.step(0.1,input:Controls())
        expect(paused.foes.isEmpty && paused.score==100,"actual resumed game completes only the original one-hundred-millisecond wait")
        let god=game();god.grantOrbs();god.foes=[body(god,god.orbShields[0].p)];god.resolveOrbHits();god.godMode=true;god.invulnerable=0;god.loseLife();god.stepTesla(0.1)
        expect(god.trainingHits==1 && god.foes[0].hp==0 && god.orbShields.count==3,"Godmode virtual loss does not cancel original player's pending chain or remaining equipment")
        let death=game();death.grantOrbs();death.foes=[body(death,death.orbShields[0].p)];death.resolveOrbHits();death.invulnerable=0;death.loseLife();death.stepTesla(0.1)
        expect(death.playerRoster.current.isDown && death.foes[0].hp>0 && death.orbShields.isEmpty,"own physical-death policy clears carried orbs and aborts only not-yet-launched planning")
        let clean=game();clean.grantOrbs();clean.foes=[body(clean,clean.orbShields[0].p)];clean.resolveOrbHits();clean.clearArenaSupport();clean.stepTesla(3)
        expect(clean.foes[0].hp>0 && clean.playerRoster.current.tesla.pendingNodes==0,"real arena-support cleanup cancels retained Tesla target threads")
        clean.reset();expect(clean.players.allSatisfy{$0.tesla.ready && $0.tesla.pendingNodes==0 && $0.tesla.clock==0},"new attempt clears per-player clocks jobs and gates")
        print("\(count) Tesla checks passed")
    }
}
