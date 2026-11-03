import Foundation

extension GameCore {
    func bounceRay(_ shot:inout Shot,at p:V2,normal:V2,incoming:V2) {
        let n=normal.length>0.001 ? normal.unit:incoming.unit*(-1)
        shot.v=incoming-n*(2*(incoming.x*n.x+incoming.y*n.y));shot.p=p+n*0.06
        shot.bounces+=1;if shot.bounces>8 {shot.ttl=0}
    }
    func stepWeaponShots(_ dt:Double) {
        for i in shots.indices {
          let owner=players.indices.contains(shots[i].ownerSlot) ? shots[i].ownerSlot:0
          withPlayer(owner) {
            var shot=shots[i]
            let start=shot.p,startHeight=shot.height,incoming=shot.v
            let end=start+incoming*dt
            shot.p=end;shot.ttl-=dt
            if shot.kind == .grenade {shot.height+=shot.verticalSpeed*dt-6*dt*dt;shot.verticalSpeed-=12*dt}
            if let target=shot.targetHeight {shot.height=max(target,shot.height+shot.verticalSpeed*dt)}
            let endHeight=shot.height
            var wallPoint:V2?,wallNormal=V2.zero,wallHeight=endHeight
            let steps=max(1,Int(ceil((end-start).length/0.10)))
            for sample in 1...steps {
                let fraction=Double(sample)/Double(steps),q=start+(end-start)*fraction,h=startHeight+(endHeight-startHeight)*fraction
                let terrain=layout.height(q)
                if terrain>h+0.05 || (shot.kind == .grenade && h<=terrain+0.12) {
                    wallPoint=start+(end-start)*(Double(sample-1)/Double(steps));wallHeight=max(terrain+0.15,h)
                    wallNormal=V2(x:layout.height(q+V2(x:0.15,y:0))-layout.height(q-V2(x:0.15,y:0)),y:layout.height(q+V2(x:0,y:0.15))-layout.height(q-V2(x:0,y:0.15))).unit
                    break
                }
                if let obstacle=layout.obstacles.first(where:{$0.contains(q,clearance:0.025) && h >= $0.elevation && h <= $0.elevation+$0.height}) {
                    wallPoint=start+(end-start)*(Double(sample-1)/Double(steps));wallHeight=h
                    wallNormal=(obstacle.pushed(q,clearance:0.06)-q).unit;break
                }
                if shot.kind == .ray && !inside(q,margin:0) {
                    wallPoint=start+(end-start)*(Double(sample-1)/Double(steps));wallNormal=abs(q.x)>10 ? V2(x:q.x>0 ? -1:1,y:0):V2(x:0,y:q.y>0 ? -1:1);break
                }
            }
            var hitEnd=wallPoint ?? end
            let bullImpact=bullHit(from:start,to:hitEnd,height:shot.height)
            if let p=bullImpact {hitEnd=p}
            let barrelImpact=barrelHit(from:start,to:hitEnd,height:shot.height)
            if let b=barrelImpact {hitEnd=b.p}
            let bossImpact=silverbackImpact(from:start,to:hitEnd,height:shot.height)
            if let hit=bossImpact {hitEnd=hit.p}
            let line=hitEnd-start,denom=max(0.000001,line.x*line.x+line.y*line.y)
            let contacts=foes.indices.compactMap{j -> (Int,Double)? in
                guard foes[j].hp>0,!shot.hitIDs.contains(foes[j].id) else{return nil}
                let rel=foes[j].p-start,t=max(0,min(1,(rel.x*line.x+rel.y*line.y)/denom))
                let total=max(0.00001,(end-start).length),time=(line*t).length/total,h=startHeight+(endHeight-startHeight)*time
                guard h>=foes[j].elevation+0.1,h<=foes[j].elevation+foes[j].hitHeight,(foes[j].p-(start+line*t)).length<foes[j].hitRadius else{return nil}
                return (j,t)
            }.sorted{$0.1<$1.1}
            var consumed=false,reflected=false
            for (j,t) in contacts where foes[j].hp>0 {
                let p=start+line*t
                shot.hitIDs.insert(foes[j].id)
                if shot.kind == .grenade {
                    weaponExplosion(at:p,height:max(layout.height(p)+0.2,shot.height),radius:2.5,damage:shot.damage)
                    shot.p=p;shot.ttl=0;consumed=true;break
                }
                foes[j].hp-=shot.damage*(foes[j].kind == .engineer && !foes[j].enraged ? 0.15:1);if shot.damage>0 {foes[j].creditSlot=activePlayerSlot}
                if foes[j].kind == .engineer {foes[j].enraged=true}
                if shot.kind == .rocket {
                    weaponExplosion(at:foes[j].p,height:shot.height,radius:2,damage:shot.explosionDamage)
                    if !shot.piercing {shot.p=p;shot.ttl=0;consumed=true;break}
                    // Rockets continue through a line of bodies; hit IDs prevent repeated direct hits.
                }else if shot.kind == .ray {
                    bounceRay(&shot,at:p,normal:p-foes[j].p,incoming:incoming);reflected=true;break
                }else {shot.p=p;shot.ttl=0;consumed=true;break}
            }
            if !consumed && !reflected {
                if let boss=bossImpact {
                    let p=boss.p
                    if shot.kind == .rocket || shot.kind == .grenade {weaponExplosion(at:p,height:shot.height,radius:shot.kind == .grenade ? 2.5:2,damage:shot.kind == .grenade ? shot.damage:shot.explosionDamage)}
                    else{damageSilverback(shot.damage,id:boss.id)}
                    shot.p=p;shot.ttl=0
                }else if let b=barrelImpact {
                    if shot.kind == .grenade || shot.kind == .rocket {weaponExplosion(at:b.p,height:shot.height,radius:2.5,damage:shot.damage)}
                    detonateBarrels([b.id]);shot.p=b.p;shot.ttl=0
                }else if let p=bullImpact {
                    if shot.kind == .rocket || shot.kind == .grenade {weaponExplosion(at:p,height:shot.height,radius:2,damage:shot.explosionDamage)}
                    shot.p=p;shot.ttl=0
                }else if let p=wallPoint {
                    if shot.kind == .ray {bounceRay(&shot,at:p,normal:wallNormal,incoming:incoming)}
                    else {
                        if shot.kind == .grenade || shot.kind == .rocket {weaponExplosion(at:p,height:wallHeight,radius:shot.kind == .grenade ? 2.5:2,damage:shot.kind == .grenade ? shot.damage:shot.explosionDamage)}
                        shot.p=p;shot.ttl=0
                    }
                }else if shot.kind == .grenade && shot.ttl<=0 {weaponExplosion(at:shot.p,height:max(layout.height(shot.p)+0.15,shot.height),radius:2.5,damage:shot.damage)}
            }
            shots[i]=shot
          }
        }
    }
}
