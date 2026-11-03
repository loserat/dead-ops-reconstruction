import Foundation
@main struct CoreChecks {
 static func main(){
  setbuf(stdout,nil)
  var passed=0
  func expect(_ yes:Bool,_ text:String){if !yes{fatalError(text)};passed+=1;print("PASS \(text)")}
  func takeFate(_ g:GameCore,_ choice:FateKind,atWall:Bool=false){
   let door=g.fateRoom!.door(for:choice)
   g.hero=atWall ? g.layout.boundary(door.p*10,clearance:0.29):door.p
   g.sideRoom!.clock=FateRoomTiming.firstArrow;g.step(0,input:Controls())
   g.sideRoom!.clock=FateRoomTiming.firstArrow+FateRoomTiming.fall;g.step(0,input:Controls())
   g.sideRoom!.clock=FateRoomTiming.firstArrow+FateRoomTiming.settle+FateRoomTiming.farewell+0.01;g.step(0,input:Controls());if let t=g.arenaTransit {g.step(t.endAt,input:Controls())}
  }
  func finishTravel(_ core:GameCore){if let t=core.arenaTransit {core.step(t.endAt,input:Controls())}}
  // Late-arena room fixtures stand for a run whose one-time Fate visit is already over.
  func enterLateBonus(_ g:GameCore,_ offer:SideRoomOffer){g.fateRoomVisited=true;g.enterSideRoom(offer);g.finishRoomLootForChecks()}
  func settle(_ core:GameCore){if core.players.contains(where:{$0.respawnRemaining != nil}){core.stepTeamRecovery(2)}}
  let g=GameCore();g.reset();settle(g);expect(g.lives==3 && g.dashes==2 && g.bombs==1,"starting resources remain distinct")
  g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.loseLife();settle(g);expect(g.lives==2 && g.deaths==1 && g.players[0].bodyShield?.remaining==RecoveryRules.fullShield,"death consumes one life and starts a separate timed respawn shield")
  g.loseLife();settle(g);expect(g.lives==2,"respawn protection prevents repeated same-frame death")
  g.apply(.life);settle(g);expect(g.lives==3 && g.collectedLives==1,"life pickup restores a life independently of boosts and bombs")
  g.apply(.dash);settle(g);expect(g.lives==3 && g.dashes==3 && g.bombs==1,"boost pickup only changes boosts")
  g.apply(.bomb);settle(g);expect(g.lives==3 && g.dashes==3 && g.bombs==2,"bomb pickup only changes bombs")
  g.award(600001);expect(g.lives==3 && g.nextLifeAt==400000 && g.directedLifeRewards.count==1,"one large score transaction creates one personal physical statue")
  g.award(0);g.award(0);g.advanceDirectedRewards(1.3);g.collectDirectedRewards();settle(g);expect(g.lives==6 && g.nextLifeAt==800000,"following explicit transactions and actual collection process remaining crossed thresholds")
  for _ in 0..<10{g.apply(.life);g.apply(.dash);g.apply(.bomb)}
  settle(g);expect(g.lives==9 && g.dashes==9 && g.bombs==9,"resource caps")
  let before=g.hero;g.step(1,input:Controls(pause:true));g.step(1,input:Controls(move:V2(x:1,y:0)));expect(g.phase == .paused && g.hero==before,"pause freezes simulation")
  g.step(0.01,input:Controls(accept:true));expect(g.phase == .playing,"resume returns to play")
  g.reset();g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.lives=0;g.loseLife();settle(g);expect(g.phase == .gameOver && g.lives==0,"death with zero spare lives produces game over")
  g.step(0.01,input:Controls(accept:true)) // Skip the ending; a separate press starts a new attempt.
  g.step(0.01,input:Controls(accept:true));expect(g.phase == .playing && g.lives==3,"restart from results resets entire run")
  g.apply(.spread);g.step(1,input:Controls(aim:V2(x:1,y:0)));expect(abs(g.weaponReserve-45)<0.001,"temporary weapon drains five times faster while firing")
  g.reset();g.finishCombatSpawning();g.foes=[];g.step(0.01,input:Controls());expect(g.phase == .cleared,"empty exhausted wave clears")
  g.clearClock=4;g.hero=g.suggestedExit;g.heroElevation=g.layout.height(g.hero);g.step(0.01,input:Controls());finishTravel(g);expect(g.round==2 && g.phase == .playing,"arena exit advances to next round")
  g.round=40;g.phase = .cleared;g.clearClock=4;g.hero=V2(x:0,y:6.6);g.step(0.01,input:Controls());expect(g.phase == .cleared && g.loopReturn==nil,"a fabricated cleared boss round cannot bypass an undefeated boss into the next loop")
  g.reset();g.hero=V2(x:0,y:0);g.foes=[Foe(id:999,p:V2(x:3,y:0),hp:1,speed:0,gait:0)];g.finishCombatSpawning();g.shots=[Shot(id:1000,p:V2(x:0,y:0),v:V2(x:100,y:0),ttl:2,damage:1,kind:nil)];g.step(0.05,input:Controls());expect(g.foes.isEmpty,"fast bullets use segment collision instead of skipping targets")
  g.reset();for _ in 0..<1000{g.step(1.0/120,input:Controls(move:V2(x:1,y:1)))};expect(g.inside(g.hero,margin:0),"diagonal movement stays inside the island")
  var shorelineSafe=true
  for degree in stride(from:0,to:360,by:5) {
   let a=Double(degree)*Double.pi/180,p=IslandLayout.clamped(V2(x:cos(a)*40,y:sin(a)*40))
   let ux=(p.x<0 ? -1.0:1.0)*pow(abs(p.x)/IslandLayout.width,IslandLayout.exponent/2)
   let uy=(p.y<0 ? -1.0:1.0)*pow(abs(p.y)/IslandLayout.depth,IslandLayout.exponent/2)
   let edge=IslandLayout.edge(angle:atan2(uy,ux),scale:1.025)
   if p.length+0.1>=edge.length {shorelineSafe=false}
  }
  expect(shorelineSafe,"walkable boundary stays inside the visible grass shoreline in every direction")
  g.reset();g.round=4;g.phase = .cleared;g.clearClock=4;g.prepareArenaExits();g.hero=g.suggestedExit;g.step(0.01,input:Controls());finishTravel(g)
  expect(g.round==5 && g.layout.kind == .courtyard && g.phase == .playing,"island exit changes arena to courtyard round five")
  g.phase = .cleared;g.clearClock=4;g.hero=V2(x:5,y:6.2);g.step(0.01,input:Controls())
  expect(g.round==5,"round exit requires the actual exit rather than any point on the lower edge")
  g.reset();g.round=5;g.beginRound();g.hero=V2(x:0,y:-3);g.invulnerable=999
  for _ in 0..<100 {g.step(1.0/120,input:Controls(move:V2(x:0,y:1)))}
  expect(g.hero.y < -1.93 && g.layout.walkable(g.hero,clearance:0.28),"walking into fountain stops at its visible rim")
  g.hero=V2(x:0,y:-3);g.facing=V2(x:0,y:1);g.step(0.05,input:Controls(dash:true))
  for _ in 0..<5 {g.step(0.05,input:Controls())}
  expect(g.hero.y < -1.93,"boost cannot tunnel through the solid fountain")
  g.reset();g.round=5;g.beginRound();g.hero=V2(x:0,y:-5);g.invulnerable=999;g.finishCombatSpawning()
  g.foes=[Foe(id:777,p:V2(x:0,y:5),hp:100,speed:2,gait:0)]
  var routeSafe=true,closest=99.0
  for _ in 0..<900 {
   g.step(1.0/60,input:Controls())
   if let f=g.foes.first {closest=min(closest,(f.p-g.hero).length);if !g.layout.walkable(f.p,clearance:0.24){routeSafe=false}}
  }
  expect(routeSafe && closest<0.6,"horde navigates around fountain from the opposite side without crossing it")
  g.reset();g.round=5;g.beginRound();g.hero=V2(x:0,y:-4);g.invulnerable=999;g.finishCombatSpawning()
  g.foes=[Foe(id:778,p:V2(x:0,y:3),hp:2,speed:0,gait:0)]
  g.shots=[Shot(id:779,p:V2(x:0,y:-3),v:V2(x:0,y:100),ttl:1,damage:9,kind:nil)]
  g.step(0.08,input:Controls());expect(g.foes.first?.hp==2 && g.shots.isEmpty,"fountain stops fast bullets before enemies behind it")
  g.reset();g.round=5;g.beginRound();let trap=g.layout.traps[0]
  expect(trap.state(at:0) == .warning && trap.state(at:0.6) == .safe && trap.state(at:10.6) == .warning && trap.state(at:11.8) == .active,"electric spike has a harmless initial pulse,ten-second lead-in,1.2s warning and randomized discharge")
  g.hero=trap.p+V2(x:0.46,y:0);g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.hazardClock=10.6
  g.step(0.01,input:Controls());settle(g);expect(g.lives==3,"red warning gives time to escape without killing the player")
  g.phase = .playing;g.hero=trap.p+V2(x:0.46,y:0);g.heroElevation=trap.elevation;g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.hazardClock=11.8
  g.step(0.01,input:Controls());settle(g);expect(g.lives==2 && g.hero==trap.p+V2(x:0.46,y:0) && g.layout.walkable(g.hero),"active electric trap consumes one life after two seconds and restores the original position with protection")
  g.reset();g.round=5;g.beginRound();let victimTrap=g.layout.traps[0];g.hero=V2(x:0,y:-5);g.invulnerable=999;g.hazardClock=11.8;g.finishCombatSpawning()
  g.foes=[Foe(id:780,p:victimTrap.p+V2(x:0.55,y:0),hp:10,speed:0,gait:0,elevation:victimTrap.elevation)]
  g.step(0.01,input:Controls());expect(g.foes.isEmpty,"electric discharge also kills zombies")
  let island=ArenaLayout(kind:.island),boat=island.obstacles[0]
  expect(!island.walkable(boat.p) && island.walkable(island.clamped(boat.p)),"boat collision has a valid escape boundary")
  g.godMode=true;g.reset();g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.hero=V2(x:2,y:2);g.apply(.ray);g.multiplier=4
  let trainingPosition=g.hero;g.loseLife()
  settle(g);expect(g.lives==3 && g.trainingHits==1 && g.displayedLives==2 && g.phase == .playing,"godmode counts one virtual lost life without reducing real stock")
  expect(g.hero==trainingPosition && g.weapon == .ray && g.multiplier==4 && g.deaths==0,"godmode preserves position weapon score multiplier and real death count")
  g.loseLife();settle(g);expect(g.trainingHits==1,"godmode counts one hit per protection window rather than one per frame")
  for _ in 0..<4 {g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.loseLife()}
  expect(g.displayedLives == -2 && g.phase == .playing && g.lives==3,"virtual life display may go below zero without game over")
  g.apply(.life);expect(g.displayedLives == -1 && g.trainingHits==5,"collected life adds to virtual balance without erasing counted hits")
  g.godMode=false;g.lives=0;g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.loseLife()
  expect(g.phase == .gameOver && g.deaths==1 && g.usedGodMode,"turning godmode off restores normal damage and retains assisted-run marking")
  g.godMode=true;g.reset();expect(g.godMode && g.trainingHits==0 && g.displayedLives==3 && g.usedGodMode,"new run retains chosen mode but resets its virtual hit counter")
  g.godMode=false;g.reset();g.step(0.01,input:Controls(systemPause:true));g.step(0.01,input:Controls(systemPause:true))
  expect(g.phase == .paused,"repeated focus or controller loss cannot resume a paused game")
  var prefs=GameSettings();expect(!prefs.godMode && prefs.cameraMode == .following && prefs.zoom == .normal,"safe defaults use closer following camera with godmode off")
  prefs.adjust(row:0,delta:1);prefs.adjust(row:1,delta:1);prefs.adjust(row:2,delta:-1);prefs.adjust(row:3,delta:1)
  let encoded=try! JSONEncoder().encode(prefs)
  expect(GameSettings.decode(encoded)==prefs && prefs.cameraMode == .following && prefs.zoom == .normal,"settings round trip retains the automatic camera standard")
  expect(GameSettings.decode(Data("invalid".utf8))==GameSettings(),"invalid saved settings recover to safe defaults")
  var m=GameMenu();_ = m.handle(Controls(menuY:1),phase:.title)
  _ = m.handle(Controls(accept:true),phase:.title)
  expect(m.settingsOpen && m.selected==0,"title menu opens settings without starting the game")
  expect(m.handle(Controls(accept:true),phase:.title) == .setting(0,1),"focused setting accepts controller or keyboard confirmation")
  _ = m.handle(Controls(back:true),phase:.title)
  expect(!m.settingsOpen && m.selected==1,"back returns to the previous menu without starting or resuming")
  m.openSettings(phase:.paused);_ = m.handle(Controls(pause:true),phase:.paused)
  expect(!m.settingsOpen && m.handle(Controls(pause:true),phase:.paused) == .resume,"first escape closes settings and second escape resumes paused game")
  _ = m.handle(Controls(accept:true,menuRow:1),phase:.title)
  expect(m.settingsOpen,"mouse selection activates the requested title-menu row")
  var closeRig=CameraRig(),wideRig=CameraRig();let normal=GameSettings()
  closeRig.update(hero:V2(x:6,y:3),settings:normal,aspect:16.0/9,dt:1.0/60)
  var overview=normal;overview.cameraMode = .overview
  wideRig.update(hero:V2(x:6,y:3),settings:overview,aspect:16.0/9,dt:1.0/60)
  expect(closeRig.scale<wideRig.scale*0.60 && closeRig.center.x>5.39 && closeRig.center.x<5.41 && wideRig.center == .zero,"default camera follows the player closely while fixed overview retains the arena center")
  var a=CameraRig(),b=CameraRig();a.update(hero:.zero,settings:normal,aspect:16.0/9,dt:0);b=a
  for _ in 0..<60 {a.update(hero:V2(x:3,y:0),settings:normal,aspect:16.0/9,dt:1.0/60)}
  for _ in 0..<30 {b.update(hero:V2(x:3,y:0),settings:normal,aspect:16.0/9,dt:1.0/30)}
  expect(abs(a.center.x-b.center.x)<0.00001 && a.center.x<2.7 && a.center.x>2.69,"camera damping is time-based and does not overshoot")
  a.update(hero:V2(x:-7,y:0),settings:normal,aspect:16.0/9,dt:1.0/60)
  expect(abs(a.center.x+6.3)<0.001,"camera resets on teleport or respawn instead of slowly crossing the arena")
  a.update(hero:.zero,settings:normal,aspect:4.0/3,dt:0,snap:true)
  expect(a.scale>closeRig.scale,"narrow windows gain enough vertical view to preserve horizontal visibility")
  g.godMode=false;g.reset();g.round=5;g.beginRound();g.phase = .cleared;g.clearClock=4
  let offer=SideRoomOffer(kind:.treasure,p:V2(x:-9.5,y:5.35));g.sideRoomOffer=offer;g.arenaExits=[ArenaExit(id:g.id(),side:.west,p:offer.p,height:0,opensAt:0,bonus:offer.kind)];g.hero=offer.p
  g.step(0.01,input:Controls());finishTravel(g)
  expect(g.phase == .bonusRoom && g.round==5 && g.sideRoom?.sourceRound==5,"golden side route enters a bonus room without consuming a round")
  g.finishRoomLootForChecks()
  expect(g.sourceLoot!.clusterStarts==25 && g.pickups.count>=75 && g.foes.isEmpty,"bonus room completes twenty-five source treasure globs without a fixed four-gem preset")
  expect(g.pickups.allSatisfy{g.layout.walkable($0.p,clearance:0.28)},"every treasure pickup is reachable outside solid chests and fountain")
  expect(ArenaLayout.treasurePiles.allSatisfy{!g.layout.walkable($0)},"treasure chest art has matching solid footprints")
  let roomElapsed=g.elapsed;g.step(0.01,input:Controls(pause:true));g.step(2,input:Controls())
  expect(g.phase == .paused && g.elapsed==roomElapsed,"bonus room pause freezes exploration and room timer")
  g.step(0.01,input:Controls(accept:true));expect(g.phase == .bonusRoom,"resuming returns to the bonus room rather than starting a wave")
  g.weapon = .ray;g.weaponReserve=17;g.orb=12;g.chicken=20;g.boots=5
  let db=g.dashes,bb=g.bombs,lootCount=g.pickups.count
  g.step(4,input:Controls(aim:V2(x:1,y:0),dash:true,bomb:true))
  expect(g.weaponReserve==17 && g.orb==12 && g.chicken==20 && g.boots==5,"temporary power timers are preserved during safe loot selection")
  expect(g.shots.isEmpty && g.dashes==db && g.bombs==bb && g.pickups.count==lootCount,"safe-room attack inputs cannot spend resources or destroy uncollected loot")
  let oldScore=g.score;g.hero=g.pickups.first{$0.kind == .treasure || $0.kind == .gem}!.p;g.step(0.01,input:Controls())
  expect(g.score>oldScore && g.pickups.count<lootCount,"bonus treasure is collected through normal movement proximity")
  let earnedScore=g.score,earnedReserve=g.weaponReserve;g.hero=g.suggestedExit;g.step(0.01,input:Controls());finishTravel(g)
  expect(g.round==6 && g.phase == .playing && g.sideRoom==nil && g.score==earnedScore && g.weaponReserve==earnedReserve,"leaving bonus room starts the next combat round exactly once and retains earned loot")
  expect(g.visitedSideRoomRounds.contains(5),"discovered side room is recorded for its source round")
  g.reset();g.round=3;g.beginRound();g.phase = .cleared;g.enterSideRoom(SideRoomOffer(kind:.armory,p:V2(x:9.5,y:5.35)))
  g.finishRoomLootForChecks()
  expect(g.sideRoom?.kind == .armory && g.pickups.count==17 && g.pickups.filter{$0.kind == .chicken}.count>=4,"solo armory completes its source supplies including four explicit chickens")
  expect(g.pickups.allSatisfy{g.layout.walkable($0.p,clearance:0.28)},"armory items remain reachable around the island boat and weapon racks")
  let roomBombs=g.bombs;g.hero=g.pickups.first{$0.kind == .bomb}!.p;g.step(0.01,input:Controls())
  expect(g.bombs>roomBombs && g.lives==3,"armory bomb contact changes the actual stock without an invented guaranteed extra life")
  let selectedGun=Pickup(id:98000,p:g.hero,kind:.ray);g.pickups=[selectedGun];g.step(0,input:Controls());expect(g.weapon == .ray,"explicit physical gun fixture in a safe room equips the chosen weapon")
  let source=g.round;g.reset();expect(g.sideRoom==nil && g.visitedSideRoomRounds.isEmpty && g.round==1 && source==3,"new run clears all side-room state without resetting user preferences")
  g.reset();g.apply(.chicken);g.apply(.chicken)
  expect(g.chickens.count==2 && g.chickens.allSatisfy{abs($0.ttl-40)<0.001},"chicken pickups add independent forty-second companions instead of refreshing one invisible duplicate")
  g.combatSpawningHeld=true;g.hero=V2(x:2,y:1);g.step(0.1,input:Controls())
  expect(g.chickens.allSatisfy{($0.p-g.hero).length<3},"flying chickens follow the actual player position")
  g.shots=[];g.shotClock=0;g.step(0.01,input:Controls(aim:V2(x:1,y:0)))
  expect(g.shots.filter{$0.height>1}.count==2 && g.shots.filter{$0.height<1}.count==1,"each chicken fires from its own airborne position alongside the player's shot")
  g.apply(.spread);g.shots=[];g.shotClock=0;for i in g.chickens.indices {g.chickens[i].shotClock=0}
  g.step(0.01,input:Controls(aim:V2(x:1,y:0)))
  expect(g.shots.filter{$0.height>1 && $0.kind == .spread}.count==10,"both chickens copy the active five-pellet shotgun")
  g.shots=[];for i in g.chickens.indices {g.chickens[i].ttl=1.5;g.chickens[i].shotClock=0}
  g.step(0.01,input:Controls());expect(g.shots.count==10 && g.chickens.allSatisfy{$0.flash>0},"expiring chickens fire a circular burst even when the player is not shooting")
  g.shots=[];g.updateCompanions(2)
  expect(g.chickens.isEmpty && g.chicken==0,"expired chickens are removed and cannot keep firing")
  g.reset();g.combatSpawningHeld=true;g.apply(.orb)
  expect(g.orbShields.count==4 && g.orb==40,"electric pickup grants four visible forty-second charges")
  let oldOrb=g.orbShields[0].p;g.step(0.05,input:Controls())
  expect((g.orbShields[0].p-oldOrb).length>0.1 && abs((g.orbShields[0].p-g.hero).length-TeslaRules.orbitRadius)<0.001,"electric charges orbit on the same radius used for collision")
  g.reset();g.combatSpawningHeld=true;g.apply(.orb);g.invulnerable=99
  let strike=g.orbShields[0].p
  g.foes=[Foe(id:9001,p:strike,hp:9,speed:0,gait:0),Foe(id:9002,p:strike+V2(x:0.8,y:0.5),hp:9,speed:0,gait:0),Foe(id:9003,p:V2(x:7,y:0),hp:9,speed:0,gait:0)]
  g.step(0.01,input:Controls())
  expect(g.orbShields.count==3 && g.foes.count==3 && g.foes[0].hp>0 && g.playerRoster.current.tesla.pendingPrograms==1,"one real orb contact consumes one charge before its delayed source chain")
  g.stepTesla(2);g.resolveDefeatedFoes()
  expect(g.foes.count==1 && g.foes[0].id==9003,"delayed Tesla chain kills nearby bodies and leaves distant body alive")
  for _ in 0..<3 {
   let p=g.orbShields[0].p;g.foes=[Foe(id:g.id(),p:p,hp:99,speed:0,gait:0)];g.step(0.001,input:Controls());g.stepTesla(2);g.resolveDefeatedFoes()
  }
  expect(g.orbShields.isEmpty && g.orb==0,"all four charges can be consumed and do not silently regenerate")
  g.reset();g.combatSpawningHeld=true;g.apply(.orb);g.invulnerable=0
  g.foes=[Foe(id:9004,p:g.hero,hp:9,speed:0,gait:0)];g.step(0.001,input:Controls())
  settle(g);expect(g.lives==2,"enemy contact between the four charges is no longer blocked by an invisible full-circle kill zone")
  g.reset();g.apply(.orb);g.orbRemaining=0.001;g.updateCompanions(0.01)
  expect(g.orbShields.isEmpty && g.flyingOrbs.count==4,"unused charges fly outward when their forty-second timer ends")
  g.stepTesla(4.01);expect(g.flyingOrbs.isEmpty,"unused Tesla models delete together after all half-second waits and two final seconds")
  g.reset();g.apply(.chicken);g.apply(.orb);let chickenBefore=g.chickens[0].p,orbBefore=g.orbShields[0].p,lifeBefore=g.chickens[0].ttl
  g.step(0.01,input:Controls(pause:true));g.step(5,input:Controls())
  expect(g.chickens[0].p==chickenBefore && g.orbShields[0].p==orbBefore && g.chickens[0].ttl==lifeBefore,"pause freezes companion motion and lifetime")
  g.step(0.01,input:Controls(accept:true));g.godMode=true;g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.loseLife()
  expect(g.chickens.count==1 && g.orbShields.count==4 && g.trainingHits==1,"godmode contact preserves both visible support types")
  g.godMode=false;g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.loseLife()
  expect(g.chickens.isEmpty && g.orbShields.isEmpty,"real death clears companion entities as well as timers")
  let prison=ArenaLayout(kind:.prison)
  expect(prison.height(.zero)==0 && prison.height(V2(x:10,y:0))==1.6 && abs(prison.height(V2(x:0,y:4.2))-0.8)<0.001,"prison walking surface has a ground court elevated catwalk and real stair gradient")
  let blocked=prison.moved(V2(x:8.4,y:0),by:V2(x:2,y:0))
  expect(blocked.x<9 && prison.height(blocked)==0,"player cannot walk directly from court through a catwalk ledge")
  expect(prison.canTraverse(V2(x:0,y:-5.6),V2(x:0,y:-5.4)) && !prison.canTraverse(V2(x:0,y:-5.4),V2(x:0,y:-5.6)),"opposite catwalk gap permits descent but cannot be used as an invisible upward stair")
  g.godMode=false;g.reset();g.round=9;g.hero=V2(x:0,y:2.5);g.beginRound();g.combatSpawningHeld=true;g.invulnerable=999
  for _ in 0..<95 {g.step(1.0/120,input:Controls(move:V2(x:0,y:1)))}
  expect(g.hero.y>6 && abs(g.heroElevation-1.6)<0.001,"walking up rendered stairs lifts player to catwalk height")
  g.hero=V2(x:0,y:-6);g.heroElevation=1.6;g.heroFallSpeed=0
  for _ in 0..<16 {g.step(1.0/120,input:Controls(move:V2(x:0,y:1)))}
  expect(g.hero.y > -5.5 && g.heroElevation>0.2 && g.heroElevation<1.6,"leaving the marked catwalk gap causes a real falling interval")
  for _ in 0..<120 {g.step(1.0/120,input:Controls(move:V2(x:0,y:1)))}
  expect(g.heroElevation==0,"falling player lands on the actual court floor")
  g.hero=V2(x:0,y:-4.8);g.heroElevation=0
  for _ in 0..<40 {g.step(1.0/120,input:Controls(move:V2(x:0,y:-1)))}
  expect(g.hero.y > -5.5 && g.heroElevation==0,"holding toward a drop gap from below never teleports player onto the deck")
  g.reset();g.round=9;g.hero=V2(x:10,y:0);g.beginRound();g.combatSpawningHeld=true;g.invulnerable=999
  g.foes=[Foe(id:9100,p:.zero,hp:99,speed:3,gait:0)]
  var reachedUpper=false,routeHeightSafe=true
  for _ in 0..<1800 {g.step(1.0/60,input:Controls());if let f=g.foes.first {if (f.p-g.hero).length<0.6 && abs(f.elevation-g.heroElevation)<0.2 {reachedUpper=true};if !g.layout.walkable(f.p,clearance:0.24){routeHeightSafe=false}}}
  expect(reachedUpper && routeHeightSafe,"ground-level zombies route up stairs and around the raised perimeter to a player on the deck")
  g.reset();g.round=9;g.hero = .zero;g.beginRound();g.combatSpawningHeld=true;g.invulnerable=999
  g.foes=[Foe(id:9101,p:V2(x:10,y:0),hp:99,speed:3,gait:0,elevation:1.6)]
  var reachedCourt=false
  for _ in 0..<1500 {g.step(1.0/60,input:Controls());if let f=g.foes.first, (f.p-g.hero).length<0.6 && f.elevation<0.1 {reachedCourt=true}}
  expect(reachedCourt,"catwalk zombies can navigate back to the court through stairs or the one-way drop")
  g.reset();g.round=9;g.hero=V2(x:8,y:0);g.beginRound();g.combatSpawningHeld=true;g.invulnerable=999
  g.foes=[Foe(id:9102,p:V2(x:10,y:0),hp:3,speed:0,gait:0,elevation:1.6)]
  g.shots=[Shot(id:9103,p:V2(x:8,y:0),v:V2(x:80,y:0),ttl:1,damage:10,kind:nil,height:0.53)]
  g.step(0.05,input:Controls());expect(g.foes.first?.hp==3,"ground-level bullets cannot hit zombies standing a full storey above them")
  g.hero=V2(x:8.5,y:0);g.heroElevation=0;g.pickups=[Pickup(id:9104,p:V2(x:9.1,y:0),kind:.life)];let livesAtLedge=g.lives
  g.step(0.01,input:Controls());settle(g);expect(g.lives==livesAtLedge && g.pickups.count==1,"pickups on a catwalk cannot be collected through the floor from below")
  g.phase = .cleared;g.round=8;g.clearClock=4;g.prepareArenaExits();g.hero=g.suggestedExit;g.heroElevation=g.layout.height(g.hero);g.step(0.01,input:Controls());finishTravel(g)
  expect(g.round==9 && g.layout.kind == .prison && g.heroElevation==0,"courtyard exit now advances into the prison instead of ending at round eight")
  g.reset();g.round=9;g.beginRound();g.phase = .cleared;g.enterSideRoom(SideRoomOffer(kind:.treasure,p:V2(x:9.5,y:5.35)))
  g.finishRoomLootForChecks()
  expect(g.phase == .bonusRoom && g.sourceLoot!.clusterStarts==25 && g.pickups.count>=75 && g.pickups.allSatisfy{g.layout.walkable($0.p,clearance:0.28)},"prison treasure remains reachable between electrical posts and raised stair geometry")
  g.reset();g.round=10;g.beginRound();g.phase = .cleared;g.enterSideRoom(SideRoomOffer(kind:.armory,p:V2(x:9.5,y:5.35)))
  g.finishRoomLootForChecks()
  expect(g.pickups.count==17 && g.pickups.allSatisfy{g.layout.walkable($0.p,clearance:0.28)} && g.heroElevation==0,"prison armory starts on the court and keeps all items outside rocks and racks")
  g.reset();g.round=9;g.hero=V2(x:0,y:5.6);g.beginRound();g.phase = .cleared;g.clearClock=4
  g.sideRoomOffer=SideRoomOffer(kind:.armory,p:V2(x:-9.5,y:5.35));g.step(0.01,input:Controls())
  expect(g.phase == .cleared && g.round==9,"climbing onto prison stair landing does not accidentally select the main exit before a side route")
  let cave=ArenaLayout(kind:.cave)
  expect(cave.contains(V2(x:8,y:5)) && !cave.contains(V2(x:10,y:5)) && !cave.walkable(.zero),"cave is a smaller arena with a solid central statue")
  expect(cave.walkable(cave.sideRoute(onLeft:true)) && cave.walkable(cave.sideRoute(onLeft:false)),"both cave side paths remain inside the compact playable bounds")
  g.reset();g.round=13;g.beginRound();g.combatSpawningHeld=false;g.step(0.01,input:Controls())
  expect(g.foes.first?.kind == .crawler && g.foes.first!.hp>=8,"first cave round introduces tough crawler enemies")
  g.reset();g.round=13;g.hero=V2(x:0,y:-4);g.beginRound();g.combatSpawningHeld=true;g.invulnerable=99
  g.foes=[Foe(id:9200,p:V2(x:3,y:-4),hp:8,speed:3,gait:0,kind:.crawler,behaviorClock:0.1,lungeDirection:V2(x:-1,y:0))]
  let resting=g.foes[0].p;g.step(0.05,input:Controls());expect(g.foes[0].p==resting,"crawler has a genuinely stationary stalking interval")
  g.foes[0].behaviorClock=0.69;g.step(0.03,input:Controls());expect((g.foes[0].p-resting).length>0.15,"crawler launches a rapid directed lunge after its pause")
  g.reset();g.round=15;g.beginRound();g.phase = .cleared;g.advanceCombatRound()
  expect(g.round==15 && g.phase == .bonusRoom && g.sideRoom?.kind == .fate && g.fate==nil,"after cave round fifteen the unvisited fate room is guaranteed without consuming a combat round")
  expect(FateDoor.allCases.allSatisfy{g.layout.walkable($0.p)},"all four permanent fate paths are physically reachable")
  takeFate(g,.firepower)
  expect(g.fate == .firepower && g.round==16 && g.phase == .playing && g.weapon==nil && g.activeWeapon == .deathMachine,"waiting for falling firepower reward selects permanent gun and starts round sixteen exactly once")
  g.apply(.ray);g.weaponReserve=0.001;g.step(0.01,input:Controls());expect(g.weapon==nil && g.activeWeapon == .deathMachine,"temporary weapon expiry restores permanent death machine")
  g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.loseLife();settle(g);expect(g.fate == .firepower && g.activeWeapon == .deathMachine,"firepower fate survives a normal death")
  g.reset();g.round=14;g.beginRound();g.phase = .cleared;g.enterFateRoom();takeFate(g,.fortitude)
  g.apply(.ray);g.apply(.boots);g.apply(.orb);g.apply(.chicken)
  expect(g.weaponReserve==100 && g.boots==20 && g.orb==80 && g.chickens[0].ttl==80,"fortitude doubles future weapon and support pickup lifetimes")
  g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.loseLife();settle(g);expect(g.multiplier==2 && g.fate == .fortitude,"fortitude retains a two-times multiplier after death")
  g.reset();g.round=14;g.beginRound();g.phase = .cleared;g.enterFateRoom();takeFate(g,.friendship)
  expect(g.chickens.count==1 && g.chickens[0].permanent,"friendship creates one explicitly permanent chicken without infinite floating-point timers")
  g.updateCompanions(100);expect(g.chickens.count==1 && g.chickens[0].permanent,"permanent chicken never expires or enters its departure burst")
  g.apply(.chicken);expect(g.chickens.count==2 && g.chickens.first{!$0.permanent}?.ttl==80,"friendship grants double lifetime to additional chicken pickups")
  g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.loseLife();settle(g);expect(g.chickens.count==1 && g.chickens[0].permanent && g.fate == .friendship,"normal death restores exactly one permanent friendship chicken")
  g.reset();g.round=14;g.beginRound();g.phase = .cleared;g.enterFateRoom();takeFate(g,.feet)
  g.dashes=0;g.boots=0;g.beginRound();expect(g.dashes==3 && g.moveSpeed==9.8,"furious feet gives permanent speed and restores three boosts at round start")
  g.dashes=7;g.beginRound();expect(g.dashes==7,"furious feet does not reduce an existing larger boost stock")
  g.fate=nil;g.fateRoomVisited=false;g.round=15;g.phase = .cleared;g.enterSideRoom(SideRoomOffer(kind:.treasure,p:g.layout.sideRoute(onLeft:true)));g.hero=g.suggestedExit;g.step(0.01,input:Controls())
  expect(g.round==15 && g.sideRoom?.kind == .fate,"a chosen bonus route after round fifteen is replaced by the guaranteed fate room")
  let fateClock=g.sideRoom!.clock;g.step(0.01,input:Controls(pause:true));g.step(3,input:Controls());expect(g.phase == .paused && g.sideRoom!.clock==fateClock,"fate selection supports pause without choosing or advancing")
  g.step(0.01,input:Controls(accept:true));takeFate(g,.feet);g.chooseFate(.firepower)
  expect(g.fate == .feet && g.round==16,"only one permanent fate can be selected in a run")
  g.reset();expect(g.fate==nil && !g.fateRoomVisited && g.activeWeapon==nil && g.chickens.isEmpty,"new run clears permanent fate benefits while preserving game settings")
  g.reset();g.round=14;g.beginRound();g.phase = .cleared;g.enterFateRoom();takeFate(g,.feet,atWall:true)
  expect(g.fate == .feet && g.round==15,"holding past fate arrow toward the wall still selects its path rather than overshooting it")
  g.reset();g.round=5;g.beginRound();g.phase = .cleared;g.clearClock=4;g.arenaExits=[ArenaExit(id:g.id(),side:.south,p:g.layout.playerExit(on:.south),height:0,opensAt:0,bonus:nil)];g.hero=g.layout.boundary(V2(x:0,y:50),clearance:0.29);g.step(0.01,input:Controls());finishTravel(g)
  expect(g.round==6,"holding toward courtyard exit against lower boundary cannot overshoot the exit zone")
  let market=ArenaLayout(kind:.marketplace)
  expect(market.walkable(.zero) && market.traps.count==4 && market.height(.zero)==0,"marketplace has an open flat center and four electrical spikes")
  expect(market.obstacles.allSatisfy{!market.walkable($0.p)} && market.walkable(market.exit) && market.walkable(market.sideRoute(onLeft:true)),"market crates traps and reachable exits share the visible layout")
  g.reset();g.round=16;g.beginRound();g.phase = .cleared;g.advanceCombatRound()
  expect(g.round==17 && g.layout.kind == .marketplace && g.phase == .playing,"cave exit advances to marketplace stampede round seventeen")
  g.combatSpawningHeld=true;g.invulnerable=99;g.stepStampede(11)
  expect(g.stampede?.bursts==1 && !g.bulls.isEmpty && g.bulls.count<=2 && g.bulls.allSatisfy{abs($0.direction.x)+abs($0.direction.y)==1},"stampede begins one source-timed group with individually born cardinal travellers")
  let herd=g.bulls.map(\.p),clock=g.bullClock;g.step(0.01,input:Controls(pause:true));g.step(2,input:Controls())
  expect(g.bulls.map(\.p)==herd && g.bullClock==clock,"pause freezes bull motion and the next stampede clock")
  g.step(0.01,input:Controls(accept:true));g.godMode=false;g.hero = .zero;g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.bullClock=999
  g.bulls=[Bull(id:9300,p:V2(x:-3,y:0),direction:V2(x:1,y:0),speed:100)]
  g.step(0.06,input:Controls());settle(g);expect(g.lives==2 && g.deaths==1,"fast bull crossing sweeps the whole body path and consumes one real life")
  g.godMode=true;g.hero = .zero;g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.bulls=[Bull(id:9301,p:V2(x:0,y:-3),direction:V2(x:0,y:1),speed:100)]
  g.apply(.ray);g.step(0.06,input:Controls())
  expect(g.trainingHits==1 && g.lives==2 && g.weapon == .ray && g.hero == .zero,"bull impact respects godmode virtual lives without a respawn or weapon loss")
  g.godMode=false;g.reset();g.round=17;g.beginRound();g.combatSpawningHeld=true;g.bullClock=999;g.hero=V2(x:8,y:-6);g.invulnerable=99
  g.foes=[Foe(id:9302,p:.zero,hp:8,speed:0,gait:0,kind:.crawler)]
  g.bulls=[Bull(id:9303,p:V2(x:-3,y:0),direction:V2(x:1,y:0),speed:100)]
  g.step(0.06,input:Controls());expect(g.foes.isEmpty && !g.bulls.isEmpty,"crossing bulls trample crawlers as well as regular zombies without stopping")
  g.foes=[Foe(id:9304,p:V2(x:5,y:0),hp:9,speed:0,gait:0)];g.bulls=[Bull(id:9305,p:.zero,direction:V2(x:0,y:1),speed:0)]
  g.shots=[Shot(id:9306,p:V2(x:-3,y:0),v:V2(x:100,y:0),ttl:1,damage:99,kind:nil)]
  g.step(0.06,input:Controls());expect(g.bulls.count==1 && g.foes[0].hp==9 && g.shots.isEmpty,"ordinary bullets stop at a bull without killing it or passing through to zombies behind")
  g.shots=[Shot(id:9307,p:V2(x:-3,y:0),v:V2(x:100,y:0),ttl:1,damage:8,kind:.rocket)]
  g.step(0.05,input:Controls());expect(g.bulls.isEmpty,"direct rocket impact destroys a bull")
  g.foes=[Foe(id:9320,p:V2(x:-4,y:0),hp:3,speed:0,gait:0)];g.bulls=[Bull(id:9321,p:.zero,direction:V2(x:0,y:1),speed:0)]
  g.effects=[];g.shots=[Shot(id:9322,p:V2(x:-8,y:0),v:V2(x:100,y:0),ttl:1,damage:8,kind:.rocket)];g.step(0.09,input:Controls())
  expect(g.foes.isEmpty && g.bulls.isEmpty && g.effects.contains{($0.p-V2(x:-4,y:0)).length<0.2},"piercing RPG explodes at the near zombie before continuing into the bull behind it")
  g.bulls=[Bull(id:9308,p:.zero,direction:V2(x:1,y:0),speed:0,golden:true)];g.pickups=[];g.explodeBulls(at:.zero,radius:2)
  expect(g.bulls.isEmpty && g.pickups.count==2 && g.sourceLoot!.pendingChildren==2 && g.pickups.allSatisfy{g.layout.walkable($0.p,clearance:0.28)},"exploding rare golden bull starts its two staggered source reward programs")
  g.bulls=[Bull(id:9309,p:V2(x:-7,y:0),direction:V2(x:1,y:0),speed:0),Bull(id:9310,p:V2(x:8,y:0),direction:V2(x:-1,y:0),speed:0)]
  g.bombs=1;g.step(0.01,input:Controls(bomb:true));expect(g.bulls.isEmpty && g.bombs==0,"bomb clears bulls across the arena as an explosive attack")
  g.finishCombatSpawning();g.foes=[];g.bulls=[Bull(id:9311,p:V2(x:13,y:0),direction:V2(x:1,y:0),speed:9)]
  g.step(0.05,input:Controls());expect(g.phase == .cleared && g.bulls.count==1,"zombie completion exposes exits while the last fake-AI bull is still crossing")
  g.step(0.2,input:Controls());expect(g.phase == .cleared && g.bulls.isEmpty,"the surviving bull continues out after zombie completion without requiring a kill")
  g.bulls=[Bull(id:9312,p:.zero,direction:V2(x:1,y:0))];enterLateBonus(g,SideRoomOffer(kind:.treasure,p:g.layout.sideRoute(onLeft:true)))
  let safeBullClock=g.bullClock;g.step(1,input:Controls())
  expect(g.phase == .bonusRoom && g.bulls.isEmpty && g.bullClock==safeBullClock,"market bonus rooms remove stampedes and never spawn hazards while collecting")
  g.bulls=[Bull(id:9313,p:.zero,direction:V2(x:1,y:0))];g.reset();expect(g.bulls.isEmpty,"new run removes all previous stampede entities")
  let city=ArenaLayout(kind:.urban)
  expect(city.height(V2(x:-6,y:-2))==1.8 && city.height(V2(x:5,y:0))==0 && abs(city.height(V2(x:-0.3,y:0))-0.9)<0.001,"urban arena has two actual levels and a central staircase incline")
  expect(abs(city.height(V2(x:-10,y:4))-0.9)<0.001 && city.walkable(city.exit) && city.walkable(city.sideRoute(onLeft:true)),"second urban corner staircase and both ground exits are reachable")
  expect(!city.canTraverse(V2(x:-1.7,y:-3),V2(x:-1.9,y:-3)),"urban height ledge cannot be climbed without using stairs")
  g.reset();g.round=20;g.beginRound();g.phase = .cleared;g.advanceCombatRound();expect(g.round==21 && g.layout.kind == .urban && g.bulls.isEmpty,"marketplace exit enters urban round twenty-one without carrying any bulls")
  g.hero=V2(x:2,y:0);g.heroElevation=0;g.combatSpawningHeld=true;g.invulnerable=999
  for _ in 0..<110 {g.step(1.0/120,input:Controls(move:V2(x:-1,y:0)))}
  expect(g.hero.x < -2 && abs(g.heroElevation-1.8)<0.001,"central city staircase physically carries the player onto the rooftop")
  g.hero=V2(x:-10,y:6);g.heroElevation=0
  for _ in 0..<105 {g.step(1.0/120,input:Controls(move:V2(x:0,y:-1)))}
  expect(g.hero.y<2.5 && abs(g.heroElevation-1.8)<0.001,"corner city staircase is a real alternative route onto the rooftop")
  g.hero=V2(x:-5,y:2.3);g.heroElevation=1.8;g.heroFallSpeed=0
  for _ in 0..<12 {g.step(1.0/120,input:Controls(move:V2(x:0,y:1)))}
  expect(g.hero.y>2.5 && g.heroElevation>0 && g.heroElevation<1.8,"marked urban ledge produces a real fall interval onto the street")
  for _ in 0..<80 {g.step(1.0/120,input:Controls(move:V2(x:0,y:1)))}
  expect(g.heroElevation==0 && !city.canTraverse(V2(x:-5,y:2.6),V2(x:-5,y:2.4)),"urban drop lands and cannot be used as an invisible upward staircase")
  g.hero=V2(x:-6,y:-2);g.heroElevation=1.8;g.foes=[Foe(id:9400,p:V2(x:8,y:0),hp:99,speed:3,gait:0)]
  var reachedRoof=false,validCity=true
  for _ in 0..<1500 {g.step(1.0/60,input:Controls());if let f=g.foes.first {if (f.p-g.hero).length<0.65 && abs(f.elevation-1.8)<0.1 {reachedRoof=true};if !city.walkable(f.p,clearance:0.24){validCity=false}}}
  expect(reachedRoof && validCity,"zombies use city stairs to reach a rooftop player while staying outside ledges and props")
  g.reset();g.round=22;g.hero=V2(x:8,y:-6);g.beginRound();g.combatSpawningHeld=false;g.invulnerable=999;g.step(0.01,input:Controls())
  expect(g.foes.first?.kind == .engineer && g.foes[0].elevation>g.layout.height(g.foes[0].p)+7,"Downpour introduces engineers above the actual local floor")
  let fallingAt=g.foes[0].p;g.combatSpawningHeld=true
  g.step(0.1,input:Controls());expect(g.foes[0].p==fallingAt && g.foes[0].fallSpeed<0,"airborne engineer falls without running sideways through the sky")
  for _ in 0..<150 {g.step(1.0/120,input:Controls())}
  expect(abs(g.foes[0].elevation-g.layout.height(g.foes[0].p))<0.01,"falling engineer lands on its local rooftop or street height")
  g.foes=[Foe(id:9401,p:V2(x:0,y:-4),hp:6,speed:1,gait:0,kind:.engineer)];g.hero=V2(x:7,y:-4);g.heroElevation=0
  let calmStart=g.foes[0].p;g.step(0.1,input:Controls());let calmMove=(g.foes[0].p-calmStart).length
  g.shots=[Shot(id:9402,p:V2(x:2,y:-4),v:V2(x:-100,y:0),ttl:1,damage:1,kind:nil)];g.step(0.025,input:Controls())
  expect(g.foes[0].enraged && abs(g.foes[0].hp-5.85)<0.001,"first shot meets calm engineer resistance then triggers rage")
  let angryStart=g.foes[0].p;g.step(0.1,input:Controls())
  expect((g.foes[0].p-angryStart).length>calmMove*4,"shot engineer changes from slow walk to rapid sprint")
  g.shots=[Shot(id:9403,p:g.foes[0].p+V2(x:1,y:0),v:V2(x:-100,y:0),ttl:1,damage:1,kind:nil)];g.step(0.02,input:Controls())
  expect(abs(g.foes[0].hp-4.85)<0.001,"enraged engineer takes ordinary projectile damage without calm resistance")
  let fallingHeight=g.foes[0].elevation;g.step(0.01,input:Controls(pause:true));g.step(2,input:Controls());expect(g.foes[0].elevation==fallingHeight,"pause freezes engineer gravity and behavior")
  g.reset();g.round=21;g.beginRound();g.phase = .cleared;enterLateBonus(g,SideRoomOffer(kind:.treasure,p:g.layout.sideRoute(onLeft:true)))
  expect(g.sourceLoot!.clusterStarts==25 && g.pickups.count>=75 && g.pickups.allSatisfy{g.layout.walkable($0.p,clearance:0.28)},"urban treasure remains reachable on both street and rooftop without overlap with electrical posts")
  g.reset();g.round=21;g.beginRound();g.combatSpawningHeld=true;g.hero=V2(x:6,y:-4);g.invulnerable=999
  g.shots=[Shot(id:9450,p:V2(x:2,y:-3),v:V2(x:-100,y:0),ttl:1,damage:1,kind:nil,height:0.53)];g.step(0.06,input:Controls())
  expect(g.shots.isEmpty,"street-height projectile stops at solid raised terrain instead of travelling through the rooftop block")
  let pilot=ArenaNavigation();g.phase = .cleared;enterLateBonus(g,SideRoomOffer(kind:.treasure,p:g.layout.sideRoute(onLeft:true)))
  g.hero=V2(x:0.48,y:1.49);g.heroElevation=0
  let roofTarget=V2(x:-7,y:-1.3);var routedRoof=false
  for _ in 0..<900 {
   pilot.update(layout:g.layout,target:roofTarget,dt:1.0/60)
   g.step(1.0/60,input:Controls(move:pilot.direction(from:g.hero,to:roofTarget,layout:g.layout)))
   if g.heroElevation>1.75 && (g.hero-roofTarget).length<1.1 {routedRoof=true;break}
  }
  expect(routedRoof,"navigation routes around a stair sidewall to its actual foot instead of stalling against a fractional-height ledge")
  let street=ArenaLayout(kind:.street)
  expect(street.height(V2(x:10,y:0))==1.4 && abs(street.height(V2(x:10,y:-3.5))-0.7)<0.001 && abs(street.height(V2(x:10,y:3.5))-0.7)<0.001,"street has a side platform with two opposing real stair gradients")
  expect(!street.canTraverse(V2(x:7.9,y:0),V2(x:8.1,y:0)) && !street.canTraverse(V2(x:7.9,y:4.8),V2(x:8.1,y:4.8)),"street platform and low stair sides cannot be climbed through their sidewall")
  g.reset();g.round=24;g.beginRound();g.phase = .cleared;g.advanceCombatRound();expect(g.round==25 && g.layout.kind == .street,"urban exit advances into Fish in a Barrel street round")
  g.hero=V2(x:10,y:-5.5);g.heroElevation=0;g.combatSpawningHeld=true;g.barrelClock=999;g.invulnerable=999
  for _ in 0..<100 {g.step(1.0/120,input:Controls(move:V2(x:0,y:1)))}
  expect(g.hero.y > -2 && g.heroElevation==1.4,"north street staircase lifts the player onto the side platform")
  g.hero=V2(x:10,y:5.5);g.heroElevation=0
  for _ in 0..<100 {g.step(1.0/120,input:Controls(move:V2(x:0,y:-1)))}
  expect(g.hero.y<2 && g.heroElevation==1.4,"south street staircase provides an independent way onto the platform")
  g.hero=V2(x:10,y:0);g.heroElevation=1.4;g.foes=[Foe(id:9500,p:V2(x:0,y:0),hp:999,speed:3,gait:0)]
  var reachedStreetDeck=false
  for _ in 0..<1500 {g.step(1.0/60,input:Controls());if let f=g.foes.first,abs(f.elevation-1.4)<0.1,(f.p-g.hero).length<0.65 {reachedStreetDeck=true}}
  expect(reachedStreetDeck,"ground zombies route to the street deck through opposing stair entrances")
  g.reset();g.round=25;g.hero=V2(x:-9,y:6);g.beginRound();g.combatSpawningHeld=true;g.barrelClock=999;g.invulnerable=999
  g.barrels=[FlamingBarrel(id:9501,p:V2(x:0,y:0),v:.zero,elevation:4,ttl:100)]
  var sawBounce=false
  for _ in 0..<180 {g.step(1.0/120,input:Controls());if g.barrels[0].bounces>0 && g.barrels[0].verticalSpeed>0 {sawBounce=true}}
  expect(sawBounce,"roof barrel has a genuine falling and rebounding interval instead of a cosmetic ground animation")
  g.barrels=[FlamingBarrel(id:9502,p:V2(x:7.8,y:0),v:V2(x:4,y:0),elevation:0,ttl:100)];g.step(0.1,input:Controls())
  expect(g.barrels[0].p.x<8 && g.barrels[0].elevation==0 && g.barrels[0].v.x<0,"rolling barrel bounces from a raised ledge instead of teleporting onto the platform")
  let barrelPos=g.barrels[0].p,barrelTTL=g.barrels[0].ttl;g.step(0.01,input:Controls(pause:true));g.step(2,input:Controls())
  expect(g.barrels[0].p==barrelPos && g.barrels[0].ttl==barrelTTL,"pause freezes rolling barrels and their explosion countdown")
  g.step(0.01,input:Controls(accept:true));g.barrels=[FlamingBarrel(id:9503,p:.zero,v:.zero,elevation:0,ttl:100)];g.foes=[]
  g.shots=[Shot(id:9504,p:V2(x:-4,y:0),v:V2(x:100,y:0),ttl:1,damage:1,kind:nil)];g.step(0.08,input:Controls())
  expect(g.barrels.isEmpty && g.shots.isEmpty,"fast ordinary bullet hits and detonates a barrel along its actual projectile path")
  g.barrels=[FlamingBarrel(id:9505,p:.zero,v:.zero,elevation:0,ttl:100),FlamingBarrel(id:9506,p:V2(x:2,y:0),v:.zero,elevation:0,ttl:100)]
  g.foes=[Foe(id:9507,p:V2(x:3.1,y:0),hp:99,speed:0,gait:0)];g.detonateBarrels([9505]);g.step(0.01,input:Controls())
  expect(g.barrels.isEmpty && g.foes.isEmpty,"barrel explosions chain once and destroy nearby zombies")
  g.barrels=[FlamingBarrel(id:9508,p:.zero,v:.zero,elevation:4,ttl:0.001)];g.hero = .zero;g.heroElevation=0;g.invulnerable=0;g.playerRoster.current.bodyShield=nil;let groundLives=g.lives;g.step(0.01,input:Controls())
  expect(g.barrels.isEmpty && g.lives==groundLives,"airborne barrel explosion does not damage a player a full storey below")
  g.barrels=[FlamingBarrel(id:9509,p:.zero,v:.zero,elevation:0,ttl:0.001)];g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.step(0.01,input:Controls())
  settle(g);expect(g.lives==groundLives-1 && g.deaths==1,"close timed barrel explosion consumes one real life")
  g.godMode=true;g.hero = .zero;g.heroElevation=0;g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.apply(.ray);g.barrels=[FlamingBarrel(id:9510,p:.zero,v:.zero,elevation:0,ttl:0.001)];g.step(0.01,input:Controls())
  expect(g.trainingHits==1 && g.weapon == .ray && g.hero == .zero,"barrel explosion counts a virtual Godmode hit while retaining weapon and position")
  g.invulnerable=0;g.playerRoster.current.bodyShield=nil;let hitStock=g.trainingHits;g.bombs=1;g.barrels=[FlamingBarrel(id:9511,p:.zero,v:.zero,elevation:0)];g.step(0.01,input:Controls(bomb:true))
  expect(g.barrels.isEmpty && g.trainingHits==hitStock && g.bombs==0,"own bomb clears nearby barrels without turning a defensive bomb into self-damage")
  g.hero=V2(x:-9,y:6);g.invulnerable=99;g.barrels=[FlamingBarrel(id:9512,p:V2(x:4,y:0),v:.zero,elevation:0,ttl:100)];g.foes=[Foe(id:9513,p:V2(x:-1,y:0),hp:1,speed:0,gait:0)]
  g.shots=[Shot(id:9514,p:V2(x:-4,y:0),v:V2(x:100,y:0),ttl:1,damage:1,kind:nil)];g.step(0.1,input:Controls())
  expect(g.foes.isEmpty && g.barrels.count==1,"zombie in front of a barrel intercepts the bullet before the barrel behind it")
  g.phase = .cleared;enterLateBonus(g,SideRoomOffer(kind:.armory,p:g.layout.sideRoute(onLeft:true)));expect(g.barrels.isEmpty && g.pickups.allSatisfy{g.layout.walkable($0.p,clearance:0.28)},"street armory removes active barrels and provides reachable items on both levels")
  g.barrels=[FlamingBarrel(id:9515,p:.zero,v:.zero)];g.reset();expect(g.barrels.isEmpty && !g.barrelDamagePending,"new run clears barrels and any pending blast damage")
  g.godMode=false;g.reset();g.round=25;g.beginRound();g.hero = .zero;g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.combatSpawningHeld=true;g.barrelClock=999
  g.barrels=[FlamingBarrel(id:9520,p:V2(x:1.5,y:0),v:.zero,elevation:0,ttl:100)]
  g.foes=[Foe(id:9521,p:V2(x:-4,y:5),hp:10,speed:0,gait:0),Foe(id:9522,p:V2(x:1.4,y:0),hp:4,speed:0,gait:0)]
  g.shots=[Shot(id:9523,p:.zero,v:V2(x:30,y:0),ttl:1,damage:8,kind:.rocket)];g.step(0.06,input:Controls())
  settle(g);expect(g.lives==2 && g.deaths==1 && g.barrels.isEmpty,"rocket-triggered close barrel blast safely resolves one respawn after projectile iteration without corrupting enemy indices")
  let facility=ArenaLayout(kind:.facility)
  expect(FacilityLayout.tanks.count==2 && FacilityLayout.tanks.allSatisfy{!facility.walkable($0)} && facility.height(.zero)==0,"snow facility has two solid full-height tank footprints on a flat yard")
  expect(facility.lineClear(V2(x:4,y:-6),V2(x:4,y:5)) && !facility.lineClear(V2(x:2,y:-6),V2(x:2,y:5)),"space between fuel tanks is traversable while a route through a tank is blocked")
  g.reset();g.round=28;g.beginRound();g.phase = .cleared;g.advanceCombatRound();expect(g.round==29 && g.layout.kind == .facility && g.barrels.isEmpty,"street exit enters the snowy facility without carrying fire barrels")
  g.combatSpawningHeld=true;g.hero=V2(x:0,y:-4);g.invulnerable=999;g.foes=[Foe(id:9600,p:V2(x:8,y:-2),hp:100,speed:3,gait:0)]
  var gotAroundTank=false
  for _ in 0..<1800 {g.step(1.0/60,input:Controls());if let f=g.foes.first,(f.p-g.hero).length<0.65 {gotAroundTank=true}}
  expect(gotAroundTank,"horde finds a real route around both tank bodies")
  g.foes=[Foe(id:9601,p:V2(x:2,y:3.8),hp:10,speed:0,gait:0)];g.shots=[Shot(id:9602,p:V2(x:2,y:-5),v:V2(x:0,y:100),ttl:1,damage:99,kind:nil)];g.step(0.1,input:Controls())
  expect(g.foes[0].hp==10 && g.shots.isEmpty,"fuel tank stops a fast projectile before the enemy behind it")
  g.round=30;g.beginRound();g.hero=V2(x:-9,y:6);g.invulnerable=999;var sawMartyr=false,sawFur=false
  for _ in 0..<100 {g.combatSpawningHeld=false;g.stepCombatSpawns(0.7);sawMartyr = sawMartyr || g.foes.contains{$0.kind == .martyr};sawFur = sawFur || g.foes.contains{$0.kind == .sasquatch}}
  expect(sawMartyr && sawFur,"round thirty introduces explosive martyrs and nonexplosive sasquatches")
  g.foes=[Foe(id:9603,p:V2(x:-5,y:0),hp:0,speed:0,gait:0,kind:.martyr),Foe(id:9604,p:V2(x:-3,y:0),hp:30,speed:0,gait:0,kind:.martyr),Foe(id:9605,p:V2(x:-1,y:0),hp:8,speed:0,gait:0)]
  g.pickups=[];g.effects=[];g.resolveDefeatedFoes()
  expect(g.foes.isEmpty && g.pickups.isEmpty && g.effects.filter{$0.color==4}.count==2,"martyr explosions chain through nearby enemies once without fabricating ordinary body drops")
  g.hero=V2(x:0,y:4);g.heroElevation=0;g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.godMode=false;g.foes=[Foe(id:9606,p:V2(x:0,y:3),hp:0,speed:0,gait:0,kind:.martyr)];let martyrLives=g.lives;g.resolveDefeatedFoes();g.resolveMartyrDamage()
  settle(g);expect(g.lives==martyrLives-1 && g.deaths==1,"close martyr death explosion causes one normal life loss after safe chain processing")
  g.godMode=true;g.hero=V2(x:0,y:4);g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.apply(.deathMachine);g.foes=[Foe(id:9607,p:V2(x:0,y:3),hp:0,speed:0,gait:0,kind:.martyr)];g.resolveDefeatedFoes();g.resolveMartyrDamage()
  expect(g.trainingHits==1 && g.weapon == .deathMachine && g.hero==V2(x:0,y:4),"martyr explosion respects Godmode and preserves weapon and position")
  g.hero=V2(x:1.8,y:2.2);g.invulnerable=0;g.playerRoster.current.bodyShield=nil;let protectedHits=g.trainingHits
  g.foes=[Foe(id:9608,p:V2(x:0.4,y:1.0),hp:0,speed:0,gait:0,kind:.martyr)];g.resolveDefeatedFoes();g.resolveMartyrDamage()
  expect(g.trainingHits==protectedHits,"solid fuel tank blocks a martyr blast line instead of damaging through its body")
  g.hero=V2(x:-3,y:4);g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.foes=[Foe(id:9609,p:V2(x:-3,y:4.5),hp:1,speed:0,gait:0,kind:.martyr)];g.bombs=1;g.combatSpawningHeld=true;g.step(0.001,input:Controls(bomb:true))
  expect(g.foes.isEmpty && g.trainingHits==protectedHits && !g.martyrDamagePending,"defensive bomb kills a nearby martyr without secondary self-damage")
  g.phase = .cleared;enterLateBonus(g,SideRoomOffer(kind:.treasure,p:g.layout.sideRoute(onLeft:true)))
  expect(g.sourceLoot!.clusterStarts==25 && g.pickups.count>=75 && g.pickups.allSatisfy{g.layout.walkable($0.p,clearance:0.28)},"facility treasure remains reachable between tanks spikes and room chests")
  g.reset();g.round=31;g.beginRound();g.invulnerable=999;g.hero=V2(x:-9,y:6)
  expect(g.ordinaryWaveKind() == .zombie && CombatSpawnFlow.unlocked(35).contains(.sasquatch),"later ordinary groups keep zombies while unlocked moss uses its own mini-boss timer")
  g.martyrDamagePending=true;g.reset();expect(!g.martyrDamagePending,"new run clears any deferred martyr explosion damage")
  let forest=ArenaLayout(kind:.forest)
  expect(!forest.walkable(.zero) && forest.walkable(forest.exit) && forest.walkable(forest.sideRoute(onLeft:true)),"snow forest has a solid central statue and accessible exits")
  g.godMode=false;g.reset();g.round=32;g.beginRound();g.phase = .cleared;g.advanceCombatRound();expect(g.round==33 && g.layout.kind == .forest,"facility exit advances into the snowy forest")
  g.hero=V2(x:0,y:-4);g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.apply(.ray);g.houndHit()
  settle(g);expect(g.lives==3 && g.dogWounds==1 && g.deaths==0 && g.weapon == .ray,"first hound bite wounds the player without losing a life weapon or position")
  g.houndHit();expect(g.dogWounds==1 && g.lives==3,"first bite protection prevents instant double damage from one contact frame")
  g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.houndHit();settle(g);expect(g.lives==3 && g.deaths==0 && g.dogWounds==2,"second separated hound bite remains nonlethal")
  g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.houndHit();settle(g);expect(g.lives==2 && g.deaths==1 && g.dogWounds==0,"third separated hound bite causes one normal death and clears the wounds")
  g.godMode=true;g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.houndHit();expect(g.trainingHits==0 && g.dogWounds==1,"Godmode also needs the first nonlethal hound bite before counting a virtual life")
  g.invulnerable=0;g.playerRoster.current.bodyShield=nil;let dogPos=g.hero;g.apply(.ray);g.houndHit()
  expect(g.trainingHits==0 && g.dogWounds==2,"Godmode also retains two nonlethal bites")
  g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.houndHit()
  expect(g.trainingHits==1 && g.lives==2 && g.hero==dogPos && g.weapon == .ray && g.dogWounds==0,"third Godmode hound bite counts one virtual life while keeping actual resources")
  g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.houndHit();g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.godMode=false;g.loseLife();settle(g);expect(g.dogWounds==0 && g.deaths==2,"other lethal damage also clears a preexisting dog wound")
  g.reset();g.round=34;g.beginRound();g.invulnerable=999;g.combatSpawningHeld=false;g.step(0.01,input:Controls());expect(g.foes.first?.kind == .hound && g.foes[0].hp==2,"round thirty-four introduces weak fast hellhounds")
  g.combatSpawningHeld=true;g.hero=V2(x:0,y:-4);g.foes=[Foe(id:9700,p:V2(x:5,y:-4),hp:2,speed:1,gait:0,kind:.hound)];let dogStart=g.foes[0].p;g.step(0.1,input:Controls());expect((g.foes[0].p-dogStart).length>0.6,"hellhound movement is faster than ordinary pursuit")
  g.foes[0].hp=0;g.effects=[];g.resolveDefeatedFoes();expect(g.foes.isEmpty && g.effects.contains{$0.color==5} && !g.martyrDamagePending,"hellhound death creates its own visual burst without inventing martyr blast damage")
  g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.dogWounds=0;g.foes=[Foe(id:9701,p:g.hero,hp:2,speed:0,gait:0,kind:.hound)];g.step(0.001,input:Controls());expect(g.dogWounds==1 && g.deaths==0,"real hound body contact reaches the three-bite damage path")
  g.phase = .cleared;enterLateBonus(g,SideRoomOffer(kind:.treasure,p:g.layout.sideRoute(onLeft:true)))
  expect(g.sourceLoot!.clusterStarts==25 && g.pickups.count>=75 && g.pickups.allSatisfy{g.layout.walkable($0.p,clearance:0.28)} && g.dogWounds==1,"forest treasure is reachable and a safe room does not silently erase the existing wound")
  g.reset();expect(g.dogWounds==0,"new run clears the hound wound state")
  let jungle=ArenaLayout(kind:.jungle)
  expect(!jungle.walkable(.zero) && jungle.obstacles.first!.height>5 && jungle.walkable(jungle.exit),"tropical jungle has a solid tall rocket and a reachable final exit")
  g.reset();g.round=36;g.beginRound();g.phase = .cleared;g.advanceCombatRound();expect(g.round==37 && g.layout.kind == .jungle,"forest exit advances into tropical jungle round thirty-seven")
  g.round=40;g.beginRound();g.phase = .playing;g.combatSpawningHeld=true;g.invulnerable=999
  g.step(0.01,input:Controls());expect(!g.silverbackStarted && g.silverback==nil,"round forty starts as an ordinary wave rather than prematurely spawning the boss")
  g.finishCombatSpawning();g.foes=[];g.step(0.01,input:Controls());expect(g.silverbackStarted && g.silverbacks.isEmpty && g.bossArrivalClock?.clock==0 && g.phase == .playing,"exhausted round forty wave begins the source introduction without an immediate boss body or open exit")
  g.hero=jungle.exit;g.step(0.01,input:Controls());expect(g.phase == .playing && g.round==40,"standing on final exit cannot bypass a living Silverback")
  g.fixtureSilverbacks();g.hero=V2(x:0,y:-5);g.silverback!.arrival=nil;g.silverback!.p=V2(x:0,y:5)
  var bossRouteSafe=true,bossReached=false
  for _ in 0..<1200 {g.step(1.0/60,input:Controls());if !g.layout.walkable(g.silverback!.p,clearance:0.85){bossRouteSafe=false};if (g.silverback!.p-g.hero).length<1.3 {bossReached=true}}
  expect(bossRouteSafe && bossReached,"large Silverback navigation routes around the rocket without penetrating its collision footprint")
  g.hero=V2(x:-5,y:-5);g.silverback!.p=V2(x:5,y:-5);g.silverback!.motion = .pursuit;g.silverback!.clock=3.49;g.step(0.02,input:Controls())
  expect(g.silverback!.motion == .windup,"Silverback signals its impending charge before accelerating")
  g.step(0.81,input:Controls());let chargeStart=g.silverback!.p;g.step(0.1,input:Controls());expect(g.silverback!.motion == .charge && (g.silverback!.p-chargeStart).length>0.5,"telegraphed Silverback charge moves rapidly in its committed direction")
  let bossP=g.silverback!.p,bossClock=g.silverback!.clock;g.step(0.01,input:Controls(pause:true));g.step(2,input:Controls());expect(g.silverback!.p==bossP && g.silverback!.clock==bossClock,"pause freezes boss motion state and timing")
  g.step(0.01,input:Controls(accept:true));g.silverback!.p=V2(x:4,y:0);g.silverback!.motion = .recovery;g.silverback!.clock=0;g.silverback!.hp=1200;g.hero=V2(x:-9,y:5);g.foes=[]
  g.shots=[Shot(id:9800,p:V2(x:2,y:0),v:V2(x:100,y:0),ttl:1,damage:2,kind:.deathMachine)];g.step(0.05,input:Controls());expect(g.silverback!.hp==1198,"swept player projectile damages the actual boss body")
  g.silverback!.p=V2(x:7,y:-4);g.silverback!.hp=1200;g.foes=[Foe(id:9801,p:V2(x:3,y:-4),hp:1,speed:0,gait:0)]
  g.shots=[Shot(id:9802,p:V2(x:1,y:-4),v:V2(x:100,y:0),ttl:1,damage:1,kind:nil)];g.step(0.08,input:Controls());expect(g.foes.isEmpty && g.silverback!.hp==1200,"ordinary enemy before the Silverback intercepts a bullet instead of allowing a remote boss hit")
  g.silverback!.p=V2(x:0,y:4);g.shots=[Shot(id:9803,p:V2(x:0,y:-4),v:V2(x:0,y:100),ttl:1,damage:99,kind:nil)];g.step(0.1,input:Controls());expect(g.silverback!.hp==1200,"rocket scenery blocks a projectile aimed at the Silverback behind it")
  g.hero=V2(x:7,y:0);g.silverback!.p=V2(x:6,y:0);g.apply(.orb);let shieldsBefore=g.orbShields.count;g.resolveSilverbackOrbs();expect(g.orbShields.count<shieldsBefore && g.silverback!.hp<1200 && g.silverback!.hp>0,"electric support consumes real charges to damage but never instantly deletes the boss")
  g.godMode=false;g.hero=V2(x:5,y:0);g.silverback!.p=V2(x:5.5,y:0);g.invulnerable=0;g.playerRoster.current.bodyShield=nil;let bossLives=g.lives;g.resolveSilverbackContact();settle(g);expect(g.lives==bossLives-1 && g.deaths==1,"boss body contact costs one normal life without resetting boss health")
  g.godMode=true;g.hero=V2(x:5,y:0);g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.apply(.ray);g.resolveSilverbackContact();expect(g.trainingHits==1 && g.weapon == .ray && g.hero==V2(x:5,y:0),"boss contact respects Godmode virtual life and retained weapon and position")
  g.hero=V2(x:-9,y:5);g.silverback!.p=V2(x:7,y:-4);g.silverback!.hp=1200;g.bombs=1;g.step(0.001,input:Controls(bomb:true));expect(g.silverback!.hp==1080 && g.bombs==0,"bomb damages a durable Silverback instead of treating it as an ordinary one-hit enemy")
  g.silverback!.p=V2(x:7,y:5);g.foes=[Foe(id:9804,p:V2(x:6,y:5),hp:0,speed:0,gait:0,kind:.martyr)];let beforeMartyr=g.silverback!.hp;g.resolveDefeatedFoes();expect(g.silverback!.hp<beforeMartyr && g.silverback!.hp>0,"nearby martyr death can harm the Silverback without instantly killing it")
  g.damageSilverback(9999);g.step(0,input:Controls());let victoryScore=g.score;g.step(0,input:Controls());expect(g.score==victoryScore && g.silverback!.deathAwarded,"boss death reward is issued once even across zero-duration frames")
  g.step(2.1,input:Controls());expect(g.phase == .cleared && g.silverback!.hp==0 && g.foes.isEmpty,"defeated Silverback opens the final exit after its death animation")
  g.clearClock=4;g.hero=g.suggestedExit;g.heroElevation=g.layout.height(g.hero);g.step(0.01,input:Controls());finishTravel(g);expect(g.phase == .cleared && g.bossVictory != nil && g.round==40 && g.arenaTransit==nil,"taking the ready post-boss pad starts victory before its movie and final blackout")
  g.reset();expect(!g.silverbackStarted && g.silverback==nil,"new run removes all boss encounter and victory state")
  let legacy=Data("{\"godMode\":true,\"cameraMode\":\"overview\",\"zoom\":2,\"brighter\":true}".utf8),migrated=GameSettings.decode(legacy)
  expect(migrated.godMode && migrated.cameraMode == .following && migrated.zoom == .normal && migrated.brighter && migrated.soundEnabled,"legacy camera overrides are retired while Godmode brightness and sound preferences survive")
  let damagedSound=Data("{\"godMode\":true,\"cameraMode\":\"overview\",\"zoom\":2,\"brighter\":true,\"soundEnabled\":\"bad\"}".utf8)
  expect(GameSettings.decode(damagedSound)==migrated,"invalid new sound field cannot erase otherwise valid saved preferences")
  var soundPrefs=migrated;soundPrefs.adjustAudio(row:0,delta:1);expect(!soundPrefs.soundEnabled && soundPrefs.godMode && soundPrefs.cameraMode == .following,"sound toggle leaves all other preferences intact")
  expect(GameSettings.decode(try! JSONEncoder().encode(soundPrefs))==soundPrefs,"sound disabled state survives settings encoding and decoding")
  var soundMenu=GameMenu();soundMenu.openSettings(phase:.paused)
  expect(soundMenu.count==5 && soundMenu.handle(Controls(accept:true,menuRow:2),phase:.paused) == .none && soundMenu.audioOpen,"the independently focusable sound row opens separate effects/music controls")
  _=soundMenu.handle(Controls(back:true),phase:.paused);_=soundMenu.handle(Controls(accept:true,menuRow:4),phase:.paused);expect(!soundMenu.settingsOpen,"last Back row leaves settings without resuming the game")
  var soundSafe=true,wavSafe=true
  for cue in AudioCue.allCases {
   let samples=AudioSynth.samples(cue),wav=AudioSynth.wav(cue)
   let peak=samples.map{abs($0)}.max() ?? 0,rms=sqrt(samples.reduce(0){$0+$1*$1}/Double(samples.count))
   if samples.isEmpty || !samples.allSatisfy({$0.isFinite}) || peak>0.91 || peak<0.02 || rms<0.005 || abs(samples.first!)>0.001 || abs(samples.last!)>0.001 {soundSafe=false}
   if wav.count != samples.count*2+44 || String(data:wav.prefix(4),encoding:.ascii) != "RIFF" || String(data:wav.subdata(in:8..<12),encoding:.ascii) != "WAVE" {wavSafe=false}
  }
  expect(soundSafe,"all original synthesized sounds have finite bounded non-silent PCM with quiet endpoints")
  expect(wavSafe,"all effect samples encode as correctly sized PCM WAV containers")
  expect(AudioSynth.wav(.shot)==AudioSynth.wav(.shot),"synthesized effects are deterministic and do not draw randomness from gameplay")
  g.reset();_=g.takeAudioEvents();g.combatSpawningHeld=true;g.step(0.01,input:Controls(aim:V2(x:1,y:0)))
  expect(g.takeAudioEvents().contains(.shot) && g.takeAudioEvents().isEmpty,"a real firing volley emits one consumable audio event without replaying it")
  for _ in 0..<1000 {g.emitAudio(.shot)};expect(g.takeAudioEvents().count<=32,"unconsumed audio events remain bounded during headless long-run checks")
  g.step(0.01,input:Controls(pause:true));_=g.takeAudioEvents();g.step(2,input:Controls(aim:V2(x:1,y:0),bomb:true))
  expect(g.takeAudioEvents().isEmpty,"paused simulation cannot create stale weapon or explosion audio events")
  g.step(0.01,input:Controls(accept:true));g.award(200000);g.advanceDirectedRewards(1.3);g.collectDirectedRewards();expect(g.takeAudioEvents().contains(.life),"score-threshold extra life emits the same distinct life cue as a life pickup")
  // Distances exercise actual movement, not just the configured speed value.
  g.reset();g.hero = .zero;g.foes=[];g.combatSpawningHeld=true
  for _ in 0..<30 {g.step(1.0/60,input:Controls(move:V2(x:1,y:0)))}
  expect(abs(g.hero.x-3.2)<0.001 && abs(g.hero.y)<0.001,"new default covers3.2 units in half a second with no acceleration delay")
  g.reset();g.hero = .zero;g.combatSpawningHeld=true
  for _ in 0..<30 {g.step(1.0/60,input:Controls(move:V2(x:0.5,y:0)))}
  expect(abs(g.hero.x-1.6)<0.001,"partial stick retains fine analogue movement after the speed increase")
  g.reset();g.hero = .zero;g.combatSpawningHeld=true
  for _ in 0..<30 {g.step(1.0/60,input:Controls(move:V2(x:1,y:1)))}
  expect(abs(g.hero.length-3.2)<0.001,"diagonal movement stays normalized at the faster default")
  g.boots=10;expect(g.moveSpeed==9.8,"boots remain noticeably faster than the revised baseline")
  var larger=CameraRig();larger.update(hero:.zero,settings:GameSettings(),aspect:16.0/9,dt:0)
  expect(abs(larger.scale-5.0)<0.001,"normal tracking view brings the world closer while fixed overview remains available")
  var arrivalsSafe=true,continuous=true,heightSafe=true,allCompleted=true
  let entranceRounds=[1,5,9,13,17,21,25,29,33,37]
  for round in entranceRounds {
   let l=ArenaLayout.forRound(round)
   for gate in 0..<l.enemyEntranceCount {for lane in [-1.0,0.0,1.0] {
    var arrival=l.enemyArrival(index:gate,lane:lane),p=arrival.start.p,h=arrival.start.height
    if l.contains(p) || !l.walkable(arrival.end.p,clearance:0.34) {print("BAD ENTRY END",round,gate,lane,p,arrival.end.p)}
    arrivalsSafe = arrivalsSafe && !l.contains(p) && l.walkable(arrival.end.p,clearance:0.34)
    heightSafe = heightSafe && abs(arrival.end.height-l.height(arrival.end.p))<0.001
    var done=false
    for _ in 0..<1800 {
     let before=p,beforeH=h;done=arrival.advance(position:&p,height:&h,distance:2.1/120)
     continuous = continuous && (p-before).length<=2.1/120+0.000001 && abs(h-beforeH)<0.03
     if l.contains(p,margin:0.34) {if !l.walkable(p,clearance:0.29) {print("BAD ENTRY PATH",round,gate,lane,p)};arrivalsSafe = arrivalsSafe && l.walkable(p,clearance:0.29)}
     if done {break}
    }
    allCompleted = allCompleted && done && (p-arrival.end.p).length<0.0001
   }}
  }
  expect(arrivalsSafe,"every entrance across ten arenas begins outside and crosses only clear ground into a walkable endpoint")
  expect(continuous,"all132 route variants consume distance continuously without boundary teleports or vertical snapping")
  expect(heightSafe && allCompleted,"all exterior paths finish at the exact local floor including both prison bridges")
  let islandEntry=ArenaLayout(kind:.island)
  expect((0..<6).map{islandEntry.enemyArrival(index:$0)}.filter{$0.kind == .water}.count==4 && (0..<6).map{islandEntry.enemyArrival(index:$0)}.filter{$0.kind == .pier}.count==2,"island offers four sea approaches and both existing piers")
  expect(islandEntry.enemyArrival(index:0).start.height < -1.2,"sea arrivals begin fully submerged and rise continuously rather than appearing on the beach")
  g.reset();g.hero = .zero;g.invulnerable=999;g.combatSpawningHeld=false;g.step(0.001,input:Controls());let incoming=g.foes[0]
  expect(incoming.arrival != nil && !g.layout.contains(incoming.p),"actual first-wave spawning creates an exterior approach instead of an interior zombie")
  g.combatSpawningHeld=true
  g.step(0.01,input:Controls(pause:true));let pausedIncoming=g.foes[0]
  g.step(2,input:Controls());expect(g.foes[0].p==pausedIncoming.p && g.foes[0].elevation==pausedIncoming.elevation,"pause freezes incoming paths and shoreline emergence")
  g.step(0,input:Controls(accept:true));var enteredNormally=false,arrivalContinuous=true
  for _ in 0..<1600 {let old=g.foes[0].p;g.step(1.0/120,input:Controls());arrivalContinuous = arrivalContinuous && (g.foes[0].p-old).length<0.07;if g.foes[0].arrival==nil {enteredNormally=true;break}}
  expect(enteredNormally && arrivalContinuous && g.layout.walkable(g.foes[0].p),"real spawning hands over to normal pursuit without a final clamp jump")
  g.foes=[incoming];g.foes[0].hp=0;g.pickups=[];g.resolveDefeatedFoes()
  expect(g.pickups.isEmpty,"killing an incoming enemy does not invent a fund in the sea or advance the source loot thread")
  g.reset();g.round=9;g.beginRound();g.hero=g.layout.spawn;g.invulnerable=999;g.combatSpawningHeld=true
  g.foes=[g.arrivingFoe(kind:.prisoner,hp:99,speed:3,entrance:0,lane:0)]
  var reachedFromBridge=false
  for _ in 0..<3600 {g.step(1.0/60,input:Controls());if (g.foes[0].p-g.hero).length<0.65 && abs(g.foes[0].elevation-g.heroElevation)<0.3 {reachedFromBridge=true;break}}
  expect(reachedFromBridge,"enemy walks the exterior prison bridge and uses the real catwalk and descent to reach the court")
  g.reset();g.round=22;g.beginRound();g.combatSpawningHeld=false;g.invulnerable=999;g.step(0.001,input:Controls())
  expect(g.foes[0].kind == .engineer && g.foes[0].elevation>7 && (g.foes[0].p-g.hero).length>=3,"Downpour remains an actual airborne entrance with reaction space rather than a ground pop-in")
  g.reset();g.round=40;g.beginRound();g.finishCombatSpawning();g.foes=[];g.step(0.001,input:Controls())
  g.fixtureSilverbacks();expect(g.silverback?.arrival != nil && !g.layout.contains(g.silverback!.p),"controlled Silverback pose also uses the exterior jungle trail")
  let startBoss=g.silverback!.p;g.combatSpawningHeld=true;g.step(0.1,input:Controls())
  expect((g.silverback!.p-startBoss).length<=0.271 && g.silverback!.motion == .pursuit && g.silverback!.clock==0,"boss approach has continuous movement and cannot charge before reaching the arena")
  g.foes=[];_=g.admitWaveEnemy(side:.north,kind:.martyr)
  expect(!g.foes.isEmpty && g.foes.allSatisfy{$0.kind == .engineer ? $0.elevation>7:$0.arrival != nil && !g.layout.contains($0.p)},"boss reinforcements use the same exterior entrance or falling pipeline")
  g.reset();expect(g.foes.isEmpty && g.silverback==nil,"reset removes pending approaches with their owning enemies")
  var shoreLootSafe=true
  for round in entranceRounds {g.reset();g.round=round;g.beginRound();g.pickups=[]
   for gate in 0..<g.layout.enemyEntranceCount {let f=g.arrivingFoe(kind:.zombie,hp:1,speed:2,entrance:gate,lane:0);g.kill(f)}
   shoreLootSafe = shoreLootSafe && g.pickups.isEmpty
  }
  expect(shoreLootSafe,"exterior kills across ten arenas do not manufacture loot outside the independent source threads")
  g.reset();g.invulnerable=999;g.finishCombatSpawning();g.foes=[g.arrivingFoe(kind:.zombie,hp:99,speed:2,entrance:0,lane:0)];g.step(0.01,input:Controls())
  expect(g.phase == .playing && g.foes[0].arrival != nil,"a wave cannot finish while living enemies are still approaching from outside")
  func emptyWeapons(_ gun:PickupKind?=nil)->GameCore {let c=GameCore();c.reset();c.invulnerable=999;c.combatSpawningHeld=true;c.hero=V2(x:0,y:-3);if let gun {c.apply(gun)};return c}
  var cadence:[Int]=[]
  for rate in [30,60,120] {
   let c=emptyWeapons()
   for _ in 0..<rate {c.step(1/Double(rate),input:Controls(aim:V2(x:1,y:0)))}
   cadence.append(c.shots.count)
  }
  expect(cadence.max()!-cadence.min()!<=1 && cadence.min()!>=45,"M60 firing cadence stays consistent at30 60 and120 simulation updates")
  let rayCadence=emptyWeapons(.ray);for _ in 0..<60 {rayCadence.step(1.0/60,input:Controls(aim:V2(x:1,y:0)))}
  expect(rayCadence.shots.count<=8 && cadence.min()!>rayCadence.shots.count*5,"Ray Gun has its own slower heavy-shot cadence instead of copying the M60")
  let nearFirst=emptyWeapons();nearFirst.foes=[Foe(id:20001,p:V2(x:4,y:-3),hp:10,speed:0,gait:0),Foe(id:20002,p:V2(x:2,y:-3),hp:10,speed:0,gait:0)]
  nearFirst.shots=[Shot(id:20003,p:V2(x:0,y:-3),v:V2(x:100,y:0),ttl:1,damage:1,kind:nil)];nearFirst.step(0.05,input:Controls())
  expect(nearFirst.foes[0].hp==10 && nearFirst.foes[1].hp==9,"nearest projectile contact wins even when enemies are stored in reverse spatial order")
  let bounce=emptyWeapons();bounce.foes=[Foe(id:20004,p:V2(x:3,y:-3),hp:100,speed:0,gait:0)]
  bounce.shots=[Shot(id:20005,p:V2(x:1,y:-3),v:V2(x:50,y:0),ttl:1,damage:10,kind:.ray)];bounce.step(0.05,input:Controls())
  expect(bounce.foes[0].hp==90 && bounce.shots.count==1 && bounce.shots[0].v.x<0,"Ray Gun damages and reflects from a zombie instead of disappearing at first contact")
  bounce.step(0.02,input:Controls());expect(bounce.foes[0].hp==90,"same ricocheting projectile cannot repeatedly damage one overlapping body")
  let rocketLine=emptyWeapons();rocketLine.foes=[Foe(id:20006,p:V2(x:2,y:-3),hp:99,speed:0,gait:0),Foe(id:20007,p:V2(x:6,y:-3),hp:99,speed:0,gait:0)]
  rocketLine.shots=[Shot(id:20008,p:V2(x:0,y:-3),v:V2(x:100,y:0),ttl:1,damage:8,kind:.rocket)];rocketLine.step(0.08,input:Controls())
  expect(rocketLine.foes.allSatisfy{$0.hp<99} && rocketLine.shots.count==1,"RPG pierces separated targets along its line while retaining bounded projectile lifetime")
  let grenade=emptyWeapons(.grenade);grenade.fire(from:grenade.hero,direction:V2(x:1,y:0));let originalHeight=grenade.shots[0].height
  grenade.step(0.20,input:Controls());expect(grenade.shots[0].height>originalHeight+0.5 && grenade.shots[0].verticalSpeed<4.7,"China Lake uses a real rising ballistic arc rather than a horizontal rocket")
  grenade.foes=[Foe(id:20009,p:V2(x:9.5,y:-3),hp:12,speed:0,gait:0)]
  for _ in 0..<100 {grenade.step(1.0/120,input:Controls())}
  expect(grenade.shots.isEmpty && grenade.foes.isEmpty,"grenade falls to the local floor and kills an enemy in its landing blast")
  let fire=emptyWeapons(.flamethrower);fire.foes=[Foe(id:20010,p:V2(x:2,y:-3),hp:99,speed:0,gait:0),Foe(id:20011,p:V2(x:2,y:0),hp:99,speed:0,gait:0)]
  fire.fire(from:fire.hero,direction:V2(x:1,y:0));let beforeBurn=fire.foes[0].hp
  fire.step(0.40,input:Controls());expect(fire.foes[0].hp<beforeBurn-0.9 && fire.foes[1].hp==99,"flame cone ignites targets ahead and the first archived burn tick follows400ms without hitting targets behind its sides")
  let shielded=emptyWeapons(.flamethrower);shielded.round=29;shielded.beginRound();shielded.combatSpawningHeld=true;shielded.hero=V2(x:0,y:-1)
  shielded.foes=[Foe(id:20012,p:V2(x:3.5,y:-1),hp:99,speed:0,gait:0)]
  shielded.fire(from:shielded.hero,direction:V2(x:1,y:0));expect(shielded.foes[0].hp==99 && shielded.flameJets[0].length<1,"solid fuel tank blocks flame damage and truncates its visible jet")
  let pausedFire=emptyWeapons(.flamethrower);pausedFire.foes=[Foe(id:20013,p:V2(x:2,y:-3),hp:99,speed:0,gait:0)];pausedFire.fire(from:pausedFire.hero,direction:V2(x:1,y:0))
  pausedFire.step(0,input:Controls(pause:true));let burnHP=pausedFire.foes[0].hp,burnTime=pausedFire.foes[0].burning
  pausedFire.step(2,input:Controls());expect(pausedFire.foes[0].hp==burnHP && pausedFire.foes[0].burning==burnTime && !pausedFire.flameJets.isEmpty,"pause freezes burning damage and visual jet lifetime")
  let fireSupport=emptyWeapons(.grenade);fireSupport.addChicken();fireSupport.fireChickens(playerFiring:true)
  expect(fireSupport.shots.count==1 && fireSupport.shots[0].kind == .grenade && fireSupport.shots[0].height>1,"chicken companions copy the new ballistic grenade weapon")
  fireSupport.apply(.flamethrower);fireSupport.fireChickens(playerFiring:true);expect(fireSupport.flameJets.count==1,"chickens also inherit the flamethrower rather than reverting to machine-gun shots")
  let reserve=emptyWeapons(.grenade);reserve.step(1,input:Controls());expect(abs(reserve.weaponReserve-49)<0.001,"new timed weapons preserve50-second idle reserve")
  reserve.step(1,input:Controls(aim:V2(x:1,y:0)));expect(abs(reserve.weaponReserve-44)<0.001,"new timed weapons retain fivefold reserve drain while firing")
  let safeGuns=emptyWeapons();safeGuns.phase = .cleared;safeGuns.enterSideRoom(SideRoomOffer(kind:.armory,p:safeGuns.layout.sideRoute(onLeft:true)))
  expect(SourceLootBag.template.contains(.grenade) && SourceLootBag.template.contains(.flamethrower) && safeGuns.sourceLoot!.pendingRoomPrograms==1,"armory random requests share the source bag including both weapon types without guaranteeing either")
  pausedFire.reset();expect(pausedFire.flameJets.isEmpty && pausedFire.shots.isEmpty,"new run removes flame streams ballistic shots and burning enemies")
  func emptyVehicle(_ round:Int=9)->GameCore {let c=GameCore();c.reset();c.round=round;c.beginRound();c.hero=V2(x:0,y:-3);c.facing=V2(x:1,y:0);c.combatSpawningHeld=true;c.invulnerable=0;c.playerRoster.current.bodyShield=nil;return c}
  expect(!SourceLootEligibility(round:3).allows(.tank) && SourceLootEligibility(round:4).allows(.tank) && !SourceLootEligibility(round:8).allows(.helicopter) && SourceLootEligibility(round:9).allows(.helicopter),"source vehicle eligibility respects earliest tank4 and helicopter9 round gates")
  let armored=emptyVehicle();armored.apply(.ray);armored.weaponReserve=17;armored.apply(.tank)
  expect(armored.vehicle?.remaining==20 && armored.vehicle?.kind == .tank,"tank pickup creates a timed20-second vehicle state")
  let tankLives=armored.lives;armored.loseLife();armored.houndHit();armored.godMode=true;armored.loseLife()
  expect(armored.lives==tankLives && armored.deaths==0 && armored.dogWounds==0 && armored.trainingHits==0,"vehicle armor suppresses real damage hound wounds and virtual Godmode damage through the common damage path")
  armored.step(1,input:Controls());expect(armored.vehicle?.remaining==19 && armored.weapon == .ray && armored.weaponReserve==17,"vehicle timer advances while the stored hand weapon and its reserve are retained")
  armored.step(0,input:Controls(pause:true));let tankTime=armored.vehicle!.remaining;armored.step(3,input:Controls(move:V2(x:1,y:0),aim:V2(x:1,y:0)))
  expect(armored.vehicle?.remaining==tankTime && armored.vehicle?.travel==0,"pause freezes vehicle lifetime movement and weapons")
  armored.step(0,input:Controls(accept:true));armored.vehicle!.remaining=0.01;armored.step(0.02,input:Controls())
  expect(armored.vehicle==nil && armored.weapon == .ray && armored.weaponReserve<17 && armored.damageProtected && armored.playerRoster.current.bodyShield != nil,"tank expiry restores the preserved hand weapon with bounded exit protection")
  let fortVehicle=emptyVehicle();fortVehicle.fate = .fortitude;fortVehicle.apply(.helicopter)
  expect(fortVehicle.vehicle?.remaining==40,"Fortitude doubles vehicle duration as well as existing weapon durations")
  let tracked=emptyVehicle();tracked.hero=V2(x:-2,y:-3);tracked.apply(.tank);tracked.foes=[Foe(id:21000,p:V2(x:-1,y:-3),hp:99,speed:0,gait:0)]
  tracked.step(0.25,input:Controls(move:V2(x:1,y:0)))
  expect(tracked.foes.isEmpty && tracked.deaths==0 && tracked.vehicle != nil,"tank crush uses the swept chassis path and destroys a durable ordinary zombie")
  let levelTank=emptyVehicle(9);levelTank.hero=V2(x:9.4,y:0);levelTank.apply(.tank);levelTank.foes=[Foe(id:21001,p:V2(x:8.7,y:0),hp:99,speed:0,gait:0)]
  levelTank.crushWithTank(from:levelTank.hero,0.02);expect(levelTank.foes[0].hp==99,"raised tank cannot crush a zombie on the lower court through the catwalk edge")
  let cannon=emptyVehicle();cannon.apply(.tank);cannon.fireVehicleWeapons(0,firing:true)
  expect(cannon.shots.count==1 && cannon.shots[0].kind == .rocket && !cannon.shots[0].piercing && cannon.shots[0].explosionDamage==16,"tank has a dedicated explosive cannon rather than inheriting the stored weapon")
  cannon.foes=[Foe(id:21002,p:V2(x:2.2,y:-3),hp:99,speed:0,gait:0),Foe(id:21003,p:V2(x:6,y:-3),hp:99,speed:0,gait:0)]
  cannon.step(0.1,input:Controls());expect(cannon.foes[0].hp<99 && cannon.foes[1].hp==99 && cannon.shots.isEmpty,"tank shell detonates at its first body instead of piercing as the handheld RPG does")
  let air=emptyVehicle();air.apply(.helicopter);air.fireVehicleWeapons(0,firing:true)
  expect(air.shots.count==2 && air.shots.contains{$0.kind == nil} && air.shots.contains{$0.kind == .rocket} && air.shots.allSatisfy{$0.targetHeight != nil && $0.height>3},"Hind launches both turret rounds and missiles with real descending height")
  air.foes=[Foe(id:21004,p:V2(x:5,y:-3),hp:20,speed:0,gait:0)]
  for _ in 0..<20 {air.step(1.0/60,input:Controls())}
  expect(air.foes.isEmpty || air.foes[0].hp<20,"airborne weapons descend and damage real ground-level enemies")
  let airCadence=emptyVehicle();airCadence.apply(.helicopter)
  for _ in 0..<60 {airCadence.fireVehicleWeapons(1.0/60,firing:true)}
  expect((12...14).contains(airCadence.shots.filter{$0.kind==nil}.count) && (5...6).contains(airCadence.shots.filter{$0.kind == .rocket}.count),"Hind turret and missiles retain their separate750 and300 RPM nominal cadences")
  for updates in [30,120] {
   let cadence=emptyVehicle();cadence.apply(.helicopter)
   for _ in 0..<updates {cadence.fireVehicleWeapons(1.0/Double(updates),firing:true)}
   expect((12...14).contains(cadence.shots.filter{$0.kind==nil}.count) && (5...6).contains(cadence.shots.filter{$0.kind == .rocket}.count),"vehicle cadence remains consistent at\(updates) updates without counting only projectiles that survive collision")
  }
  let crew=emptyVehicle();crew.apply(.flamethrower);crew.addChicken();crew.apply(.tank);crew.fireChickens(playerFiring:true)
  expect(crew.shots.count==1 && crew.shots[0].kind == .grenade,"tank assigns China Lake to its chicken escort")
  crew.shots=[];crew.apply(.helicopter);crew.fireChickens(playerFiring:true)
  expect(crew.shots.count==1 && crew.shots[0].kind == .ray && crew.shots[0].targetHeight != nil,"helicopter assigns descending Ray Gun shots to its escort")
  crew.endVehicle();crew.flameJets=[];crew.fireChickens(playerFiring:true)
  expect(crew.flameJets.count==1,"escort reverts to the player's saved hand weapon after vehicle exit")
  let lootAir=emptyVehicle();lootAir.apply(.helicopter);lootAir.pickups=[Pickup(id:21005,p:lootAir.hero,kind:.life)];let beforeAirLife=lootAir.lives;lootAir.step(0.01,input:Controls())
  expect(lootAir.pickups.isEmpty && lootAir.lives==beforeAirLife+1,"hovering player can collect ground pickups without an impossible vertical reach requirement")
  let lowPass=emptyVehicle(29);lowPass.hero=V2(x:-2,y:-1);lowPass.apply(.helicopter)
  for _ in 0..<42 {lowPass.step(1.0/60,input:Controls(move:V2(x:1,y:0)))}
  expect(!lowPass.layout.walkable(lowPass.hero) && lowPass.heroElevation>2.8,"helicopter can cross low solid tanks which block ground movement")
  lowPass.vehicle!.remaining=0.001;lowPass.step(0.01,input:Controls());let safeTarget=lowPass.vehicle!.landingTarget!
  expect(lowPass.layout.walkable(safeTarget,clearance:0.29),"flight expiry chooses a reachable landing point instead of dropping the soldier into a fuel tank")
  var landingContinuous=true;for _ in 0..<240 {let old=lowPass.hero;lowPass.step(1.0/60,input:Controls());landingContinuous = landingContinuous && (lowPass.hero-old).length<0.08;if lowPass.vehicle==nil {break}}
  expect(lowPass.vehicle==nil && lowPass.layout.walkable(lowPass.hero,clearance:0.29) && lowPass.heroElevation==lowPass.layout.height(lowPass.hero) && landingContinuous,"helicopter returns continuously to clear ground and restores a valid standing soldier")
  let highPass=emptyVehicle(37);highPass.hero=V2(x:-3,y:0);highPass.apply(.helicopter)
  for _ in 0..<100 {highPass.step(1.0/60,input:Controls(move:V2(x:1,y:0)))}
  expect(highPass.hero.x < -1.7,"helicopter avoids a rocket taller than its flight plane instead of passing through it")
  let groundStop=emptyVehicle(5);groundStop.hero=V2(x:-4,y:0);groundStop.apply(.tank)
  for _ in 0..<120 {groundStop.step(1.0/60,input:Controls(move:V2(x:1,y:0)))}
  expect(groundStop.hero.x < -2.2 && groundStop.layout.walkable(groundStop.hero,clearance:0.60),"tracked vehicle respects the fountain and its enlarged physical chassis clearance")
  let safeVehicle=emptyVehicle(9);safeVehicle.phase = .cleared;safeVehicle.enterSideRoom(SideRoomOffer(kind:.armory,p:safeVehicle.layout.sideRoute(onLeft:true)))
  expect(SourceLootBag.template.contains(.tank) && !SourceLootEligibility(round:9,roundActive:false,magicalExit:true,prison:true).allows(.helicopter),"armory source bag includes vehicles but the prison magical room rejects fresh Hind pickups")
  safeVehicle.apply(.helicopter);let safeClock=safeVehicle.vehicle!.remaining;safeVehicle.step(2,input:Controls());safeVehicle.hero=safeVehicle.suggestedExit;safeVehicle.step(0.01,input:Controls());finishTravel(safeVehicle)
  expect(safeVehicle.round==10 && safeVehicle.vehicle?.remaining==safeClock && safeVehicle.vehicle?.velocity == .zero,"safe-room exploration freezes vehicle reserve and arena transition clears old vehicle momentum")
  safeVehicle.reset();expect(safeVehicle.vehicle==nil && safeVehicle.heroElevation==0,"new run removes vehicle state and flight elevation")
  func emptySupport(_ round:Int=1)->GameCore {let c=GameCore();c.reset();c.round=round;c.beginRound();c.hero=V2(x:0,y:-3);c.heroElevation=c.layout.height(c.hero);c.facing=V2(x:1,y:0);c.combatSpawningHeld=true;c.invulnerable=0;c.playerRoster.current.bodyShield=nil;return c}
  expect(PickupKind.helicopter.rawValue==15 && PickupKind.teddy.rawValue==16,"new support pickups preserve every previous serialized pickup value")
  expect([PickupKind.teddy,.barrelShield,.monkey,.turret].allSatisfy{SourceLootBag.template.contains($0)},"all four support pickups belong to the source equipment bag rather than kill-drop probability intervals")
  let bear=emptySupport();bear.apply(.teddy);bear.foes=[Foe(id:22001,p:V2(x:2,y:-3),hp:99,speed:2,gait:0,homeEntrance:2)];bear.step(0.4,input:Controls())
  expect(bear.foes[0].p.x>2 && bear.foes[0].hp==99 && bear.foes[0].retreatEntrance==2,"Teddy sends a nearby ordinary zombie toward its own entrance without inflicting damage")
  let frozen=emptySupport();frozen.apply(.teddy);frozen.foes=[Foe(id:22002,p:V2(x:2,y:-3),hp:99,speed:2,gait:0,kind:.crawler,behaviorClock:0.8),Foe(id:22003,p:V2(x:3,y:-3),hp:99,speed:2,gait:0,elevation:8,kind:.engineer),Foe(id:22004,p:V2(x:5,y:-3),hp:99,speed:2,gait:0,kind:.prisoner)];let frozenPositions=frozen.foes.map(\.p)
  frozen.step(0.5,input:Controls());expect(frozen.foes.map(\.p)==frozenPositions && frozen.foes[0].behaviorClock==0.8 && frozen.foes[1].elevation==8,"Teddy freezes special foes including crawler lunge clocks and falling engineers")
  let bearBoss=emptySupport(40);bearBoss.apply(.teddy);bearBoss.fixtureSilverbacks();let beforeBearBoss=bearBoss.silverback!.p;bearBoss.step(0.2,input:Controls())
  expect(bearBoss.silverback!.p != beforeBearBoss,"Teddy does not freeze the Cosmic Silverback or his entry")
  let bearContact=emptySupport();bearContact.apply(.teddy);bearContact.foes=[Foe(id:22005,p:bearContact.hero,hp:99,speed:0,gait:0)];bearContact.step(0.01,input:Controls())
  settle(bearContact);expect(bearContact.lives==2 && bearContact.teddyRemaining==0,"Teddy does not grant immunity and ordinary body contact still costs a life")
  bear.teddyRemaining=0.001;let retreatX=bear.foes[0].p.x;bear.step(0.1,input:Controls())
  expect(bear.foes[0].p.x<retreatX && bear.foes[0].retreatEntrance==nil,"expired fear restores normal pursuit rather than permanently parking zombies at entrances")
  let supportFate=emptySupport();supportFate.fate = .fortitude;supportFate.apply(.teddy);supportFate.apply(.barrelShield);supportFate.apply(.monkey);supportFate.apply(.turret)
  expect(supportFate.teddyRemaining==40 && supportFate.shieldBarrelRemaining==40 && supportFate.monkeys[0].remaining==8 && supportFate.sentries[0].remaining==30,"Fortitude doubles Teddy and shield duration but keeps Monkey and Turret timers unchanged")
  let exactDrop=emptySupport();let monkeyPlace=exactDrop.hero+V2(x:0.6,y:0);exactDrop.pickups=[Pickup(id:22006,p:monkeyPlace,kind:.monkey)];exactDrop.collectNearbyPickups()
  expect(exactDrop.monkeys[0].p==monkeyPlace && exactDrop.pickups.isEmpty,"collecting a monkey deploys it at the pickup location rather than following the player's center")
  let lure=emptySupport();lure.hero=V2(x:5,y:-3);lure.apply(.monkey,at:V2(x:-3,y:-3));lure.foes=[Foe(id:22007,p:V2(x:-1,y:-3),hp:99,speed:2,gait:0)];lure.step(0.2,input:Controls())
  expect(lure.foes[0].p.x < -1,"a closer monkey actually redirects movement away from the player")
  let nearPlayer=emptySupport();nearPlayer.hero=V2(x:5,y:-3);nearPlayer.apply(.monkey,at:V2(x:-3,y:-3));nearPlayer.foes=[Foe(id:22008,p:V2(x:4,y:-3),hp:99,speed:2,gait:0)];nearPlayer.step(0.1,input:Controls())
  expect(nearPlayer.foes[0].p.x>4,"a farther monkey does not override a closer player")
  let nearestMonkey=emptySupport();nearestMonkey.hero=V2(x:9,y:-3);nearestMonkey.apply(.monkey,at:V2(x:-3,y:-3));nearestMonkey.apply(.monkey,at:V2(x:1,y:-3));nearestMonkey.foes=[Foe(id:22009,p:V2(x:-1,y:-3),hp:99,speed:2,gait:0)];nearestMonkey.updateSupportNavigation(0.1)
  expect(nearestMonkey.supportPursuit(0).target==nearestMonkey.monkeys[0].p,"equal-distance decoys remain stable without consuming world randomness")
  let detonation=emptySupport();detonation.hero=V2(x:0,y:-3);detonation.apply(.monkey,at:detonation.hero);detonation.foes=[Foe(id:22010,p:V2(x:2,y:-3),hp:30,speed:0,gait:0),Foe(id:22011,p:V2(x:6,y:-3),hp:99,speed:0,gait:0)];detonation.stepSupportPowers(8.1)
  expect(detonation.monkeys.isEmpty && detonation.foes[0].hp<=0 && detonation.foes[1].hp==99 && detonation.lives==3,"timed monkey blast kills nearby tough foes while preserving distant bodies and the player's life")
  let coveredMonkey=emptySupport(29);coveredMonkey.apply(.monkey,at:V2(x:0,y:-1));coveredMonkey.foes=[Foe(id:22012,p:V2(x:3.6,y:-1),hp:99,speed:0,gait:0)];coveredMonkey.stepSupportPowers(8.1)
  expect(coveredMonkey.foes[0].hp==99,"a solid fuel tank blocks the monkey explosion rather than allowing blast damage through cover")
  let dropping=emptySupport();dropping.hero=V2(x:6,y:-3);dropping.apply(.turret,at:V2(x:0,y:-3));dropping.foes=[Foe(id:22013,p:V2(x:0,y:-3),hp:999,speed:0,gait:0)];let turretStart=dropping.sentries[0].elevation;dropping.stepSupportPowers(0.4)
  expect(dropping.sentries[0].elevation<turretStart && dropping.sentries[0].elevation>0 && dropping.shots.isEmpty,"sentry falls visibly from above and cannot fire before landing")
  dropping.stepSupportPowers(0.5);expect(dropping.sentries[0].motion == .active && dropping.foes[0].hp==0,"sentry touchdown crushes a zombie directly below it")
  for updates in [30,60,120] {
   let cadence=emptySupport();var turret=SentryTurret(id:22014,p:.zero,elevation:0,motion:.active)
   for _ in 0..<updates {cadence.fireSentry(&turret,1.0/Double(updates),at:V2(x:6,y:0))}
   expect((66...68).contains(turret.shotCount) && cadence.shots.count==turret.shotCount,"sentry maintains nominal4000RPM at\(updates) simulation updates")
   if updates==60 {expect(Set(cadence.shots.map{Int($0.v.y*1000)}).count>10,"sentry has limited accuracy rather than a perfectly identical ray for every shot")}
  }
  let sentryHit=emptySupport();sentryHit.apply(.turret);sentryHit.sentries[0].elevation=0;sentryHit.sentries[0].motion = .active;sentryHit.foes=[Foe(id:22015,p:V2(x:4,y:-3),hp:20,speed:0,gait:0)];sentryHit.step(0.2,input:Controls())
  expect(sentryHit.foes.isEmpty || sentryHit.foes[0].hp<20,"autonomous turret projectiles damage real ground-level enemies without player aim")
  let blockedSentry=emptySupport(5);blockedSentry.apply(.turret,at:V2(x:-3,y:0));blockedSentry.sentries[0].elevation=0;blockedSentry.sentries[0].motion = .active;blockedSentry.foes=[Foe(id:22016,p:V2(x:3,y:0),hp:99,speed:0,gait:0)];blockedSentry.stepSupportPowers(0.1)
  expect(blockedSentry.shots.isEmpty,"turret cannot acquire an enemy through the solid central fountain")
  let highSentry=emptySupport(9);highSentry.apply(.turret,at:V2(x:9.4,y:0));highSentry.sentries[0].elevation=1.6;highSentry.sentries[0].motion = .active;highSentry.foes=[Foe(id:22017,p:V2(x:8,y:0),hp:99,speed:0,gait:0)];highSentry.stepSupportPowers(0.1)
  expect(highSentry.shots.isEmpty,"elevated sentry does not fire a level bullet into an unreachable lower-floor target")
  dropping.phase = .cleared;dropping.stepSupportPowers(0.2);expect(dropping.sentries[0].motion == .leaving && dropping.sentries[0].elevation>0,"a used sentry lifts away at wave end instead of continuing to shoot forever")
  dropping.stepSupportPowers(1.5);expect(dropping.sentries.isEmpty,"departure completes and releases the turret entity")
  let timedSentry=emptySupport();timedSentry.apply(.turret);timedSentry.sentries[0].motion = .active;timedSentry.sentries[0].elevation=0;timedSentry.stepSupportPowers(30.1)
  expect(timedSentry.sentries.isEmpty,"turret lifetime is bounded even if the wave never ends")
  let shield=emptySupport();shield.apply(.barrelShield);shield.foes=[Foe(id:22018,p:shield.hero+V2(x:1.18,y:0),hp:999,speed:0,gait:0),Foe(id:22019,p:shield.hero+V2(x:3,y:0),hp:99,speed:0,gait:0)];shield.step(0.01,input:Controls())
  expect(shield.shieldBarrels.count==2 && shield.foes.count==1 && shield.foes[0].id==22019,"two orbiting barrels kill at real body contact without an invisible full-radius kill field")
  let shieldGap=emptySupport();shieldGap.apply(.barrelShield);shieldGap.foes=[Foe(id:22020,p:shieldGap.hero,hp:99,speed:0,gait:0)];shieldGap.step(0.01,input:Controls())
  settle(shieldGap);expect(shieldGap.lives==2,"a foe inside the gap between orbiting barrels can still touch and kill the player")
  let highShield=emptySupport(9);highShield.hero=V2(x:9.4,y:0);highShield.heroElevation=1.6;highShield.apply(.barrelShield);highShield.foes=[Foe(id:22021,p:V2(x:8.22,y:0),hp:99,speed:0,gait:0)];highShield.resolveShieldBarrelHits(0.01)
  expect(highShield.foes[0].hp==99,"barrel shields cannot crush a foe below a high catwalk through the floor")
  let departing=emptySupport();departing.apply(.barrelShield);departing.foes=[Foe(id:22022,p:departing.hero+V2(x:3,y:0),hp:99,speed:0,gait:0)];departing.shieldBarrelRemaining=0.001;departing.stepSupportPowers(0.3);departing.resolveShieldBarrelHits(0.3)
  expect(departing.shieldBarrels.isEmpty && departing.departingShieldBarrels.count==2 && departing.foes[0].hp==0,"expired shield barrels fly outward and retain swept contact kills during departure")
  let pauseSupport=emptySupport();pauseSupport.apply(.teddy);pauseSupport.apply(.barrelShield);pauseSupport.apply(.monkey);pauseSupport.apply(.turret);pauseSupport.step(0,input:Controls(pause:true));pauseSupport.step(3,input:Controls())
  expect(pauseSupport.teddyRemaining==20 && pauseSupport.shieldBarrelRemaining==20 && pauseSupport.monkeys[0].remaining==8 && pauseSupport.sentries[0].remaining==30,"pause freezes every new support timer and the turret drop")
  let deathSupport=emptySupport();deathSupport.apply(.teddy);deathSupport.apply(.barrelShield);deathSupport.apply(.monkey);deathSupport.apply(.turret);deathSupport.loseLife()
  expect(deathSupport.teddyRemaining==0 && deathSupport.shieldBarrels.isEmpty && deathSupport.monkeys.count==1 && deathSupport.sentries.count==1,"death removes carried powers while already deployed stationary equipment stays in its arena")
  let godSupport=emptySupport();godSupport.godMode=true;godSupport.apply(.teddy);godSupport.apply(.barrelShield);godSupport.loseLife()
  expect(godSupport.trainingHits==1 && godSupport.teddyRemaining==20 && godSupport.shieldBarrels.count==2,"virtual Godmode damage preserves the player's support equipment")
  let stock=emptySupport();stock.phase = .cleared;stock.enterSideRoom(SideRoomOffer(kind:.armory,p:stock.layout.sideRoute(onLeft:true)))
  stock.finishRoomLootForChecks()
  expect(stock.pickups.count==17 && stock.pickups.allSatisfy{$0.kind != .monkey && $0.kind != .turret && $0.kind != .life},"solo armory completes seventeen source gifts while respecting magical-room exclusions")
  stock.pickups=[];stock.apply(.teddy);stock.apply(.barrelShield);stock.apply(.monkey);stock.apply(.turret);stock.step(2,input:Controls())
  expect(stock.teddyRemaining==20 && stock.monkeys[0].remaining==8 && stock.monkeys[0].stowed && stock.sentries[0].stowed,"safe-room stationary pickups wait for combat and do not waste their fuse or turret timer")
  stock.hero=stock.suggestedExit;stock.heroElevation=stock.layout.height(stock.hero);stock.step(0.01,input:Controls());finishTravel(stock)
  expect(stock.round==2 && stock.monkeys.count==1 && !stock.monkeys[0].stowed && !stock.sentries[0].stowed && stock.layout.walkable(stock.monkeys[0].p) && stock.layout.walkable(stock.sentries[0].p),"leaving an armory deploys stored supports on valid ground in the next arena")
  stock.phase = .cleared;stock.enterSideRoom(SideRoomOffer(kind:.treasure,p:stock.layout.sideRoute(onLeft:true)))
  expect(stock.monkeys.isEmpty && stock.sentries.isEmpty,"deployed stationary equipment is removed when its old arena is left")
  stock.reset();expect(stock.teddyRemaining==0 && stock.shieldBarrels.isEmpty && stock.departingShieldBarrels.isEmpty && stock.monkeys.isEmpty && stock.sentries.isEmpty,"new run clears every new support state")
  var allArmoriesValid=true
  for round in stride(from:1,through:37,by:4) {let room=emptySupport(round);room.phase = .cleared;enterLateBonus(room,SideRoomOffer(kind:.armory,p:room.layout.sideRoute(onLeft:true)));allArmoriesValid = allArmoriesValid && room.pickups.count==17 && room.pickups.allSatisfy{room.layout.walkable($0.p,clearance:0.24)}}
  expect(allArmoriesValid,"expanded armory stock remains reachable on all ten arena layouts")
  func emptyTreasure()->GameCore {let c=GameCore();c.reset();c.pickups=[];c.combatSpawningHeld=true;c.invulnerable=0;c.playerRoster.current.bodyShield=nil;return c}
  var sameMetalValue=true
  for i in 0..<9 {let c=emptyTreasure();c.multiplier=3;c.apply(.treasure,loot:.treasure(index:i));sameMetalValue = sameMetalValue && c.score==375 && c.multiplierCharge==9.0/512}
  expect(sameMetalValue,"all nine own gold/silver forms share125-point base value and the current stage's integer contribution")
  let gradual=emptyTreasure();for _ in 0..<25 {gradual.apply(.treasure)}
  expect(gradual.multiplier==1 && gradual.multiplierCharge==500.0/512,"twenty-five ordinary treasures fill500 of512 units without premature promotion")
  gradual.apply(.treasure);expect(gradual.multiplier==2 && gradual.multiplierCharge==8.0/512 && gradual.score==3250,"the twenty-sixth treasure crosses the first stage and scores at the previous multiplier")
  for _ in 0..<39 {gradual.apply(.treasure)}
  expect(gradual.multiplier==3 && gradual.multiplierCharge==3.0/512 && gradual.score==13000,"the next stage uses13 units per coin and retains integer overflow")
  let quarters=emptyTreasure();for _ in 0..<2 {quarters.apply(.gem,loot:.gem(.blue,.small),gemUnits:128)}
  expect(quarters.multiplier==1 && quarters.multiplierCharge==0.5,"two spilled quarter gems fill half a bar regardless of visible size")
  quarters.apply(.gem,loot:.gem(.red,.large),gemUnits:128);expect(quarters.multiplier==1 && quarters.multiplierCharge==0.75,"a stored quarter value remains a quarter even with a different appearance")
  let halves=emptyTreasure();halves.apply(.gem,loot:.gem(.white,.medium),gemUnits:256);expect(halves.multiplier==1 && halves.multiplierCharge==0.5,"a stored256-unit gem fills half the bar")
  halves.apply(.gem,loot:.gem(.blue,.medium),gemUnits:256);expect(halves.multiplier==1 && halves.multiplierCharge==1,"exactly512 units fill the old stage without crossing its strict boundary")
  let big=emptyTreasure();big.multiplier=3;big.multiplierCharge=0.375;big.apply(.gem,loot:.gem(.red,.small),gemUnits:512)
  expect(big.multiplier==4 && big.multiplierCharge==0.375,"a full-bar stored value advances once and retains the exact integer remainder")
  let overflow=emptyTreasure();overflow.multiplierCharge=0.75;overflow.apply(.gem,loot:.gem(.white,.medium),gemUnits:256)
  expect(overflow.multiplier==2 && overflow.multiplierCharge==0.25,"gem value carries integer overflow into the next stage")
  var sameGemColor=true
  for color in GemColor.allCases {let c=emptyTreasure();c.apply(.gem,loot:.gem(color,.small),gemUnits:128);sameGemColor = sameGemColor && c.multiplierCharge==0.25 && c.score==625}
  expect(sameGemColor,"gem color is cosmetic while each gem scores625 base points and its stored meter units")
  let killMeter=emptyTreasure();killMeter.multiplier=4;killMeter.kill(Foe(id:23000,p:V2(x:3,y:0),hp:0,speed:0,gait:0),drops:false)
  expect(killMeter.score==400 && killMeter.multiplierCharge==0,"zombie kills score with the active multiplier but do not fill a treasure-only bar")
  let capMeter=emptyTreasure();capMeter.multiplier=8;capMeter.multiplierCharge=0.75;capMeter.apply(.gem,loot:.gem(.blue,.large),gemUnits:512);let capScore=capMeter.score;capMeter.apply(.treasure)
  expect(capMeter.multiplier==9 && capMeter.multiplierFill==385.0/512 && capMeter.multiplierCharge==385.0/512 && capMeter.score==capScore+1125,"reaching times9 retains a partial bar and ordinary treasure still scores at the cap")
  for _ in 0..<100 {capMeter.apply(.gem,loot:.gem(.white,.large),gemUnits:512)}
  expect(capMeter.multiplier==9 && capMeter.multiplierCharge==1 && capMeter.multiplierFill==1,"collecting gems at the cap cannot accumulate hidden multiplier debt")
  let lifeCoin=emptyTreasure();lifeCoin.score=199875;lifeCoin.multiplierCharge=0.99;lifeCoin.apply(.treasure);lifeCoin.advanceDirectedRewards(1.3);lifeCoin.collectDirectedRewards()
  expect(lifeCoin.score==200000 && lifeCoin.lives==4 && lifeCoin.multiplier==2 && lifeCoin.nextLifeAt==400000 && lifeCoin.message=="EXTRA-LEBEN","one treasure can cross score and multiplier thresholds with a single life award and a visible life notice")
  let banked=emptyTreasure();banked.score=12345;banked.multiplier=5;banked.multiplierCharge=0.72;banked.loseLife();settle(banked)
  expect(banked.score==12345 && banked.multiplier==1 && banked.multiplierCharge==0,"real death resets multiplier and partial charge while preserving banked score")
  banked.fate = .fortitude;banked.multiplier=6;banked.multiplierCharge=0.6;banked.invulnerable=0;banked.playerRoster.current.bodyShield=nil;banked.loseLife();settle(banked)
  expect(banked.multiplier==2 && banked.multiplierCharge==0,"Fortitude resets the new bar to an empty times-two stage after death")
  let virtualMeter=emptyTreasure();virtualMeter.godMode=true;virtualMeter.multiplier=4;virtualMeter.multiplierCharge=0.71;virtualMeter.loseLife()
  expect(virtualMeter.multiplier==4 && virtualMeter.multiplierCharge==0.71 && virtualMeter.trainingHits==1,"Godmode preserves partial multiplier progress as well as equipment and banked score")
  let fullVirtual=emptyTreasure();fullVirtual.godMode=true;fullVirtual.lives=9;fullVirtual.trainingHits=12;fullVirtual.score=199875;fullVirtual.apply(.treasure);fullVirtual.advanceDirectedRewards(1.3);fullVirtual.collectDirectedRewards()
  expect(fullVirtual.lives==9 && fullVirtual.displayedLives == -2 && fullVirtual.trainingHits==12 && fullVirtual.trainingBonusLives==1,"score extra life improves a negative Godmode balance even when the real stock is capped at9")
  fullVirtual.apply(.life);expect(fullVirtual.displayedLives == -1 && fullVirtual.lives==9 && fullVirtual.trainingHits==12,"life pickup also repairs the virtual balance without erasing the counted damage events")
  for _ in 0..<30 {fullVirtual.apply(.life)}
  expect(fullVirtual.displayedLives==9 && fullVirtual.lives==9 && !fullVirtual.canGainDisplayedLife,"virtual recovery stops at the displayed nine-life cap without creating an unbounded reserve")
  fullVirtual.godMode=false;expect(fullVirtual.displayedLives==9,"turning Godmode off uses the real life stock rather than virtual accounting")
  fullVirtual.reset();expect(fullVirtual.multiplier==1 && fullVirtual.multiplierCharge==0 && fullVirtual.trainingBonusLives==0 && fullVirtual.pointsUntilLife==200000,"new run clears multiplier progress virtual bonuses and next-life distance")
  let safeMeter=emptyTreasure();safeMeter.multiplier=3;safeMeter.multiplierCharge=0.35;safeMeter.phase = .cleared;safeMeter.enterSideRoom(SideRoomOffer(kind:.armory,p:safeMeter.layout.sideRoute(onLeft:true)));safeMeter.pickups=[];safeMeter.step(2,input:Controls());safeMeter.hero=safeMeter.suggestedExit;safeMeter.step(0.01,input:Controls());finishTravel(safeMeter)
  expect(safeMeter.round==2 && safeMeter.multiplier==3 && safeMeter.multiplierCharge==0.35,"bonus-room entry and exit retain an earned partial multiplier bar")
  let waveLoot=emptyTreasure();waveLoot.finishCombatSpawning();waveLoot.step(0,input:Controls());let firstClearCount=waveLoot.pickups.count;waveLoot.step(0,input:Controls())
  expect(waveLoot.phase == .cleared && firstClearCount==1 && waveLoot.pickups.count==firstClearCount && waveLoot.sourceLoot!.pendingChildren>0,"wave completion starts its staggered treasure phase without duplicating the first fund on zero-time ticks")
  var allRoundLootValid=true
  for r in stride(from:1,through:37,by:4) {let c=emptyTreasure();c.round=r;c.beginRound();allRoundLootValid = allRoundLootValid && c.pickups.isEmpty && !c.layout.sourceLootMap.sites.isEmpty && c.layout.sourceLootMap.sites.allSatisfy{c.layout.walkable(c.layout.clamped($0.p,clearance:0.4),clearance:0.28)}}
  expect(allRoundLootValid,"all ten arenas start without invented free funds and provide reachable editable source pickup sites")
  let exactGem=emptyTreasure();exactGem.pickups=[Pickup(id:23001,p:exactGem.hero,kind:.gem,loot:.gem(.white,.small),gemUnits:128)];exactGem.collectNearbyPickups()
  expect(exactGem.multiplier==1 && exactGem.multiplierCharge==0.25 && exactGem.score==625 && exactGem.pickups.isEmpty,"normal proximity collection preserves a gem's stored value instead of inferring it from appearance")
  let guardedGem=emptyTreasure();guardedGem.round=9;guardedGem.beginRound();guardedGem.hero=V2(x:8.5,y:0);guardedGem.heroElevation=0;guardedGem.pickups=[Pickup(id:23002,p:V2(x:9.1,y:0),kind:.gem,loot:.gem(.red,.large))];guardedGem.collectNearbyPickups()
  expect(guardedGem.multiplier==1 && guardedGem.pickups.count==1,"a large gem above a catwalk cannot raise the meter through the floor")
  let bossLoot=emptyTreasure();bossLoot.round=40;bossLoot.beginRound();bossLoot.pickups=[];bossLoot.fixtureSilverbacks();bossLoot.damageSilverback(9999);bossLoot.step(2.1,input:Controls());let bossDropCount=bossLoot.pickups.count;bossLoot.step(0,input:Controls())
  expect(bossLoot.phase == .cleared && bossDropCount==1 && bossLoot.pickups.count==1 && bossLoot.sourceLoot!.clusterStarts==1,"complete boss-round clear begins one physical source glob without an immediate per-brother shower or duplicate zero-frame rewards")
  bossLoot.stepWorldLoot(20)
  expect(bossLoot.sourceLoot!.clusterStarts==25 && (75...175).contains(bossLoot.pickups.count) && bossLoot.pickups.allSatisfy{p in p.kind == .treasure ? p.loot != nil && p.gemUnits==nil:p.kind == .gem && p.gemUnits != nil && p.loot?.gemColor != nil && p.loot?.size != nil},"completed source boss globs retain valid stored reward/appearance data without requiring an invented guaranteed gem count")
  let pauseMeter=emptyTreasure();pauseMeter.multiplierCharge=0.41;pauseMeter.step(0,input:Controls(pause:true));pauseMeter.step(10,input:Controls())
  expect(pauseMeter.multiplierCharge==0.41 && pauseMeter.score==0,"pause cannot consume multiplier progress or collect world treasure")
  let lipNav=ArenaNavigation(clearance:0.68),lipLayout=ArenaLayout.forRound(22);var lip=V2(x:1.1759989954,y:1.3);let lipTarget=V2(x:-3.6,y:0);var lipValid=true
  for _ in 0..<600 {lipNav.update(layout:lipLayout,target:lipTarget,dt:1.0/60);let d=lipNav.direction(from:lip,to:lipTarget,layout:lipLayout),next=lipLayout.moved(lip,by:d*(3.0/60),clearance:0.65);lipValid = lipValid && lipLayout.walkable(next,clearance:0.60) && lipLayout.canTraverse(lip,next);lip=next}
  expect((lip-lipTarget).length<0.8 && lipValid,"navigation can leave a sub-grid urban stair lip by a short legal approach without crossing a side wall")
  let monkeyScore=emptyTreasure();monkeyScore.multiplier=3;monkeyScore.apply(.monkey,at:V2(x:3,y:0));monkeyScore.foes=[Foe(id:23003,p:V2(x:4,y:0),hp:30,speed:0,gait:0)];monkeyScore.stepSupportPowers(8.1);monkeyScore.resolveDefeatedFoes()
  expect(monkeyScore.score==600,"monkey explosion kills receive the reported double zombie score on top of the active multiplier")
  let woundedScore=emptyTreasure();woundedScore.apply(.monkey,at:V2(x:3,y:0));woundedScore.foes=[Foe(id:23004,p:V2(x:4,y:0),hp:60,speed:0,gait:0)];woundedScore.stepSupportPowers(8.1);woundedScore.foes[0].hp=0;woundedScore.resolveDefeatedFoes()
  expect(woundedScore.score==100,"surviving a monkey blast does not retain a double-score tag for an unrelated later kill")
  expect(ArenaLayout.forRound(41).kind == .island && ArenaLayout.forRound(45).kind == .courtyard && ArenaLayout.forRound(80).kind == .jungle && ArenaLayout.forRound(81).kind == .island && ArenaLayout.forRound(120).kind == .jungle,"arena themes repeat after each forty-round loop without resetting the absolute round")
  expect(try! TimedAttackWaves.groupCount(round:41)>TimedAttackWaves.groupCount(round:40) && TimedAttackWaves.groupCount(round:81)>TimedAttackWaves.groupCount(round:41) && RoundRules.health(.zombie,round:41)>RoundRules.health(.zombie,round:40),"later loops expand timed source programs without reverting enemy health")
  expect(CombatSpawnFlow.unlocked(35).count==6 && !CombatSpawnFlow.unlocked(35).contains(.martyr),"random unlocked mini-boss types are separate from ordinary wave admissions")
  func loopFixture(_ round:Int)->GameCore {let c=GameCore();c.reset();c.round=round;c.beginRound();c.pickups=[];c.hero=V2(x:-8,y:-4);c.heroElevation=0;c.combatSpawningHeld=true;c.invulnerable=999;c.godMode=true;return c}
  let batch41=loopFixture(41),budget41=batch41.spawnRemaining;batch41.combatSpawningHeld=false;batch41.step(0.001,input:Controls())
  expect(batch41.foes.count==1 && batch41.spawnRemaining==budget41-1 && batch41.foes.allSatisfy{$0.arrival != nil},"round41 starts its timed physical group without inventing an immediate doubled batch")
  let batch81=loopFixture(81);batch81.combatSpawningHeld=false;batch81.step(0.001,input:Controls())
  expect(batch81.foes.count==1 && batch81.combatSpawnFlow!.waves.groups.count==87 && batch81.foes.allSatisfy{$0.arrival != nil},"round81 increases the actual source group count instead of fabricating four births per tick")
  let lateLives=loopFixture(81);lateLives.rareLifeTimer=RareLifeTimer(baseWait:240);lateLives.stepRareLifeTimer(270,combatStartClock:0)
  expect(lateLives.pickups.filter{$0.kind == .life}.count==1 && lateLives.rareLifeTimer?.drops==1,"real rare-life base wait plus three-reserve delay produces one physical team life")
  expect(lateLives.pickups.allSatisfy{lateLives.layout.walkable($0.p) && $0.ttl==SourcePowerupTimeout.lifetime && $0.sourcePowerupTimeout},"timed rare lives use reachable own-map positions and source timeout plus forty local blinking waits")
  let earlyLives=loopFixture(1);earlyLives.rareLifeTimer=RareLifeTimer(baseWait:240);earlyLives.stepRareLifeTimer(100)
  expect(earlyLives.pickups.isEmpty && earlyLives.rareLifeTimer?.remaining==240,"rare-life waits do not progress under an inactive source round flag")
  let pair=loopFixture(80);pair.fixtureSilverbacks();let pairIDs=pair.silverbacks.map(\.id)
  expect(pair.silverbacks.count==2 && Set(pairIDs).count==2 && pair.silverbacks.allSatisfy{$0.arrival != nil && !pair.layout.contains($0.p)},"round80 creates two independent bosses with unique identities and exterior entries")
  pair.fixtureSilverbacks();expect(pair.silverbacks.map(\.id)==pairIDs,"repeated boss-stage triggers cannot duplicate a living boss group")
  let triple=loopFixture(120);triple.fixtureSilverbacks();expect(triple.silverbacks.count==3,"round120 uses the three-boss count from the detailed original-game guide")
  let fourth=loopFixture(160);fourth.fixtureSilverbacks();expect(fourth.silverbacks.count==4,"later multiples of40 continue increasing the group rather than stopping after the tested loops")
  pair.damageSilverback(100,id:pairIDs[1]);expect(pair.silverbacks[0].hp==1200 && pair.silverbacks[1].hp==1100,"targeted damage reaches only the addressed brother rather than a shared boss-health scalar")
  pair.damageSilverback(120);expect(pair.silverbacks[0].hp==1080 && pair.silverbacks[1].hp==980,"a screen-wide bomb-style damage event affects each living brother once")
  for i in pair.silverbacks.indices {pair.silverbacks[i].hp=1200;pair.silverbacks[i].arrival=nil;pair.silverbacks[i].p=V2(x:i==0 ? 7:3,y:-3);pair.silverbacks[i].motion = .recovery;pair.silverbacks[i].clock=0}
  pair.shots=[Shot(id:24001,p:V2(x:0,y:-3),v:V2(x:100,y:0),ttl:1,damage:7,kind:nil)];pair.step(0.10,input:Controls())
  expect(pair.silverbacks[0].hp==1200 && pair.silverbacks[1].hp==1193 && pair.shots.isEmpty,"a projectile hits the nearer brother even when the farther boss is first in storage")
  let blastPair=loopFixture(80);blastPair.fixtureSilverbacks();for i in blastPair.silverbacks.indices {blastPair.silverbacks[i].arrival=nil;blastPair.silverbacks[i].p=V2(x:i==0 ? -5:5,y:-3)}
  blastPair.weaponExplosion(at:V2(x:5,y:-3),height:0.6,radius:2,damage:10)
  expect(blastPair.silverbacks[0].hp==1200 && blastPair.silverbacks[1].hp==1180,"local explosive splash cannot remotely damage a brother outside its radius")
  let flamePair=loopFixture(80);flamePair.fixtureSilverbacks();for i in flamePair.silverbacks.indices {flamePair.silverbacks[i].arrival=nil;flamePair.silverbacks[i].p=V2(x:i==0 ? -5:2,y:-3)}
  flamePair.fireFlame(from:V2(x:0,y:-3),direction:V2(x:1,y:0),height:0.6,damage:1)
  expect(flamePair.silverbacks[0].hp==1200 && flamePair.silverbacks[1].hp<1200,"flame targeting uses each brother's body position rather than damaging the first boss by proxy")
  let orbPair=loopFixture(80);orbPair.fixtureSilverbacks();orbPair.hero=V2(x:5,y:-3);for i in orbPair.silverbacks.indices {orbPair.silverbacks[i].p=orbPair.hero;orbPair.silverbacks[i].arrival=nil}
  orbPair.grantOrbs();orbPair.resolveSilverbackOrbs();let orbDamage=orbPair.silverbacks.reduce(0){$0+1200-$1.hp}
  expect(orbPair.orbShields.count==3 && abs(orbDamage-1200/500000)<0.000001,"one consumed orb supplies initial raw1 to only one overlapping brother and closes the gate")
  let contactPair=loopFixture(80);contactPair.fixtureSilverbacks();contactPair.invulnerable=0;contactPair.playerRoster.current.bodyShield=nil;contactPair.silverbacks[0].p=V2(x:5,y:5);contactPair.silverbacks[1].p=contactPair.hero;contactPair.resolveSilverbackContact()
  expect(contactPair.trainingHits==1,"a second brother can cause real contact accounting even when the first boss is far away")
  let partialBoss=loopFixture(80);partialBoss.fixtureSilverbacks();for i in partialBoss.silverbacks.indices {partialBoss.silverbacks[i].arrival=nil;partialBoss.silverbacks[i].p=V2(x:Double(i)*6-3,y:-3);partialBoss.silverbacks[i].motion = .recovery}
  partialBoss.foes=[Foe(id:24002,p:V2(x:6,y:5),hp:99,speed:0,gait:0)];partialBoss.damageSilverback(9999,id:partialBoss.silverbacks[0].id);partialBoss.step(0.01,input:Controls());let oneReward=partialBoss.score,oneShower=partialBoss.pickups.count
  expect(partialBoss.phase == .playing && partialBoss.foes.count==1 && partialBoss.silverbacks[1].hp>0,"defeating the first of two bosses neither clears the support horde nor opens the exit")
  partialBoss.step(0.01,input:Controls());expect(partialBoss.score==oneReward && oneShower==0 && partialBoss.pickups.isEmpty,"a dead brother scores once while round-clear treasure waits for all brothers and support enemies")
  partialBoss.damageSilverback(9999,id:partialBoss.silverbacks[1].id);partialBoss.step(2.1,input:Controls())
  expect(partialBoss.phase == .playing && partialBoss.foes.count==1 && partialBoss.silverbacks.allSatisfy{$0.deathAwarded},"all dead brothers retain the actual living support horde and cannot open the exit")
  partialBoss.foes[0].hp=0;partialBoss.resolveDefeatedFoes();partialBoss.step(0,input:Controls());expect(partialBoss.phase == .cleared,"controlled post-return death poll opens the exit after the final actual supporting enemy dies")
  partialBoss.hero=partialBoss.suggestedExit;partialBoss.clearClock=4;partialBoss.step(0.01,input:Controls());finishTravel(partialBoss);expect(partialBoss.phase == .cleared && partialBoss.bossVictory != nil && partialBoss.round==80,"the second boss-group teleporter starts its victory HUD before the return movie")
  let returning=loopFixture(40);returning.fixtureSilverbacks();returning.damageSilverback(9999);returning.step(2.1,input:Controls());returning.fate = .friendship;returning.restoreFateBenefits();returning.apply(.ray);returning.weaponReserve=17;returning.apply(.tank);returning.multiplier=5;returning.multiplierCharge=0.4;returning.lives=6;returning.bombs=3;returning.dashes=4;returning.fateRoomVisited=true
  let keptScore=returning.score,keptHits=returning.trainingHits;returning.hero=returning.suggestedExit;returning.clearClock=4;returning.step(0.01,input:Controls());finishTravel(returning);returning.step(BossVictory.duration,input:Controls());let returnPosition=returning.hero,keptVehicleTime=returning.vehicle!.remaining
  returning.step(0.5,input:Controls(move:V2(x:1,y:0),aim:V2(x:1,y:0),dash:true,bomb:true))
  expect(returning.phase == .loopReturn && returning.hero==returnPosition && returning.bombs==3 && returning.dashes==4 && returning.weaponReserve==17,"return animation freezes combat inputs and temporary equipment instead of spending resources offscreen")
  returning.step(0,input:Controls(pause:true));let pausedReturn=returning.loopReturn!.clock;returning.step(10,input:Controls())
  expect(returning.phase == .paused && returning.loopReturn!.clock==pausedReturn,"pause also freezes the return cinematic")
  returning.step(0,input:Controls(accept:true));returning.step(2.4,input:Controls());returning.step(2.7,input:Controls())
  expect(returning.round==41 && returning.phase == .playing && returning.layout.kind == .island && returning.loopReturn==nil,"completing the return continues into actual round41 on the island")
  expect(returning.score==keptScore && returning.lives==6 && returning.bombs==3 && returning.dashes==4 && returning.weapon == .ray && returning.weaponReserve==17 && returning.fate == .friendship && returning.fateRoomVisited && returning.trainingHits==keptHits && returning.multiplier==5 && returning.multiplierCharge==0.4 && returning.chickens.contains{$0.permanent} && returning.vehicle?.remaining==keptVehicleTime,"loop return preserves earned score lives inventory fate companions and virtual-life accounting")
  expect(returning.layout.walkable(returning.hero,clearance:0.60) && returning.heroElevation==returning.layout.height(returning.hero) && returning.combatSpawnFlow?.waves.groups.count==47,"new-loop arrival has a valid tank-sized position and the stronger wave is really armed")
  let lateRoom=loopFixture(45);lateRoom.phase = .cleared;enterLateBonus(lateRoom,SideRoomOffer(kind:.armory,p:lateRoom.layout.sideRoute(onLeft:true)))
  expect(lateRoom.phase == .bonusRoom && lateRoom.round==45,"bonus rooms remain discoverable after round40 instead of being blocked by the former cap")
  let noRepeatFate=loopFixture(54);noRepeatFate.fate = .feet;noRepeatFate.fateRoomVisited=true;noRepeatFate.phase = .cleared;noRepeatFate.advanceCombatRound()
  expect(noRepeatFate.round==55 && noRepeatFate.phase == .playing && noRepeatFate.fate == .feet && noRepeatFate.sideRoom==nil,"later cave loops do not offer another Room of Fate or erase the first choice")
  let malformedExit=loopFixture(80);malformedExit.phase = .cleared;malformedExit.advanceCombatRound();expect(malformedExit.round==80 && malformedExit.loopReturn==nil,"an undefeated later boss round cannot be skipped with an exit call")
  returning.reset();expect(returning.round==1 && returning.loopReturn==nil && returning.silverbacks.isEmpty && returning.rareLifeTimer?.drops==0,"new game clears loop return boss groups and scheduled-drop history")
  let prisonChest=GameCore();prisonChest.reset();prisonChest.round=49;prisonChest.beginRound();prisonChest.phase = .cleared;enterLateBonus(prisonChest,SideRoomOffer(kind:.treasure,p:prisonChest.layout.sideRoute(onLeft:true)))
  let tankStart=V2(x:-5.424544013640015,y:-3.473072546456463),tankLoot=V2(x:-4.25,y:-2.5),tankGoal=prisonChest.layout.clamped(tankLoot,clearance:0.72)
  expect(prisonChest.layout.walkable(tankGoal,clearance:0.68) && (tankGoal-tankLoot).length<0.8,"prison chest and tower leave a real tank-width aisle with the previously blocked treasure in collection range")
  let chestNav=ArenaNavigation(clearance:0.68);var chestPath=tankStart,chestValid=true
  for _ in 0..<600 {chestNav.update(layout:prisonChest.layout,target:tankGoal,dt:1.0/60);let d=chestNav.direction(from:chestPath,to:tankGoal,layout:prisonChest.layout);chestPath=prisonChest.layout.moved(chestPath,by:d*0.04,clearance:0.65);chestValid = chestValid && prisonChest.layout.walkable(chestPath,clearance:0.65)}
  expect(chestValid && (chestPath-tankLoot).length<0.8,"tank navigation reaches the prison treasure through the widened own-map aisle without collision exceptions or teleporting")
  let legacyColor=GameSettings.decode(Data("{\"godMode\":true,\"zoom\":2,\"soundEnabled\":false}".utf8))
  expect(legacyColor.playerColor == .green && legacyColor.godMode && legacyColor.zoom == .normal && !legacyColor.soundEnabled,"legacy settings keep color Godmode and sound while using the automatic camera standard")
  var colorPrefs=legacyColor;for color in PlayerColor.allCases {colorPrefs.playerColor=color;expect(GameSettings.decode(try! JSONEncoder().encode(colorPrefs))==colorPrefs,"player color \(color.title) survives save/load without changing existing preferences")}
  colorPrefs.playerColor = .green;colorPrefs.adjust(row:3,delta:-1);expect(colorPrefs.playerColor == .white && colorPrefs.godMode && !colorPrefs.soundEnabled,"color selection cycles backward while preserving Godmode and sound")
  let badColor=GameSettings.decode(Data("{\"playerColor\":\"unavailable\",\"brighter\":true}".utf8));expect(badColor.playerColor == .green && badColor.brighter,"an unknown stored player color falls back without discarding valid settings")
  var colorMenu=GameMenu();colorMenu.openSettings(phase:.paused);expect(colorMenu.handle(Controls(accept:true,menuRow:3),phase:.paused) == .setting(3,1) && colorMenu.settingsOpen,"controller activation changes player color without leaving settings")
  _=colorMenu.handle(Controls(accept:true,menuRow:4),phase:.paused);expect(!colorMenu.settingsOpen,"the fifth Back row returns to the paused menu")
  let mailbox=FrameInputMailbox();mailbox.publish(Controls(dash:true,accept:true,menuX:1),size:CGSize(width:1600,height:900));mailbox.publish(Controls(move:V2(x:1,y:0)),size:CGSize(width:1440,height:900));let frameOne=mailbox.take(),frameTwo=mailbox.take()
  expect(frameOne.controls.accept && frameOne.controls.dash && frameOne.controls.menuX==1 && frameOne.controls.move==V2(x:1,y:0) && frameOne.size.width==1440,"render input mailbox preserves one-shot events across several main-thread samples while taking the latest movement and viewport")
  expect(!frameTwo.controls.accept && !frameTwo.controls.dash && frameTwo.controls.menuX==0 && frameTwo.controls.move==V2(x:1,y:0),"one-shot input is consumed once while held movement survives to the next rendered frame")
  mailbox.publish(Controls(),size:CGSize(width:0,height:-4));let emptyViewport=mailbox.take().size;expect(emptyViewport.width==1 && emptyViewport.height==1,"a minimized or transient empty viewport cannot divide the camera aspect by zero")
  mailbox.publish(Controls(),size:CGSize(width:64,height:64));let resultLock=NSLock();var tornFrames=0
  DispatchQueue.concurrentPerform(iterations:2000){i in if i%2==0 {mailbox.publish(Controls(move:V2(x:Double(i),y:Double(i))),size:CGSize(width:Double(i+1),height:Double(i+1)))}else{let frame=mailbox.take();if frame.size.width != frame.size.height || frame.controls.move.x != frame.controls.move.y {resultLock.lock();tornFrames+=1;resultLock.unlock()}}}
  expect(tornFrames==0,"parallel event publication and render consumption never expose a torn controls or viewport snapshot")
  print("\(passed) checks passed")
 }
}
