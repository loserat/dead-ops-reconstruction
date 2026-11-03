import Foundation

@main struct DefeatedBodyChecks {
    static func main() {
        var passed=0
        func expect(_ ok:Bool,_ why:String) {guard ok else{fatalError(why)};passed+=1;print("PASS \(why)")}
        func fixture()->GameCore {
            let g=GameCore();g.reset(playerCount:2);g.combatSpawningHeld=true;g.foes=[];g.pickups=[]
            for p in g.players {p.hero = .zero;p.heroElevation=0;p.invulnerable=999}
            _=g.takeDefeatPresentations();return g
        }
        let g=fixture(),f=Foe(id:123,p:V2(x:0.3,y:0),hp:100,speed:0,gait:0)
        g.foes=[f];g.withPlayer(1){g.beginBodyShield();g.stepTeamRecovery(0.05);g.resolveBodyShieldContacts()}
        expect(g.foes[0].launchedByContact && g.foes[0].hp==0 && g.takeDefeatPresentations().isEmpty,"Contact records the cause on its foe; presentation waits for the existing defeat pass")
        g.resolveDefeatedFoes();let shield=g.takeDefeatPresentations()
        expect(shield.count==1 && shield[0].id==123 && shield[0].position==f.p && shield[0].launched && g.players[1].score==100 && g.players[0].score==0,"Shield launch event uses real death position and preserves player-two kill credit")
        expect(g.takeDefeatPresentations().isEmpty,"A frame consumes each death presentation only once")
        g.resolveDefeatedFoes();expect(g.takeDefeatPresentations().isEmpty && g.players[1].score==100,"Repeated defeat pass cannot create a second launch or award")
        g.foes=[f];g.dashTime=0.3;g.players[0].boostDirection=V2(x:1,y:0);g.facing=V2(x:1,y:0)
        g.resolveBoostContacts(from:.zero,to:.zero,oldHeight:0,endHeight:0);g.resolveDefeatedFoes()
        expect(g.takeDefeatPresentations().first?.launched==true,"Both boost contact circles use the same upward body presentation as the shield")
        g.kill(Foe(id:124,p:.zero,hp:0,speed:0,gait:0,elevation:1.2))
        let ordinary=g.takeDefeatPresentations()
        expect(ordinary.count==1 && !ordinary[0].launched && ordinary[0].elevation==1.2,"Ordinary kill stays an ordinary fall and retains its actual elevation")
        g.foes=[f];g.foes.removeAll();expect(g.takeDefeatPresentations().isEmpty,"Withdrawal or arena removal without a kill never invents a corpse")
        for id in 0..<300 {g.kill(Foe(id:id,p:.zero,hp:0,speed:0,gait:0))}
        let bounded=g.takeDefeatPresentations()
        expect(bounded.count==256 && bounded.first?.id==44 && bounded.last?.id==299,"Unobserved presentation queue is bounded while retaining newest real deaths")
        let a=fixture(),b=fixture()
        for id in 0..<50 {a.kill(Foe(id:id,p:.zero,hp:0,speed:0,gait:0));b.kill(Foe(id:id,p:.zero,hp:0,speed:0,gait:0));_=b.takeDefeatPresentations()}
        expect(a.id()==b.id() && a.random()==b.random() && a.players.map(\.score)==b.players.map(\.score) && a.effects.count==b.effects.count,"Draining or retaining visual events does not consume world IDs, randomness, effects or score")
        a.beginRound();expect(a.takeDefeatPresentations().isEmpty,"Round boundary clears stale death presentations")
        b.kill(f);b.reset();expect(b.takeDefeatPresentations().isEmpty,"New run clears pending bodies")
        for launched in [false,true] {
            let motion=DefeatedBodyMotion(launched:launched),first=motion.pose(age:0),last=motion.pose(age:motion.duration)
            expect(first.angle==0 && first.lift==0 && !first.settled && last.settled && abs(last.lift)<1e-8,"\(launched ? "Launched":"Ordinary") body starts upright and settles finitely at its own floor")
            var maxLift=0.0
            for i in 0...100 {let pose=motion.pose(age:motion.duration*Double(i)/100);expect(pose.lift>=0 && pose.angle.isFinite && pose.opacity>=0.65 && pose.opacity<=1,"Bounded finite body pose \(launched)-\(i)");maxLift=max(maxLift,pose.lift)}
            expect(launched ? maxLift>0.5:maxLift==0,"Only explicit launch has a positive ballistic arc")
            expect(motion.pose(age:100).settled && motion.pose(age:100).angle==last.angle && motion.pose(age:100).lift==last.lift,"Finished body never restarts or keeps spinning")
        }
        print("\(passed) defeat-presentation checks passed; own bounded visual motion, no original ragdoll/rumble/audio/60FPS claim")
    }
}
