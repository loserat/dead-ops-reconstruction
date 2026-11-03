import Foundation

@main struct VehicleExitChecks {
    static func main() {
        setbuf(stdout,nil);var passed=0
        func expect(_ yes:Bool,_ text:String){guard yes else{fatalError(text)};passed+=1;print("PASS \(text)")}
        func near(_ a:Double,_ b:Double)->Bool {abs(a-b)<1e-7}
        func game(_ round:Int=5,_ count:Int=1)->GameCore {
            let g=GameCore();g.reset(playerCount:count);g.round=round;g.beginRound();g.foes=[];g.pickups=[];g.effects=[];g.combatSpawningHeld=true
            for p in g.players {p.hero=V2(x:4,y:3);p.heroElevation=g.layout.height(p.hero);p.invulnerable=0;p.bodyShield=nil}
            return g
        }
        expect(ReferenceVitality.ordinary(1)==1000 && ReferenceVitality.ordinary(61)==10000 && ReferenceVitality.ordinary(81)==13000,"archived ordinary health grows1000+150per completed round across arena laps")
        for (kind,round,raw) in [(FoeKind.prisoner,9,4880.0),(.crawler,13,8960),(.villager,17,6700),(.engineer,22,14150),(.sasquatch,30,7675),(.martyr,30,15350)] {
            let v=ReferenceVitality.foe(kind,round:round,mini:true,localMaximum:100)
            expect(v.sourceMaximum==raw && v.exactScriptBase,"source mini\(kind) combines ordinary health,+10k and the actual archetype modifier")
        }
        expect(!ReferenceVitality.foe(.hound,round:34,mini:true,localMaximum:2).exactScriptBase,"missing dog native base health stays explicitly marked as an estimate")
        let ordinary=game(10);ordinary.combatSpawningHeld=false
        _=ordinary.admitWaveEnemy(side:.east)
        expect(ordinary.foes.last!.kind == .prisoner && ordinary.foes.last!.referenceVitality?.sourceMaximum==2350,"ordinary prison-style body does not accidentally acquire mini-boss raw health")
        _=ordinary.admitWaveEnemy(side:.east,kind:.prisoner)
        expect(ordinary.foes.last!.referenceVitality?.sourceMaximum==4940,"separately admitted prisoner carries its true mini-spawn health metadata")
        let late=game(81);_=late.admitWaveEnemy(side:.west);let last=late.foes.last!
        expect(last.referenceVitality?.sourceMaximum==13000 && last.referenceVitality?.localMaximum==RoundRules.health(last.kind,round:81),"actual late-round world spawn captures both health domains before taking damage")
        for kind in VehicleKind.allCases {
            let g=game();g.weapon = .ray;g.weaponReserve=17;g.addChicken();g.beginVehicle(kind);_=g.takeAudioEvents();let point=g.hero
            g.foes=[Foe(id:9100,p:point+V2(x:1,y:0),hp:100,speed:0,gait:0),Foe(id:9101,p:point+V2(x:2.1,y:0),hp:100,speed:0,gait:0)]
            g.endVehicle()
            expect(g.vehicle==nil && g.hero==point && g.heroElevation==g.layout.height(point),"\(kind) exit restores a valid body at its reachable ground point")
            expect(g.foes[0].hp<=0 && g.foes[1].hp==100,"\(kind) exit damages a close real target and preserves one outside the mapped200unit radius")
            expect(g.playerRoster.current.bodyShield?.remaining==3.05 && !g.playerRoster.current.bodyShield!.contactActive && g.damageProtected,"\(kind) immediately protects the body while its narrow trigger still warms for50ms")
            expect(g.effects.filter{$0.color==8}.count==1 && g.effects.first{$0.color==8}!.size==2 && near(g.effects.first{$0.color==8}!.ttl ?? 0,0.45),"\(kind) creates exactly one bounded45centisecond ground pulse")
            expect(g.takeAudioEvents()==[.respawn] && g.weapon == .ray && g.weaponReserve==17 && g.chickens.count==1 && g.lives==3 && g.deaths==0,"\(kind) exit has one return cue and preserves weapon/helper/reserve/life accounting")
            let effects=g.effects.count;g.endVehicle()
            expect(g.effects.count==effects && g.takeAudioEvents().isEmpty,"repeated\(kind) cleanup cannot duplicate a pulse or return cue")
            g.resolveDefeatedFoes();expect(g.foes.map(\.id)==[9101] && g.score==ScoreRules.ordinaryKill,"\(kind) pressure-wave kill follows ordinary owner scoring exactly once")
            g.stepTeamRecovery(0.049);expect(!g.playerRoster.current.bodyShield!.contactActive && g.takeAudioEvents().isEmpty,"\(kind) short shield does not warn or contact-kill before50ms")
            g.stepTeamRecovery(0.001);expect(g.playerRoster.current.bodyShield!.contactActive && g.takeAudioEvents()==[.shieldWarning],"\(kind) short shield opens its contact trigger and source half-shield warning at50ms")
            g.stepTeamRecovery(2.999);expect(g.damageProtected && g.takeAudioEvents().isEmpty,"\(kind) protection survives just before3.05seconds")
            g.stepTeamRecovery(0.001);expect(g.playerRoster.current.bodyShield==nil && g.acceptsPlayerDamage && g.takeAudioEvents()==[.shieldEnd],"\(kind) short shield and its final cue expire at3.05seconds")
        }
        let fractional=game();fractional.beginVehicle(.tank);fractional.vehicle!.remaining=0.01
        fractional.step(0.02,input:Controls())
        expect(fractional.vehicle==nil && near(fractional.playerRoster.current.bodyShield!.remaining,3.04),"tank expiration10ms into a20ms frame advances its new shield only through the final10ms")
        expect(near(fractional.effects.first{$0.color==8}!.ttl,0.44),"new pulse lifetime uses the same sub-frame birth offset")
        for frames in [30,60,120] {
            let g=game();g.beginVehicle(.tank);g.vehicle!.remaining=0.25
            for _ in 0..<frames {g.step(1.0/Double(frames),input:Controls())}
            expect(g.vehicle==nil && near(g.playerRoster.current.bodyShield!.remaining,2.3),"\(frames)Hz expiry yields the same3.05second post-vehicle protection deadline")
        }
        let later=game(81);let reference=ReferenceVitality.foe(.zombie,round:81,mini:false,localMaximum:100)
        later.foes=[Foe(id:9200,p:later.hero+V2(x:1,y:0),hp:50,speed:0,gait:0,referenceVitality:reference)]
        later.beginVehicle(.tank);later.endVehicle()
        expect(later.foes[0].hp<0,"a previously half-damaged late body uses its captured full health domain")
        later.foes=[Foe(id:9201,p:later.hero+V2(x:1,y:0),hp:100,speed:0,gait:0,referenceVitality:reference)]
        later.beginVehicle(.tank);later.endVehicle()
        expect(near(later.foes[0].hp,100*(1-10000.0/13000)),"late ordinary body survives the true10k pulse fraction instead of an invented instant kill")
        later.beginVehicle(.tank);later.endVehicle();expect(later.foes[0].hp<0,"a second pulse reuses the original scale rather than rescaling the remaining wound")
        for count in 1...4 {
            let g=game(40,count);g.fixtureSilverbacks();g.silverbacks[0].arrival=nil;g.silverbacks[0].entryElevation=0;g.silverbacks[0].p=g.hero+V2(x:0.5,y:0)
            g.beginVehicle(.tank);g.endVehicle()
            expect(near(g.silverbacks[0].hp,Silverback.maxHP-24/Double(count)) && !g.sourceBossDead,"\(count)roles map the10k pulse to the source500k-per-player ape health without killing the boss")
            g.stepTeamRecovery(0.05);g.silverbacks[0].p=g.hero;let hp=g.silverbacks[0].hp;g.resolveBodyShieldContacts()
            expect(g.silverbacks[0].hp==hp,"\(count)role short contact shield still excludes the boss after the separate pulse")
        }
        let wall=game(1);wall.hero=V2(x:-5.8,y:1.3);let boat=OpeningMapDesign.boat
        wall.hero=boat.p+V2(x:0.85,y:0);wall.beginVehicle(.helicopter)
        wall.foes=[Foe(id:9300,p:boat.p+V2(x:-0.85,y:0),hp:100,speed:0,gait:0),Foe(id:9302,p:wall.hero+V2(x:0,y:1.7),hp:100,speed:0,gait:0)]
        wall.endVehicle()
        expect(hypot((wall.foes[0].p-wall.hero).length,0.65-0.08)<2,"boat occlusion target is actually inside the pulse sphere")
        expect(wall.foes[0].hp==100 && wall.foes[1].hp<=0,"the 3D pulse trace blocks the real boat while an equally near unobstructed control dies")
        let high=game(9);high.hero=V2(x:9.4,y:0);high.heroElevation=high.layout.height(high.hero);high.beginVehicle(.tank)
        high.foes=[Foe(id:9301,p:high.hero,hp:100,speed:0,gait:0,elevation:high.heroElevation+3)]
        high.endVehicle();expect(high.foes[0].hp==100,"an enemy above the spherical exit radius remains alive on another level")
        let owner=game(5,2);owner.players[0].hero=V2(x:-6,y:-4)
        owner.withPlayer(1){owner.beginVehicle(.tank);owner.foes=[Foe(id:9400,p:owner.hero+V2(x:1,y:0),hp:100,speed:0,gait:0)];owner.endVehicle()};owner.resolveDefeatedFoes()
        expect(owner.players[0].score==0 && owner.players[1].score==ScoreRules.ordinaryKill && owner.players[0].bodyShield==nil && owner.players[1].bodyShield != nil,"player-two pulse credit and short shield remain personal")
        let herd=game(17);herd.bulls=[Bull(id:9401,p:herd.hero,direction:V2(x:1,y:0),golden:true)];herd.beginVehicle(.tank);herd.endVehicle()
        expect(herd.bulls.count==1 && herd.pickups.isEmpty && herd.score==0,"generic exit damage does not invent projectile-type golden-cow explosion loot")
        let prison=game(9,4);prison.withPlayer(0){prison.beginVehicle(.helicopter)};prison.withPlayer(1){prison.beginVehicle(.tank)};prison.withPlayer(2){prison.beginVehicle(.helicopter)}
        prison.cleanupSourceRoundVehicles()
        expect(prison.players[0].vehicle==nil && prison.players[2].vehicle==nil && prison.players[1].vehicle?.kind == .tank && prison.effects.filter{$0.color==8}.count==2,"prison completion emits one pulse per actual aborted Hind and retains the tank")
        expect(prison.players[0].bodyShield != nil && prison.players[2].bodyShield != nil && prison.players[1].bodyShield==nil,"only the two ended prison pilots receive short shields")
        let keep=game();keep.beginBodyShield();keep.stepTeamRecovery(1);let remaining=keep.playerRoster.current.bodyShield!.remaining;keep.beginVehicle(.tank);keep.endVehicle()
        expect(near(keep.playerRoster.current.bodyShield!.remaining,remaining),"own overlap policy preserves a longer existing respawn shield")
        let pause=game();pause.beginVehicle(.tank);pause.vehicle!.remaining=0.01;pause.step(0,input:Controls(pause:true));pause.step(100,input:Controls())
        expect(pause.vehicle != nil && pause.effects.isEmpty && pause.playerRoster.current.bodyShield==nil,"pause cannot expire a vehicle or generate a hidden pulse")
        print("\(passed) vehicle exit checks passed;archived10k/200unit pulse and3.05s shield,own health projection/geometry/ties,dog base estimated,no engine or hardware acceptance")
    }
}
