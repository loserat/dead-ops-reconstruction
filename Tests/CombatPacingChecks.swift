import Foundation
@main struct CombatPacingChecks {
 static func main(){
  setbuf(stdout,nil);var passed=0
  func expect(_ ok:Bool,_ why:String){if !ok{print("FAIL \(why)");exit(1)};passed+=1;print("PASS \(why)")}
  func fixture(_ round:Int=1,_ count:Int=1)->GameCore {
   let g=GameCore();g.reset(playerCount:count);g.round=round;g.beginRound();g.foes=[];g.pickups=[];g.combatSpawningHeld=true
   for p in g.players{p.hero=V2(x:-6,y:0);p.heroElevation=g.layout.height(p.hero);p.invulnerable=0;p.dashes=5}
   return g
  }
  for (round,limit) in [(1,32),(8,32),(9,20),(10,32),(13,20),(17,20),(22,20),(25,32),(30,28),(34,10),(35,32),(40,32),(49,32),(74,32),(81,32)] {
   let g=fixture(round);g.combatSpawningHeld=false;g.combatSpawnFlow!.nextMini=nil
   g.combatSpawnFlow!.waves=try! TimedAttackWaves(round:round,random:{0})
   g.foes=(0..<limit).map{i in g.arrivingFoe(kind:.zombie,hp:2,speed:2,entrance:i%g.layout.enemyEntranceCount,lane:0)}
   let ids=g.foes.map(\.id),budget=g.spawnRemaining
   g.stepCombatSpawns(2)
   expect(g.activeAIEnemies==limit && g.foes.map(\.id)==ids && g.spawnRemaining<budget && g.combatSpawnFlow!.waves.totals.rejected>0,"round\(round) ceiling\(limit) includes outer approaches and consumes failed timed attempts")
   g.foes.removeFirst();g.stepCombatSpawns(0.001)
   expect(g.activeAIEnemies==limit-1,"round\(round) cannot refill between actual source deadlines")
   g.stepCombatSpawns(g.spawnClock)
   let admitted=g.foes.last!,physicalArrival=(admitted.arrival != nil && !g.layout.contains(admitted.p)) || (admitted.kind == .engineer && admitted.elevation>5)
   expect(g.activeAIEnemies==limit && physicalArrival,"round\(round) admits one physical body at the next future deadline without replaying failures")
  }

  let boss=fixture(80);boss.fixtureSilverbacks();boss.foes=(0..<29).map{i in Foe(id:200+i,p:.zero,hp:1,speed:0,gait:0)};_=boss.admitWaveEnemy(side:.north,kind:.hound)
  expect(boss.activeAIEnemies==32,"boss reinforcement uses the shared32-AI limit including two real brothers")
  boss.foes=Array(boss.foes.prefix(27));boss.silverbacks += (0..<4).map{i in var b=Silverback();b.id=900+i;return b};_=boss.admitWaveEnemy(side:.north,kind:.hound)
  expect(boss.activeAIEnemies==33 && boss.foes.count==27,"injected over-limit fixture never receives extra boss adds")
  let a=fixture();a.step(0.3,input:Controls(aim:V2(x:1,y:0),dash:true))
  expect(abs(a.hero.x)<1e-8 && abs(a.dashTime-0.3)<1e-8 && a.dashes==4,"boost travels six own units in its first300ms and consumes one reserve")
  a.step(0.3,input:Controls(aim:V2(x:0,y:1),dash:true))
  expect(abs(a.hero.x-6)<1e-8 && abs(a.hero.y)<1e-8 && a.dashTime==0 && a.dashes==4 && a.facing.y==1,"600ms boost retains its launch velocity while aim turns and repeated activation is ignored")
  let small=fixture();for i in 0..<36{small.step(1.0/60,input:Controls(aim:V2(x:1,y:0),dash:i==0))}
  expect((small.hero-a.hero).length<1e-8 && small.dashTime==0,"one600ms step and36 small steps agree on unobstructed boost displacement")
  let remaining=fixture();remaining.dashTime=0.01;remaining.players[0].boostDirection=V2(x:1,y:0);remaining.step(0.05,input:Controls())
  expect(abs(remaining.hero.x+5.8)<1e-8,"last partial boost step moves for10ms rather than overshooting for the entire frame")
  expect(!remaining.acceptsPlayerDamage,"last boost movement remains protected through its world collision pass")
  remaining.step(0.001,input:Controls());expect(remaining.acceptsPlayerDamage,"boost protection ends at the next ordinary collision pass")
  let swept=fixture();swept.foes=[Foe(id:99,p:V2(x:-3,y:0),hp:100,speed:0,gait:0),Foe(id:100,p:V2(x:-3,y:0),hp:100,speed:0,gait:0,elevation:2)]
  swept.step(0.3,input:Controls(aim:V2(x:1,y:0),dash:true))
  expect(!swept.foes.contains{$0.id==99} && swept.foes.contains{$0.id==100 && $0.hp==100} && swept.score==100,"actual swept boost kills a crossed same-level body,credits its owner,and preserves another level")
  let team=fixture(1,2);team.players[1].hero=V2(x:-6,y:3);team.withPlayer(1){team.moveCombatPlayer(0.1,input:Controls(aim:V2(x:1,y:0),dash:true))}
  expect(team.players[0].dashes==5 && team.players[0].dashTime==0 && team.players[1].dashes==4 && team.activePlayerSlot==0,"boost state and spending belong to the selected team role")
  for kind in VehicleKind.allCases {
   let g=fixture();g.beginVehicle(kind);let start=g.hero;g.step(0.1,input:Controls(aim:V2(x:1,y:0),dash:true))
   expect(g.dashes==5 && g.dashTime==0 && (g.hero-start).length<1e-8,"\(kind) cannot consume a foot boost or acquire boost velocity")
  }
  let cleared=fixture();cleared.phase = .cleared;cleared.step(0.1,input:Controls(dash:true));expect(cleared.dashes==4 && cleared.dashTime>0,"cleared arena retains boost for collection and visitor escape until the actual exit transition")
  let safe=fixture();safe.phase = .cleared;safe.enterSideRoom(SideRoomOffer(kind:.armory,p:safe.hero));let stock=safe.dashes;safe.step(0.1,input:Controls(dash:true));expect(safe.dashes==stock && safe.dashTime==0,"own safe room still blocks boost consumption")
  let paused=fixture();paused.step(0.1,input:Controls(aim:V2(x:1,y:0),dash:true));paused.step(0,input:Controls(pause:true));let p=paused.hero,t=paused.dashTime;paused.step(10,input:Controls(dash:true))
  expect(paused.hero==p && paused.dashTime==t && paused.dashes==4,"pause freezes boost travel and does not consume extra reserves")
  paused.step(0,input:Controls(accept:true));paused.beginRound();expect(paused.dashTime==0 && !paused.boostProtected,"round transition cancels remaining travel and per-step boost protection")
  let wall=fixture(5);wall.hero=V2(x:-4,y:0);wall.step(0.6,input:Controls(aim:V2(x:1,y:0),dash:true))
  expect(wall.hero.x < -1.9 && wall.layout.walkable(wall.hero),"longer boost still stops on the solid courtyard fountain")
  let b=fixture(40);b.fixtureSilverbacks();b.silverbacks[0].arrival=nil;b.silverbacks[0].p=b.hero;b.step(0.1,input:Controls(dash:true))
  expect(b.silverbacks[0].hp==Silverback.maxHP && b.deaths==0,"boost protects the player but does not damage an excluded Silverback boss")
  print("\(passed) combat pacing checks passed;archived limits/timing,source timed admission;own world scale/contact shape;legacy boss choreography pending")
 }
}
