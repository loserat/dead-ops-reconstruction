import Foundation
import SceneKit
import SpriteKit
import GameController
#if os(macOS)
import AppKit
typealias GameColor = NSColor
typealias NodeFloat = CGFloat
#else
import UIKit
typealias GameColor = UIColor
typealias NodeFloat = Float
#endif

func rgb(_ n:Int, _ alpha:CGFloat=1)->GameColor {
    #if os(macOS)
    return NSColor(srgbRed:CGFloat((n>>16)&255)/255,green:CGFloat((n>>8)&255)/255,blue:CGFloat(n&255)/255,alpha:alpha)
    #else
    return UIColor(red:CGFloat((n>>16)&255)/255,green:CGFloat((n>>8)&255)/255,blue:CGFloat(n&255)/255,alpha:alpha)
    #endif
}
func material(_ color:Int, glow:Bool=false)->SCNMaterial {
    let m=SCNMaterial();m.diffuse.contents=rgb(color);m.roughness.contents=0.95
    for p in [m.diffuse,m.normal,m.roughness,m.transparent] {p.minificationFilter = .linear;p.magnificationFilter = .linear;p.mipFilter = .linear;p.maxAnisotropy=4}
    if glow {m.emission.contents=rgb(color)}
    return m
}
func box(_ x:CGFloat,_ y:CGFloat,_ z:CGFloat,_ color:Int)->SCNNode {
    let g=SCNBox(width:x,height:y,length:z,chamferRadius:0.02);g.chamferSegmentCount=1;g.materials=[material(color)];return SCNNode(geometry:g)
}
func ball(_ radius:CGFloat,_ color:Int,glow:Bool=false)->SCNNode {
    let g=SCNSphere(radius:radius);g.segmentCount=10;g.materials=[material(color,glow:glow)];return SCNNode(geometry:g)
}
func cylinder(_ radius:CGFloat,_ height:CGFloat,_ color:Int)->SCNNode {
    let g=SCNCylinder(radius:radius,height:height);g.radialSegmentCount=8;g.materials=[material(color)];return SCNNode(geometry:g)
}


#if os(macOS)
final class GameView:SCNView {
    var input:InputState?
    var menuClick:((CGPoint)->Void)?
    override var acceptsFirstResponder:Bool {true}
    override func keyDown(with event:NSEvent) {
        guard let input else{return};input.keys.insert(event.keyCode)
        if !event.isARepeat {
            switch event.keyCode {
            case 36:input.pendingAccept=true
            case 49:input.pendingDash=true
            case 11:input.pendingBomb=true
            case 53:input.pendingPause=true
            default:break
            }
        }
    }
    override func keyUp(with event:NSEvent) {input?.keys.remove(event.keyCode)}
    override func mouseDown(with event:NSEvent) {
        let p=convert(event.locationInWindow,from:nil),s=min(bounds.width/1280,bounds.height/720)
        guard s>0 else{return}
        let y=isFlipped ? bounds.height-p.y:p.y
        menuClick?(CGPoint(x:(p.x-(bounds.width-1280*s)/2)/s,y:(y-(bounds.height-720*s)/2)/s))
    }
}
#else
final class GameView:SCNView {}
#endif

