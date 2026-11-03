import Foundation
@main struct AudioChecks {
 static func main(){
  setbuf(stdout,nil);var passed=0
  func expect(_ v:Bool,_ text:String){if !v {print("FAIL \(text)");exit(1)};passed+=1;print("PASS \(text)")}
  let kinds:[PickupKind?]=[nil,.spread,.ray,.rocket,.deathMachine,.grenade,.flamethrower]
  expect(Set(kinds.map{AudioCue.weapon($0)}).count==7,"all seven player weapon types have independent sound cues")
  var payloads=Set<Data>()
  for cue in AudioCue.allCases {
   let pcm=AudioSynth.samples(cue),wav=AudioSynth.wav(cue),peak=pcm.map{abs($0)}.max()!,rms=sqrt(pcm.reduce(0){$0+$1*$1}/Double(pcm.count))
   expect(pcm.allSatisfy{$0.isFinite} && peak<=0.90001 && rms>0.005 && abs(pcm[0])<0.001 && abs(pcm.last!)<0.001,"\(cue):finite audible-level PCM,headroom and quiet endpoints without playing audio")
   expect(wav==AudioSynth.wav(cue) && wav.count==pcm.count*2+44,"\(cue):deterministic correctly sized WAV without gameplay random draws")
   payloads.insert(wav)
  }
  expect(payloads.count==AudioCue.allCases.count,"all29 synthesized effect payloads differ;this is not perceptual/original-audio acceptance")
  let returning=GameCore();returning.reset();returning.invulnerable=0;returning.loseLife();_=returning.takeAudioEvents();returning.stepTeamRecovery(1.99)
  expect(returning.takeAudioEvents().isEmpty,"a pending funded return does not play its body-ready cue before the callback completes")
  returning.stepTeamRecovery(0.01)
  expect(returning.takeAudioEvents()==[.respawn] && AudioCue.respawn.priority==AudioCue.life.priority,"one actual restored body emits a separate high-priority return cue rather than a new-life pickup sound")
  for kind in kinds {
   let c=GameCore();c.reset();c.foes=[];_=c.takeAudioEvents();c.fireUsing(kind,from:.zero,direction:V2(x:1,y:0))
   expect(c.takeAudioEvents()==[AudioCue.weapon(kind)],"actual \(WeaponProfile.forPickup(kind).title) firing emits its specific cue exactly once")
   expect(kind == .flamethrower ? !c.flameJets.isEmpty:!c.shots.isEmpty,"\(WeaponProfile.forPickup(kind).title) sound selection still produces real weapon effects/projectiles")
  }
  for kind in [PickupKind.tank,.helicopter] {
   let c=GameCore();c.reset();c.apply(kind);_=c.takeAudioEvents();c.fireVehicleWeapons(0,firing:true)
   expect(c.takeAudioEvents().contains(kind == .tank ? .tankShot:.helicopterShot) && !c.shots.isEmpty,"actual \(kind) firing uses its own sound and retains its projectile")
  }
  let tankClock=GameCore();tankClock.reset();tankClock.apply(.tank);_=tankClock.takeAudioEvents();var emitted=0,sounded=0,lastSound = -100.0
  for i in 1...100 {
   tankClock.fireVehicleWeapons(0.01,firing:true);let cues=tankClock.takeAudioEvents();emitted+=cues.filter{$0 == .tankShot}.count
   if cues.contains(.tankShot),Double(i)*0.01-lastSound>=AudioCue.tankShot.minimumGap {sounded+=1;lastSound=Double(i)*0.01}
  }
  expect(emitted>=5 && sounded==emitted,"the actual tank cannon cadence is never halved by a longer audio cooldown")
  let sentryCore=GameCore();sentryCore.reset();_=sentryCore.takeAudioEvents();var sentry=SentryTurret(id:99999,p:.zero,elevation:0)
  sentryCore.fireSentry(&sentry,0,at:V2(x:3,y:0))
  expect(sentryCore.takeAudioEvents()==[.turretShot] && sentry.shotCount==1,"sentry fire is distinguishable and still produces a real shot")
  var safe=true
  for count in 1...AudioMix.maxVoices {for offset in 0..<AudioCue.allCases.count {
   let cues=(0..<count).map{AudioCue.allCases[($0+offset)%AudioCue.allCases.count]},weight=cues.reduce(0.0){$0+$1.gain}
   let gain=cues.reduce(0.0){$0+Double(AudioMix.voiceGain($1,totalWeight:weight,level:1,master:1))}
   safe = safe && gain<=AudioMix.effectBudget+0.00001 && gain*0.9+Double(AudioMix.musicGain(level:1,master:1,returning:false))<1
  }}
  expect(safe,"bounded simultaneous effect voices plus full-scale music leave mathematical output headroom")
  expect([Double.nan,Double.infinity,-Double.infinity,-1].allSatisfy{AudioMix.bounded($0)==0} && AudioMix.bounded(5)==1,"invalid or out-of-range gains cannot become nonfinite audio-player volumes")
  expect(AudioMix.musicGain(level:1,master:1,returning:true)==AudioMix.musicGain(level:1,master:1,returning:false)/2,"loop return music is ducked independently of the effects bus")
  expect(AudioCue.life.priority>AudioCue.turretShot.priority && AudioCue.hurt.priority>AudioCue.minigun.priority,"life and damage notifications take precedence over crowded automatic fire")
  let legacy=GameSettings.decode(Data("{\"godMode\":true,\"soundEnabled\":false,\"playerColor\":\"blue\"}".utf8))
  expect(legacy.effectsVolume==80 && legacy.musicVolume==60 && legacy.godMode && !legacy.soundEnabled && legacy.playerColor == .blue,"older preferences gain separate volume defaults while preserving existing state")
  let damaged=GameSettings.decode(Data("{\"effectsVolume\":999,\"musicVolume\":-2,\"godMode\":true}".utf8))
  expect(damaged.effectsVolume==100 && damaged.musicVolume==0 && damaged.godMode,"stored volumes are bounded without throwing away valid gameplay settings")
  var prefs=legacy;prefs.adjustAudio(row:1,delta:-1);prefs.adjustAudio(row:2,delta:1)
  expect(prefs.effectsVolume==60 && prefs.musicVolume==80 && prefs.godMode && prefs.playerColor == .blue && !prefs.soundEnabled,"effects and music adjust independently while global mute and player preferences survive")
  expect(GameSettings.decode(try! JSONEncoder().encode(prefs))==prefs,"separate volume preferences survive persistence roundtrip")
  for _ in 0..<20 {prefs.adjustAudio(row:1,delta:1);prefs.adjustAudio(row:2,delta:-1)}
  expect(prefs.effectsVolume==100 && prefs.musicVolume==0,"controller volume changes stop at zero/100 instead of wrapping from silent to loud")
  var menu=GameMenu();menu.openSettings(phase:.paused);_=menu.handle(Controls(accept:true,menuRow:2),phase:.paused)
  expect(menu.audioOpen && menu.count==5 && menu.selected==0,"sound selection opens a five-row controller menu without resuming the game")
  expect(menu.handle(Controls(menuX:-1,menuRow:2),phase:.paused) == .audioSetting(2,-1),"controller left/right on music changes only its volume")
  expect(menu.handle(Controls(accept:true,menuRow:3),phase:.paused) == .musicTrack(1),"controller activation on track advances the optional local playlist")
  expect(menu.handle(Controls(accept:true,menuRow:6),phase:.paused) == .none && menu.selected==3,"clicking a hidden row cannot activate the previously selected sound action")
  _=menu.handle(Controls(back:true),phase:.paused);expect(menu.settingsOpen && !menu.audioOpen && menu.selected==2,"Back leaves audio at its parent sound row without altering the run")
  var transport=MusicTransport();transport.replace(count:3);transport.update(arena:0);transport.update(arena:0)
  expect(transport.index==0,"music remains on one track within an arena instead of restarting each round/frame")
  transport.update(arena:1);expect(transport.index==1,"changing arena advances the own playlist once,without claiming an original track-map assignment")
  transport.select(-1);transport.select(-1);expect(transport.index==2,"manual previous-track selection wraps safely")
  transport.replace(count:1);expect(transport.index==0,"library shrink never leaves a stale track index")
  var enabled=GameSettings();let active=MusicRequest(settings:enabled,phase:.playing,round:1)
  expect(transport.shouldPlay(active),"a nonempty enabled playlist is eligible during actual play")
  expect([RunPhase.title,.paused,.gameOver,.checkpointComplete].allSatisfy{!transport.shouldPlay(MusicRequest(settings:enabled,phase:$0,round:1))},"title pause death and completion cannot continue background music output")
  expect([RunPhase.cleared,.bonusRoom,.loopReturn].allSatisfy{transport.shouldPlay(MusicRequest(settings:enabled,phase:$0,round:1))},"collection bonus rooms and loop return retain deliberate music transport")
  enabled.soundEnabled=false;expect(!transport.shouldPlay(MusicRequest(settings:enabled,phase:.playing,round:1)),"global mute also mutes imported music")
  enabled.soundEnabled=true;enabled.musicVolume=0;expect(!transport.shouldPlay(MusicRequest(settings:enabled,phase:.playing,round:1)),"music volume zero pauses music without changing effect gain")
  transport.replace(count:0);transport.select(1);expect(!transport.shouldPlay(active) && transport.index==0,"an absent library stays silent and cannot index an unavailable original track")
  print("\(passed) audio checks passed;no audio output,not listening/hardware/original-sound acceptance")
 }
}
