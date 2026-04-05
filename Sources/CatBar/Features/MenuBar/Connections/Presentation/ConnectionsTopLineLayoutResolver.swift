import CoreGraphics

struct ConnectionsTopLineLayout: Equatable {
    let hostWidth: CGFloat
    let ruleWidth: CGFloat
    let payloadWidth: CGFloat
}

struct ConnectionsTopLineLayoutResolver {
    let topLineSpacing: CGFloat
    let topMetaSpacing: CGFloat
    let minimumHostWidthRatio: CGFloat
    let minimumRuleWidth: CGFloat
    let minimumPayloadWidth: CGFloat

    func resolve(
        totalWidth: CGFloat,
        desiredRuleWidth: CGFloat,
        desiredPayloadWidth: CGFloat) -> ConnectionsTopLineLayout
    {
        guard totalWidth > 0 else {
            return ConnectionsTopLineLayout(hostWidth: 0, ruleWidth: 0, payloadWidth: 0)
        }

        let hostMinWidth = floor(totalWidth * self.minimumHostWidthRatio)
        let metaMaxWidth = max(totalWidth - self.topLineSpacing - hostMinWidth, 0)

        var ruleWidth = max(self.minimumRuleWidth, desiredRuleWidth)
        var payloadWidth = max(self.minimumPayloadWidth, desiredPayloadWidth)
        let desiredMetaWidth = ruleWidth + self.topMetaSpacing + payloadWidth

        if desiredMetaWidth > metaMaxWidth {
            var overflow = desiredMetaWidth - metaMaxWidth

            let payloadReducible = max(payloadWidth - self.minimumPayloadWidth, 0)
            let payloadReduction = min(overflow, payloadReducible)
            payloadWidth -= payloadReduction
            overflow -= payloadReduction

            if overflow > 0 {
                let ruleReducible = max(ruleWidth - self.minimumRuleWidth, 0)
                let ruleReduction = min(overflow, ruleReducible)
                ruleWidth -= ruleReduction
                overflow -= ruleReduction
            }

            if overflow > 0 {
                let metaContentWidth = max(metaMaxWidth - self.topMetaSpacing, 0)
                if metaContentWidth <= 0 {
                    ruleWidth = 0
                    payloadWidth = 0
                } else {
                    let totalDesiredWidth = max(ruleWidth + payloadWidth, 1)
                    let ruleRatio = ruleWidth / totalDesiredWidth
                    ruleWidth = floor(metaContentWidth * ruleRatio)
                    payloadWidth = max(metaContentWidth - ruleWidth, 0)
                }
            }
        }

        let metaWidth = ruleWidth + self.topMetaSpacing + payloadWidth
        let hostWidth = max(totalWidth - self.topLineSpacing - metaWidth, hostMinWidth)
        return ConnectionsTopLineLayout(
            hostWidth: hostWidth,
            ruleWidth: ruleWidth,
            payloadWidth: payloadWidth)
    }
}
