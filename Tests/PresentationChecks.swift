import Foundation
@main struct PresentationChecks {
 static func main(){
  setbuf(stdout,nil);var passed=0
  func expect(_ condition:Bool,_ message:String){if !condition {print("FAIL \(message)");exit(1)};passed+=1;print("PASS \(message)")}
  func fixture(_ round:Int=1)->GameCore {let c=GameCore();c.reset();c.round=round;c.beginRound();c.hero = .zero;c.heroElevation=0;c.pickups=[];return c}
  let styles=PickupKind.allCases.map{PickupPresentation.forKind($0)}
  expect(Set(styles.map(\.title)).count==PickupKind.allCases.count && styles.allSatisfy{!$0.title.isEmpty && $0.tint>0},"every actual pickup has a distinct German readout and a visible tint")
  expect(WeaponProfile.pickups.allSatisfy{kind in let s=PickupPresentation.forKind(kind);return s.category == .weapon && s.title.replacingOccurrences(of:"-",with:" ")==WeaponProfile.forPickup(kind).title.replacingOccurrences(of:"-",with:" ")},"ground gun labels agree with the six usable temporary weapon names")
  expect(Set(WeaponProfile.pickups.map{PickupPresentation.forKind($0).tint}).count==6,"six weapon tints remain distinct alongside their separate native silhouettes")
  expect(PickupPresentation.forKind(.treasure).category == .treasure && PickupPresentation.forKind(.gem).category == .treasure && PickupCategory.treasure.markerCorners==0,"ordinary metal and gems do not receive a powerup marker or crowd the near-player readout")
  expect([PickupKind.tank,.helicopter].allSatisfy{PickupPresentation.forKind($0).category == .vehicle} && [PickupKind.orb,.teddy,.barrelShield].allSatisfy{PickupPresentation.forKind($0).category == .protection},"vehicles and shields are identified independently of weapon pickups")
  let c=fixture();c.pickups=[Pickup(id:1,p:V2(x:0.1,y:0),kind:.gem),Pickup(id:2,p:V2(x:0.2,y:0),kind:.treasure),Pickup(id:3,p:V2(x:2,y:0),kind:.ray),Pickup(id:4,p:V2(x:2.4,y:0),kind:.rocket)]
  expect(PickupPresentation.hint(in:c,keeping:nil)?.id==3,"nearby treasure never masks the nearest useful equipment readout")
  expect(PickupPresentation.hint(in:c,keeping:4)?.id==4,"small distance changes retain the current item instead of flickering between neighboring funds")
  c.pickups[3].p=V2(x:2.5,y:0);expect(PickupPresentation.hint(in:c,keeping:4)?.id==3,"a meaningfully nearer item takes over the retained hint")
  c.pickups.removeAll{$0.id==3};expect(PickupPresentation.hint(in:c,keeping:3)?.id==4,"a collected or expired current item cannot leave a stale label")
  c.pickups[2].p=V2(x:3.21,y:0);expect(PickupPresentation.hint(in:c,keeping:4)==nil,"equipment outside the actual short readout radius remains unlabelled")
  let floor=fixture(9);floor.hero=V2(x:0,y:6.1);floor.heroElevation=0;floor.pickups=[Pickup(id:5,p:V2(x:0,y:6.2),kind:.life)]
  expect(floor.layout.height(floor.pickups[0].p)>1.5 && PickupPresentation.hint(in:floor,keeping:5)==nil,"a life on the prison catwalk is not advertised to a player under the floor")
  floor.heroElevation=1.6;expect(PickupPresentation.hint(in:floor,keeping:nil)?.id==5,"the same catwalk life is identified when the player reaches its floor")
  floor.apply(.helicopter);floor.heroElevation=3.2;expect(PickupPresentation.hint(in:floor,keeping:nil)?.id==5,"flying uses the same cross-height eligibility as actual helicopter collection")
  let phases:[RunPhase]=[.title,.paused,.gameOver,.checkpointComplete,.loopReturn]
  expect(phases.allSatisfy{floor.phase=$0;return PickupPresentation.hint(in:floor,keeping:5)==nil},"menus death and loop cinematics cannot show a stale nearby pickup hint")
  expect([RunPhase.playing,.cleared,.bonusRoom].allSatisfy{floor.phase=$0;return PickupPresentation.hint(in:floor,keeping:nil)?.id==5},"combat collection and bonus-room phases all identify nearby equipment using the same floor eligibility")
  let score=floor.score,lives=floor.lives,ttl=floor.pickups[0].ttl,weapon=floor.weapon
  for _ in 0..<1000 {_=PickupPresentation.hint(in:floor,keeping:5)}
  expect(floor.score==score && floor.lives==lives && floor.pickups[0].ttl==ttl && floor.weapon==weapon && floor.pickups.count==1,"render readout selection never collects spends grants score or advances the gameplay clock")
  let gifts=fixture();gifts.makeDirectedReward(for:0,kind:.bomb);gifts.makeDirectedReward(for:0,kind:.bomb);gifts.makeDirectedReward(for:0,kind:.bomb)
  gifts.stepTeamRecovery(0.5)
  expect(PickupPresentation.hint(in:gifts,keeping:nil)==nil,"high directed compensation never advertises a physically unreachable pickup")
  gifts.stepTeamRecovery(0.8);gifts.hero=V2(x:2,y:0)
  let bundle=gifts.visibleRewardBundles[0]
  expect(gifts.directedLifeRewards.count==3 && gifts.visibleRewardBundles.count==1 && bundle.count==3,"three identical landed compensation triggers keep their inventory value while sharing one non-overexposed symbol")
  expect(PickupPresentation.hint(in:gifts,keeping:nil)?.id==bundle.reward.id && PickupPresentation.hint(in:gifts,keeping:nil)?.kind == .bomb,"landed directed compensation participates in the same nearby item identification as ordinary equipment")
  gifts.hero = .zero;gifts.collectDirectedRewards()
  expect(gifts.bombs==4 && gifts.visibleRewardBundles.isEmpty && PickupPresentation.hint(in:gifts,keeping:bundle.reward.id)==nil,"collecting a rendered bundle awards all three logical bombs once and clears its hint")
  gifts.makeDirectedReward(for:0,kind:.dash);gifts.stepTeamRecovery(1.3);gifts.round=5;gifts.beginRound();gifts.pickups=[]
  expect(PickupPresentation.hint(in:gifts,keeping:nil)==nil && gifts.visibleRewardBundles.isEmpty && gifts.directedLifeRewards.count==1,"retained compensation on another own map cannot leak into the current item hint")
  print("\(passed) presentation checks passed;native model readability is checked separately")
 }
}
