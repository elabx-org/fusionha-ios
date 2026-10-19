import Foundation

// The Tasks feed's voice inputs (web `routes/tasks-format.ts` `runQuipKind` /
// `runOutcome`, rendered by `TaskLine`): the playful one-liner a run gets after
// its facts when `voice_playful` is on.
public enum TaskVoice {
    /// `runQuipKind`: the run's `media_kind` onto the voice's kind (anime is first-class).
    public static func quipKind(_ mediaKind: String?) -> VoiceQuip.Kind {
        switch mediaKind {
        case "movie": return .movie
        case "anime": return .anime
        default: return .series
        }
    }

    /// `runOutcome`: what the run did; a failure always wins.
    public static func outcome(status: String, grabbed: Int, upgraded: Int) -> VoiceQuip.Outcome {
        if status == "failed" { return .failed }
        if status == "running" { return .running }
        if grabbed > 0 { return .grabbed }
        if upgraded > 0 { return .upgraded }
        return .noRelease
    }

    /// The `TaskLine` suffix, or nil in Plain voice or for a queued run
    /// (a run doing nothing yet must not narrate activity).
    public static func quip(_ run: ActivityRun, playful: Bool, queued: Bool = false) -> String? {
        guard playful, !queued else { return nil }
        let line = VoiceQuip.mediaSuffix(kind: quipKind(run.mediaKind), title: run.targetTitle ?? run.name,
                                         outcome: outcome(status: run.status, grabbed: run.grabbed, upgraded: run.upgraded))
        return line.isEmpty ? nil : line
    }
}
