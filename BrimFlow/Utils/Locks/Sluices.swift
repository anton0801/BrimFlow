import Foundation
import AppsFlyerLib

final class SpillSluice: Sluice {
    var downstream: Sluice?

    func channel(_ ctx: FlowContext) async -> Surge {
        guard let pushURL = UserDefaults.standard.string(forKey: BrimDictKey.pushURL),
              !pushURL.isEmpty else {
            return await passDownstream(ctx)
        }
        return ctx.finalizeSpillway(pushURL)
    }
}

final class IntakeSluice: Sluice {
    var downstream: Sluice?

    func channel(_ ctx: FlowContext) async -> Surge {
        guard ctx.watermark.intakeCharged else {
            return .slack
        }
        return await passDownstream(ctx)
    }
}

final class EddySluice: Sluice {
    var downstream: Sluice?

    func channel(_ ctx: FlowContext) async -> Surge {
        let needsEddy = ctx.watermark.slackTide
            && ctx.watermark.dry
            && !ctx.watermark.eddyRun

        guard needsEddy else {
            return await passDownstream(ctx)
        }

        ctx.watermark.eddyRun = true
        ctx.works.cistern.store(ctx.watermark.log())

        try? await Task.sleep(nanoseconds: 5_000_000_000)

        guard !ctx.watermark.brimmed else {
            return await passDownstream(ctx)
        }

        let deviceID = AppsFlyerLib.shared().getAppsFlyerUID()

        do {
            var fetched = try await ctx.works.sounder.sound(deviceID: deviceID)
            for (k, v) in ctx.watermark.tributaries {
                if fetched[k] == nil { fetched[k] = v }
            }
            ctx.watermark.intake = fetched.mapValues { "\($0)" }
            ctx.works.cistern.store(ctx.watermark.log())
        } catch {
            print("\(BrimGazetteer.logRipple) Eddy refetch soft fail: \(error)")
        }

        return await passDownstream(ctx)
    }
}

final class WeirSluice: Sluice {
    var downstream: Sluice?

    func channel(_ ctx: FlowContext) async -> Surge {
        guard ctx.watermark.intakeCharged else {
            return .slack
        }

        let cargo = ctx.watermark.intake.mapValues { $0 as Any }

        do {
            let url = try await ctx.works.conduit.pump(cargo: cargo)
            return ctx.finalizeSpillway(url)
        } catch {
            return .silted
        }
    }
}
