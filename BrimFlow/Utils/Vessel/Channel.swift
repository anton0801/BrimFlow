import Foundation

protocol Sluice: AnyObject {
    var downstream: Sluice? { get set }
    func channel(_ ctx: FlowContext) async -> Surge
}

extension Sluice {
    func passDownstream(_ ctx: FlowContext) async -> Surge {
        guard let downstream = downstream else { return .silted }
        return await downstream.channel(ctx)
    }
}

final class FlowContext {
    var watermark: Watermark
    let works: Waterworks

    init(watermark: Watermark, works: Waterworks) {
        self.watermark = watermark
        self.works = works
    }

    func finalizeSpillway(_ url: String) -> Surge {
        let needsClearance = watermark.clearanceDue

        watermark.spillwayURL = url
        watermark.spillwayMode = "Active"
        watermark.dry = false
        watermark.brimmed = true

        works.cistern.store(watermark.log())
        works.cistern.brandSpillway(url: url, mode: "Active")
        works.cistern.raisePrimedFlag()
        UserDefaults.standard.removeObject(forKey: BrimDictKey.pushURL)

        return needsClearance ? .raiseFloodgate : .openSpillway
    }
}
