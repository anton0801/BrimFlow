import Foundation
import Combine

@MainActor
final class Lockkeeper {

    private var watermark = Watermark()
    private var brimmed = false

    let stopcock = Stopcock()

    private let works: Waterworks
    private let headSluice: Sluice

    private let surgeSubject = PassthroughSubject<Surge, Never>()
    var surgePublisher: AnyPublisher<Surge, Never> {
        surgeSubject.eraseToAnyPublisher()
    }

    private var clearanceTask: Task<Void, Never>?

    init(works: Waterworks) {
        self.works = works

        let spill = SpillSluice()
        let intake = IntakeSluice()
        let eddy = EddySluice()
        let weir = WeirSluice()

        spill.downstream = intake
        intake.downstream = eddy
        eddy.downstream = weir

        self.headSluice = spill
    }

    private func ensureBrimmed() {
        guard !brimmed else { return }
        watermark = Watermark.draw(from: works.cistern.draw())
        brimmed = true
    }

    func prime() {
        ensureBrimmed()
    }

    func drawIntake(_ raw: [String: Any]) {
        ensureBrimmed()
        watermark.intake = raw.mapValues { "\($0)" }
        works.cistern.store(watermark.log())
    }

    func drawTributaries(_ raw: [String: Any]) {
        ensureBrimmed()
        watermark.tributaries = raw.mapValues { "\($0)" }
        works.cistern.store(watermark.log())
    }

    func channelFlow() async {
        ensureBrimmed()
        guard !stopcock.isClosed else { return }

        let ctx = FlowContext(watermark: watermark, works: works)
        let surge = await headSluice.channel(ctx)
        watermark = ctx.watermark

        if case .slack = surge {
            surgeSubject.send(.slack)
            return
        }

        if stopcock.tryClose() {
            surgeSubject.send(surge)
        }
    }

    func liftFloodgate(then ack: @escaping () -> Void) {
        ensureBrimmed()
        clearanceTask = Task { [weak self] in
            guard let self = self else { return }

            let granted = await self.works.floodgate.liftBarrier()
            let now = Date()

            self.watermark.consentSealed = granted
            self.watermark.consentBreached = !granted
            self.watermark.consentLoggedAt = now

            self.works.cistern.store(self.watermark.log())

            if granted {
                self.works.floodgate.wireDownspout()
            }

            self.surgeSubject.send(.openSpillway)
            ack()
        }
    }

    func holdFloodgate() {
        ensureBrimmed()
        watermark.consentLoggedAt = Date()
        works.cistern.store(watermark.log())
        surgeSubject.send(.openSpillway)
    }

    func reportDeadline() -> Bool {
        return stopcock.tryClose()
    }
}
