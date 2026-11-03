import Foundation
@main struct FateEntryChecks {
 static func main(){
  var count=0
  func expect(_ yes:Bool,_ message:String){guard yes else{fatalError(message)};count+=1;print("PASS \(message)")}
  var draws=0
  func low()->Int{draws+=1;return 0}
  for round in [1,2,3,4,8,11,12,16,20,40,80] {
   expect(!FateEntryRules.due(after:round,visited:false,roll:low),"round \(round) cannot offer Fate before eligibility or at an arena boundary")
  }
  expect(draws==0,"ineligible rounds consume no fate chance draw")
  for round in [13,14] {
   let allowed=(0..<100).filter{value in FateEntryRules.due(after:round,visited:false,roll:{value})}
   expect(allowed==Array(0...30),"after round \(round) the reference's inclusive threshold accepts exactly31 of100 integer outcomes")
  }
  expect(FateEntryRules.due(after:15,visited:false,roll:low) && draws==0,"after round15 Fate is guaranteed without another chance draw")
  expect(!FateEntryRules.due(after:15,visited:true,roll:low) && draws==0,"a visited room never reopens on later guaranteed eligibility")
  expect(FateEntryRules.due(after:17,visited:false,roll:low) && draws==0,"late skipped-stage fixtures still follow the script's unvisited forced rule")
  func fixture(_ round:Int,_ offset:Int=0,_ players:Int=1)->GameCore {
   let g=GameCore();g.reset(playerCount:players);for _ in 0..<offset{_ = g.random()};g.round=round;g.beginRound();g.phase = .cleared;return g
  }
  var randomEntries=0,randomMisses=0
  for offset in 0..<64 {
   let main=fixture(13,offset),branch=fixture(13,offset)
   main.advanceCombatRound();branch.enterSideRoom(SideRoomOffer(kind:.armory,p:branch.layout.sideRoute(onLeft:true)))
   if main.sideRoom?.kind == .fate {
    randomEntries+=1
    expect(branch.sideRoom?.kind == .fate && branch.round==13 && branch.sideRoomOffer==nil && !branch.visitedSideRoomRounds.contains(13),"matching chance hit replaces both normal and bonus exit before bonus loot appears")
    expect(branch.pickups.isEmpty && branch.fateRoomVisited && branch.fateRoom != nil,"overridden armory exposes no weapons before the Fate choice")
   }else{
    randomMisses+=1
    expect(main.round==14 && branch.sideRoom?.kind == .armory && branch.round==13 && branch.pickups.count<=1 && branch.sourceLoot!.pendingRoomPrograms==1,"matching chance miss starts the selected source armory program and advances normal exit directly")
    branch.advanceCombatRound()
    expect(branch.round==14 && branch.phase == .playing && !branch.fateRoomVisited,"leaving the armory advances once without a second chance for the same completed round")
   }
  }
  expect(randomEntries>0 && randomMisses>0,"64 real seeded exit pairs exercise both chance branches")
  let failed=(0..<64).first{offset in let g=fixture(13,offset);return !g.takeFateRouteIfDue()}!
  let repeated=fixture(13,failed),mirror=fixture(13,failed)
  expect(!repeated.takeFateRouteIfDue() && !mirror.takeFateRouteIfDue(),"the selected miss fixture has the same first evaluation")
  for _ in 0..<100 {precondition(!repeated.takeFateRouteIfDue())}
  expect(repeated.random()==mirror.random(),"repeated contacts in one cleared round neither reroll nor consume extra randomness")
  let forced=fixture(15,0,2);forced.players[1].isDown=true;forced.players[1].reviveRemaining=60;forced.players[1].donationCooldown=999
  forced.enterSideRoom(SideRoomOffer(kind:.treasure,p:forced.layout.sideRoute(onLeft:false)))
  expect(forced.round==15 && forced.sideRoom?.kind == .fate && forced.players[1].isDown && forced.players[1].reviveRemaining==60,"guaranteed Fate replaces a treasure route without silently reviving a waiting teammate")
  forced.sideRoom!.clock=FateRoomTiming.choiceEnd;forced.step(0,inputs:[])
  forced.sideRoom!.clock=FateRoomTiming.choiceEnd+FateRoomTiming.settle+FateRoomTiming.farewell;forced.step(0,inputs:[]);forced.step(2.7,inputs:[])
  expect(forced.round==16 && forced.phase == .playing && forced.fateRoomVisited && forced.players.allSatisfy(\.missedFate),"missed choice ends the room once and still marks its visit complete")
  forced.round=17;forced.phase = .cleared;forced.advanceCombatRound()
  expect(forced.round==18 && forced.sideRoom==nil,"missing a Fate does not create repeated visits later in the run")
  let frozen=fixture(15);frozen.clearClock=4;frozen.hero=frozen.layout.exit;frozen.step(0,input:Controls(pause:true));frozen.step(2,input:Controls())
  expect(frozen.phase == .paused && frozen.round==15 && frozen.fateEntryEvaluatedRound==nil,"paused real exit processing cannot evaluate or enter Fate")
  repeated.reset();expect(repeated.fateEntryEvaluatedRound==nil && !repeated.fateRoomVisited,"new run clears the once-per-combat-exit evaluation")
  print("\(count) fate entry checks passed")
 }
}
