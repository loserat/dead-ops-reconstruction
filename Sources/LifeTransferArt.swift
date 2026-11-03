import Foundation
import SceneKit

extension ArcadeGame {
    func syncLifeTransferArt(){
        sync(&lifeLinkNodes,ids:Set(core.lifeTransfers.map(\.id)))
        sync(&lifeTransferNodes,ids:Set(core.lifeTransfers.filter{$0.stage == .flying}.map(\.id)))
        for transfer in core.lifeTransfers {
            guard core.players.indices.contains(transfer.donor),core.players.indices.contains(transfer.recipient) else{continue}
            let source=core.players[transfer.donor],target=core.players[transfer.recipient]
            let color=settings.color(for:source.slot).tint
            let link=lifeLinkNodes[transfer.id] ?? ball(0.10,color,glow:true)
            if lifeLinkNodes[transfer.id]==nil {link.name="life-link-\(transfer.id)";link.castsShadow=false;lifeLinkNodes[transfer.id]=link;actors.addChildNode(link)}
            let pulse=transfer.clock.truncatingRemainder(dividingBy:RecoveryRules.creditInterval)/RecoveryRules.creditInterval
            let p=source.hero+(target.hero-source.hero)*pulse,h=source.heroElevation+(target.heroElevation-source.heroElevation)*pulse
            link.position=SCNVector3(p.x,h+0.55,p.y);link.geometry?.firstMaterial?.diffuse.contents=rgb(color);link.geometry?.firstMaterial?.emission.contents=rgb(color)
            guard transfer.stage == .flying else{continue}
            let icon=lifeTransferNodes[transfer.id] ?? detailedPickup(.life)
            if lifeTransferNodes[transfer.id]==nil {icon.name="life-transfer-\(transfer.id)";lifeTransferNodes[transfer.id]=icon;actors.addChildNode(icon)}
            let progress=transfer.flightProgress,q=transfer.origin+(transfer.target-transfer.origin)*progress
            let elevation=transfer.originElevation+(transfer.targetElevation-transfer.originElevation)*progress
            icon.position=SCNVector3(q.x,elevation+0.55,q.y);icon.eulerAngles.y=NodeFloat(transfer.clock*2)
        }
        let rewards=core.visibleRewardBundles.map(\.reward)
        sync(&directedRewardNodes,ids:Set(rewards.map(\.id)))
        for reward in rewards {
            let node=directedRewardNodes[reward.id] ?? detailedPickup(reward.kind)
            if directedRewardNodes[reward.id]==nil {
                node.name="donation-reward-\(reward.id)"
                directedRewardNodes[reward.id]=node;actors.addChildNode(node)
            }
            node.position=SCNVector3(reward.p.x,reward.elevation+0.15,reward.p.y)
            node.eulerAngles.y=NodeFloat(core.elapsed*1.4)
        }
    }
}
