import Foundation

@main struct HerdAudioChecks {
    static func main() {
        setbuf(stdout,nil);var passed=0
        func expect(_ yes:Bool,_ text:String){guard yes else{fatalError(text)};passed+=1;print("PASS \(text)")}
        func world(_ count:Int=1)->GameCore {
            let g=GameCore();g.reset(playerCount:count);g.round=17;g.beginRound();g.foes=[];g.pickups=[];g.combatSpawningHeld=true
            for p in g.players {p.hero=V2(x:6,y:5);p.invulnerable=0};_=g.takeAudioEvents();return g
        }
        expect(AudioCue.allCases.count==29 && AudioLoopKind.allCases.count==7,"two distinct one-shot types and one world loop extend existing stable effect identifiers")
        expect(AudioLoopKey(bullID:1).valid && AudioLoopKey(bullID:1) != AudioLoopKey(slot:1,kind:.tank),"world cow identity cannot alias the same-numbered player role")
        expect(!AudioLoopKey(bullID:0).valid && !AudioLoopKey(bullID:-1).valid && !AudioLoopKey(slot:0,kind:.buffalo).valid,"invalid world identities and player-owned buffalo types cannot enter native audio")
        expect(AudioLoopKind.buffalo.fadeOut==1 && AudioLoopKind.boots.fadeOut==0.5,"natural cow tail preserves the source one-second stop while powerups keep half-second tails")
        let p=SoundSpace.placement(V2(x:-5,y:0),centerX:0,centerY:0,halfWidth:10,halfDepth:8,sign:1)
        let reversed=SoundSpace.placement(V2(x:-5,y:0),centerX:0,centerY:0,halfWidth:10,halfDepth:8,sign:-1)
        expect(p.pan == -0.5 && reversed.pan==0.5 && p.gain==reversed.gain,"camera reversal flips stereo without changing distance gain")
        let near=SoundSpace.placement(.zero,centerX:0,centerY:0,halfWidth:10,halfDepth:8,sign:1),far=SoundSpace.placement(V2(x:15,y:0),centerX:0,centerY:0,halfWidth:10,halfDepth:8,sign:1)
        expect(near.gain>far.gain && far.gain>0 && far.pan==1,"an approaching offscreen edge remains quiet but audible before reaching the battle centre")
        expect(SoundSpace.placement(V2(x:100,y:100),centerX:0,centerY:0,halfWidth:10,halfDepth:8,sign:1).gain==0,"remote unseen cattle cannot occupy audible sound voices")
        expect(SoundSpace.placement(V2(x:.nan,y:0),centerX:0,centerY:0,halfWidth:10,halfDepth:8,sign:1).gain==0,"nonfinite source position becomes silence instead of invalid player gain")
        let invalid=SoundSpace.placement(.zero,centerX:.nan,centerY:.infinity,halfWidth:.nan,halfDepth:0,sign:1)
        expect(invalid.pan.isFinite && invalid.gain.isFinite,"transient invalid camera values use a bounded finite sound frame")
        let g=world(4);g.bulls=(1...10).map{i in Bull(id:i,p:V2(x:Double(i-1),y:0),direction:V2(x:1,y:0),speed:3.2)}
        let requests=g.loopAudioRequests()
        expect(requests.count==4 && Set(requests.compactMap{$0.key.worldID})==Set(1...4),"real world snapshot chooses four loudest nearby cow identities with deterministic ties")
        g.bulls.reverse();expect(g.loopAudioRequests()==requests,"reordering actual world objects cannot churn the selected sound sources")
        g.withPlayer(0){g.boots=10;g.beginVehicle(.tank)};g.withPlayer(1){g.beginVehicle(.helicopter)}
        let mixed=AudioLoopPolicy.normalized(g.loopAudioRequests(),enabled:true,phase:.playing,level:1)
        expect(mixed.count<=8 && mixed.filter{$0.key.worldID != nil}.count==4 && mixed.contains{$0.key.kind == .tank} && mixed.contains{$0.key.kind == .hind},"cow ambience shares bounded voices with independent tank/Hind/equipment owners")
        var transport=AudioLoopTransport();_=transport.update(mixed)
        let moved=mixed.map{AudioLoopRequest(key:$0.key,pan:-$0.pan,gain:$0.gain*0.5)},delta=transport.update(moved)
        expect(delta.started.isEmpty && delta.stopped.isEmpty,"moving and attenuating an existing animal does not restart its gait waveform")
        for phase in [RunPhase.paused,.title,.bonusRoom,.transition,.loopReturn,.gameOver] {
            let output=AudioLoopPolicy.normalized(requests,enabled:true,phase:phase,level:1)
            expect(output.isEmpty,"\(phase) cannot retain sound from world cattle")
        }
        for phase in [RunPhase.playing,.cleared] {
            expect(AudioLoopPolicy.normalized(requests,enabled:true,phase:phase,level:1).count==4,"\(phase) keeps the physically remaining herd audible")
        }
        expect(AudioLoopPolicy.normalized(mixed,enabled:false,phase:.playing,level:1).isEmpty && AudioLoopPolicy.normalized(mixed,enabled:true,phase:.playing,level:0).isEmpty,"global mute and zero effects gain stop both role and world voices")
        let herd=world();herd.bulls=[Bull(id:21,p:.zero,direction:V2(x:1,y:0),speed:0),Bull(id:22,p:.zero,direction:V2(x:1,y:0),age:-0.1),Bull(id:23,p:.zero,direction:V2(x:1,y:0),age:10)]
        expect(herd.loopAudioRequests().isEmpty,"stationary,not-yet-active and expired bodies cannot produce a running hoof loop")
        herd.bulls=[Bull(id:24,p:V2(x:3,y:0),direction:V2(x:1,y:0))];herd.phase = .cleared;herd.stampede?.stop()
        expect(herd.loopAudioRequests().count==1,"stopping new challenge births does not silence the surviving visible cow")
        herd.phase = .transition;expect(herd.loopAudioRequests().isEmpty,"actual exit-taking transition silences cow sound before its model reaches black")
        var a=HerdVoiceTimeline(),b=HerdVoiceTimeline()
        expect(a.roars(through:-0.001,id:51).isEmpty,"sacred-cow initialization does not play a roar before activation")
        let complete=a.roars(through:10,id:51)
        var split=[Double]();for frame in 0...600 {split+=b.roars(through:Double(frame)/60,id:51)}
        expect(complete==split && complete.first==0 && complete.count>=2,"large and600small age samples preserve every sound-only roar deadline")
        let waits=zip(complete,complete.dropFirst()).map{$1-$0-AudioSynth.duration(.bullRoar)}
        expect(waits.allSatisfy{$0>=1 && $0<4.5},"roars wait for the own clip to end and then the source1–4.5second pause")
        expect(a.roars(through:100,id:51).isEmpty && b.roars(through:0,id:51).isEmpty,"expired/repeated/rewound snapshots cannot replay a backlog of roars")
        var other=HerdVoiceTimeline();expect(other.roars(through:10,id:52) != complete,"independent animal identities do not all roar in permanent lockstep")
        let random=world(),control=world();random.bulls=[Bull(id:71,p:V2(x:-8,y:-5),direction:V2(x:1,y:0),speed:3.2)]
        random.moveStampedeBulls(3.5);_=random.loopAudioRequests();_=random.takeSpatialAudioFrame()
        expect(random.random()==control.random() && random.id()==control.id(),"real hoof/roar snapshots and timers never consume gameplay randomness or world identities")
        let warm=world();warm.bulls=[Bull(id:81,p:V2(x:-7,y:-4),direction:V2(x:1,y:0),age:-0.1)];warm.moveStampedeBulls(0.099)
        expect(warm.takeAudioEvents().isEmpty,"actual golden birth remains silent just before its100ms local initialization")
        warm.moveStampedeBulls(0.001);expect(warm.takeAudioEvents()==[.bullRoar],"actual activation emits one positioned starting roar")
        warm.moveStampedeBulls(0);expect(warm.takeAudioEvents().isEmpty,"zero-time presentation revisit cannot duplicate the starting roar")
        let impact=world();impact.hero = .zero;impact.godMode=true;impact.foes=[Foe(id:91,p:V2(x:1,y:0),hp:10,speed:0,gait:0)];impact.bulls=[Bull(id:92,p:V2(x:-3,y:0),direction:V2(x:1,y:0),speed:10)]
        impact.moveStampedeBulls(0.6)
        expect(impact.takeAudioEvents().filter{$0 == .bullImpact}.count==2 && impact.foes[0].hp==0 && impact.trainingHits==1,"real swept body contacts cue both player and NPC impacts while preserving gameplay damage")
        let staying=world();staying.hero = .zero;staying.godMode=true;staying.bulls=[Bull(id:93,p:.zero,direction:V2(x:1,y:0),speed:0)]
        staying.moveStampedeBulls(0);_=staying.takeAudioEvents();staying.moveStampedeBulls(0.1)
        expect(!staying.takeAudioEvents().contains(.bullImpact),"one physical crossing does not spam a new impact on every presentation frame")
        let spatial=world();spatial.emitAudio(.bullRoar,at:V2(x:-2,y:0));spatial.emitAudio(.bullRoar,at:V2(x:14,y:0));spatial.emitAudio(.life)
        let frame=spatial.takeSpatialAudioFrame()
        expect(frame.placements[.bullRoar]!.pan<0 && frame.placements[.life]==AudioPlacement() && frame.cues.contains(.life),"multiple same-type sounds choose the nearer world source while ordinary life cues stay centred")
        expect(spatial.takeAudioEvents().isEmpty,"spatial frame consumes the same bounded once-only event queue")
        spatial.emitAudio(.bullRoar,at:V2(x:100,y:100));expect(spatial.takeSpatialAudioFrame().cues.isEmpty,"inaudible distant roars are discarded before native playback")
        for _ in 0..<100 {spatial.emitAudio(.bullRoar,at:.zero)};spatial.emitAudio(.hurt);spatial.emitAudio(.life)
        let crowded=spatial.takeSpatialAudioFrame();expect(crowded.cues.count==32 && crowded.cues.contains(.hurt) && crowded.cues.contains(.life),"dense world events cannot displace later critical life/damage hints")
        print("\(passed) herd audio checks passed;source event structure,own synthesis/range/voice-budget/roar RNG/contact policy;no output,not listening/original-waveform/hardware acceptance")
    }
}
