# Apple Intelligence Limitations

Known limitations and workarounds when using Apple's Foundation Models framework on-device.

## Content Safety Guardrails

Apple's Foundation Models enforce safety guardrails that can refuse to process content deemed "sensitive."

### The Problem

When using `streamResponse(to:generating:)` with `@Generable` types (guided generation), the framework runs guardrails against both input and output. This can throw `GenerationError.Refusal` with message: *"May contain sensitive content"* — even for benign articles like sports interviews.

```
[AI] streamSummary error: refusal(..., "May contain sensitive content")
```

This affects **all article content** — the safety filter is broad and unpredictable.

### The Fix

Use `SystemLanguageModel(guardrails: .permissiveContentTransformations)` with raw `String` generation:

```swift
let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
let session = LanguageModelSession(model: model)

// Use streamResponse(to:) returning String, NOT streamResponse(to:generating:)
for try await snapshot in session.streamResponse(to: prompt) {
    let text = snapshot.content  // accumulated String so far
}
```

### Limitations of `permissiveContentTransformations`

| Aspect | Behavior |
|--------|----------|
| `String` generation | Guardrails skipped — no `guardrailViolation` errors |
| `@Generable` generation | Guardrails still run — same refusal behavior as default |
| Refusals | Model may still generate a refusal string (e.g., "Sorry, I can't...") |
| Output guardrails | Reduced but not eliminated — model has internal safety layer |
| Availability | Only works on iOS 26+ with Apple Intelligence enabled |

### When to Use

- Summarizing external content (news articles, web pages)
- Transforming user-provided text
- Any content you don't fully control

### When NOT to Use

- Generating `@Generable` structured output (use default guardrails)
- Internal app data you control (use default guardrails)
- When you need strict safety guarantees

---

## Guided Generation vs String Output

| Approach | Pros | Cons |
|----------|------|------|
| `streamResponse(to:generating: MyType.self)` | Type-safe structured output, `@Generable` parsing | Subject to guardrails, can refuse |
| `streamResponse(to: prompt)` returning `String` | Bypasses guardrails with permissive mode | Requires manual parsing of output |

### Recommendation

Use `permissiveContentTransformations` + `String` output for article summarization. Parse the output manually with a flexible section parser that handles:
- Numbered format: `1. Title: content`
- Em dash format: `1. Title — content`
- Markdown bold: `**Title**`
- Markdown heading: `## Title`

---

## Model Availability States

```swift
let status = SystemLanguageModel.default.availability

switch status {
case .available:
    // Model ready
case .unavailable(.appleIntelligenceNotEnabled):
    // User must enable in Settings > General > Apple Intelligence & Siri
case .unavailable(.modelNotReady):
    // ~1.6 GB download, needs WiFi and ~7 GB free space
case .unavailable(.deviceNotEligible):
    // Requires A17 Pro chip (iPhone 15 Pro+, iPhone 16+, iPhone 17+)
case .unavailable(let other):
    // Other states
}
```

**Important:** `SystemLanguageModel.default.isAvailable` can return `true` even when the safety sub-model isn't fully downloaded. Use `availability` for the full state check.

---

## Session Behavior

- `LanguageModelSession()` creates a fresh session each time
- Sessions are **not** `Sendable` — create per-request
- Each `streamResponse` call is independent (no conversation history unless you build it)
- The model may echo prompt format on first generation — session history helps on retry

---

## Simulator vs Device

```swift
#if !targetEnvironment(simulator)
    // Gemini fallback only available on device
    // Foundation Models only available on device
#endif
```

On simulator, all AI features return `nil` / empty — no on-device model, no Gemini fallback. The UI gracefully hides AI cards.

---

## Related Files

- `Glance/Core/Intelligence/FoundationModelsClient.swift` — Permissive model setup, streaming
- `Glance/Core/Intelligence/IntelligenceRouter.swift` — Apple → Gemini → nil routing
- `Glance/Core/Intelligence/ArticleModels.swift` — System prompts, `@Generable` types
- `Glance/Shared/ArticleIntelligenceCard.swift` — Streaming UI, section parser
