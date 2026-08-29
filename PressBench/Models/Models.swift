import Foundation

struct Setup: Identifiable, Hashable {
    let id: String
    var title: String
    var material: String
    var transferMedium: String
    var status: SetupStatus
    var cleanRuns: Int
    var firstPassYield: Double?
    var lastProven: Date?
    var stages: [ProcessStage]
    var notes: String
    var defaultQuantity: Int = 1
    var temperature: String = ""
    var duration: String = ""
    var pressure: String = ""
    var machineNickname: String = ""
    var platen: String = ""
    var lastUsedAt: Date? = nil
}

enum SetupStatus: String, CaseIterable, Hashable {
    case proven, trial, draft, archived

    var localizationKey: String {
        switch self {
        case .proven: return "status.proven"
        case .trial: return "status.trial"
        case .draft: return "status.draft"
        case .archived: return "status.archived"
        }
    }
}

struct ProcessStage: Identifiable, Hashable {
    let id: String
    var name: String
    var value: String
    var instruction: String = ""
    var repeatCount: Int = 1
    var placementAction: String = ""
    var finishAction: String = ""
    var stageType: String = ""
}

struct BatchRun: Identifiable, Hashable {
    let id: String
    var title: String
    var state: RunState
    var processed: Int
    var planned: Int
    var stage: String
    var stageIndex: Int
    var stageCount: Int
    var elapsed: TimeInterval
    var firstPassYield: Double?
    var completedAt: Date?
    var phase: String = ""
    var temperature: String = ""
    var pressure: String = ""
    var platen: String = ""
    var jobReference: String = ""
    var duration: String = ""
    var timerRemaining: TimeInterval? = nil
    var timerTotal: TimeInterval? = nil
    var timerRunning: Bool = false
    var timerCompleted: Bool = false
    var material: String = ""
    var transferMedium: String = ""
    var machineName: String = ""
    var instructionSource: String = ""
    var instructionCheckedDate: String = ""
    var processStages: [ProcessStage] = []
    var progressMode: String = "final_confirmation"
    var qcCheckCount: Int = 0
    var lastQCProcessed: Int = 0
    var qcEnabled: Bool = false
    var qcFirstAt: Int = 0
    var qcEvery: Int = 0
    var currentStageInstruction: String = ""
    var currentStageRepeatIndex: Int = 1
    var currentStageRepeatCount: Int = 1
    var currentStagePlacementAction: String = ""
    var currentStageFinishAction: String = ""
    var canDiscardUnstarted: Bool = false
    var currentStageType: String = ""
    var setupID: String = ""
    var waste: Int = 0
    var reworked: Int = 0
    var notes: String = ""
    var issues: [IssueDraftInput] = []
    var qcCheckCountTotal: Int = 0
    var interruptionCount: Int = 0
}

enum RunState: String, Hashable {
    case running, completed, draft

    var localizationKey: String {
        switch self {
        case .running: return "runState.running"
        case .completed: return "runState.completed"
        case .draft: return "runState.draft"
        }
    }
}

struct MachineProfile: Identifiable, Hashable {
    let id: String
    var nickname: String
    var platen: String
    var detail: String
    var active: Bool
    var brand: String = ""
    var model: String = ""
    var notes: String = ""
}

struct DashboardMetrics {
    var setups: Int
    var batches: Int
    var firstPassYield: Double
    var wasteRate: Double
}

struct MachineDraft: Equatable {
    var id: String = ""
    var nickname: String = ""
    var brand: String = ""
    var model: String = ""
    var platen: String = ""
    var notes: String = ""
}

struct SetupDraft: Equatable {
    var id: String = ""
    var title: String = ""
    var material: String = ""
    var transferMedium: String = ""
    var machineID: String = ""
    var temperature: String = ""
    var durationSeconds: String = ""
    var pressure: String = ""
    var sourceName: String = ""
    var sourceReference: String = ""
    var defaultQuantity: String = "1"
    var notes: String = ""
    var stages: [SetupStageDraft] = []
}

struct SetupStageDraft: Identifiable, Equatable {
    var id = UUID().uuidString
    var stageType: String = "press"
    var name: String = ""
    var instruction: String = ""
    var temperature: String = ""
    var temperatureUnit: String = "F"
    var durationSeconds: String = ""
    var pressure: String = ""
    var repeatCount: String = "1"
    var placementAction: String = ""
    var finishAction: String = ""
}

enum SetupReuseClass: String, CaseIterable, Identifiable, Equatable {
    case exactRepeat = "exact_repeat"
    case sameProductVariant = "same_product_variant"
    case materiallyDifferent = "materially_different"

    var id: String { rawValue }
    var localizationKey: String {
        switch self {
        case .exactRepeat: return "run.exactRepeat"
        case .sameProductVariant: return "run.sameProductVariant"
        case .materiallyDifferent: return "run.materiallyDifferent"
        }
    }
    var systemImage: String {
        switch self {
        case .exactRepeat: return "scope"
        case .sameProductVariant: return "tshirt"
        case .materiallyDifferent: return "square.3.layers.3d"
        }
    }
}

struct ResultDraftInput: Equatable {
    var processed: String = ""
    var waste: String = "0"
    var rework: String = "0"
    var notes: String = ""
    var explicitAllGood: Bool = false
    var saveChoice: String = "batch_only"
    var variantTitle: String = ""
    var issues: [IssueDraftInput] = []
}

struct RunStartDraft: Equatable {
    var setupID: String = ""
    var runMode: String = "production"
    var quantity: String = "1"
    var jobReference: String = ""
    var progressMode: String = "live_cycles"
    var confirmUnprovenProduction: Bool = false
}

struct IssueDraftInput: Identifiable, Hashable, Codable {
    var id = UUID()
    var quantity: String = "1"
    var symptom: String = "unknown"
    var suspectedCause: String = "unknown"
    var disposition: String = "discarded"
    var note: String = ""
}
