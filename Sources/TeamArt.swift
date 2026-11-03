import Foundation
import SceneKit
import SpriteKit

extension ArcadeGame {
    func syncPlayerPose(controls:Controls,dt:Double,now:Double){
        let transit=core.loopReturn,shift=transit?.displacement ?? .zero
        hero.position=SCNVector3(core.hero.x+shift.x,(transit==nil ? core.heroElevation:core.layout.height(core.hero))+0.08+(transit?.lift ?? 0),core.hero.y+shift.y)
        hero.eulerAngles.z=NodeFloat(-(transit?.flight ?? 0)*Double.pi*2)
        hero.eulerAngles.y=NodeFloat(atan2(-core.facing.x,-core.facing.y))
        hero.childNodes.first?.childNode(withName:"muzzle",recursively:false)?.isHidden = !(controls.aim.length>0.18 && core.weaponsEnabled && Int(now*30)%2==0)
        if let model=hero.childNodes.first {
            let deathMachine=core.activeWeapon == .deathMachine
            model.childNodes.filter{$0.name=="standard-gun"}.forEach{$0.isHidden=deathMachine}
            model.childNode(withName:"death-machine",recursively:false)?.isHidden = !deathMachine
            model.childNode(withName:"barrel-rotor",recursively:true)?.eulerAngles.z=NodeFloat(core.elapsed*20)
        }
        // Protection keeps the living body readable; the existing player ring carries the pulse.
        hero.opacity=1
        if let marker=hero.childNodes.first?.childNode(withName:"player-marker",recursively:true) {
            let protected=core.damageProtected && core.isPlayerActive && core.vehicle==nil
            let pulse=protected ? 1.08+0.06*sin(core.elapsed*9):1
            marker.scale=SCNVector3(pulse,1,pulse)
        }
        let art=activeArt
        art.locomotion.update(position:core.hero,clock:core.elapsed,revision:core.environmentRevision,speed:core.moveSpeed,active:core.isPlayerActive,boosting:core.boostProtected)
        if let model=hero.childNodes.first {animateHumanCharacter(model,phase:walking,amount:art.locomotionAmount,player:true,direction:art.locomotion.localDirection(facing:core.facing))}
        if !core.isPlayerActive {hero.eulerAngles.x = -NodeFloat.pi/2;hero.position.y+=0.5;hero.opacity=0.45}
        else {hero.eulerAngles.x=0}
        syncCombatEffects()
        syncRoleBadge()
    }
    func syncCamera(viewSize:CGSize,dt:Double,arenaChanged:Bool){
        let aspect=GameCameraProjection.aspect(Double(viewSize.width/max(1,viewSize.height)))
        let orientation=core.viewOrientation
        func place(_ center:V2,_ elevation:Double,_ scale:Double){
            let distance=GameCameraProjection.distance(scale:scale,aspect:aspect)
            camera.position=SCNVector3(center.x,elevation+distance*GameCameraProjection.ground,center.y+orientation.sign*distance*GameCameraProjection.up)
            camera.look(at:SCNVector3(center.x,elevation,center.y),up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))
        }
        let transit=core.loopReturn,shift=transit?.displacement ?? .zero
        let subjects:[CameraSubject]
        if core.sideRoom?.kind == .fate {subjects=core.fateCameraSubjects}
        else {
            subjects=core.recoveryCameraPlayers.map { player in
                CameraSubject(p:player.hero+shift,
                    elevation:transit==nil ? player.heroElevation:core.layout.height(player.hero)+(transit?.lift ?? 0),
                    radius:transit != nil ? 0.65:player.vehicle?.kind == .helicopter ? 2.5:player.vehicle?.kind == .tank ? 2:1.2,
                    height:2.4)
            }
        }
        defer {
            applyArenaCameraTween()
            let p=camera.worldPosition
            let fog=OverviewFog.range(cameraX:Double(p.x),cameraY:Double(p.y),cameraZ:Double(p.z),subjects:cameraRig.atmosphereSubjects+subjects)
            if abs(scene.fogStartDistance-fog.start)>0.0001 {scene.fogStartDistance=fog.start}
            if abs(scene.fogEndDistance-fog.end)>0.0001 {scene.fogEndDistance=fog.end}
        }
        cameraRig.update(layout:core.layout,subjects:subjects,aspect:aspect,dt:dt,
                         snap:arenaChanged || lastRound != core.round || core.elapsed<0.08,orientation:orientation,players:core.playerCount)
        cameraElevation=0
        camera.camera?.orthographicScale=cameraRig.scale
        camera.camera?.exposureOffset=settings.brighter ? 0.65:core.sideRoom != nil ? 0.35:0.15
        place(cameraRig.center,0,cameraRig.scale)
        previousCameraHero=nil

    }
}
