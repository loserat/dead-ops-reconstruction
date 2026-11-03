import Foundation

@main struct HoundChecks {
    static func main(){
        setbuf(stdout,nil);var count=0
        func expect(_ value:Bool,_ message:String){precondition(value,message);count+=1;print("PASS \(message)")}
        func close(_ a:Double,_ b:Double)->Bool {abs(a-b)<0.000001}
        func game(_ players:Int=1)->GameCore {
            let g=GameCore();g.reset(playerCount:players);g.round=34;g.beginRound()
            g.foes=[];g.pickups=[];g.combatSpawningHeld=true
            for p in g.players {p.invulnerable=0;p.hero=g.layout.clamped(V2(x:Double(p.slot)*2-4,y:-4));p.heroElevation=g.layout.height(p.hero)}
            return g
        }
        func bite(_ g:GameCore,_ slot:Int=0){g.withPlayer(slot){g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.houndHit()};if g.players.contains(where:{$0.respawnRemaining != nil}){g.stepTeamRecovery(2)}}
        let normal=game();normal.apply(.ray);let position=normal.hero
        bite(normal);bite(normal)
        expect(normal.dogWounds==2 && normal.deaths==0 && normal.lives==3 && normal.hero==position && normal.weapon == .ray,"two bites retain the living body and equipment")
        expect(normal.houndWoundText=="HUND 2/3","wound text reports accumulated bites and the lethal threshold")
        normal.houndHit();expect(normal.dogWounds==2 && normal.deaths==0,"one contact frame cannot bypass the existing protection window")
        bite(normal)
        expect(normal.dogWounds==0 && normal.deaths==1 && normal.lives==2 && normal.players[0].dogRecoveryClock==0,"the third bite follows the actual death and reset path")
        for slot in 0..<4 {for fate in [FateKind?.none,.friendship,.fortitude,.feet,.firepower] {
            let g=game(4);g.players[slot].fate=fate
            g.withPlayer(slot){expect(g.houndLethalBites==(slot==1 && fate == .friendship ? 4:3),"bite resistance follows the stable original role and fate")}
        }}
        let blue=game(2);blue.players[1].fate = .friendship
        for _ in 0..<3 {bite(blue,1)}
        expect(blue.players[1].dogWounds==3 && blue.players[1].lives==3 && blue.players[1].deaths==0,"the second original role with Friendship survives three bites")
        bite(blue,1)
        expect(blue.players[1].deaths==1 && blue.players[1].lives==2 && blue.players[0].deaths==0,"that role's fourth bite kills only its owner")
        expect(blue.players[1].fate == .friendship && blue.players[1].chickens.contains{$0.permanent},"hound death restores the permanent personal fate helper")
        let heal=game();bite(heal);bite(heal)
        let interval=HoundRules.recoverySecondsPerBite
        heal.stepHoundRecovery(interval-0.1)
        expect(heal.dogWounds==2 && close(heal.players[0].dogRecoveryClock,interval-0.1),"recovery keeps its partial progress before the configured interval")
        heal.stepHoundRecovery(0.1)
        expect(heal.dogWounds==1 && close(heal.players[0].dogRecoveryClock,0),"recovery removes one bite at a time")
        heal.stepHoundRecovery(interval*3)
        expect(heal.dogWounds==0 && heal.players[0].dogRecoveryClock==0 && heal.lives==3 && heal.deaths==0,"complete healing creates neither lives nor a future healing credit")
        bite(heal);heal.stepHoundRecovery(interval/2);bite(heal)
        expect(heal.dogWounds==2 && heal.players[0].dogRecoveryClock==0,"a fresh bite restarts the recovery interval")
        let carry=game();carry.deaths=1;bite(carry);carry.stepHoundRecovery(1000)
        expect(carry.dogWounds==1 && carry.players[0].dogRecoveryClock==0 && !carry.houndRecoveryEnabled,"a previously killed actor does not gain the no-death recovery exception")
        carry.round=35;carry.beginRound();carry.stepHoundRecovery(1000)
        expect(carry.dogWounds==1,"ordinary wounds persist across round changes")
        carry.phase = .cleared;carry.enterSideRoom(SideRoomOffer(kind:.treasure,p:carry.layout.sideRoute(onLeft:true)));carry.stepSideRoom(12,inputs:[])
        expect(carry.dogWounds==1,"a safe room does not erase an ordinary persistent wound")
        let rooms=game();bite(rooms);rooms.phase = .cleared
        rooms.enterSideRoom(SideRoomOffer(kind:.treasure,p:rooms.layout.sideRoute(onLeft:true)))
        rooms.stepSideRoom(interval/2,inputs:[])
        expect(rooms.dogWounds==1 && close(rooms.players[0].dogRecoveryClock,interval/2),"eligible healing advances once inside a safe room")
        rooms.step(0,inputs:[Controls(pause:true)]);rooms.step(interval*2,inputs:[])
        expect(rooms.phase == .paused && rooms.dogWounds==1 && close(rooms.players[0].dogRecoveryClock,interval/2),"pause freezes the actual safe-room recovery clock")
        rooms.step(0,inputs:[Controls(accept:true)]);rooms.stepSideRoom(interval/2,inputs:[])
        expect(rooms.dogWounds==0,"resuming a safe room continues the saved recovery progress")
        let shared=game(4);for slot in 0..<4 {bite(shared,slot)}
        shared.players[2].deaths=1;shared.players[3].isDown=true;shared.players[3].lives=0;shared.players[3].reviveRemaining=90;shared.players[3].donationCooldown=90
        for p in shared.players {p.lives=0}
        shared.step(0.1,inputs:[])
        expect(close(shared.players[0].dogRecoveryClock,0.1) && close(shared.players[1].dogRecoveryClock,0.1),"each eligible actor heals once per shared world frame")
        expect(shared.players[2].dogWounds==1 && shared.players[2].dogRecoveryClock==0 && shared.players[3].dogRecoveryClock==0,"dead-history and waiting actors cannot borrow another actor's healing")
        let frozen=shared.players[0].dogRecoveryClock;shared.step(0,inputs:[Controls(systemPause:true)]);shared.step(interval,inputs:[])
        expect(close(shared.players[0].dogRecoveryClock,frozen),"the shared pause path also freezes healing")
        let armor=game();armor.deaths=1;bite(armor)
        armor.players[0].dogRecoveryClock=2;armor.apply(.tank)
        expect(armor.dogWounds==1 && armor.players[0].dogRecoveryClock==2,"entering armor no longer silently erases existing bite damage")
        bite(armor);expect(armor.dogWounds==1,"armor still rejects new bites")
        armor.endVehicle();armor.stepTeamRecovery(RecoveryRules.shortShield);armor.invulnerable=0;armor.loseLife()
        expect(armor.dogWounds==0 && armor.players[0].dogRecoveryClock==0,"another lethal damage source clears wounds and recovery progress")
        let training=game();training.godMode=true;let trainingPosition=training.hero
        for _ in 0..<3 {bite(training)}
        expect(training.trainingHits==1 && training.lives==3 && training.deaths==0 && training.hero==trainingPosition && training.dogWounds==0,"Godmode counts one virtual life at the same lethal bite without real death")
        bite(training);training.stepHoundRecovery(interval*5)
        expect(!training.houndRecoveryEnabled && training.dogWounds==1,"a virtual death ends the no-death recovery benefit consistently")
        let invalid=game();bite(invalid);invalid.stepHoundRecovery(.nan);invalid.stepHoundRecovery(.infinity);invalid.stepHoundRecovery(-1)
        expect(invalid.dogWounds==1 && invalid.players[0].dogRecoveryClock==0,"invalid elapsed times cannot heal or poison the clock")
        invalid.reset(playerCount:4)
        expect(invalid.players.allSatisfy{$0.dogWounds==0 && $0.dogRecoveryClock==0},"a new team attempt clears every bite and partial healing clock")
        let before=game();before.round=33;bite(before);before.stepHoundRecovery(interval*3)
        expect(before.dogWounds==1 && !before.houndRecoveryEnabled,"the no-death exception does not activate before round34")
        print("\(count) hound checks passed;three/four-bite source model,personal recovery and damage lifecycle;healing interval provisional,not hardware or exact original timing acceptance")
    }
}
