import Foundation
@main struct PlayerChecks {
 static func main(){
  setbuf(stdout,nil);var passed=0
  func expect(_ value:Bool,_ message:String){guard value else{fatalError(message)};passed+=1;print("PASS \(message)")}
  let g=GameCore();g.reset(playerCount:2)
  expect(g.players.count==2 && g.players.map(\.slot)==[0,1] && g.activePlayerSlot==0,"two personal states share one selected simulation owner")
  expect(g.pickups.isEmpty && g.sourceLoot?.clock==0 && g.combatSpawnFlow?.waves.groups.count==7 && g.round==1,"new roster starts one arena and one global source director without invented initial loot")
  let owner=g.hero
  g.withPlayer(1){g.hero=V2(x:3,y:2);g.heroElevation=1.6;g.facing=V2(x:1,y:0);g.apply(.ray);g.dashes=7;g.bombs=4;g.score=199999;g.multiplier=4;g.multiplierCharge=0.75}
  expect(g.hero==owner && g.heroElevation==0 && g.weapon==nil && g.dashes==2 && g.bombs==1 && g.score==0,"moving arming and scoring player two cannot change player one")
  expect(g.players[1].hero==V2(x:3,y:2) && g.players[1].weapon == .ray && g.players[1].multiplier==4 && g.players[1].multiplierCharge==0.75,"player two retains personal height weapon position and multiplier")
  g.withPlayer(1){g.award(1)};g.advanceDirectedRewards(1.3);g.collectDirectedRewards()
  expect(g.players[1].lives==4 && g.players[1].nextLifeAt==400000 && g.players[0].lives==3 && g.players[0].nextLifeAt==200000,"crossing a personal score threshold grants only that player's life")
  g.apply(.life)
  expect(g.players.map(\.lives)==[4,5] && g.players.map(\.collectedLives)==[1,2],"a soldier-statue pickup grants one life to every team member exactly once")
  g.withPlayer(1){g.apply(.life)}
  expect(g.players.map(\.lives)==[5,6] && g.activePlayerSlot==0,"team life grant restores the caller's selection even when player two collects it")
  g.players[0].lives=9;g.players[1].lives=8;g.apply(.life)
  expect(g.players.map(\.lives)==[9,9],"team life caps are applied individually without blocking another member's gain")
  g.withPlayer(1){
   expect(g.activePlayerSlot==1,"scoped operation selects its actor")
   g.withPlayer(0){g.bombs=6;expect(g.activePlayerSlot==0,"nested operation can select another actor")}
   expect(g.activePlayerSlot==1 && g.bombs==4,"nested operation restores the outer actor and personal inventory")
  }
  expect(g.activePlayerSlot==0 && g.bombs==6,"outer operation restores player one")
  enum Failure:Error {case intended}
  do{try g.withPlayer(1){throw Failure.intended}}catch{}
  expect(g.activePlayerSlot==0,"throwing operations restore the prior actor")
  var invalidRan=false
  let missing:Void?=g.withPlayer(9){invalidRan=true};let negative:Void?=g.withPlayer(-1){invalidRan=true}
  expect(missing==nil && negative==nil && !invalidRan && g.activePlayerSlot==0,"stale invalid actor slots cannot run an operation or corrupt selection")
  g.withPlayer(1){g.apply(.chicken);g.apply(.orb);g.apply(.barrelShield);g.apply(.monkey);g.apply(.turret)}
  expect(g.chickens.isEmpty && g.orbShields.isEmpty && g.shieldBarrels.isEmpty && g.monkeys.isEmpty && g.sentries.isEmpty,"player two's helper arrays never appear as player one's inventory")
  expect(g.players[1].chickens.count==1 && g.players[1].orbShields.count==4 && g.players[1].shieldBarrels.count==2 && g.players[1].monkeys.count==1 && g.players[1].sentries.count==1,"all five actual helper grant paths populate the selected owner's state")
  g.withPlayer(1){g.chickens[0].shotClock=1.25;g.sentries[0].remaining=12;g.hero.x=4}
  expect(g.players[1].chickens[0].shotClock==1.25 && g.players[1].sentries[0].remaining==12 && g.players[1].hero.x==4,"in-place array and vector edits write through to the retained actor")
  g.withPlayer(1){g.apply(.tank)}
  expect(g.vehicle==nil && g.players[1].vehicle?.kind == .tank,"vehicle ownership is independent of the shared arena")
  g.withPlayer(1){g.vehicle=nil;g.fate = .friendship;g.restoreFateBenefits()}
  expect(g.fate==nil && g.players[1].fate == .friendship && g.players[1].chickens.contains{$0.permanent},"fate and permanent helpers belong to one player")
  g.godMode=true;g.withPlayer(1){g.invulnerable=0;g.loseLife()}
  expect(g.trainingHits==0 && g.players[1].trainingHits==1 && g.usedGodMode,"Godmode hit accounting is personal while the run-wide assisted marker is shared")
  let nav=g.players[0].navigation,other=g.players[1].navigation,prior=g.players[0]
  expect(nav !== other && g.players[0].teddyNavigation[0] !== g.players[1].teddyNavigation[0],"players do not overwrite each other's pursuit and helper navigation caches")
  var ids=[Int]()
  for player in g.players {
   ids.append(contentsOf:player.chickens.map(\.id));ids.append(contentsOf:player.orbShields.map(\.id))
   ids.append(contentsOf:player.shieldBarrels.map(\.id));ids.append(contentsOf:player.monkeys.map(\.id));ids.append(contentsOf:player.sentries.map(\.id))
  }
  expect(ids.count==Set(ids).count,"one world ID allocator keeps different owned helper classes globally unique")
  g.reset()
  expect(g.players.count==2 && g.players[0] === prior && g.players[0].navigation === nav && g.players[1].navigation === other,"new attempts keep the chosen roster and reusable navigation caches")
  expect(g.players.allSatisfy{$0.lives==3 && $0.score==0 && $0.weapon==nil && $0.vehicle==nil && $0.chickens.isEmpty && $0.orbShields.isEmpty && $0.monkeys.isEmpty && $0.sentries.isEmpty && $0.fate==nil && $0.trainingHits==0},"new attempts clear every player's prior equipment score fate and virtual losses")
  g.reset(playerCount:99);expect(g.players.count==4 && g.players.map(\.slot)==[0,1,2,3],"roster is bounded to four stable player slots")
  g.reset(playerCount:0);expect(g.players.count==1 && g.activePlayerSlot==0 && g.hero == .zero,"roster cannot become empty and single-player starting position remains unchanged")
  g.godMode=false;g.reset();g.apply(.life);expect(g.lives==4 && g.collectedLives==1,"single-player life pickup retains the previous grant behavior")
  func battle()->GameCore {
   let c=GameCore();c.reset(playerCount:2);c.hero=V2(x:-4,y:-4);c.invulnerable=999;c.pickups=[];c.foes=[];c.combatSpawningHeld=true
   c.withPlayer(1){c.hero = .zero;c.heroElevation=0;c.invulnerable=999}
   return c
  }
  let shot=battle();shot.foes=[Foe(id:99001,p:V2(x:1,y:0),hp:1,speed:0,gait:0)]
  shot.withPlayer(1){shot.fireUsing(nil,from:shot.hero,direction:V2(x:1,y:0))}
  expect(shot.shots.count==1 && shot.shots[0].ownerSlot==1 && shot.elapsed==0,"player-two firing creates one owned projectile in the shared world without advancing world time")
  shot.step(0.05,input:Controls())
  expect(shot.players[0].score==0 && shot.players[1].score==100 && shot.foes.isEmpty,"actual projectile defeat credits the shooter even when the world step is selected on player one")
  expect(shot.activePlayerSlot==0 && shot.elapsed==0.05,"owned projectile processing restores selection and advances the one world clock only once")
  let final=battle();final.foes=[Foe(id:99002,p:V2(x:1,y:0),hp:2,speed:0,gait:0)]
  final.withPlayer(1){final.fireUsing(nil,from:final.hero,direction:V2(x:1,y:0))};final.step(0.05,input:Controls())
  expect(final.foes.count==1 && final.foes[0].creditSlot==1 && final.foes[0].hp==1,"a nonlethal player-two hit records ownership without prematurely awarding points")
  final.fireUsing(nil,from:final.hero,direction:(final.foes[0].p-final.hero).unit);final.step(0.2,input:Controls())
  expect(final.players[0].score==100 && final.players[1].score==0,"a later lethal hit replaces earlier damage ownership")
  let blast=battle();blast.players[1].multiplier=3;blast.foes=[Foe(id:99003,p:V2(x:1,y:0),hp:2,speed:0,gait:0)]
  blast.withPlayer(1){blast.weaponExplosion(at:V2(x:1,y:0),height:0.53,radius:2,damage:10)};blast.resolveDefeatedFoes()
  expect(blast.players[1].score==300 && blast.players[0].score==0,"explosions use their owner's personal multiplier")
  let flame=battle();flame.foes=[Foe(id:99004,p:V2(x:1,y:0),hp:1,speed:0,gait:0)]
  flame.foes[0].referenceVitality=ReferenceVitality.foe(.zombie,round:1,mini:false,localMaximum:10)
  flame.withPlayer(1){flame.fireFlame(from:.zero,direction:V2(x:1,y:0),height:0.53,damage:0.1)}
  flame.stepBurning(0.4);flame.resolveDefeatedFoes()
  expect(flame.players[1].score==100 && flame.players[0].score==0,"later burn damage remains attributed to the original flame owner")
  let tankShot=battle();tankShot.withPlayer(1){tankShot.apply(.tank);tankShot.fireVehicleWeapons(0.01,firing:true)}
  expect(!tankShot.shots.isEmpty && tankShot.shots.allSatisfy{$0.ownerSlot==1},"tank cannon projectiles retain vehicle ownership")
  let hind=battle();hind.withPlayer(1){hind.apply(.helicopter);hind.fireVehicleWeapons(0.01,firing:true)}
  expect(hind.shots.count>=2 && hind.shots.allSatisfy{$0.ownerSlot==1},"both helicopter cannons and missiles retain the pilot's ownership")
  let turret=battle();turret.withPlayer(1){var sentry=SentryTurret(id:99005,p:.zero,elevation:0);turret.fireSentry(&sentry,0.01,at:V2(x:2,y:0))}
  expect(!turret.shots.isEmpty && turret.shots.allSatisfy{$0.ownerSlot==1},"independent sentry bullets retain the helper owner's slot")
  let bomb=battle();bomb.foes=[Foe(id:99006,p:V2(x:3,y:0),hp:1,speed:0,gait:0,creditSlot:1)]
  bomb.step(0.01,input:Controls(bomb:true));expect(bomb.players[0].score==100 && bomb.players[1].score==0,"the bomb's lethal action supersedes prior damage credit")
  let boss=battle();boss.round=40;boss.fixtureSilverbacks();boss.silverbacks[0].hp=1;boss.players[1].multiplier=2
  boss.withPlayer(1){boss.damageSilverback(5,id:boss.silverbacks[0].id)};boss.stepSilverback(0)
  expect(boss.players[1].score==60000 && boss.players[0].score==0 && boss.silverbacks[0].deathAwarded,"boss reward goes exactly once to the lethal attacker with that player's multiplier")
  boss.stepSilverback(0);expect(boss.players[1].score==60000,"subsequent boss frames cannot repeat the personal boss reward")
  print("\(passed) player-state checks passed;foundation only,no playable cooperative loop/controllers/revival claim")
 }
}