final class ArcadeGame:NSObject,SKSceneDelegate {
    let inputMailbox=FrameInputMailbox()
    let core=GameCore(),input=InputState(),scene=SCNScene(),camera=SCNNode(),sun=SCNNode()
    let view:GameView
    let audio:ArcadeAudio
    let music:ArcadeMusic
    let settingsDefaults:UserDefaults?
    var settings:GameSettings
    var cameraRig=ArenaOverviewCamera(),menu=GameMenu()
    var menuNames:[SKLabelNode]=[],menuValues:[SKLabelNode]=[],menuHighlights:[SKShapeNode]=[]
    let modeLabel=SKLabelNode(fontNamed:"Menlo-Bold")
    let actors=SCNNode(),decor=SCNNode(),exit=SCNNode(),sideExit=SCNNode(),remains=SCNNode()
    var artMaterials:[String:SCNMaterial]=[:]
    var enemyCharacterTemplates:[Int:SCNNode]=[:]
    var enemySkinGeometries:[Int:EnemySkinGeometry]=[:]
    var projectileGeometries:[Int:SCNGeometry]=[:]
    var foliageImages:[String:CGImage]=[:],foliageMasks:[ObjectIdentifier:FoliageOpacityMask]=[:],foliageMasksByImage:[ObjectIdentifier:FoliageOpacityMask]=[:]
    var clothTexture:CGImage?
    let readabilityHUD=SKNode()
    var builtRevision = -1
    var builtArena:ArenaKind?,trapNodes:[SCNNode]=[],rainNodes:[SCNNode]=[],forestSnowNodes:[SCNNode]=[]
    var corpseNodes:[SCNNode]=[]
    var fallingBodies:[FallenBodyArt]=[]
    let weaponLabel=SKLabelNode(fontNamed:"Menlo-Bold"),fateLabel=SKLabelNode(fontNamed:"Menlo-Bold")
    var barrelNodes:[Int:SCNNode]=[:]
    let multiplierFill=SKShapeNode(),nextLifeLabel=SKLabelNode(fontNamed:"Menlo-Bold")
    let pickupHintLabel=SKLabelNode(fontNamed:"Menlo-Bold")
    var pickupHintID:Int?
    var silverbackNodes:[Int:SCNNode]=[:],loopVisitor:SCNNode?,raiderNode:SCNNode?
    var silverbackNode:SCNNode? {silverbackNodes.keys.sorted().first.flatMap{silverbackNodes[$0]}}
    let bossHUD=SKNode(),bossLabel=SKLabelNode(fontNamed:"Menlo-Bold"),bossHealth=SKShapeNode(rectOf:CGSize(width:280,height:5))
    let bossIntroHUD=SKNode(),bossIntroTitle=SKLabelNode(fontNamed:"AvenirNext-Heavy"),bossIntroSubtitle=SKLabelNode(fontNamed:"AvenirNext-DemiBold")
    let bossIntroBackdrop=SKShapeNode(rectOf:CGSize(width:640,height:116),cornerRadius:18)
    let bossVictoryHUD=SKNode(),bossVictoryTitle=SKLabelNode(fontNamed:"AvenirNext-Heavy"),bossVictorySubtitle=SKLabelNode(fontNamed:"AvenirNext-DemiBold"),bossVictoryBrothers=SKLabelNode(fontNamed:"AvenirNext-DemiBold")
    let bossVictoryBackdrop=SKShapeNode(rectOf:CGSize(width:780,height:176),cornerRadius:18)
    var bullNodes:[Int:SCNNode]=[:]
    var flameJetNodes:[Int:SCNNode]=[:]
    var entryMarkerNodes:[Int:SCNNode]=[:]
    var fateDoorNodes:[Int:SCNNode]=[:],fateDropNodes:[Int:SCNNode]=[:]
    var fateBootNodes:[Int:SCNNode]=[:]
    var fateLifeNodes:[Int:SCNNode]=[:]
    var lifeLinkNodes:[Int:SCNNode]=[:],lifeTransferNodes:[Int:SCNNode]=[:],directedRewardNodes:[Int:SCNNode]=[:]
    var foeNodes:[Int:SCNNode]=[:],shotNodes:[Int:SCNNode]=[:],pickupNodes:[Int:SCNNode]=[:],effectNodes:[Int:SCNNode]=[:]
    var arenaExitNodes:[Int:SCNNode]=[:]
    let transitCurtain=SKSpriteNode(color:.black,size:CGSize(width:1280,height:720))
    var transitCameraOrigin:SCNMatrix4?,transitCameraID:Int?
    let hud=SKScene(size:CGSize(width:1280,height:720))
    let hudCanvas=SKNode()
    let stat=SKLabelNode(fontNamed:"Menlo-Bold"),score=SKLabelNode(fontNamed:"Menlo-Bold"),roundLabel=SKLabelNode(fontNamed:"Menlo-Bold")
    let title=SKLabelNode(fontNamed:"AvenirNext-Heavy"),sub=SKLabelNode(fontNamed:"AvenirNext-Medium"),hint=SKLabelNode(fontNamed:"AvenirNext-Medium"),notice=SKLabelNode(fontNamed:"Menlo-Bold")
    let curtain=SKShapeNode(rectOf:CGSize(width:1280,height:720))
    let endingBars=SKNode()
    private(set) var renderedFrames=0
    var timer:Timer?,lastTime=ProcessInfo.processInfo.systemUptime,lastRound=0
    var lastAudioFrame=SpatialAudioFrame(cues:[],placements:[:])
    var lastLoopAudioRequests=[AudioLoopRequest]()
    var openingTextureImages:[String:CGImage]=[:],openingTerrainLoads=0,openingTerrainBuilds=0
    var cameraElevation=0.0
    let endingArt=GameOverArt()
    var previousCameraHero:V2?
    var playerArtStates=[PlayerArtState(slot:0)],teamCamera=TeamCameraRig()
    let teamHUD=SKNode(),roundBackdrop=SKShapeNode(),noticeBackdrop=HUDRoundedShape()
    var testPilot=false
    var keyboardPlayer=false,inputDevices:[InputDeviceStatus]=[],availableControllers=0
    init(view:GameView,defaults:UserDefaults? = .standard,music:ArcadeMusic?=nil) {
        self.view=view;settingsDefaults=defaults;settings=GameSettings.load(defaults);audio=ArcadeAudio(allowed:defaults != nil)
        self.music=music ?? ArcadeMusic(allowed:defaults != nil,folder:defaults == nil ? nil:ArcadeMusic.userFolder,bundleFolder:Bundle.main.resourceURL?.appendingPathComponent("Music"))
        super.init()
        core.godMode=settings.godMode
        view.scene=scene;view.backgroundColor=rgb(0x101c1b);view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond=60;view.isPlaying=false;view.rendersContinuously=false
        #if os(macOS)
        view.input=input
        #endif
        scene.rootNode.addChildNode(decor);scene.rootNode.addChildNode(actors);scene.rootNode.addChildNode(remains)
        camera.camera=SCNCamera();camera.camera?.usesOrthographicProjection=false;camera.camera?.projectionDirection = .horizontal;camera.camera?.fieldOfView=GameCameraProjection.fieldOfView;camera.camera?.orthographicScale=9.7
        let initialDistance=GameCameraProjection.distance(scale:9.7,aspect:16.0/9)
        camera.camera?.zNear=0.75;camera.camera?.zFar=120;camera.position=SCNVector3(0,initialDistance*GameCameraProjection.ground,initialDistance*GameCameraProjection.up)
        camera.look(at:SCNVector3(0,0,0));scene.rootNode.addChildNode(camera);view.pointOfView=camera
        camera.camera?.wantsHDR=true;camera.camera?.wantsExposureAdaptation=false;camera.camera?.exposureOffset=0.05
        camera.camera?.screenSpaceAmbientOcclusionIntensity=0;camera.camera?.screenSpaceAmbientOcclusionRadius=0.5
        camera.camera?.screenSpaceAmbientOcclusionBias=0.04;camera.camera?.saturation=1.0;camera.camera?.contrast=0.08
        camera.camera?.bloomIntensity=0.10;camera.camera?.bloomThreshold=1.4;camera.camera?.bloomBlurRadius=5
        camera.camera?.vignettingIntensity=0.07;camera.camera?.vignettingPower=0.7
        sun.light=SCNLight();sun.light?.type = .directional;sun.light?.intensity=1000;sun.light?.castsShadow=true
        sun.light?.shadowColor=rgb(0x17251b,0.42);sun.light?.shadowMode = .deferred;sun.light?.shadowRadius=2.5;sun.light?.shadowSampleCount=16
        sun.light?.shadowMapSize=CGSize(width:2048,height:2048);sun.light?.orthographicScale=32;sun.light?.shadowBias=0.025
        sun.eulerAngles=SCNVector3(-0.7,-0.65,0);scene.rootNode.addChildNode(sun)
        let ambient=SCNNode();ambient.light=SCNLight();ambient.light?.type = .ambient;ambient.light?.color=rgb(0xb0bcc6);ambient.light?.intensity=340;scene.rootNode.addChildNode(ambient)
        scene.fogColor=rgb(0x395a58);scene.fogStartDistance=48;scene.fogEndDistance=85
        rebuildArena();hero.addChildNode(detailedCharacter(player:true));actors.addChildNode(hero)
        buildHUD();hint.numberOfLines=2;hint.preferredMaxLayoutWidth=1120;buildMenus();buildSideExit();view.overlaySKScene=hud
        prepareEnemySkinTemplates()
        GCController.shouldMonitorBackgroundEvents=false
        if defaults != nil {
            // SpriteKit owns all scene/HUD updates; a main-thread timer captures native input only.
            hud.delegate=self
            captureNativeInput()
            timer=Timer(timeInterval:1.0/60,repeats:true){[weak self] _ in self?.captureNativeInput()}
            RunLoop.main.add(timer!,forMode:.common)
            view.isPlaying=true;view.rendersContinuously=true
        }
        #if os(macOS)
        NotificationCenter.default.addObserver(forName:NSApplication.didResignActiveNotification,object:nil,queue:.main){[weak self] _ in
            guard let self else{return};input.keys=[]
            input.pendingSystemPause=true
        }
        #endif
    }
    deinit {timer?.invalidate();audio.stop();music.stop()}
    func pickupNode(_ kind:PickupKind)->SCNNode { detailedPickup(kind) }
    func label(_ l:SKLabelNode,_ size:CGFloat,_ color:Int,_ x:CGFloat,_ y:CGFloat,align:SKLabelHorizontalAlignmentMode = .center) {
        l.fontSize=size;l.fontColor=rgb(color);l.position=CGPoint(x:x,y:y);l.horizontalAlignmentMode=align;hudCanvas.addChild(l)
    }
    var acceptHint:String {
        #if os(macOS)
        return "✕ / Return"
        #else
        return "✕"
        #endif
    }
    func buildHUD() {
        hud.scaleMode = .resizeFill;hud.backgroundColor = .clear;hud.addChild(hudCanvas)
        curtain.fillColor=rgb(0x08130f,0.86);curtain.strokeColor = .clear;curtain.position=CGPoint(x:640,y:360);curtain.zPosition=5;hudCanvas.addChild(curtain)
        for (y,h) in [(667.0,105.0),(49.0,98.0)] {
            let panel=SKShapeNode(rectOf:CGSize(width:1280,height:h));panel.fillColor=rgb(0x0b151b,y>600 ? 0.74:0.44);panel.strokeColor = .clear;panel.position=CGPoint(x:640,y:y);panel.zPosition = -1;readabilityHUD.addChild(panel)
        }
        readabilityHUD.isHidden=false;hudCanvas.addChild(readabilityHUD)
        bossHUD.isHidden=true;hudCanvas.addChild(bossHUD)
        bossLabel.fontName="Menlo-Bold";bossLabel.fontSize=13;bossLabel.fontColor=rgb(0xffc49b);bossLabel.position=CGPoint(x:640,y:675);bossHUD.addChild(bossLabel)
        let bossTrack=SKShapeNode(rectOf:CGSize(width:284,height:9));bossTrack.fillColor=rgb(0x17221d,0.85);bossTrack.strokeColor = .clear;bossTrack.position=CGPoint(x:640,y:662);bossHUD.addChild(bossTrack)
        bossHealth.fillColor=rgb(0xd98b62);bossHealth.strokeColor = .clear;bossHealth.position=CGPoint(x:640,y:662);bossHUD.addChild(bossHealth)
        bossIntroHUD.zPosition=3;bossIntroHUD.isHidden=true;hudCanvas.addChild(bossIntroHUD)
        bossIntroBackdrop.position=CGPoint(x:640,y:401);bossIntroBackdrop.fillColor=rgb(0x101c2a,0.94);bossIntroBackdrop.strokeColor=rgb(0xffb37c,0.45);bossIntroBackdrop.lineWidth=1;bossIntroHUD.addChild(bossIntroBackdrop)
        bossIntroTitle.text="BOSSRUNDE";bossIntroTitle.fontSize=34;bossIntroTitle.fontColor=rgb(0xffb37c);bossIntroTitle.position=CGPoint(x:640,y:410);bossIntroTitle.zPosition=1;bossIntroHUD.addChild(bossIntroTitle)
        bossIntroSubtitle.fontSize=21;bossIntroSubtitle.fontColor=rgb(0xe7eef5);bossIntroSubtitle.position=CGPoint(x:640,y:373);bossIntroSubtitle.zPosition=1;bossIntroHUD.addChild(bossIntroSubtitle)
        bossVictoryHUD.zPosition=3;bossVictoryHUD.isHidden=true;hudCanvas.addChild(bossVictoryHUD)
        bossVictoryBackdrop.position=CGPoint(x:640,y:395);bossVictoryBackdrop.fillColor=rgb(0x101c2a,0.94);bossVictoryBackdrop.strokeColor=rgb(0xff786b,0.45);bossVictoryBackdrop.lineWidth=1;bossVictoryHUD.addChild(bossVictoryBackdrop)
        for (node,text,y,size) in [(bossVictoryTitle,"BOSSRUNDE GESCHAFFT",435.0,34.0),(bossVictorySubtitle,"DER KOSMISCHE SILVERBACK IST BESIEGT",393.0,20.0),(bossVictoryBrothers,"SEINE BRÜDER WARTEN IM NÄCHSTEN DURCHGANG",350.0,18.0)] {
            node.text=text;node.position=CGPoint(x:640,y:y);node.fontSize=size;node.fontColor=rgb(node === bossVictoryTitle ? 0xff786b:0xe7eef5);node.zPosition=1;bossVictoryHUD.addChild(node)
        }
        label(stat,18,0xe1f5bf,30,680,align:.left);label(score,23,0xffedb8,30,653,align:.left)
        label(roundLabel,18,0xf2e6bb,1250,680,align:.right)
        label(title,54,0xe5ce86,640,425);label(sub,22,0xe2e7ce,640,371);label(hint,19,0xb3c4b5,640,297)
        for l in [title,sub,hint] {l.zPosition=6}
        label(notice,20,0xffd476,640,86)
        supportLabel.numberOfLines=2;supportLabel.preferredMaxLayoutWidth=760
        label(supportLabel,16,0xc4d8ec,1250,32,align:.right)
        let meter=SKShapeNode(rect:CGRect(x:0,y:0,width:270,height:4));meter.fillColor=rgb(0x394a3c);meter.strokeColor=rgb(0x68816a);meter.lineWidth=0.5;meter.position=CGPoint(x:30,y:642);readabilityHUD.addChild(meter)
        multiplierFill.strokeColor = .clear;multiplierFill.position=meter.position;hudCanvas.addChild(multiplierFill)
        label(nextLifeLabel,12,0xcbd5b6,1250,628,align:.right)
        label(pickupHintLabel,16,0xe5e6cc,30,55,align:.left);pickupHintLabel.isHidden=true
        label(vehicleLabel,17,0xffd992,640,628);vehicleLabel.isHidden=true
        label(weaponLabel,16,0xd4ddbb,30,620,align:.left);label(fateLabel,16,0xdbc887,1250,653,align:.right)
        buildRefinedHUD()

    }
    func sync(_ nodes:inout [Int:SCNNode], ids:Set<Int>) {
        for key in Array(nodes.keys) where !ids.contains(key) {nodes.removeValue(forKey:key)?.removeFromParentNode()}
    }
    func captureNativeInput() {
        assert(Thread.isMainThread)
        let frame=input.samplePlayers(routing:inputMailbox.routing())
        inputMailbox.publish(players:frame.players,devices:frame.devices,size:view.bounds.size,availableControllers:frame.availableControllers,operatorControls:frame.operatorControls)
    }
    func update(_ currentTime:TimeInterval,for scene:SKScene) {
        renderedFrames+=1
        let frame=inputMailbox.take()
        tick(players:frame.players,devices:frame.devices,viewSize:frame.size,availableControllers:frame.availableControllers,operatorControls:frame.operatorControls)
    }
    /// Manual, sequential entry point for own offscreen checks (defaults:nil disables live rendering).
    func tick() {tick(controls:input.sample(),viewSize:view.bounds.size)}
    func tick(controls sampled:Controls,viewSize:CGSize) {
        tick(players:[sampled],devices:[],viewSize:viewSize)
    }
    func tick(players sampled:[Controls],devices:[InputDeviceStatus],viewSize:CGSize,availableControllers:Int=0,operatorControls:Controls=Controls()) {
        let now=ProcessInfo.processInfo.systemUptime,dt=min(1.0/20,max(0,now-lastTime));lastTime=now
        layoutHUD(viewSize)
        inputDevices=devices;self.availableControllers=availableControllers
        var players=sampled.isEmpty ? [Controls()]:Array(sampled.prefix(4)),controls=players[0]
        if testPilot {
            if core.phase == .title {controls.accept=true}
            if core.phase == .playing {
                controls.move=V2(x:cos(core.elapsed*0.6),y:sin(core.elapsed*0.6))
                if let f=core.foes.min(by:{($0.p-core.hero).length<($1.p-core.hero).length}) {controls.aim=core.viewOrientation.transform((f.p-core.hero).unit)}
            }
        }
        players[0]=controls
        handleMenus(InputMenu.merge(players,operatorControls:operatorControls,count:menu.teamOpen ? menu.teamCount:core.playerCount),dt:dt,players:players)
        inputMailbox.configure(requestedInputRouting)
        let arenaChanged=builtArena != core.layout.kind || builtRevision != core.environmentRevision
        if arenaChanged {rebuildArena();for art in playerArtStates {art.playerVisibility.reset()}}
        animateArena(now,dt:dt)
        syncFateArt()
        artMaterials["water"]?.normal.contentsTransform=waterNormalTransform(now:now)
        ensurePlayerArtRoster()
        for player in core.players {core.withPlayer(player.slot){syncPlayerPose(controls:core.controls(for:player.slot,in:players),dt:dt,now:now)}}
        syncCamera(viewSize:viewSize,dt:dt,arenaChanged:arenaChanged)
        let defeats=core.takeDefeatPresentations()
        if arenaChanged || lastRound != core.round || core.elapsed<0.08 {clearFallenBodies()}
        else {for defeat in defeats {if let old=foeNodes[defeat.id] {addFallenBody(defeat,from:old)}}}
        animateFallenBodies()
        sync(&foeNodes,ids:Set(core.foes.map(\.id)))
        for foe in core.foes {
            let n=foeNodes[foe.id] ?? (foe.kind == .hound ? houndModel():foe.kind == .martyr || foe.kind == .sasquatch ? sasquatchModel(explosive:foe.kind == .martyr):foe.kind == .engineer ? engineerModel():foe.kind == .crawler ? crawlerModel():detailedCharacter(player:false,variant:foe.id,prisoner:foe.kind == .prisoner))
            if foeNodes[foe.id]==nil{
                if foe.kind == .villager {n.scale=SCNVector3(0.94,0.94,0.94)}
                foeNodes[foe.id]=n;actors.addChildNode(n)
            }
            n.position=SCNVector3(foe.p.x,foe.elevation+0.08,foe.p.y);let dir=foe.arrival?.heading ?? (core.players[core.targetSlot(near:foe.p,height:foe.elevation,magnet:foe.kind != .hound)].hero-foe.p);n.eulerAngles.x=foe.arrival?.kind == .water && foe.elevation < -0.05 ? -0.28:0;n.eulerAngles.y=NodeFloat(atan2(-dir.x,-dir.y))
            n.childNode(withName:"leftLeg",recursively:false)?.eulerAngles.x=NodeFloat(sin(foe.gait)*0.4)
            n.childNode(withName:"rightLeg",recursively:false)?.eulerAngles.x=NodeFloat(-sin(foe.gait)*0.4)
            animateHumanCharacter(n,phase:foe.gait,amount:1,player:false)
            if foe.kind == .crawler {animateCrawler(n,foe:foe)}
            if foe.kind == .hound {animateHound(n,foe:foe)}
        }
        sync(&shotNodes,ids:Set(core.shots.map(\.id)))
        for shot in core.shots {
            let n=shotNodes[shot.id] ?? projectileNode(shot.kind)
            if shotNodes[shot.id]==nil {shotNodes[shot.id]=n;actors.addChildNode(n)}
            n.position=SCNVector3(shot.p.x,shot.height,shot.p.y);n.eulerAngles.y=NodeFloat(atan2(shot.v.x,shot.v.y))
        }
        sync(&pickupNodes,ids:Set(core.pickups.map(\.id)))
        for p in core.pickups {
            let n=pickupNodes[p.id] ?? detailedPickup(p.kind,loot:p.loot,gemUnits:p.gemUnits)
            if pickupNodes[p.id]==nil {pickupNodes[p.id]=n;actors.addChildNode(n)}
            let lift=p.popup?.height(age:p.age) ?? 0
            n.position=SCNVector3(p.p.x,core.layout.height(p.p)+0.12+lift+sin(now*3+Double(p.id))*0.07,p.p.y)
            n.childNode(withName:"pickup-icon",recursively:false)?.eulerAngles.y=NodeFloat(PickupPersistence.rotation(p,clock:core.elapsed))
            n.opacity=CGFloat(p.opacity(clock:core.elapsed))
        }
        syncLifeTransferArt()
        syncArenaExitArt(viewSize:viewSize)
        sync(&effectNodes,ids:Set(core.effects.map(\.id)))
        for e in core.effects {
            let n=effectNodes[e.id] ?? (e.color==8 ? vehicleExitPulseModel():e.color==6 || e.color==7 ? supportBlastModel(dust:e.color==7):ball(1,e.color==1 ? 0xf18b64:e.color==2 ? 0xffd285:e.color==3 ? 0x8ea9f2:e.color==4 ? 0xffa05d:e.color==5 ? 0xc5c8b6:0x648745,glow:true))
            if effectNodes[e.id]==nil{effectNodes[e.id]=n;actors.addChildNode(n)}
            n.position=SCNVector3(e.p.x,e.height ?? (core.layout.height(e.p)+0.3),e.p.y);let s=Float(e.size*(0.2+(0.7-e.ttl)));n.scale=SCNVector3(s,s*0.22,s);n.opacity=CGFloat(min(0.6,e.ttl))
            if e.color==6 || e.color==7 {
                let t=max(0,min(1,1-e.ttl/(e.color==6 ? 0.48:0.30))),scale=Float(e.size*(0.65+t*0.85))
                n.scale=SCNVector3(scale,scale,scale);n.opacity=CGFloat(1-t)
            }else if e.color==8 {
                let t=max(0,min(1,1-e.ttl/VehicleExitPulse.effectDuration)),scale=Float(e.size*(0.18+0.82*t))
                n.scale=SCNVector3(scale,1,scale);n.opacity=CGFloat(0.7*(1-t)*(1-t))
            }
        }
        exit.isHidden=true
        sideExit.isHidden=true
        if let offer=core.sideRoomOffer {
            sideExit.position=SCNVector3(offer.p.x,core.layout.height(offer.p)+0.1,offer.p.y);sideExit.eulerAngles.y=offer.p.x<0 ? NodeFloat.pi:0
            sideExit.opacity=CGFloat(0.7+sin(now*4)*0.3)
        }
        if arenaChanged || lastRound != core.round {
            lastRound=core.round
            sun.light?.color=rgb(core.round%4==3 ? 0xffbc70:core.round%4==0 ? 0x7f9ad8:core.layout.kind != .island ? 0xf4f5ec:0xfff0ce)
            sun.light?.intensity=core.round%4==0 ? 650:1000
            if core.sideRoom != nil {sun.light?.color=rgb(0x8baeff);sun.light?.intensity=1250}
            decor.eulerAngles.y = 0
        }
        stat.text="LEBEN \(core.displayedLives)\(core.godMode ? "*":"")     BOMBEN \(core.bombs)     BOOST \(core.dashes)\(core.hasPlayerWounds ? " · "+core.playerWoundText:"")"
        if let remaining=core.playerRoster.current.respawnRemaining {stat.text="RÜCKKEHR \(Int(ceil(remaining)))s · RESERVE \(core.lives)     BOMBEN \(core.bombs)     BOOST \(core.dashes)"}
        stat.fontColor=rgb(core.hasPlayerWounds ? 0xffb3a0:0xe1f5bf)
        score.text=String(format:"%08lld  ×%d",Int64(core.score),core.multiplier)+(core.multiplier>=9 ? " MAX":"")
        syncTreasureHUD()
        roundLabel.text=core.sideRoom.map{"\($0.kind.title) · NACH RUNDE \(core.round)"} ?? "\(core.layout.kind.title) · RUNDE \(core.round) · DURCHGANG \(core.loopIndex+1)"
        let clearHint=core.exitInstruction
        let raidHint=core.treasureRaider.map{_ in "SILVERBACK · UNVERWUNDBAR · "+clearHint}
        notice.text=core.messageTime>0 ? core.message : core.phase == .cleared ? (raidHint ?? clearHint):core.phase == .bonusRoom ? "EINSAMMELN · "+core.exitInstruction:""
        let gun=core.activeWeapon
        weaponLabel.text=WeaponProfile.forPickup(gun).title+(gun==nil || (gun == .deathMachine && core.weapon==nil) ? " ∞":" · \(Int(ceil(core.weaponReserve/5)))s FEUER")
        if let v=core.vehicle {weaponLabel.text=v.kind == .tank ? "PANZERKANONE":"BORDKANONE + RAKETEN"}
        fateLabel.text=core.fate.map{"SCHICKSAL: \($0.title)"} ?? (core.playerRoster.current.missedFate ? "SCHICKSAL VERPASST":"")
        if core.sideRoom?.kind == .fate {notice.text=core.fateRoomInstruction}
        readabilityHUD.isHidden=false
        for player in core.players {core.withPlayer(player.slot){
            syncVehicleArt();syncPlayerColor();syncHeldWeaponArt();syncCompanionArt();syncSupportArt()
            playerVisibility.update(game:self,dt:dt,now:now)
        }}
        syncWorldWeaponArt()
        syncEnemyEntryArt()
        syncSilverbackArt()
        syncTreasureRaiderArt()
        syncLoopReturnArt()
        syncBarrelArt()
        syncBullArt()
        syncTeamPickupPresentation()
        endingArt.update(game:self,aspect:Double(viewSize.width/max(1,viewSize.height)))
        updateMenuHUD();syncTeamHUD()
        let audioHalfWidth=(camera.camera?.orthographicScale ?? 9)*Double(viewSize.width/max(1,viewSize.height))
        let audioFrame=core.takeSpatialAudioFrame(centerX:Double(camera.position.x),centerY:cameraRig.center.y,halfWidth:audioHalfWidth,halfDepth:cameraRig.scale)
        lastAudioFrame=audioFrame
        lastLoopAudioRequests=core.loopAudioRequests(centerX:Double(camera.position.x),halfWidth:audioHalfWidth,centerY:cameraRig.center.y,halfDepth:cameraRig.scale)
        audio.play(audioFrame.cues,enabled:settings.soundEnabled,phase:core.phase,now:now,effectsGain:Double(settings.effectsVolume)/100,loops:lastLoopAudioRequests,placements:audioFrame.placements)
        music.update(MusicRequest(settings:settings,phase:core.phase,round:core.round))
    }
}
