import Foundation
@main struct ExitChecks {
 static func main(){
  setbuf(stdout,nil);var passed=0
  func expect(_ ok:Bool,_ why:String){if !ok {print("FAIL \(why)");exit(1)};passed+=1;print("PASS \(why)")}
  func close(_ a:Double,_ b:Double)->Bool {abs(a-b)<1e-8}
  func game(_ round:Int=1,_ count:Int=1)->GameCore {let g=GameCore();g.reset(playerCount:count);g.round=round;g.beginRound();g.foes=[];g.pickups=[];g.combatSpawningHeld=true;g.phase = .cleared;g.clearClock=0;g.fateRoomVisited=true;return g}
  var counts=Set<Int>(),sides=Set<Int>(),magicSeen=Set<SideRoomKind>(),valid=true
  for seed in 1...180 {
   let g=game(5);g.exitSeed=UInt64(seed);g.prepareArenaExits()
   counts.insert(g.arenaExits.count);sides.formUnion(g.arenaExits.compactMap{$0.side?.rawValue});magicSeen.formUnion(g.arenaExits.compactMap(\.bonus))
   valid = valid && g.arenaExits.allSatisfy{$0.side != .east && $0.side != nil} && Set(g.arenaExits.compactMap(\.side)).count==g.arenaExits.count
  }
  expect(counts==[1,2,3] && sides==[0,2,3] && valid,"180 independent exit seeds cover1–3 unique directions while excluding the previously taken east exit")
  expect(magicSeen==[.treasure,.armory],"actual route generation can expose both natural bonus types")
  for round in stride(from:1,through:37,by:4) {
   let layout=ArenaLayout.forRound(round);var reachable=true
   for side in EntrySide.allCases {
    let target=layout.playerExit(on:side),nav=ArenaNavigation();var p=layout.clamped(layout.spawn)
    for _ in 0..<1800 where (p-target).length>=0.55 {nav.update(layout:layout,target:target,dt:1.0/60);p=layout.moved(p,by:nav.direction(from:p,to:target,layout:layout)*0.10)}
    reachable = reachable && (p-target).length<0.55
   }
   expect(reachable,"arena\(round) navigation reaches every physical cardinal exit through actual collision and height transitions")
  }
  for round in [1,2,3,5,6,7,9,10,11,13,14,15,39,43] {
   let g=game(round);g.prepareArenaExits()
   expect(round%4 != 3 || g.arenaExits.count==1,"round\(round) before arena-round4 has exactly one path")
   expect(g.arenaExits.allSatisfy{g.layout.walkable($0.p,clearance:0.28) && close($0.height,g.layout.height($0.p))},"round\(round) every own exit lies on reachable map-height ground")
  }
  for round in [4,8,12,16,40,80] {
   let g=game(round);g.prepareArenaExits()
   expect(g.arenaExits.count==1 && g.arenaExits[0].teleporter && g.availableExits.isEmpty && g.sideRoomOffer==nil,"round\(round) arena boundary has a rising pad instead of random edge or magic routes")
   g.clearClock=3;expect(g.availableExits.count==1,"round\(round) pad becomes usable only after its3s rise")
  }
  let delay=game(5);for seed in 1...100 {delay.exitSeed=UInt64(seed);delay.prepareArenaExits();if delay.arenaExits.count==3 {break}}
  expect(delay.arenaExits.count==3 && delay.availableExits.count==1,"only the first of three paths opens initially")
  delay.clearClock=0.199;expect(delay.availableExits.count==1,"second path stays closed before200ms")
  delay.clearClock=0.2;expect(delay.availableExits.count==2,"second path opens at200ms")
  delay.clearClock=0.4;expect(delay.availableExits.count==3,"third path opens at400ms")
  let cooldown=game(6);cooldown.lastMagicExitRound=5;cooldown.prepareArenaExits();expect(cooldown.sideRoomOffer==nil,"two-round magic interval blocks a premature bonus even when multiple exits open")
  let early=game(1);early.prepareArenaExits();expect(early.sideRoomOffer==nil,"first round cannot expose an early magical route")
  let guaranteed=game(21);var guaranteedArmory=true,armories=0
  for seed in 1...100 {guaranteed.exitSeed=UInt64(seed);guaranteed.prepareArenaExits();if let offer=guaranteed.sideRoomOffer {armories+=1;guaranteedArmory = guaranteedArmory && offer.kind == .armory}}
  expect(guaranteedArmory && armories>0,"a first natural magic visit after round20 must be an armory until one is actually taken")
  let transit=game(1,2);transit.prepareArenaExits();transit.clearClock=1;let path=transit.availableExits[0];transit.players[1].hero=path.p;transit.players[1].heroElevation=path.height
  let starts=transit.players.map(\.hero);expect(transit.tryTeamExit() && transit.phase == .transition,"player two can start a shared exit transition through an actually open route")
  let stocks=transit.players.map{[$0.bombs,$0.dashes]},clocks=transit.roundClock
  transit.step(0.6,inputs:[Controls(move:V2(x:1,y:0),dash:true,bomb:true),Controls(aim:V2(x:1,y:0))])
  expect(transit.players.map(\.hero)==starts && transit.players.map{[$0.bombs,$0.dashes]}==stocks && transit.shots.isEmpty && close(transit.roundClock,clocks+0.6),"fade-out blocks all player combat input while independent world time continues")
  expect(close(transit.arenaTransit!.darkness,0.5) && transit.round==1,"ordinary exit reaches half black after100ms debounce plus500ms fade")
  transit.step(0,input:Controls(pause:true));let clock=transit.arenaTransit!.clock;transit.step(20,input:Controls());expect(transit.phase == .paused && transit.arenaTransit!.clock==clock,"pause freezes a partially dark transition")
  transit.step(0,input:Controls(accept:true));transit.step(2.199,input:Controls());expect(transit.round==1 && transit.arenaTransit!.darkness==1,"map cannot change before the black hold ends")
  transit.step(0.001,input:Controls());expect(transit.round==2 && transit.phase == .transition && transit.arenaTransit!.committed && transit.arenaTransit!.darkness==1,"map changes once at2.8s while completely hidden")
  expect(transit.previousExitSide==path.side && transit.players.allSatisfy{transit.layout.walkable($0.hero) && ($0.facing-(V2.zero-$0.hero).unit).length<1e-8},"the taken side persists and both new bodies face the arena center")
  transit.step(0.2,input:Controls());expect(close(transit.arenaTransit!.cameraProgress,1) && close(transit.arenaTransit!.darkness,1),"200ms camera tween finishes before the fade-in reveals the map")
  transit.step(0.75,input:Controls());expect(close(transit.arenaTransit!.darkness,0.5) && transit.phase == .transition,"controls remain frozen halfway through the1.5s fade-in")
  transit.step(0.75,input:Controls());expect(transit.phase == .playing && transit.round==2 && transit.arenaTransit==nil,"4.5s ordinary sequence restores gameplay exactly once")
  let identity=transit.environmentRevision;transit.step(0,input:Controls());expect(transit.environmentRevision==identity,"completed transition cannot repeat its round commit")
  for side in EntrySide.allCases {
   let g=game(2,4);g.previousExitSide=side;g.positionTeamForArenaEntry()
   let center=g.players.map(\.hero).reduce(.zero,+)*(0.25),expected=g.layout.playerExit(on:side)*0.8
   expect((center-expected).length<1e-6 && g.players.allSatisfy{g.layout.walkable($0.hero,clearance:0.28)},"four players form a centered legal own-width row on the selected\(side) side")
  }
  let pad=game(4);pad.prepareArenaExits();pad.clearClock=3;pad.hero=pad.arenaExits[0].p;_=pad.tryTeamExit();pad.step(1,input:Controls());expect(pad.round==5 && pad.arenaTransit!.darkness==1,"boundary teleporter commits after1s fade with no ordinary1.7s hold")
  pad.step(1.7,input:Controls());expect(pad.round==5 && pad.phase == .playing,"boundary teleporter releases controls after2.7s")
  let reset=game();reset.prepareArenaExits();reset.clearClock=1;reset.hero=reset.availableExits[0].p;_=reset.tryTeamExit();reset.reset();expect(reset.arenaExits.isEmpty && reset.arenaTransit==nil && reset.previousExitSide == .east && reset.lastMagicExitRound==0,"new run clears routes,transition and source initial previous-side/magic history")
  print("\(passed) arena exit/transition checks passed;source path counts/waits,own route geometry/row width;source background spawn timing")
 }
}
