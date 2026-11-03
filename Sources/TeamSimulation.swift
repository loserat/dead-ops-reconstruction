import Foundation

/// One shared world step, with scoped personal actions. Input capture and rendering remain separate.
extension GameCore {
    func controls(for slot:Int,in inputs:[Controls])->Controls {inputs.indices.contains(slot) ? inputs[slot]:Controls()}
    func systemControls(_ inputs:[Controls])->Controls {
        var result=Controls()
        for c in inputs.prefix(playerCount) {
            result.pause = result.pause || c.pause;result.systemPause = result.systemPause || c.systemPause
            result.accept = result.accept || c.accept;result.back = result.back || c.back
        }
        return result
    }
    func forEachPlayer(_ operation:()->Void) {
        for slot in players.indices {withPlayer(slot,operation)}
    }
    func forEachLivingPlayer(_ operation:()->Void) {
        for player in players where !player.isDown {
            if phase == .gameOver {break}
            withPlayer(player.slot,operation)
        }
    }
    func teamPosition(_ base:V2,slot:Int)->V2 {
        if slot==0 {return base}
        let offsets=[V2.zero,V2(x:1.15,y:0),V2(x:-1.15,y:0),V2(x:0,y:1.15)]
        return layout.clamped(base+offsets[max(0,min(3,slot))],clearance:0.4)
    }
    // Original rank belongs to a stable player role, independent of cosmetic color choice.
    var helicopterMagnet:Int? {
        guard let first=players.first(where:{!$0.isDown}),first.slot<3,
              first.vehicle?.kind == .helicopter else{return nil}
        return first.slot
    }
    var ordinaryContactAllowed:Bool {helicopterMagnet.map{$0==activePlayerSlot} ?? true}
    func targetSlot(near point:V2,height:Double=0,magnet:Bool=false)->Int {
        if magnet,let slot=helicopterMagnet {return slot}
        return players.filter{!$0.isDown}.min {
            let a=hypot(($0.hero-point).length,$0.heroElevation-height),b=hypot(($1.hero-point).length,$1.heroElevation-height)
            return a==b ? $0.slot<$1.slot:a<b
        }?.slot ?? 0
    }
    func teamTeddyFreezes(_ foe:Foe)->Bool {
        players.contains{!$0.isDown && $0.teddyRemaining>0} && foe.kind != .zombie && foe.kind != .villager
    }
    func teamPursuit(_ index:Int)->(target:V2,direction:V2,waiting:Bool) {
        if playerCount==1 {return supportPursuit(index)}
        let foe=foes[index]
        let slot=targetSlot(near:foe.p,height:foe.elevation,magnet:foe.kind != .hound)
        let teddies=players.filter{!$0.isDown && $0.teddyRemaining>0}
        if let teddy=teddies.filter({foe.retreatEntrance != nil || ($0.hero-foe.p).length<3.8})
            .min(by:{($0.hero-foe.p).length<($1.hero-foe.p).length}) {
            return withPlayer(teddy.slot){supportPursuit(index)}!
        }
        foes[index].retreatEntrance=nil
        let player=players[slot],distance=hypot((player.hero-foe.p).length,player.heroElevation-foe.elevation)
        let decoy=players.flatMap(\.monkeys).filter{!$0.stowed && hypot(($0.p-foe.p).length,$0.elevation-foe.elevation)<distance}
            .min(by:{hypot(($0.p-foe.p).length,$0.elevation-foe.elevation)<hypot(($1.p-foe.p).length,$1.elevation-foe.elevation)})
        if let m=decoy {return (m.p,m.navigation.direction(from:foe.p,to:m.p,layout:layout),(m.p-foe.p).length<0.4)}
        return (player.hero,player.navigation.direction(from:foe.p,to:player.hero,layout:layout),false)
    }
    func tryTeamExit()->Bool {
        guard bossVictory==nil else{return false}
        for player in players where !player.isDown {
            if let exit=availableExits.first(where:{(player.hero-$0.p).length<0.85 && (player.vehicle?.kind == .helicopter || abs(player.heroElevation-$0.height)<0.65)}) {
                withPlayer(player.slot){requestArenaExit(exit)};return arenaTransit != nil || bossVictory != nil
            }
        }
        return false
    }
    func moveCombatPlayer(_ dt:Double,input:Controls) {
        var updatedElevation=false
        if input.aim.length>0.18 { facing=input.aim.unit }
        if dt>0,input.dash,dashes>0,dashTime<=0,weaponsEnabled,vehicle==nil {
            emitAudio(.boost);dashes-=1;dashTime=CombatRules.boostDuration
            playerRoster.current.boostDirection=facing.unit
        }
        if vehicle != nil {moveVehicle(dt,move:input.move);dashTime=0}
        else if dashTime>0 {moveBoost(dt);updatedElevation=true}
        else if playerRoster.current.shieldContactThisStep || playerRoster.current.bodyShield?.contactActive==true {moveShieldedFoot(dt,move:input.move);updatedElevation=true}
        else {hero=layout.moved(hero,by:input.move.unit*(dt*moveSpeed*min(1,input.move.length)))}
        if !updatedElevation {updateHeroElevation(dt)}
        if input.bomb, bombs>0, weaponsEnabled {
            emitAudio(.explosion);bombs-=1;damageSilverback(120);for bull in bulls {explodeBulls(at:bull.p,radius:1.5)};detonateBarrels(Set(barrels.map(\.id)),canDamageHero:false);let removed=foes;foes=[];for f in removed{var defeated=f;defeated.creditSlot=activePlayerSlot;kill(defeated,drops:false,canDamageHero:false)}
            effects.append(Effect(id:id(),p:hero,ttl:0.65,size:24,color:2))
        }
    }
    func fireCombatPlayer(_ dt:Double,input:Controls) {
        updateCompanions(dt)
        let firing=input.aim.length>0.18
        shotClock-=dt
        if vehicle != nil {if weaponsEnabled {fireVehicleWeapons(dt,firing:firing)};shotClock=0}
        else if firing && weaponsEnabled {
            var count=0
            while shotClock<=0 && count<64 {fire(from:hero,direction:facing);shotClock+=fireInterval;count+=1}
        }else{shotClock=max(0,shotClock)}
        fireChickens(playerFiring:firing)
        if weapon != nil && vehicle==nil {weaponReserve-=dt*(firing ? 5:1);if weaponReserve<=0{weapon=nil}}
    }
    func stepCombatFoes(_ dt:Double) {
        for i in foes.indices {
            if teamTeddyFreezes(foes[i]) {continue}
            if advanceFoeArrival(i,dt) {continue}
            let pursuit=teamPursuit(i)
            var direction=pursuit.direction
            for j in foes.indices where i != j {
                let diff=foes[i].p-foes[j].p;let d=diff.length
                if d>0.01 && d<0.52 { direction=direction+diff.unit*((0.52-d)*2.3) }
            }
            var speed=foes[i].speed
            if foes[i].kind == .hound {speed=6.5}
            if foes[i].kind == .martyr {speed=2.6}
            if foes[i].kind == .sasquatch {speed=3.1}
            if foes[i].kind == .engineer {
                if foes[i].elevation>layout.height(foes[i].p)+0.15 {speed=0}
                else {speed=foes[i].enraged ? 5.7:0.75}
            }
            if foes[i].kind == .crawler {
                let previous=foes[i].behaviorClock.truncatingRemainder(dividingBy:2.6)
                foes[i].behaviorClock+=dt
                let t=foes[i].behaviorClock.truncatingRemainder(dividingBy:2.6)
                if t<0.7 {speed=0}
                else if t<1.05 {
                    if previous<0.7 {foes[i].lungeDirection=(pursuit.target-foes[i].p).unit}
                    direction=foes[i].lungeDirection;speed=6.8
                }else{speed*=0.65}
            }
            // Own locomotion maps the archived gas moveplaybackrate to its local root motion.
            if foes[i].flameAfterburn != nil {speed*=FlameAfterburn.playbackRate}
            if pursuit.waiting {speed=0}
            foes[i].p=layout.moved(foes[i].p,by:direction.unit*(speed*dt),clearance:0.29);foes[i].gait+=dt*speed*3;updateFoeElevation(i,dt)
        }
        forEachLivingPlayer {
            resolveBoostContacts(from:hero,to:hero,oldHeight:heroElevation,endHeight:heroElevation)
            resolveBodyShieldContacts()
        }
    }
}
