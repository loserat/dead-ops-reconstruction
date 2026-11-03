import Foundation
@main struct ShieldChecks {
 static func main(){
  setbuf(stdout,nil);var passed=0
  func expect(_ ok:Bool,_ why:String){if !ok{print("FAIL \(why)");exit(1)};passed+=1;print("PASS \(why)")}
  func near(_ a:Double,_ b:Double)->Bool {abs(a-b)<1e-7}
  func fixture(_ count:Int=1)->GameCore {
   let g=GameCore();g.reset(playerCount:count);g.foes=[];g.pickups=[];g.combatSpawningHeld=true
   for p in g.players {p.hero = .zero;p.heroElevation=0;p.invulnerable=0}
   return g
  }
  func foe(_ id:Int,_ p:V2,_ height:Double=0)->Foe {Foe(id:id,p:p,hp:100,speed:0,gait:0,elevation:height)}
  let g=fixture();g.beginBodyShield();g.foes=[foe(99001,V2(x:0.4,y:0)),foe(99002,V2(x:1.5,y:0))]
  g.invulnerable=0
  expect(!g.acceptsPlayerDamage,"the real return shield remains effective independently of the legacy wound-invulnerability field")
  g.step(0.049,input:Controls())
  expect(g.foes.count==2 && g.foes.allSatisfy{$0.hp==100} && !g.acceptsPlayerDamage,"full shield protects immediately but does not silently delete nearby enemies before50ms")
  g.step(0.001,input:Controls())
  expect(!g.foes.contains{$0.id==99001} && g.foes.contains{$0.id==99002} && g.score>=100 && g.deaths==0,"the delayed narrow shield kills a touching foe through normal scoring and leaves the old2.5radius crowd intact")
  let limits=fixture();limits.beginBodyShield();limits.stepTeamRecovery(0.05)
  limits.foes=[foe(1,V2(x:0.649,y:0)),foe(2,V2(x:0.651,y:0)),foe(3,.zero,0.501),foe(4,.zero,0.499)]
  limits.resolveBodyShieldContacts()
  expect(limits.foes.filter{$0.hp<=0}.map(\.id)==[1,4],"own mapped65radius/50height bounds retain enemies just outside or on another level")
  let owner=fixture(2);owner.players[0].hero=V2(x:-5,y:0);owner.withPlayer(1){owner.beginBodyShield()};owner.stepTeamRecovery(0.05);owner.foes=[foe(1,V2(x:0.3,y:0))]
  owner.forEachLivingPlayer{owner.resolveBodyShieldContacts()};owner.resolveDefeatedFoes()
  expect(owner.players[0].score==0 && owner.players[1].score==100 && owner.foes.isEmpty,"a shield kill follows its real player-two credit through ordinary defeat and drop handling")
  let generic=fixture();generic.invulnerable=999;generic.foes=[foe(1,.zero)];generic.step(0.1,input:Controls())
  expect(generic.foes.count==1 && generic.score==0 && generic.players[0].bodyShield==nil,"wound or diagnostic invulnerability alone never invents a contact-kill shield")
  let movement=fixture();movement.hero=V2(x:-3,y:0);movement.beginBodyShield();movement.stepTeamRecovery(0.05);movement.foes=[foe(1,V2(x:-1.5,y:0))]
  movement.step(0.5,input:Controls(move:V2(x:1,y:0)))
  expect(movement.foes.isEmpty && movement.score>=100,"the shield sweeps its actual walking path rather than testing only the final endpoint")
  let expiry=fixture();expiry.beginBodyShield();expiry.stepTeamRecovery(8.65)
  expect(expiry.players[0].bodyShield==nil && expiry.acceptsPlayerDamage,"full shield and its damage protection expire on their own8.65s clock")
  expiry.foes=[foe(1,.zero)];expiry.step(0.001,input:Controls());expect(expiry.players[0].isDown && expiry.deaths==1,"a fresh touching enemy after expiry causes a real death")
  let short=fixture();short.beginBodyShield(short:true);short.stepTeamRecovery(3.049)
  expect(!short.acceptsPlayerDamage && near(short.players[0].bodyShield!.remaining,0.001),"donor's short shield survives until3.05s")
  short.stepTeamRecovery(0.001);expect(short.players[0].bodyShield==nil && short.acceptsPlayerDamage,"short donation shield ends without acquiring the full return duration")
  let overlap=fixture();overlap.beginBodyShield();overlap.stepTeamRecovery(1);let remaining=overlap.players[0].bodyShield!.remaining;overlap.beginBodyShield(short:true)
  expect(near(overlap.players[0].bodyShield!.remaining,remaining),"short shield cannot truncate an existing longer full shield")
  overlap.stepTeamRecovery(6);overlap.beginBodyShield(short:true)
  expect(near(overlap.players[0].bodyShield!.remaining,3.05) && overlap.players[0].bodyShield!.contactActive,"overlapping extension retains an existing mature contact trigger instead of creating a50ms hole")
  let paused=fixture();paused.beginBodyShield();paused.step(0.1,input:Controls());paused.step(0,input:Controls(pause:true));let age=paused.players[0].bodyShield!.age;paused.step(30,input:Controls())
  expect(paused.players[0].bodyShield!.age==age,"pause freezes shield age and visual phase")
  paused.step(0,input:Controls(accept:true));paused.reset();expect(paused.players[0].bodyShield==nil && !paused.players[0].shieldContactThisStep,"new run clears shield and its last collision-window flag")
  let partial=fixture(2);partial.players[0].lives=0;partial.loseLife();partial.players[0].reviveRemaining=0.05;partial.stepTeamRecovery(0.2)
  expect(near(partial.players[0].bodyShield!.remaining,8.5),"return halfway through a recovery step advances its shield only through the remaining150ms")
  let boss=fixture();boss.round=40;boss.beginRound();boss.fixtureSilverbacks();boss.beginBodyShield();boss.stepTeamRecovery(0.05);boss.silverbacks[0].p=boss.hero;boss.resolveBodyShieldContacts()
  expect(boss.silverbacks[0].hp==Silverback.maxHP,"body contact shield excludes the Silverback boss")
  for direction in [V2(x:1,y:0),V2(x:0,y:1),V2(x:-1,y:0),V2(x:0,y:-1)] {
   let boost=fixture();boost.facing=direction;boost.dashTime=0.3;boost.players[0].boostDirection=direction
   boost.foes=[foe(1,direction*2.84),foe(2,direction * -0.36),foe(3,direction*1.0,0.51),foe(4,direction*0.5)]
   boost.resolveBoostContacts(from:boost.hero,to:boost.hero,oldHeight:0,endHeight:0)
   expect(boost.foes.filter{$0.hp<=0}.map(\.id)==[1,4],"two forward boost circles rotate with aim\(direction),reach ahead,exclude behind and other floors")
  }
  let rotation=fixture();rotation.dashTime=0.3;rotation.players[0].boostDirection=V2(x:1,y:0);rotation.facing=V2(x:0,y:1);rotation.foes=[foe(1,V2(x:0,y:2.7)),foe(2,V2(x:2.7,y:0))]
  rotation.resolveBoostContacts(from:.zero,to:.zero,oldHeight:0,endHeight:0)
  expect(rotation.foes[0].hp==0 && rotation.foes[1].hp==100,"linked forward kill circles follow current aim while stored travel velocity remains independent")
  let vehicle=fixture();vehicle.beginVehicle(.helicopter);vehicle.beginBodyShield();vehicle.stepTeamRecovery(0.05);vehicle.foes=[foe(1,vehicle.hero)];vehicle.resolveBodyShieldContacts()
  expect(vehicle.foes[0].hp==100,"an elevated helicopter shield cannot erase a ground-level foe")
  let sound=fixture();sound.beginBodyShield();_=sound.takeAudioEvents();sound.stepTeamRecovery(5.649)
  expect(sound.takeAudioEvents().isEmpty,"full shield has no premature three-second warning")
  sound.stepTeamRecovery(0.001)
  expect(sound.takeAudioEvents()==[.shieldWarning],"entering the last three seconds emits one distinct warning cue")
  sound.stepTeamRecovery(2.999);expect(sound.takeAudioEvents().isEmpty,"warning is not repeated on every protected frame")
  sound.stepTeamRecovery(0.001);expect(sound.takeAudioEvents()==[.shieldEnd],"shield expiry emits one distinct end cue")
  sound.stepTeamRecovery(10);expect(sound.takeAudioEvents().isEmpty,"an expired shield cannot keep emitting end cues")
  print("\(passed) shield contact checks passed;archived waits/trigger dimensions,own world scale/overlap/vertical bounds")
 }
}
