import Foundation
@main struct CooperativeChecks {
 static func main(){
  setbuf(stdout,nil);var passed=0
  func expect(_ value:Bool,_ message:String){guard value else{fatalError(message)};passed+=1;print("PASS \(message)")}
  func close(_ a:Double,_ b:Double)->Bool {abs(a-b)<0.000001}
  func game(_ count:Int=2)->GameCore {
   let g=GameCore();g.reset(playerCount:count);g.foes=[];g.pickups=[];g.combatSpawningHeld=true
   for p in g.players {p.hero=V2(x:Double(p.slot)*2-4,y:0);p.invulnerable=999}
   return g
  }
  let start=GameCore();start.reset(playerCount:4)
  expect(Set(start.players.map{"\($0.hero.x),\($0.hero.y)"}).count==4 && start.players.allSatisfy{start.layout.walkable($0.hero) && $0.invulnerable==2},"four new players have distinct walkable positions and personal initial protection")
  expect(start.pickups.isEmpty && start.sourceLoot?.clock==0 && start.combatSpawnFlow?.waves.groups.count==7,"a four-player roster starts one arena with shared source timers and no artificial initial loot ring")
  let move=game(4),positions=game(4).players.map(\.hero)
  move.effects=[Effect(id:999,p:.zero,ttl:2,size:1,color:0)];move.pickups=[Pickup(id:998,p:V2(x:8,y:5),kind:.ray,ttl:10)]
  move.step(0.1,inputs:[Controls(move:V2(x:1,y:0)),Controls(move:V2(x:-1,y:0)),Controls(move:V2(x:0,y:1)),Controls()])
  expect(close(move.players[0].hero.x,positions[0].x+0.64) && close(move.players[1].hero.x,positions[1].x-0.64) && close(move.players[2].hero.y,0.64) && move.players[3].hero==positions[3],"one shared frame applies four independent movement snapshots")
  expect(close(move.elapsed,0.1) && close(move.roundClock,0.1) && close(move.combatSpawnFlow!.waves.clock,0) && close(move.effects[0].ttl,1.9) && close(move.pickups[0].ttl,9.9),"four actors advance world clocks, effects and pickup lifetime exactly once")
  expect(move.activePlayerSlot==0,"a shared frame leaves the original actor selection intact")
  let missing=game(4),idle=missing.players.map(\.hero);missing.step(0.1,inputs:[Controls(move:V2(x:0,y:1))])
  expect(missing.players[0].hero != idle[0] && (1..<4).allSatisfy{missing.players[$0].hero==idle[$0]},"missing controller slots are neutral and cannot reuse another player's input")
  missing.step(0.1,inputs:[Controls(),Controls(),Controls(),Controls(),Controls(bomb:true,pause:true)])
  expect(missing.phase == .playing && missing.players.allSatisfy{$0.bombs==1},"unconfigured extra input slots cannot pause the run or spend supplies")
  let solo=GameCore(),team=GameCore();solo.reset();team.reset(playerCount:4)
  solo.pickups=[];team.pickups=[];solo.step(1.3,input:Controls());team.step(1.3,inputs:[])
  expect(solo.spawnRemaining==team.spawnRemaining && team.combatSpawnFlow!.waves.totals.attempts==solo.combatSpawnFlow!.waves.totals.attempts && team.foes.count==solo.foes.count && team.foes.count>0 && solo.foes[0].id==team.foes[0].id && solo.foes[0].p==team.foes[0].p && solo.foes[0].hp==team.foes[0].hp,"the spawn director creates one batch with the same world random stream, independent of roster size")
  let guns=game();guns.players[0].hero=V2(x:-4,y:0);guns.players[1].hero=V2(x:4,y:0)
  guns.foes=[Foe(id:90001,p:V2(x:-3,y:0),hp:1,speed:0,gait:0),Foe(id:90002,p:V2(x:3,y:0),hp:1,speed:0,gait:0)]
  guns.step(0.05,inputs:[Controls(aim:V2(x:1,y:0)),Controls(aim:V2(x:-1,y:0))])
  expect(guns.players.map(\.score)==[100,100] && guns.foes.isEmpty,"both players fire and receive their own lethal projectile points in the same real frame")
  expect(Set(guns.shots.map(\.ownerSlot))==Set([0,1]) && guns.shots.allSatisfy{close($0.ttl,1.15)},"surviving projectiles retain each shooter and age only once")
  let power=game();power.forEachPlayer{power.apply(.ray);power.apply(.orb);power.apply(.tank)}
  power.step(0.5,inputs:[])
  expect(power.players.allSatisfy{close($0.vehicle!.remaining,19.5) && close($0.orbRemaining,39.5) && $0.weaponReserve==50},"both vehicle and helper clocks run once while vehicle stowage preserves each gun reserve")
  let paused=game();paused.step(1,inputs:[Controls(),Controls(bomb:true,pause:true)])
  expect(paused.phase == .paused && paused.elapsed==0 && paused.players.allSatisfy{$0.bombs==1},"a teammate's pause takes precedence over all gameplay actions")
  paused.step(90,inputs:[]);paused.step(0,inputs:[Controls(),Controls(accept:true)])
  expect(paused.phase == .playing && paused.elapsed==0,"either configured player can resume without advancing frozen time")
  paused.step(1,inputs:[Controls(),Controls(systemPause:true)])
  expect(paused.phase == .paused && paused.elapsed==0,"system pause from any configured input freezes the shared world")
  let invalid=game(),old=invalid.players.map(\.hero)
  for dt in [-1.0,.nan,.infinity] {invalid.step(dt,inputs:[Controls(move:V2(x:1,y:0))])}
  expect(invalid.elapsed==0 && invalid.players.map(\.hero)==old,"invalid time deltas cannot advance or corrupt any player")
  let down=game(4);for p in down.players {p.lives=0};down.players[0].invulnerable=0;down.loseLife()
  let corpse=down.hero;down.pickups=[Pickup(id:90003,p:corpse,kind:.ray)];down.players[0].reviveRemaining=10
  down.step(0.1,inputs:[Controls(move:V2(x:1,y:0),aim:V2(x:1,y:0),dash:true,bomb:true),Controls(move:V2(x:0,y:1))])
  expect(down.players[0].hero==corpse && down.players[0].bombs==1 && down.players[0].dashes==2 && down.players[0].weapon==nil && down.shots.isEmpty && down.pickups.count==1,"a waiting player cannot move, fire, spend equipment or collect ground loot")
  expect(close(down.players[0].reviveRemaining,9.9) && close(down.elapsed,0.1) && down.players[1].hero.y>0,"the living team continues while the four-player recovery clock advances only once")
  down.players[0].reviveRemaining=0.05;down.step(0.1,inputs:[])
  expect(!down.players[0].isDown && down.players[0].lives==0 && close(down.players[0].bodyShield?.remaining ?? -1,RecoveryRules.fullShield-0.05),"the real shared frame restores an expired waiting body and advances its new shield for the remaining50ms")
  let near=game();near.players[0].hero=V2(x:-7,y:0);near.players[1].hero=V2(x:7,y:0)
  near.foes=[Foe(id:90004,p:V2(x:3,y:0),hp:9,speed:1,gait:0)];near.step(0.1,inputs:[])
  expect(near.foes[0].p.x>3 && close(near.foes[0].gait,0.3),"an enemy pursues the nearest living teammate and moves only once")
  near.players[1].isDown=true;near.players[1].lives=0;near.players[1].reviveRemaining=99;near.players[0].lives=0;near.players[1].donationCooldown=99
  expect(near.targetSlot(near:V2(x:6,y:0))==0,"AI target selection excludes a closer waiting body")
  let magnet=game();magnet.players[0].hero=V2(x:-7,y:0);magnet.players[1].hero=V2(x:4,y:0)
  magnet.apply(.helicopter);magnet.players[1].invulnerable=0
  magnet.foes=[Foe(id:90005,p:V2(x:4,y:0),hp:9,speed:0,gait:0)]
  magnet.step(0,inputs:[])
  expect(magnet.helicopterMagnet==0 && magnet.players[1].deaths==0 && magnet.targetSlot(near:V2(x:4,y:0),magnet:true)==0,"the highest-ranked active Hind pilot attracts ordinary zombies and shields teammates from their body contact")
  magnet.foes=[Foe(id:90006,p:magnet.players[1].hero,hp:9,speed:0,gait:0,kind:.hound)];magnet.step(0,inputs:[])
  expect(magnet.players[1].dogWounds==1 && magnet.teamPursuit(0).target==magnet.players[1].hero,"hounds retain nearest-player pursuit and still wound a helicopter-protected teammate")
  let lower=game();lower.withPlayer(1){lower.apply(.helicopter)}
  expect(lower.helicopterMagnet==nil,"a lower-ranked pilot cannot replace a higher-ranked living player's original role")
  let yellow=game(4);for slot in 0..<3 {yellow.players[slot].isDown=true;yellow.players[slot].reviveRemaining=999}
  yellow.withPlayer(3){yellow.apply(.helicopter)}
  expect(yellow.helicopterMagnet==nil,"the fourth original role does not become a helicopter magnet")
  let monkey=game();monkey.players[0].isDown=true;monkey.players[0].lives=0;monkey.players[0].reviveRemaining=999;monkey.players[0].donationCooldown=999;monkey.players[1].hero=V2(x:8,y:0)
  monkey.withPlayer(0){monkey.addMonkey(at:V2(x:4,y:0))};monkey.foes=[Foe(id:90007,p:V2(x:3,y:0),hp:9,speed:1,gait:0)]
  monkey.step(0.1,inputs:[])
  expect(monkey.teamPursuit(0).target==V2(x:4,y:0) && close(monkey.players[0].monkeys[0].remaining,7.9),"a deployed monkey remains active and attracts enemies after its owner is down")
  let teddy=game();teddy.withPlayer(1){teddy.apply(.teddy)}
  teddy.foes=[Foe(id:90008,p:V2(x:3,y:0),hp:9,speed:2,gait:0,kind:.crawler)];teddy.step(0.1,inputs:[])
  expect(teddy.foes[0].p==V2(x:3,y:0) && close(teddy.players[1].teddyRemaining,19.9),"a teammate's teddy freezes eligible enemies without duplicating its timer")
  let barrel=game();barrel.players[0].hero=V2(x:3,y:2);barrel.players[1].hero=V2(x:4,y:2)
  for p in barrel.players {p.invulnerable=0;p.lives=1}
  barrel.barrels=[FlamingBarrel(id:90009,p:V2(x:3.5,y:2),v:.zero,elevation:0)];barrel.withPlayer(1){barrel.detonateBarrels([90009])};barrel.resolveBarrelDamage()
  barrel.stepTeamRecovery(2);expect(barrel.players.allSatisfy{$0.lives==0 && $0.deaths==1 && !$0.isDown} && barrel.activePlayerSlot==0,"one barrel blast damages every exposed player once while retaining the attacker's selection scope")
  let martyr=game();martyr.players[0].hero=V2(x:3,y:2);martyr.players[1].hero=V2(x:4,y:2)
  for p in martyr.players {p.invulnerable=0;p.lives=1}
  martyr.foes=[Foe(id:90010,p:V2(x:4,y:3),hp:9,speed:0,gait:0)]
  martyr.withPlayer(1){martyr.detonateMartyr(Foe(id:90011,p:V2(x:3.5,y:2),hp:0,speed:0,gait:0,kind:.martyr))};martyr.resolveMartyrDamage();martyr.resolveDefeatedFoes()
  expect(martyr.players.allSatisfy{$0.deaths==1} && martyr.players[1].score==100 && martyr.players[0].score==0,"martyr blast exposure is shared while chained enemy points retain their attacker")
  let bull=game();bull.round=17;bull.players[0].hero=V2(x:-1,y:0);bull.players[1].hero=V2(x:1,y:0);bull.bullClock=999
  for p in bull.players {p.invulnerable=0;p.lives=1}
  bull.bulls=[Bull(id:90012,p:V2(x:-3,y:0),direction:V2(x:1,y:0),speed:10)];bull.step(0.6,inputs:[])
  expect(bull.players.allSatisfy{$0.deaths==1} && close(bull.bulls[0].p.x,3),"one bull sweep hits both exposed players while the bull moves once")
  let flames=game();flames.forEachPlayer{flames.fireFlame(from:flames.hero,direction:V2(x:0,y:1),height:0.53,damage:0.1)}
  flames.players[0].invulnerable=0;flames.loseLife()
  expect(flames.flameJets.count==1 && flames.flameJets[0].ownerSlot==1,"one player's death cannot erase a teammate's flame visuals")
  flames.apply(.tank);expect(flames.flameJets.count==1 && flames.flameJets[0].ownerSlot==1,"one vehicle pickup cannot clear another player's flame visuals")
  let bosses=game();bosses.round=80;bosses.players[0].hero=V2(x:-8,y:0);bosses.players[1].hero=V2(x:8,y:0)
  bosses.silverbackStarted=true;bosses.silverbacks=[Silverback(id:90013,p:V2(x:-4,y:0)),Silverback(id:90014,p:V2(x:4,y:0))]
  bosses.step(0.1,inputs:[])
  expect(bosses.silverbacks[0].p.x < -4 && bosses.silverbacks[1].p.x>4 && bosses.silverbacks.allSatisfy{close($0.clock,0.1)},"two independent bosses pursue different nearby players and each advance once")
  let visitor=game();visitor.phase = .cleared;visitor.players[0].hero=V2(x:-7,y:0);visitor.players[1].hero=V2(x:4,y:0);visitor.players[1].invulnerable=0
  visitor.treasureRaider=TreasureRaider(id:90015,entrance:0,p:visitor.players[1].hero,elevation:0,arrival:nil,motion:.roaring)
  visitor.step(0.1,inputs:[])
  expect(visitor.players[1].deaths==1 && visitor.players[0].deaths==0 && close(visitor.treasureRaider!.clock,0.1),"one intermission visitor update can harm player two without duplicating its world clock")
  let loot=game();loot.players[0].hero = .zero;loot.players[1].hero = .zero;loot.pickups=[Pickup(id:90016,p:.zero,kind:.treasure)]
  loot.step(0,inputs:[])
  expect(loot.pickups.isEmpty && loot.players.map(\.score)==[125,0],"simultaneous proximity resolves one ground item once in stable slot order")
  let exit=game();exit.round=4;exit.phase = .cleared;exit.clearClock=4;exit.prepareArenaExits();exit.players[1].hero=exit.suggestedExit
  exit.step(0.1,inputs:[])
  expect(exit.phase == .transition && exit.round==4,"player two starts one hidden map transition through the ready teleporter")
  exit.step(2.7,inputs:[])
  expect(exit.round==5 && exit.phase == .playing && exit.combatSpawnFlow?.waves.groups.count==11 && exit.players.allSatisfy{exit.layout.walkable($0.hero) && $0.invulnerable>0},"masked transition repositions the entire team safely before controls resume")
  let room=game();room.phase = .cleared;room.enterSideRoom(SideRoomOffer(kind:.treasure,p:.zero));room.pickups=[]
  let roomStart=room.players.map(\.hero);room.step(0.1,inputs:[Controls(move:V2(x:1,y:0)),Controls(move:V2(x:-1,y:0))])
  expect(room.players[0].hero.x>roomStart[0].x && room.players[1].hero.x<roomStart[1].x && close(room.sideRoom!.clock,0.1) && close(room.elapsed,0.1),"safe-room movement serves both actors while room and run time advance once")
  let fate=game();fate.round=14;fate.phase = .cleared;fate.players[1].isDown=true;fate.players[1].lives=0;fate.players[1].reviveRemaining=3;fate.players[1].donationCooldown=999
  fate.enterFateRoom();fate.pickups=[];fate.hero=fate.fateRoom!.door(for:.firepower).p
  expect(fate.players[1].isDown,"entering the Room of Fate preserves a waiting player's original exception")
  fate.step(1.6,inputs:[])
  expect(fate.fate==nil && fate.phase == .bonusRoom && fate.round==14 && close(fate.players[1].reviveRemaining,1.4),"an early exit visitor waits for the falling Fate while the other player's recovery clock runs")
  fate.step(1.4,inputs:[]);expect(!fate.players[1].isDown && fate.players[1].fate==nil,"a waiting teammate can recover inside the Room of Fate before selecting a personal power")
  fate.players[1].hero=fate.fateRoom!.door(for:.friendship).p
  fate.sideRoom!.clock=FateRoomTiming.firstArrow;fate.step(0,inputs:[])
  fate.sideRoom!.clock=FateRoomTiming.firstArrow+FateRoomTiming.fall;fate.step(0,inputs:[])
  fate.sideRoom!.clock=FateRoomTiming.firstArrow+FateRoomTiming.settle+FateRoomTiming.farewell+0.01;fate.step(0,inputs:[])
  fate.step(2.7,inputs:[])
  expect(fate.round==15 && fate.phase == .playing && fate.players[0].fate == .firepower && fate.players[1].fate == .friendship && fate.players[1].chickens.contains{$0.permanent},"the final personal Fate choice advances the team exactly once and retains each permanent benefit")
  var invalidPoses=0,poses=0
  for arena in 0..<10 {
   let g=game(4);g.godMode=true;g.round=arena*4+1;g.beginRound();g.pickups=[];g.combatSpawningHeld=false
   for p in g.players {p.hero=g.teamPosition(g.layout.spawn,slot:p.slot);p.heroElevation=g.layout.height(p.hero)}
   for frame in 0..<120 {
    let controls=g.players.map{p in Controls(move:V2(x:cos(Double(frame)*0.03+Double(p.slot)),y:sin(Double(frame)*0.03+Double(p.slot))),aim:V2(x:sin(Double(frame)*0.05+Double(p.slot)),y:cos(Double(frame)*0.05+Double(p.slot))))}
    g.step(1.0/60,inputs:controls)
    for p in g.players {poses+=1;if !p.hero.x.isFinite || !p.hero.y.isFinite || !g.layout.walkable(p.hero,clearance:0.24){invalidPoses+=1}}
   }
   expect(close(g.elapsed,2) && g.activePlayerSlot==0 && g.players.count==4,"ten-arena four-player integration retains one world clock and a stable roster")
  }
  expect(invalidPoses==0 && poses==4800,"4800 real four-player poses across ten arenas remain finite and walkable")
  print("\(passed) shared cooperative simulation checks passed;controller/render/lobby and physical play acceptance remain separate")
 }
}
