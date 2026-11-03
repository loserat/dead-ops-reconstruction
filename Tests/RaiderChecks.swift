import Foundation
@main struct RaiderChecks {
 static func main(){
  setbuf(stdout,nil)
  var passed=0
  func expect(_ condition:Bool,_ message:String){if !condition {print("FAIL \(message)");exit(1)};passed+=1;print("PASS \(message)")}
  func fixture(_ round:Int=5)->GameCore {let c=GameCore();c.reset();c.round=round;c.beginRound();c.phase = .cleared;c.finishCombatSpawning();c.foes=[];c.pickups=[];c.clearClock=0.8;c.nextRaidRound=round;c.hero=c.layout.clamped(V2(x:8,y:-4));c.invulnerable=999;return c}
  let noVisit=fixture();noVisit.phase = .playing;noVisit.addLoot(at:.zero,kind:.treasure);noVisit.beginTreasureRaid();expect(noVisit.treasureRaider==nil,"treasure visitor cannot interrupt an unfinished combat wave")
  let early=fixture(4);early.nextRaidRound=5;early.addLoot(at:.zero,kind:.treasure);early.beginTreasureRaid();expect(early.treasureRaider==nil && !early.raiderVisited,"visits wait for their scheduled round rather than appearing on every cleared wave")
  let visit=fixture();visit.seedClearedTreasure();visit.beginTreasureRaid();let visitID=visit.treasureRaider!.id,scheduled=visit.nextRaidRound
  expect(visit.treasureRaider!.arrival != nil && !visit.layout.contains(visit.treasureRaider!.p) && !visit.treasureRaider!.hostile,"visitor begins outside the arena with an active approach and is harmless before its roar")
  visit.beginTreasureRaid();expect(visit.raidsSeen==1 && visit.treasureRaider!.id==visitID && scheduled==visit.nextRaidRound,"one cleared round cannot duplicate a raid or repeatedly reschedule it")
  expect((4...6).contains(scheduled-visit.round),"visits recur around five rounds using an explicit provisional four-to-six-round gap")
  let noLoot=fixture();noLoot.pickups=[Pickup(id:99001,p:.zero,kind:.life)];noLoot.beginTreasureRaid();expect(noLoot.treasureRaider==nil && noLoot.raiderVisited && noLoot.nextRaidRound>5,"an empty treasure phase skips the visitor once without stealing a life pickup")
  let boss=fixture(40);boss.seedClearedTreasure();boss.beginTreasureRaid();expect(boss.treasureRaider==nil,"boss rounds cannot also spawn an invincible treasure visitor")
  let safe=fixture();safe.seedClearedTreasure();safe.beginTreasureRaid();safe.treasureRaider!.p=safe.hero;safe.treasureRaider!.arrival=nil;safe.treasureRaider!.motion = .roaring;safe.invulnerable=0;safe.score=12345;safe.multiplier=5;safe.multiplierCharge=0.4
  safe.stepTreasureRaider(0)
  expect(safe.players[0].isDown && safe.players[0].respawnRemaining==2,"visitor contact schedules the funded return before spending a reserve");safe.stepTeamRecovery(2)
  expect(safe.deaths==1 && safe.lives==2 && safe.phase == .cleared && safe.score==12345 && safe.multiplier==1 && safe.treasureRaider != nil,"post-roar contact in the collection phase uses real life loss and multiplier reset without restarting the cleared wave")
  safe.stepTreasureRaider(0);expect(safe.deaths==1,"ordinary respawn protection prevents one overlapping visitor from consuming several lives immediately")
  let god=fixture();god.seedClearedTreasure();god.beginTreasureRaid();god.treasureRaider!.p=god.hero;god.treasureRaider!.arrival=nil;god.treasureRaider!.motion = .roaring;god.godMode=true;god.invulnerable=0;god.multiplier=5;god.weapon = .ray;god.weaponReserve=17;let godPosition=god.hero;god.stepTreasureRaider(0)
  expect(god.trainingHits==1 && god.deaths==0 && god.lives==3 && god.hero==godPosition && god.weapon == .ray && god.weaponReserve==17 && god.multiplier==5,"Godmode counts a lethal visitor contact as one virtual life while retaining position and gear")
  let last=fixture();last.seedClearedTreasure();last.beginTreasureRaid();last.treasureRaider!.p=last.hero;last.treasureRaider!.arrival=nil;last.treasureRaider!.motion = .roaring;last.lives=0;last.invulnerable=0;last.stepTreasureRaider(0);expect(last.phase == .gameOver && last.lives==0,"a hostile visitor can end a run after the combat wave has been cleared")
  let tank=fixture();tank.seedClearedTreasure();tank.beginTreasureRaid();tank.apply(.tank);tank.treasureRaider!.p=tank.hero;tank.treasureRaider!.motion = .roaring;tank.treasureRaider!.arrival=nil;tank.invulnerable=0;tank.stepTreasureRaider(0);expect(tank.lives==3 && tank.deaths==0,"an active vehicle retains its normal protection from visitor contact")
  let height=fixture(9);height.seedClearedTreasure();height.beginTreasureRaid();height.treasureRaider!.arrival=nil;height.treasureRaider!.motion = .roaring;height.hero=V2(x:0,y:6.2);height.heroElevation=1.6;height.treasureRaider!.p=height.hero;height.treasureRaider!.elevation=0;height.invulnerable=0;height.stepTreasureRaider(0);expect(height.deaths==0,"visitor contact does not reach a player on a different floor")
  let immune=fixture();immune.seedClearedTreasure();immune.beginTreasureRaid();immune.treasureRaider!.p=V2(x:3,y:-3);immune.treasureRaider!.elevation=0;immune.treasureRaider!.arrival=nil;immune.treasureRaider!.motion = .looting;immune.hero=V2(x:-6,y:-3);let initialLoot=immune.pickups.count
  immune.damageSilverback(999999,id:immune.treasureRaider!.id);immune.damageSilverback(999999);immune.weaponExplosion(at:V2(x:3,y:-3),height:1,radius:3,damage:999999);immune.fireFlame(from:V2(x:0,y:-3),direction:V2(x:1,y:0),height:0.6,damage:999999)
  expect(immune.treasureRaider != nil && immune.silverbacks.isEmpty && immune.score==0 && immune.pickups.count==initialLoot && immune.effects.count>0,"direct hits nukes explosions and flame produce feedback without health damage boss rewards or fabricated loot")
  immune.shots=[Shot(id:99002,p:V2(x:0,y:-3),v:V2(x:40,y:0),ttl:1,damage:99999,kind:nil)];immune.stepWeaponShots(0.2);expect(immune.shots[0].ttl<=0 && immune.treasureRaider != nil,"bullets collide with an invincible visitor instead of passing through its visible body")
  let shooting=fixture();shooting.pickups=[];shooting.nextRaidRound=99;shooting.step(0.05,input:Controls(aim:V2(x:0,y:-1)));expect(!shooting.shots.isEmpty,"player can still shoot during the intermission instead of losing weapon control when a visitor arrives")
  let escaping=fixture();escaping.pickups=[];escaping.nextRaidRound=99;escaping.step(0.01,input:Controls(aim:V2(x:1,y:0),dash:true,bomb:true));expect(escaping.dashes==1 && escaping.bombs==0,"boost and bomb controls remain usable between waves for escape or collection")
  let paused=fixture();paused.seedClearedTreasure();paused.beginTreasureRaid();paused.step(0,input:Controls(pause:true));let pausedP=paused.treasureRaider!.p,pausedTime=paused.treasureRaider!.totalClock;paused.step(10,input:Controls());expect(paused.phase == .paused && paused.treasureRaider!.p==pausedP && paused.treasureRaider!.totalClock==pausedTime,"pause freezes the visitor's approach and theft timer")
  let leaving=fixture();leaving.seedClearedTreasure();leaving.beginTreasureRaid();leaving.prepareArenaExits();leaving.clearClock=4;let path=leaving.availableExits.first(where:{$0.bonus==nil})!;leaving.hero=path.p;leaving.heroElevation=path.height;leaving.step(0.01,input:Controls());expect(leaving.phase == .transition,"a visible visitor cannot lock a real open exit");leaving.step(4.5,input:Controls());expect(leaving.round==6 && leaving.phase == .playing && leaving.treasureRaider==nil,"visitor departure completes through the ordinary masked transition without waiting for theft")
  let room=fixture();room.seedClearedTreasure();room.beginTreasureRaid();room.enterSideRoom(SideRoomOffer(kind:.treasure,p:room.layout.sideRoute(onLeft:true)));let roomLoot=room.pickups.count,oldTheft=room.treasuresStolen;room.step(3,input:Controls());expect(room.phase == .bonusRoom && room.treasureRaider==nil && room.pickups.count>=roomLoot && room.treasuresStolen==oldTheft,"entering a bonus room removes the arena visitor and protects the room from remote theft")
  var allVisits=0,allThefts=0
  for round in stride(from:1,through:37,by:4) {
   let c=fixture(round);c.seedClearedTreasure();c.pickups.append(Pickup(id:99010,p:c.layout.clamped(V2(x:8,y:4)),kind:.life,ttl:300));c.beginTreasureRaid();let originalTreasures=c.pickups.filter{$0.kind == .treasure || $0.kind == .gem}.count
   var largestStep=0.0,invalid=0,roared=false,frames=0
   while c.treasureRaider != nil && frames<3600 {
    let before=c.treasureRaider!.p;c.stepTreasureRaider(1.0/60);frames+=1
    if let r=c.treasureRaider {largestStep=max(largestStep,(r.p-before).length);roared = roared || r.hostile
     if r.arrival==nil && r.departure==nil && !c.layout.walkable(r.p,clearance:0.71) {invalid+=1}
    }
   }
   print("Arena\(round) result:frames=\(frames),position=\(String(describing:c.treasureRaider?.p)),stage=\(String(describing:c.treasureRaider?.motion)),stolen=\(c.treasuresStolen),maxStep=\(largestStep),invalid=\(invalid)")
   expect(c.treasureRaider==nil && roared && c.treasuresStolen>0 && largestStep<0.0801 && invalid==0,"arena\(round): visitor enters continuously,roars,reaches real treasure and leaves through its outside route without jumps or invalid positions")
   expect(c.pickups.contains{$0.id==99010} && c.pickups.count==originalTreasures+1-c.treasuresStolen && c.score==0 && c.multiplier==1 && c.deaths==0,"arena\(round): theft removes only physically reached ground treasure,never powerups or banked points")
   allVisits+=c.raidsSeen;allThefts+=c.treasuresStolen
  }
  let reset=fixture();reset.seedClearedTreasure();reset.beginTreasureRaid();reset.reset();expect(reset.round==1 && reset.treasureRaider==nil && reset.raidsSeen==0 && reset.treasuresStolen==0 && reset.nextRaidRound==5,"new run clears visitor state counters and schedule without carrying invincibility into a boss")
  print("\(passed) raider checks passed;\(allVisits) staged arena visits,\(allThefts) physically stolen treasures,no injected production outcomes")
 }
}
