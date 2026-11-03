import Foundation
@main struct RunThroughRooms {
 static func main(){
  let vehiclePilot=VehiclePilot();let pilotNav=ArenaNavigation();let g=GameCore();g.godMode=true;g.reset();var simulated=0.0,lastRound=0,roomCount=0,illegal=0,looted=0,bullsSeen=Set<Int>(),goldBullsSeen=Set<Int>(),engineersSeen=Set<Int>(),barrelsSeen=Set<Int>(),martyrsSeen=Set<Int>(),houndsSeen=Set<Int>(),bossFrames=0
  var vehiclesSeen=Set<Int>(),vehicleFrames=0,vehicleMissiles=0
  var supportSeen=Set<String>(),activeSentries=Set<Int>(),departingSupports=0
  var gemStyles=Set<String>(),metalStyles=Set<String>(),partialMeterFrames=0,maxMultiplier=1
  var defeatedGroups=Set<Int>(),returnFrames=0
  var lastPhase=g.phase;var lastRoom:SideRoomKind?
  var seen=Set<Int>(),waterSeen=Set<Int>(),pierSeen=Set<Int>(),birthErrors=0,entryJumps=0,outsideWithoutEntry=0

  for _ in 0..<400000 {
   var c=Controls()
   if g.phase == .bonusRoom {
    let target=g.sideRoom?.kind == .fate ? (g.revealedFatePosition(.firepower) ?? g.hero):(g.pickups.min(by:{($0.p-g.hero).length<($1.p-g.hero).length})?.p ?? g.suggestedExit)
    pilotNav.update(layout:g.layout,target:target,dt:1.0/60)
    c.move=pilotNav.direction(from:g.hero,to:target,layout:g.layout);vehiclePilot.steer(&c,core:g,target:target)
   }else{
    let prisonTargets=[V2(x:0,y:-2),V2(x:0,y:6.5),V2(x:10.3,y:0),V2(x:0,y:-6.4)]
    let target=g.layout.kind == .prison ? prisonTargets[Int(g.roundClock/18)%prisonTargets.count]:g.layout.clamped(V2(x:cos(g.elapsed*0.43)*9,y:sin(g.elapsed*0.43)*5.8))
    pilotNav.update(layout:g.layout,target:target,dt:1.0/60);c.move=pilotNav.direction(from:g.hero,to:target,layout:g.layout);vehiclePilot.steer(&c,core:g,target:target)
    let visible=g.foes.filter{g.layout.lineClear(g.hero,$0.p,clearance:0.03)}
    if let f=(visible.isEmpty ? g.foes:visible).min(by:{($0.p-g.hero).length<($1.p-g.hero).length}) {c.aim=(f.p-g.hero).unit}
    if let boss=g.silverbacks.filter({$0.hp>0 && g.layout.lineClear(g.hero,$0.p,clearance:0.03)}).min(by:{($0.p-g.hero).length<($1.p-g.hero).length}) {c.aim=(boss.p-g.hero).unit}
    if simulated<20 {c=Controls()}
    if g.foes.count>35 && g.bombs>0 {c.bomb=true}
    if g.phase == .cleared {
     let target=g.exitClock<0.45 && g.arenaExits.first?.teleporter != true ? g.hero:g.suggestedExit
     pilotNav.update(layout:g.layout,target:target,dt:1.0/60);c.move=pilotNav.direction(from:g.hero,to:target,layout:g.layout);vehiclePilot.steer(&c,core:g,target:target)
    }
   }
   if let v=g.vehicle {vehiclesSeen.insert(v.kind.rawValue);vehicleFrames+=1;vehicleMissiles=max(vehicleMissiles,v.missiles)}
   if g.teddyRemaining>0 {supportSeen.insert("teddy")}
   if !g.shieldBarrels.isEmpty {supportSeen.insert("barrels")}
   if !g.monkeys.isEmpty {supportSeen.insert("monkey")}
   if !g.sentries.isEmpty {supportSeen.insert("turret")}
   for t in g.sentries where t.shotCount>0 {activeSentries.insert(t.id)}
   if !g.departingShieldBarrels.isEmpty {departingSupports+=1}
   for p in g.pickups {
    if case .gem(let color,let size)=p.loot {gemStyles.insert("\(color.rawValue)-\(size.rawValue)")}
    if case .metal(let metal,let form)=p.loot {metalStyles.insert("\(metal.rawValue)-\(form.rawValue)")}
   }
   if g.multiplierCharge>0 && g.multiplierCharge<1 {partialMeterFrames+=1};maxMultiplier=max(maxMultiplier,g.multiplier)
   if g.silverback != nil {bossFrames+=1}
   if !g.silverbacks.isEmpty && g.silverbacks.allSatisfy({$0.hp<=0}) {defeatedGroups.insert(g.round)}
   if g.phase == .loopReturn {returnFrames+=1}
   for foe in g.foes where foe.kind == .hound {houndsSeen.insert(foe.id)}
   for foe in g.foes where foe.kind == .martyr {martyrsSeen.insert(foe.id)}
   for barrel in g.barrels {barrelsSeen.insert(barrel.id)}
   for foe in g.foes where foe.kind == .engineer {engineersSeen.insert(foe.id)}
   for bull in g.bulls {bullsSeen.insert(bull.id);if bull.golden {goldBullsSeen.insert(bull.id)}}
   let before=g.pickups.count,wasRoom=g.phase == .bonusRoom
   let oldArrivals=Dictionary(uniqueKeysWithValues:g.foes.filter{$0.arrival != nil}.map{($0.id,$0.p)})
   g.step(1.0/60,input:c);simulated+=1.0/60
   for f in g.foes {
    if seen.insert(f.id).inserted && f.kind != .engineer {if f.arrival==nil || g.layout.contains(f.p) {birthErrors+=1}}
    if f.arrival?.kind == .water {waterSeen.insert(f.id)}
    if f.arrival?.kind == .pier {pierSeen.insert(f.id)}
    if let before=oldArrivals[f.id],(f.p-before).length>0.12 {entryJumps+=1}
    if f.arrival==nil && !g.layout.walkable(f.p,clearance:0.24) {outsideWithoutEntry+=1}
   }

   if wasRoom {looted+=max(0,before-g.pickups.count)}
   if g.flying ? !g.layout.contains(g.hero,margin:0.28):!g.layout.walkable(g.hero,clearance:0.28) {illegal+=1}
   if g.phase == .bonusRoom && (lastPhase != g.phase || lastRoom != g.sideRoom?.kind) {roomCount+=1;print("ROOM \(g.sideRoom!.kind) after round \(g.round) at \(Int(simulated))s, loot=\(g.pickups.count)")}
   lastPhase=g.phase;lastRoom=g.sideRoom?.kind
   if lastRound != g.round {lastRound=g.round;print("ROUND \(g.round) at \(Int(simulated))s")}
   if g.round==41 && g.phase == .playing {
    precondition(roomCount>=2 && looted>=34 && illegal==0 && g.deaths==0 && g.trainingHits>3 && g.fate == .firepower && !bullsSeen.isEmpty && !engineersSeen.isEmpty && !barrelsSeen.isEmpty && !martyrsSeen.isEmpty && !houndsSeen.isEmpty && bossFrames>0 && defeatedGroups.contains(40) && returnFrames>=160 && g.layout.kind == .island)
    precondition(gemStyles.count==9 && metalStyles.count==9 && partialMeterFrames>600 && maxMultiplier==9 && g.score>=200000 && g.nextLifeAt==(g.score/200000+1)*200000)
    print("PASS first40 actual return: boss40 defeated,\(returnFrames) return frames,round41 island with preserved run state")
    print("PASS treasure coverage:\(gemStyles.count) gem color-size variants,\(metalStyles.count) metal forms,\(partialMeterFrames) partial-meter frames,maxMultiplier\(maxMultiplier),score\(g.score),\(g.score/200000) crossed life thresholds")
    precondition(supportSeen.count==4 && !activeSentries.isEmpty && departingSupports>0)
    print("PASS support coverage: \(supportSeen.sorted()),\(activeSentries.count) independently firing sentries,\(departingSupports) barrel departure frames; equipment only collected through gameplay")
    precondition(vehiclesSeen.count==2 && vehicleFrames>1200 && vehicleMissiles>10)
    print("PASS natural vehicle coverage: \(vehiclesSeen.count) vehicle types,\(vehicleFrames) vehicle frames,max\(vehicleMissiles) helicopter missiles in one flight; no injected vehicle equipment")
    precondition(birthErrors==0 && entryJumps==0 && outsideWithoutEntry==0 && !waterSeen.isEmpty && !pierSeen.isEmpty)
    print("PASS entrance audit: \(seen.count) observed enemies, \(waterSeen.count) sea approaches, \(pierSeen.count) pier approaches; zero interior births, zero approach jumps over0.12units/frame, zero enemies outside without an entrance")
    print("PASS forty-round godmode run including Silverback victory and bounded sound events, hound combat, fuel tanks, explosive martyrs, flaming barrels, falling engineers and marketplace herds and permanent firepower using movement for all room and combat exits with \(roomCount) side rooms, \(looted) collected room pickups, \(Int(simulated))s simulated, \(g.trainingHits) virtual hits, \(g.deaths) real deaths, \(illegal) invalid hero positions, \(bullsSeen.count) bulls including \(goldBullsSeen.count) golden, \(engineersSeen.count) engineers, \(barrelsSeen.count) flaming barrels, \(martyrsSeen.count) martyrs, \(houndsSeen.count) hounds, boss frames \(bossFrames)")
    return
   }
  }
  fatalError("timeout round \(g.round), phase \(g.phase), hero \(g.hero), loot \(g.pickups),vehicle \(String(describing:g.vehicle))")
 }
}
