import Testing
@testable import Glance
import Foundation

@Suite("OpenRouterStreamDecoder")
struct OpenRouterStreamDecoderTests {
    @Test("A content frame yields its delta")
    func contentFrameYieldsDelta() throws {
        var decoder = OpenRouterStreamDecoder()
        let line = #"data: {"choices":[{"delta":{"content":"Verdict: a win."}}]}"#
        #expect(try decoder.consume(line: line) == ["Verdict: a win."])
    }

    @Test("Content split across frames reassembles when concatenated")
    func splitFramesReassemble() throws {
        var decoder = OpenRouterStreamDecoder()
        var output = ""
        for piece in ["Ver", "dict: ", "a win."] {
            let line = #"data: {"choices":[{"delta":{"content":"\#(piece)"}}]}"#
            output += try decoder.consume(line: line).joined()
        }
        #expect(output == "Verdict: a win.")
    }

    @Test("DONE stops the stream and yields nothing")
    func doneStopsTheStream() throws {
        var decoder = OpenRouterStreamDecoder()
        #expect(try decoder.consume(line: "data: [DONE]").isEmpty)
        #expect(decoder.isDone)

        let after = #"data: {"choices":[{"delta":{"content":"ignored"}}]}"#
        #expect(try decoder.consume(line: after).isEmpty)
    }

    @Test("Non-data lines are ignored")
    func nonDataLinesIgnored() throws {
        var decoder = OpenRouterStreamDecoder()
        #expect(try decoder.consume(line: ": ping").isEmpty)
        #expect(try decoder.consume(line: "").isEmpty)
        #expect(try decoder.consume(line: "event: message").isEmpty)
    }

    @Test("Malformed JSON does not stop later frames")
    func malformedJSONDoesNotStopLaterFrames() throws {
        var decoder = OpenRouterStreamDecoder()
        #expect(try decoder.consume(line: "data: {not json").isEmpty)

        let good = #"data: {"choices":[{"delta":{"content":"recovered"}}]}"#
        #expect(try decoder.consume(line: good) == ["recovered"])
    }

    @Test("A frame with no choices yields nothing")
    func emptyChoicesYieldsNothing() throws {
        var decoder = OpenRouterStreamDecoder()
        #expect(try decoder.consume(line: #"data: {"choices":[]}"#).isEmpty)
    }

    @Test("A null content field yields nothing")
    func nullContentYieldsNothing() throws {
        var decoder = OpenRouterStreamDecoder()
        let line = #"data: {"choices":[{"delta":{}}]}"#
        #expect(try decoder.consume(line: line).isEmpty)
    }

    @Test("Whitespace after the data marker is tolerated")
    func whitespaceAfterMarkerTolerated() throws {
        var decoder = OpenRouterStreamDecoder()
        let line = #"data:   {"choices":[{"delta":{"content":"ok"}}]}"#
        #expect(try decoder.consume(line: line) == ["ok"])
    }

    @Test("A mid-stream error frame throws instead of yielding nothing")
    func errorFrameThrows() {
        var decoder = OpenRouterStreamDecoder()
        let line = #"data: {"error":{"code":429,"message":"No free model available"}}"#

        // A mid-stream failure arrives as an ordinary `data:` frame carrying an
        // `error` object and no `choices`. A decoder that only understands
        // `choices` drops it, the stream then finishes "successfully" having
        // produced nothing, and the user is told the summary simply doesn't
        // exist instead of being shown the real reason.
        #expect(throws: GlanceError.networkError("No free model available")) {
            try decoder.consume(line: line)
        }
    }

    @Test("An error frame with no message is ignored rather than fatal")
    func errorFrameWithoutMessageIgnored() throws {
        var decoder = OpenRouterStreamDecoder()
        #expect(try decoder.consume(line: #"data: {"error":{"code":500}}"#).isEmpty)
    }

    @Test("A stream stays usable after an ignorable frame")
    func usableAfterIgnorableFrame() throws {
        var decoder = OpenRouterStreamDecoder()
        _ = try decoder.consume(line: #"data: {"id":"gen-1","object":"chunk"}"#)

        let good = #"data: {"choices":[{"delta":{"content":"recovered"}}]}"#
        #expect(try decoder.consume(line: good) == ["recovered"])
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
