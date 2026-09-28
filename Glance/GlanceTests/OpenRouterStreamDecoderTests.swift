import Testing
@testable import Glance
import Foundation

@Suite("OpenRouterStreamDecoder")
struct OpenRouterStreamDecoderTests {
    @Test("A content frame yields its delta")
    func contentFrameYieldsDelta() {
        var decoder = OpenRouterStreamDecoder()
        let line = #"data: {"choices":[{"delta":{"content":"Verdict: a win."}}]}"#
        #expect(decoder.consume(line: line) == ["Verdict: a win."])
    }

    @Test("Content split across frames reassembles when concatenated")
    func splitFramesReassemble() {
        var decoder = OpenRouterStreamDecoder()
        var output = ""
        for piece in ["Ver", "dict: ", "a win."] {
            let line = #"data: {"choices":[{"delta":{"content":"\#(piece)"}}]}"#
            output += decoder.consume(line: line).joined()
        }
        #expect(output == "Verdict: a win.")
    }

    @Test("DONE stops the stream and yields nothing")
    func doneStopsTheStream() {
        var decoder = OpenRouterStreamDecoder()
        #expect(decoder.consume(line: "data: [DONE]").isEmpty)
        #expect(decoder.isDone)

        let after = #"data: {"choices":[{"delta":{"content":"ignored"}}]}"#
        #expect(decoder.consume(line: after).isEmpty)
    }

    @Test("Non-data lines are ignored")
    func nonDataLinesIgnored() {
        var decoder = OpenRouterStreamDecoder()
        #expect(decoder.consume(line: ": ping").isEmpty)
        #expect(decoder.consume(line: "").isEmpty)
        #expect(decoder.consume(line: "event: message").isEmpty)
    }

    @Test("Malformed JSON does not stop later frames")
    func malformedJSONDoesNotStopLaterFrames() {
        var decoder = OpenRouterStreamDecoder()
        #expect(decoder.consume(line: "data: {not json").isEmpty)

        let good = #"data: {"choices":[{"delta":{"content":"recovered"}}]}"#
        #expect(decoder.consume(line: good) == ["recovered"])
    }

    @Test("A frame with no choices yields nothing")
    func emptyChoicesYieldsNothing() {
        var decoder = OpenRouterStreamDecoder()
        #expect(decoder.consume(line: #"data: {"choices":[]}"#).isEmpty)
    }

    @Test("A null content field yields nothing")
    func nullContentYieldsNothing() {
        var decoder = OpenRouterStreamDecoder()
        let line = #"data: {"choices":[{"delta":{}}]}"#
        #expect(decoder.consume(line: line).isEmpty)
    }

    @Test("Whitespace after the data marker is tolerated")
    func whitespaceAfterMarkerTolerated() {
        var decoder = OpenRouterStreamDecoder()
        let line = #"data:   {"choices":[{"delta":{"content":"ok"}}]}"#
        #expect(decoder.consume(line: line) == ["ok"])
    }
}

@Suite("ArticleStreamFailure")
struct ArticleStreamFailureTests {
    @Test("Only cancellation is silent")
    func onlyCancellationIsSilent() {
        #expect(ArticleStreamFailure.cancelled.isSilent)
        for failure in [
            ArticleStreamFailure.modelNotReady,
            .modelUnavailable("reason"),
            .exceededContextSize,
            .guardrail,
            .refusal,
            .rateLimited,
            .network("offline"),
            .unknown("boom"),
        ] {
            #expect(failure.isSilent == false, "\(failure) should not be silent")
        }
    }

    @Test("Every non-silent failure has user-facing copy")
    func everyFailureHasCopy() {
        for failure in [
            ArticleStreamFailure.modelNotReady,
            .modelUnavailable("Enable Apple Intelligence in Settings"),
            .exceededContextSize,
            .guardrail,
            .refusal,
            .rateLimited,
            .network("offline"),
            .unknown("boom"),
        ] {
            #expect(!failure.message.isEmpty, "\(failure) has no message")
        }
    }

    @Test("An unavailable model surfaces the reason verbatim")
    func unavailableSurfacesReasonVerbatim() {
        let reason = "Enable Apple Intelligence in Settings > General > Apple Intelligence & Siri"
        #expect(ArticleStreamFailure.modelUnavailable(reason).message == reason)
    }

    @Test("Cancellation produces no message")
    func cancellationHasNoMessage() {
        #expect(ArticleStreamFailure.cancelled.message.isEmpty)
    }

    @Test("Network failures are attributed to the cloud")
    func networkFailureNamesCloud() {
        #expect(ArticleStreamFailure.network("offline").message.hasPrefix("Cloud summary failed:"))
    }
}
