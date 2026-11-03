import Foundation
@main struct DonationChecks {
 static func main(){
  setbuf(stdout,nil);var count=0
  func expect(_ yes:Bool,_ message:String){guard yes else{fatalError(message)};count+=1;print("PASS \(message)")}
  func near(_ a:Double,_ b:Double)->Bool {abs(a-b)<0.000001}
  func game(_ n:Int=2)->GameCore {let g=GameCore();g.reset(playerCount:n);g.foes=[];g.pickups=[];g.combatSpawningHeld=true;for p in g.players {p.lives=0;p.invulnerable=0;p.hero=V2(x:Double(p.slot)*3,y:0)};return g}
  func hit(_ g:GameCore,_ slot:Int){g.withPlayer(slot){g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.vehicle=nil;g.loseLife()}}
  let flow=game();flow.players[0].lives=1;hit(flow,1)
  expect(flow.lifeTransfers.isEmpty && flow.players[0].lives==1 && flow.players[1].reviveRemaining==60,"a zero-reserve death starts a sixty-second timer and does not immediately steal a life")
  flow.stepTeamRecovery(0.99)
  expect(flow.lifeTransfers.isEmpty && flow.players[0].donationCooldown==0,"the initial one-second search wait is observable")
  flow.stepTeamRecovery(0.01)
  expect(flow.lifeTransfers.count==1 && flow.lifeTransfers[0].stage == .linking && flow.players[0].lives==1 && flow.players[0].donationsGiven==0,"finding a donor begins the link without debiting their reserve")
  expect(near(flow.players[0].donationCooldown,10) && near(flow.players[1].donationCooldown,65),"donor and recipient share role cooldowns of ten and sixty-five seconds")
  flow.stepTeamRecovery(0.99);expect(flow.players[0].lives==1 && flow.players[1].respawnRemaining==nil,"the donor keeps the reserve during the link's one-second lead-in")
  flow.stepTeamRecovery(0.01)
  expect(flow.players[0].lives==0 && flow.players[0].donationsGiven==1 && flow.lifeTransfers[0].stage == .flying && near(flow.players[0].bodyShield?.remaining ?? -1,3.05),"the debit occurs once at the start of the physical one-second life transfer and protects the donor")
  flow.stepTeamRecovery(0.99);expect(!flow.players[1].sponsoredRespawn && flow.players[1].donationsReceived==0,"an in-flight life is not already a received respawn credit")
  flow.stepTeamRecovery(0.01)
  expect(flow.players[1].sponsoredRespawn && flow.players[1].donationsReceived==1 && near(flow.players[1].respawnRemaining ?? -1,2),"arrival wakes the independent credit watcher and begins the funded two-second return")
  expect(flow.directedLifeRewards.isEmpty && flow.players[0].bombs==1 && flow.players[0].dashes==2 && flow.players[0].vehicle==nil,"a completed transfer grants no instant compensation equipment")
  flow.stepTeamRecovery(0.049);expect(flow.directedLifeRewards.isEmpty,"compensation selection waits at least its first fifty-millisecond attempt")
  flow.stepTeamRecovery(1.951)
  expect(!flow.players[1].isDown && flow.players[1].lives==0 && near(flow.players[1].bodyShield?.remaining ?? -1,8.65),"the complete initial search/link/flight/funded return restores one body at five seconds with the full read shield duration")
  expect(!flow.directedLifeRewards.isEmpty && flow.directedLifeRewards.allSatisfy{$0.kind == .bomb || $0.kind == .dash},"early-round compensation is physical bombs or boosts rather than unavailable vehicles")
  expect(flow.players.allSatisfy{$0.score==0 && $0.collectedLives==0} && flow.activePlayerSlot==0,"the transfer creates no score or collected lives and leaks no selected player")
  let busy=game(4);busy.players[0].lives=3;hit(busy,1);hit(busy,2);busy.stepTeamRecovery(1)
  expect(busy.lifeTransfers.count==1 && busy.lifeTransfers[0].recipient==1 && !busy.players[2].donationSearchActive,"simultaneous searches choose the same richest first role and its busy status blocks the second search")
  busy.stepTeamRecovery(14)
  expect(busy.players[0].donationCooldown==0 && busy.players[2].isDown && busy.players[2].donationsReceived==0 && near(busy.players[2].reviveRemaining,45),"a busy-source attempt does not silently retry when its cooldown later expires")
  busy.stepTeamRecovery(45);expect(!busy.players[2].isDown && busy.players[2].lives==0,"the blocked recipient still returns through the independent sixty-second timer")
  let wait=game();hit(wait,1);wait.stepTeamRecovery(59.99)
  expect(wait.players[1].isDown && near(wait.players[1].reviveRemaining,0.01),"without a donor the body remains down until the sixty-second boundary")
  wait.stepTeamRecovery(0.01);expect(!wait.players[1].isDown && wait.players[1].lives==0,"automatic return creates a current body without a reserve")
  let paused=game();paused.players[0].lives=1;hit(paused,1);paused.stepTeamRecovery(1.5)
  let remaining=paused.lifeTransfers[0].remaining,cooldown=paused.players[0].donationCooldown
  paused.phase = .paused;paused.stepTeamRecovery(100)
  expect(paused.lifeTransfers[0].remaining==remaining && paused.players[0].donationCooldown==cooldown,"pause freezes the link, both cooldowns and recovery instead of completing a hidden transfer")
  paused.phase = .playing;paused.stepTeamRecovery(1.5);paused.stepTeamRecovery(1)
  let fall=paused.directedLifeRewards.first!.fallClock;paused.phase = .paused;paused.stepTeamRecovery(100)
  expect(paused.directedLifeRewards.first!.fallClock==fall,"physical compensation fall freezes with the same shared pause")
  let gifts=game(3);gifts.makeDirectedReward(for:0,kind:.bomb);gifts.stepTeamRecovery(0.5);gifts.collectDirectedRewards()
  expect(gifts.directedLifeRewards.count==1 && gifts.players[0].bombs==1,"an airborne compensation model above collection height cannot apply its reward early")
  gifts.players[0].hero=V2(x:4,y:2);gifts.stepTeamRecovery(0.8)
  expect(gifts.directedLifeRewards[0].landed && gifts.directedLifeRewards[0].p==gifts.players[0].hero,"a compensation follows its original target while falling and then lands at that actual position")
  gifts.players[0].hero=V2(x:-4,y:-2);gifts.players[1].hero=V2(x:4,y:2);gifts.collectDirectedRewards()
  expect(gifts.directedLifeRewards.isEmpty && gifts.players[0].bombs==1 && gifts.players[1].bombs==2,"another living teammate can physically collect the donor's landed compensation")
  gifts.collectDirectedRewards();expect(gifts.players[1].bombs==2,"a consumed compensation model cannot award a second time")
  let stored=game();stored.makeDirectedReward(for:0,kind:.dash);stored.stepTeamRecovery(1.3);let original=stored.directedLifeRewards[0].p
  stored.round=5;stored.beginRound();stored.collectDirectedRewards()
  expect(stored.directedLifeRewards.count==1 && stored.visibleDirectedRewards.isEmpty,"a landed gift stays associated with its original own arena instead of appearing in the next map")
  stored.round=1;stored.beginRound();stored.players[1].hero=original;stored.players[0].hero=V2(x:-5,y:0);stored.collectDirectedRewards()
  expect(stored.directedLifeRewards.isEmpty && stored.players[1].dashes==3,"revisiting the gift's arena permits a living teammate to collect the retained physical object")
  let eligibility=game();expect(!eligibility.donationRewardAllowed(.tank) && !eligibility.donationRewardAllowed(.helicopter) && eligibility.donationRewardAllowed(.bombs) && eligibility.donationRewardAllowed(.boosts),"early-round reward eligibility follows tank4 and Hind9 while consumables remain available")
  eligibility.round=4;expect(eligibility.donationRewardAllowed(.tank) && !eligibility.donationRewardAllowed(.helicopter),"round4 opens the tank compensation without opening the helicopter")
  eligibility.round=9;expect(eligibility.donationRewardAllowed(.helicopter),"an active prison combat round can admit a helicopter compensation")
  eligibility.phase = .cleared;expect(!eligibility.donationRewardAllowed(.helicopter),"prison intermission blocks the helicopter compensation")
  eligibility.phase = .playing;eligibility.withPlayer(1){eligibility.apply(.orb)}
  expect(!eligibility.donationRewardAllowed(.tank) && !eligibility.donationRewardAllowed(.helicopter),"another player's active exclusive protection blocks new vehicle compensation")
  eligibility.players[1].orbShields=[];eligibility.pickups=[Pickup(id:999000,p:.zero,kind:.teddy)]
  expect(!eligibility.donationRewardAllowed(.tank) && eligibility.donationRewardAllowed(.bombs),"an uncollected exclusive world pickup also blocks vehicles without blocking consumable bundles")
  let parityA=game(),parityB=game();parityA.players[0].lives=2;parityB.players[0].lives=2;hit(parityA,1);hit(parityB,1)
  parityA.stepTeamRecovery(6);for _ in 0..<360{parityB.stepTeamRecovery(1.0/60)}
  expect(parityA.players.map(\.lives)==parityB.players.map(\.lives) && parityA.players.map(\.isDown)==parityB.players.map(\.isDown) && parityA.directedLifeRewards.map(\.kind)==parityB.directedLifeRewards.map(\.kind) && zip(parityA.players,parityB.players).allSatisfy{near($0.donationCooldown,$1.donationCooldown)},"one large recovery step agrees with360 small steps for funding, return, reward types and both cooldowns")
  let late=game();late.players[0].lives=1;hit(late,1);late.stepTeamRecovery(1.5);late.players[1].reviveRemaining=0.1;late.stepTeamRecovery(0.1);late.stepTeamRecovery(1.4)
  expect(!late.players[1].isDown && late.players[1].sponsoredRespawn && late.players[1].donationsReceived==1,"a gift already underway can arrive after a free return and retain its original future-body credit")
  hit(late,1);late.stepTeamRecovery(2)
  expect(!late.players[1].isDown && !late.players[1].sponsoredRespawn && late.players[1].lives==0,"the late sponsored credit funds the next real death exactly once")
  let all=game();all.players[0].lives=1;hit(all,1);all.stepTeamRecovery(2.5);hit(all,0)
  expect(all.phase == .gameOver && all.lifeTransfers.isEmpty && all.directedLifeRewards.isEmpty,"the final unfunded real death cancels an in-flight gift and starts one ending")
  let protected=game();protected.players[0].lives=1;hit(protected,0);protected.stepTeamRecovery(2)
  protected.foes=[Foe(id:900099,p:protected.hero,hp:9,speed:0,gait:0)]
  protected.step(8.64,inputs:[])
  expect(!protected.players[0].isDown && protected.players[0].deaths==1 && (protected.players[0].bodyShield?.remaining ?? 0)>0,"full return protection prevents a real touching enemy from killing the body before8.65seconds")
  protected.step(0.02,inputs:[])
  protected.foes=[Foe(id:900100,p:protected.hero,hp:9,speed:0,gait:0)];protected.step(0.001,inputs:[])
  expect(protected.players[0].isDown && protected.players[0].deaths==2,"a fresh real enemy can kill the body after the full shield and its prior contact-kill pass expire")
  var branches=Set<PickupKind>(),bundles=true
  for offset in 0..<40 {
   let probe=game();probe.round=13;probe.beginRound();probe.pickups=[];probe.foes=[];probe.players[0].lives=1;probe.players[1].lives=0
   for _ in 0..<offset {_=probe.random()};hit(probe,1);probe.stepTeamRecovery(7)
   let kinds=Set(probe.directedLifeRewards.map(\.kind));branches.formUnion(kinds)
   bundles = bundles && kinds.count==1 && probe.directedLifeRewards.count==(kinds.contains(.bomb) ? 3:kinds.contains(.dash) ? 4:1)
  }
  expect(branches == [.bomb,.dash,.tank,.helicopter],"forty production transfer sequences with different generator positions reach all four eligible compensation types")
  expect(bundles,"actual compensation sequences issue exactly three separate bombs four separate boosts or one vehicle model")
  let spent=game(3);spent.players[0].lives=1;hit(spent,0);hit(spent,1);spent.stepTeamRecovery(2)
  expect(!spent.players[0].isDown && spent.players[1].isDown && spent.players[0].lives==0 && spent.players[0].donationsGiven==0 && spent.players[1].donationsReceived==0 && spent.lifeTransfers.isEmpty && spent.directedLifeRewards.isEmpty,"a donor's own simultaneous funded return consumes its only reserve without a second manufactured transfer or reward")
  let paid=game();paid.players[0].lives=1;hit(paid,1);paid.stepTeamRecovery(1.2);hit(paid,0)
  for _ in 0..<228 {paid.stepTeamRecovery(1.0/60)}
  expect(paid.phase == .playing && paid.players[0].isDown && !paid.players[1].isDown && paid.players.allSatisfy{$0.lives==0} && paid.players[0].donationsGiven==1 && paid.players[1].donationsReceived==1 && near(paid.players[0].reviveRemaining,58.2),"228 ordinary frames preserve an already paid flying life while a now-unfunded donor body enters normal waiting without ending or creating a reserve")
  flow.reset();expect(flow.lifeTransfers.isEmpty && flow.directedLifeRewards.isEmpty && flow.players.allSatisfy{!$0.hasRecoveryProcess && !$0.donationSearchActive && !$0.recoveryWatchActive && $0.donationCooldown==0},"new runs clear both lifecycle clocks, all transfers and retained gift maps")
  print("\(count) donation lifecycle checks passed;source-based waits and physical gifts,own world scale/tie policy,not original binary or hardware acceptance")
 }
}
