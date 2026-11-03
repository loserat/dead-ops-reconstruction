import Foundation

@main struct StampedeChecks {
    static func main() {
        setbuf(stdout,nil);var passed=0
        func expect(_ yes:Bool,_ text:String){guard yes else{fatalError(text)};passed+=1;print("PASS \(text)")}
        func near(_ a:Double,_ b:Double)->Bool {abs(a-b)<1e-7}
        var normal=StampedeDirector(mode:.normal)
        expect(normal.step(9.999,random:{0}).isEmpty,"normal monitor waits ten seconds before its first outside model")
        let n0=normal.step(0.001,random:{0})
        expect(n0.count==1 && near(n0[0].clock,10) && n0[0].side == .north && n0[0].golden,"low-end normal draw creates one sacred model, not a simultaneous herd")
        expect(normal.step(1.099,random:{0}).isEmpty,"sacred model initialization adds its100ms local wait before the one-second child spacing")
        let n1=normal.step(0.001,random:{0});expect(n1.count==1 && near(n1[0].clock,11.1),"second low-end child is born at11.1seconds")
        let n2=normal.step(11.1,random:{0})
        expect(n2.count==1 && near(n2[0].clock,22.2) && normal.bursts==2,"normal burst retains the final child wait then ten-second inter-burst gap")
        var medium=StampedeDirector(mode:.normal);let m=medium.step(39.6,random:{0.6})
        expect(m.count==5 && zip(m.map(\.clock),[10.0,11.9,13.8,15.7,39.6]).allSatisfy{near($0.0,$0.1)},"normal mid draw schedules four single births at1.9second intervals then22second gap")
        expect(m.allSatisfy{!$0.golden && $0.side == .west},"normal groups may reuse a closed side rather than applying challenge history")
        for roll in [0.0,0.049999,0.05,0.5,1.0.nextDown] {
            var d=StampedeDirector(mode:.normal);let first=d.step(10,random:{roll})
            expect(first.count==1 && first[0].golden==(roll<0.05),"gold threshold draw\(roll) follows five percent rather than ten")
            expect(d.remaining+1==2+Int(roll*4),"normal draw\(roll) selects source2–5total children")
        }
        var blocked=StampedeDirector(mode:.normal)
        expect(blocked.step(10.1,openSides:[.north],random:{0}).isEmpty && blocked.births==0,"a normal burst cannot begin on an open player exit")
        let freed=blocked.step(0.05,random:{0});expect(freed.count==1,"the waiting source side check retries every50ms and resumes when that side closes")
        var allOpen=StampedeDirector(mode:.normal)
        expect(allOpen.step(100,openSides:Set(EntrySide.allCases),random:{0.5}).isEmpty,"all-open synthetic layout remains bounded without inventing an allowed side")
        func sequence(split:Bool)->[StampedeBirth] {
            var d=StampedeDirector(mode:.challenge),seed:UInt64=78231
            func random()->Double {seed=seed&*6364136223846793005&+1;return Double(seed>>11)/Double(UInt64.max>>11)}
            if !split{return d.step(240,random:random)}
            var out=[StampedeBirth]();for _ in 0..<14400 {out+=d.step(1.0/60,random:random)};return out
        }
        let large=sequence(split:false),small=sequence(split:true)
        expect(large==small && large.count>50,"large and14400small steps preserve every challenge birth,side,gold draw and timestamp")
        var groups=[[StampedeBirth]]()
        for e in large {if groups.last?.last?.side != e.side {groups.append([])};groups[groups.count-1].append(e)}
        expect(groups.count>5 && groups.dropLast().allSatisfy{(5...9).contains($0.count)},"challenge groups contain five through nine staggered children")
        expect((2..<groups.count).allSatisfy{groups[$0][0].side != groups[$0-1][0].side && groups[$0][0].side != groups[$0-2][0].side},"challenge fronts avoid both last-used sides")
        expect(groups.dropLast().allSatisfy {g in zip(g,g.dropFirst()).allSatisfy{a,z in let delay=z.clock-a.clock-a.activationDelay;return delay>=1-1e-8 && delay<2.5}},"each child spacing retains1–2.5seconds plus only its preceding sacred initialization")
        var stopped=StampedeDirector(mode:.challenge);stopped.stop()
        expect(stopped.step(100,random:{0}).isEmpty && !stopped.active,"all-zombies-dead/exit stop prevents future children")
        for round in [1,8,16,17,18,20,21,57,58,60,61] {
            let g=GameCore();g.reset();g.round=round;g.beginRound()
            let expected:StampedeDirector.Mode?=round==17 ? .challenge:[18,20,58,60].contains(round) ? .normal:nil
            expect(g.stampede?.mode==expected,"actual round\(round) prepares only its source factory/challenge mode")
        }
        var observed=Set<EntrySide>()
        for seed in 1...32 {
            let g=GameCore();g.reset();for _ in 0..<seed {_=g.random()};g.round=18;g.beginRound();g.foes=[];g.pickups=[];g.combatSpawningHeld=true;g.hero=V2(x:-6,y:-6);g.invulnerable=999;g.bullClock=0
            g.stepStampede(0);guard let b=g.bulls.first else{fatalError("normal first child missing")}
            expect(g.bulls.count==1 && b.destination != nil,"world seed\(seed) creates only the first real ten-second traveller")
            let side:EntrySide=abs(b.p.x)>abs(b.p.y) ? (b.p.x<0 ? .west:.east):(b.p.y<0 ? .north:.south);observed.insert(side)
            let a=g.layout.enemyArrival(index:g.layout.entrance(on:side,roll:0)).start.p,z=g.layout.enemyArrival(index:g.layout.entrance(on:side.opposite,roll:0)).start.p
            expect(b.p==a && b.destination==z && near(b.speed,(z-a).length/10) && !g.layout.contains(b.p),"world seed\(seed) starts outside the real portal and targets the opposite physical spawn")
            g.stampede?.stop();g.stepStampede(5+max(0,-b.age))
            expect(g.bulls.count==1 && (g.bulls[0].p-(a+z)*0.5).length<1e-7,"world seed\(seed) reaches its midpoint after five active seconds")
            g.stepStampede(4.999);expect(g.bulls.count==1,"world seed\(seed) survives just before ten-second destination")
            g.stepStampede(0.001);expect(g.bulls.isEmpty,"world seed\(seed) disappears on the ten-second far endpoint")
        }
        expect(observed==Set(EntrySide.allCases),"actual world births cover all four existing map entrances")
        let g=GameCore();g.reset();g.round=17;g.beginRound();g.combatSpawningHeld=true;g.foes=[];g.pickups=[];g.invulnerable=999;g.hero=V2(x:6,y:5)
        g.bulls=[Bull(id:9001,p:.zero,direction:V2(x:1,y:0),speed:0)];let score=g.score;g.explodeBulls(at:.zero,radius:1)
        expect(g.score==score,"ordinary bull destruction has no invented250point credit")
        g.foes=[Foe(id:9002,p:.zero,hp:10,speed:0,gait:0)];g.bulls=[Bull(id:9003,p:V2(x:-1,y:0),direction:V2(x:1,y:0),speed:5)];g.moveStampedeBulls(0.4);g.resolveDefeatedFoes()
        expect(g.foes.isEmpty && g.score==score,"bull-trampled zombies remain environment kills with no false player score")
        g.bulls=[Bull(id:9004,p:.zero,direction:V2(x:1,y:0),speed:1)];g.finishCombatSpawning();g.step(0,input:Controls())
        expect(g.phase == .cleared && g.bulls.count==1 && g.stampede?.active==false,"challenge completion stops births without waiting for fake-AI bull models")
        let before=g.bulls[0].p;g.step(0.2,input:Controls());expect(g.bulls[0].p != before,"surviving challenge bull keeps moving while player exits are open")
        g.fateRoomVisited=true;let exit=g.availableExits.first{$0.bonus==nil}!;g.requestArenaExit(exit);let transit=g.arenaTransit!;g.stepArenaTransit(transit.debounce+1-0.001)
        expect(!g.bulls.isEmpty,"existing cow remains during the actual fade-out")
        g.stepArenaTransit(0.001);expect(g.bulls.isEmpty,"exit_taken_fadeout removes the remaining physical cow at black")
        g.stepArenaTransit(100)
        expect(g.round==18 && near(g.bullClock,6.6),"normal source ten-second monitor wait includes1.7second hold and1.7second fade/tween")
        let clock=g.bullClock;g.step(0,input:Controls(pause:true));g.step(100,input:Controls())
        expect(near(g.bullClock,clock),"pause freezes the real monitor deadline")
        print("\(passed) stampede checks passed;archived schedule/gold/route lifetime/exit lifecycle/no invented score;own map scale/contacts,not original engine or hardware acceptance")
    }
}
