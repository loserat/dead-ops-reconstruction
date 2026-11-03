import Foundation
@main struct EndingChecks {
 static func main(){
  setbuf(stdout,nil);var passed=0
  func expect(_ ok:Bool,_ message:String){guard ok else{print("FAIL \(message)");exit(1)};passed+=1;print("PASS \(message)")}
  func fixture()->GameCore {let g=GameCore();g.reset();g.foes=[];g.pickups=[];g.combatSpawningHeld=true;g.invulnerable=0;return g}
  var clip=GameOverSequence();clip.step(-1,input:Controls());clip.step(.nan,input:Controls());clip.step(.infinity,input:Controls())
  expect(clip.clock==0 && !clip.finished,"invalid elapsed times cannot advance the ending")
  clip.step(1.2,input:Controls());expect(clip.landing==0 && clip.visitorHeight==9 && clip.heroFlight==0,"visitor begins above the pedestal after the opening treasure moment")
  clip.step(0.6,input:Controls());expect(abs(clip.landing-0.5)<0.00001 && abs(clip.visitorHeight-4.5)<0.00001,"the visitor descends continuously rather than popping into the scene")
  clip.step(0.6,input:Controls());expect(abs(clip.visitorHeight)<0.00001 && clip.heroFlight==0,"the visitor lands before the player is struck")
  clip.step(1.3,input:Controls());expect(clip.strike==1 && clip.heroFlight>0 && clip.gathering>0,"the strike sends the player away before treasure gathering")
  clip.step(1.7,input:Controls());expect(clip.gathering==1 && clip.departure>0 && clip.visitorHeight>0 && clip.heroFlight==1,"the visitor takes the gathered treasure when departing")
  clip.step(999,input:Controls());expect(clip.finished && clip.clock==6.4 && clip.departure==1,"the ending reaches one stable terminal pose without replaying")
  var small=GameOverSequence(),large=GameOverSequence();for _ in 0..<240 {small.step(1.0/60,input:Controls())};large.step(4,input:Controls())
  expect(abs(small.clock-large.clock)<0.00001 && abs(small.heroFlight-large.heroFlight)<0.00001,"animation progress depends on elapsed time rather than render frame count")
  var pause=GameOverSequence();pause.step(2,input:Controls());pause.step(1,input:Controls(systemPause:true));pause.step(30,input:Controls())
  expect(pause.clock==2 && pause.suspended,"focus loss suspends the ending and cannot silently finish it")
  pause.step(1,input:Controls(accept:true));expect(!pause.suspended && pause.clock==2,"the first confirmation resumes a suspended ending without skipping or restarting")
  pause.step(1,input:Controls(accept:true));expect(pause.finished,"a second deliberate confirmation can skip the ending")
  for input in [Controls(accept:true),Controls(pause:true),Controls(back:true)] {var x=GameOverSequence();x.step(0,input:input);expect(x.finished,"confirm pause and back each offer a direct skip")}
  let last=fixture();last.lives=0;last.score=345678;last.round=17;last.apply(.ray);last.pickups=[];last.loseLife()
  let elapsed=last.elapsed,deathCount=last.deaths
  expect(last.phase == .gameOver && last.gameOverSequence != nil && last.lives==0 && deathCount==1,"actual loss of the final life starts the ending exactly once")
  let oldClock=last.gameOverSequence!.clock;last.loseLife();expect(last.gameOverSequence!.clock==oldClock && last.deaths==deathCount,"further hazard calls cannot repeat the final life loss")
  last.step(6.4,input:Controls(move:V2(x:1,y:1),aim:V2(x:1,y:0),dash:true,bomb:true))
  expect(last.gameOverSequence!.finished && last.phase == .gameOver && last.score==345678 && last.round==17 && last.elapsed==elapsed && last.deaths==deathCount,"ending movement and combat inputs never spend score or alter the ended run")
  last.step(0,input:Controls(accept:true));expect(last.phase == .playing && last.gameOverSequence==nil && last.score==0 && last.lives==3 && last.round==1,"new attempt clears the ending and restores the genuine starting state")
  let skip=fixture();skip.lives=0;skip.loseLife();skip.step(0,input:Controls(accept:true));expect(skip.phase == .gameOver && skip.gameOverSequence!.finished && skip.lives==0,"skip shows results without also starting a new run on the same press")
  let normal=fixture();normal.loseLife();expect(normal.players[0].isDown && normal.players[0].respawnRemaining==2,"funded solo death remains pending before its ending check");normal.stepTeamRecovery(2);expect(normal.lives==2 && normal.gameOverSequence==nil && normal.phase == .playing,"an ordinary life loss does not trigger the final ending")
  let god=fixture();god.godMode=true;god.lives=1;god.loseLife();expect(god.phase == .playing && god.gameOverSequence==nil && god.trainingHits==1,"Godmode virtual losses never start the actual Game Over ending")
  let vehicle=fixture();vehicle.apply(.tank);vehicle.invulnerable=0;vehicle.loseLife();expect(vehicle.lives==3 && vehicle.gameOverSequence==nil,"vehicle protection cannot accidentally trigger an ending")
  expect(!PickupPersistence.eligible(.treasure) && !PickupPersistence.eligible(.gem) && WeaponProfile.pickups.allSatisfy(PickupPersistence.eligible) && PickupPersistence.eligible(.helicopter),"only equipment and supplies receive rare ground persistence, not ordinary treasure")
  expect(PickupPersistence.selected(roll:0) && !PickupPersistence.selected(roll:1.0/128) && !PickupPersistence.selected(roll:-1) && !PickupPersistence.selected(roll:.nan),"rare-drop selection excludes invalid rolls and its upper boundary")
  let drops=fixture();drops.pickups=[Pickup(id:10,p:V2(x:5,y:0),kind:.ray,ttl:0.1,persistent:true),Pickup(id:11,p:V2(x:5,y:1),kind:.rocket,ttl:0.1),Pickup(id:12,p:V2(x:5,y:2),kind:.bomb,ttl:10)]
  drops.stepPickupLifetimes(1);expect(drops.pickups.map(\.id)==[10,12] && drops.pickups[0].ttl==0.1 && drops.pickups[1].ttl==9,"only normal expired drops disappear; persistent equipment retains its ground lifetime")
  drops.stepPickupLifetimes(100000);expect(drops.pickups.count==1 && drops.pickups[0].id==10,"the persistent drop remains after a long uncollected combat wait")
  let before=drops.pickups;drops.stepPickupLifetimes(.nan);drops.stepPickupLifetimes(-1);expect(drops.pickups.count==before.count && drops.pickups[0].ttl==before[0].ttl,"invalid lifetime updates cannot destroy or extend a fund")
  let still=drops.pickups[0],rotating=Pickup(id:20,p:.zero,kind:.ray)
  expect(PickupPersistence.rotation(still,clock:1)==PickupPersistence.rotation(still,clock:500) && PickupPersistence.rotation(rotating,clock:1) != PickupPersistence.rotation(rotating,clock:500),"persistent funds keep a fixed orientation while ordinary funds rotate")
  drops.hero=still.p;drops.collectNearbyPickups();expect(drops.pickups.isEmpty && drops.weapon == .ray && drops.weaponReserve==50,"collecting a persistent gun removes it and grants the ordinary finite weapon reserve")
  let tank=fixture();tank.hero = .zero;tank.pickups=[Pickup(id:30,p:.zero,kind:.tank,persistent:true)];tank.collectNearbyPickups();expect(tank.pickups.isEmpty && tank.vehicle?.kind == .tank && tank.vehicle?.remaining==20,"persistent ground tank still has the standard finite driving time")
  let death=fixture();death.pickups=[Pickup(id:40,p:V2(x:5,y:0),kind:.bomb,persistent:true)];death.loseLife();expect(death.pickups.count==1 && death.pickups[0].persistent,"ordinary respawn does not remove a waiting persistent supply")
  death.phase = .cleared;death.startNextCombatRound();expect(!death.pickups.contains{$0.id==40},"persistent means until collection in this arena, not transfer into another world")
  let paused=fixture();paused.pickups=[Pickup(id:50,p:V2(x:5,y:0),kind:.ray,ttl:2,persistent:true)];paused.step(0,input:Controls(pause:true));paused.step(100,input:Controls());expect(paused.pickups[0].ttl==2 && paused.phase == .paused,"pause freezes all pickup lifetimes")
  let actual=fixture();let director=actual.sourceLoot!
  for i in 0..<10000 {actual.kill(Foe(id:i,p:V2(x:5,y:0),hp:0,speed:0,gait:0));actual.effects=[]}
  expect(actual.pickups.isEmpty && director.clock==0 && director.bag.draws==0,"ten thousand defeats cannot fabricate equipment or consume the independent source bag/timer")
  let noDrop=fixture();for i in 0..<100 {noDrop.kill(Foe(id:i,p:.zero,hp:0,speed:0,gait:0),drops:false)};expect(noDrop.pickups.isEmpty,"bomb/no-drop kills cannot manufacture persistent rewards")
  print("\(passed) ending/persistence checks passed;own rates and scene timing,not original constants or hardware acceptance")
 }
}
