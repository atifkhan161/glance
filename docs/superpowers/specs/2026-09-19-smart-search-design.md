# Smart Search — Design Spec

**Date:** 2026-09-19
**Status:** Approved (brainstorming phase complete)
**Scope:** New 4th tab ("ExaSearch") with Quick Search + Deep Research modes

---

## Overview

Add a Smart Search feature to Glance as a new 4th tab in the floating dock. The tab has two independent modes:

1. **Quick Search** — Instant Exa `auto` search for browsing results. No persistence.
2. **Deep Research** — Multi-query research workflow that generates sub-queries, runs Exa `deep-reasoning` for each, synthesizes via OpenRouter, and saves results as MD files.

---

## Data Sources

### Exa API (existing, enhanced)
- **Reuse** the existing `ExaClient` API key stored in Keychain (`keys_exa`)
- **Quick Search:** `type: "auto"` with `contents.highlights: true`
- **Deep Research:** `type: "deep-reasoning"` with `contents.text: true` + `contents.highlights: true`
- **New parameters needed:** `numResults`, `startPublishedDate`/`endPublishedDate`, `systemPrompt`, `outputSchema`
- The existing `ExaClient` only supports basic search. A new enhanced client or extension is needed.

### OpenRouter API (new)
- **User provides their own API key** — stored in Keychain (`keys_openrouter`)
- **Endpoint:** `POST https://openrouter.ai/api/v1/chat/completions`
- **Model:** `openrouter/free` (auto-router selects best free model per request)
- **Purpose:** Synthesize multiple Exa search results into a single coherent MD document
- **Free tier:** No credit card required. Rate limits apply but are sufficient for personal use.

---

## Architecture

### New Files

```
Glance/
  Features/
    SmartSearch/
      SmartSearchView.swift          # Main tab view (Quick/Deep segmented control)
      QuickSearchView.swift          # Search bar + instant results list
      QuickSearchResultRow.swift     # Individual result card
      DeepResearchView.swift         # Topic input, sub-query config, progress
      ResearchListView.swift         # Chronological saved MD files
      ResearchFileRow.swift          # MD file list item
      MarkdownPreviewView.swift      # WKWebView wrapper for MD rendering
      SmartSearchPipeline.swift      # Orchestrates Exa + OpenRouter calls
      SmartSearchModels.swift        # Data models
  Core/
    Network/
      OpenRouterClient.swift         # API client for OpenRouter chat completions
      ExaEnhancedClient.swift        # Extended ExaClient with deep-reasoning + text + outputSchema
  Core/
    Cache/
      MarkdownStore.swift            # FileManager wrapper for MD files in Documents/
```

### Modified Files

| File | Change |
|------|--------|
| `Glance/App/ContentView.swift` | Add `.search` case to `GlanceTab`, add tab to dock |
| `Glance/Shared/Enums.swift` | Add `.search` to `GlanceTab` enum |
| `Glance/Settings/SettingsView.swift` | Add OpenRouter API key entry section |
| `Glance/Settings/SettingsStore.swift` | Add `openrouterKey` keychain key + persistence |
| `Glance/Core/Network/ExaClient.swift` | Extend protocol or create `ExaEnhancedClient` for deep-reasoning + text content |

---

## Components

### 1. SmartSearchView (Main Tab)
- `Picker` or custom segmented control: "Quick Search" | "Deep Research"
- Renders `QuickSearchView` or `DeepResearchView` based on selection
- Top section: "Saved Research" link to `ResearchListView`

### 2. QuickSearchView
- Search bar with debounced input
- Results list: title, URL domain, highlights snippet, published date
- Tap result → open URL in Safari (or in-app)
- Loading skeleton while searching
- Empty state when no query

### 3. DeepResearchView
- Topic text field (multi-line)
- Sub-query count picker: 3, 4, 5, 6, 7 (default: 5)
- "Start Research" button
- Progress view: "Generating sub-queries..." → "Searching (2/5)..." → "Synthesizing..." → "Saving..."
- On completion: auto-navigate to `ResearchListView`

### 4. ResearchListView
- Chronological list of saved MD files
- Each row: title (query), date, source count badge
- Swipe-to-delete with confirmation
- Tap → push to `MarkdownPreviewView`
- Empty state: "No research yet. Start your first deep research above."

### 5. MarkdownPreviewView
- WKWebView rendering markdown as styled HTML
- HTML template with Glance theme colors (dark background, readable typography)
- Share button (UIActivityViewController)
- Delete button in toolbar

### 6. OpenRouterClient
```swift
protocol OpenRouterClientProtocol: Sendable {
    func complete(
        systemPrompt: String,
        userPrompt: String,
        apiKey: String
    ) async throws -> String
}
```
- POST to `https://openrouter.ai/api/v1/chat/completions`
- Model: `openrouter/free`
- Standard OpenAI-compatible chat completions format
- Retry on 429 with exponential backoff (same pattern as ExaClient)

### 7. ExaEnhancedClient
Extends the existing Exa search to support:
- `type: "deep-reasoning"` for research
- `contents.text` for full page content
- `numResults` parameter
- `systemPrompt` for guided synthesis
- `outputSchema` for structured output

### 8. MarkdownStore
```swift
actor MarkdownStore: Sendable {
    static let shared = MarkdownStore()
    
    func save(query: String, content: String, sources: [String]) async throws -> URL
    func list() async -> [ResearchFile]
    func load(url: URL) async throws -> String
    func delete(url: URL) async throws
}
```
- Files saved to `FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]`
- File naming: `research-<timestamp>-<slug>.md`
- `ResearchFile` struct: `url`, `title`, `date`, `sourceCount`

---

## Data Flow

### Quick Search
```
User types query
  → ExaEnhancedClient.search(type: "auto", highlights: true)
  → Display [ExaResult] in list
  → (no persistence)
```

### Deep Research
```
User enters topic + sub-query count (N)
  → OpenRouterClient.complete(
      systemPrompt: "Generate N diverse search sub-queries about: {topic}",
      userPrompt: "Return JSON array of N search queries"
    )
  → Parse response as [String] (sub-queries)
  → For each sub-query in parallel:
      ExaEnhancedClient.search(type: "deep-reasoning", text: true, highlights: true)
  → Collect all [ExaResult] from all sub-queries
  → OpenRouterClient.complete(
      systemPrompt: "Synthesize these search results into a comprehensive research document...",
      userPrompt: "All results: {results}. Write a markdown document."
    )
  → MarkdownStore.save(query: topic, content: synthesizedMD, sources: [urls])
  → Navigate to ResearchListView
```

### MD File Format
```markdown
# {topic}

*Researched on {date} — {sourceCount} sources*

---

{synthesized markdown content}

---

## Sources

1. {title} — {url}
2. {title} — {url}
...
```

---

## Error Handling

| Error | Handling |
|-------|----------|
| Exa API failure | Show error in UI, allow retry |
| OpenRouter API failure | Show "Synthesis failed" with retry, raw results still visible |
| OpenRouter key missing | Show "Add OpenRouter API key in Settings" link |
| Exa key missing | Show "Add Exa API key in Settings" (already exists) |
| Sub-query generation fails | Fall back to using the original topic as single query |
| Network offline | Show offline banner, disable search |
| MD file save fails | Show error toast, research results still viewable in memory |

---

## Settings Integration

Add to `SettingsView`:
- OpenRouter API key input (SecureField, same pattern as Exa/Gemini keys)
- Keychain key: `keys_openrouter`
- Show key status: ✅ configured / ❌ not configured

---

## Testing Plan

- Unit tests for `SmartSearchPipeline` (mock Exa + OpenRouter clients)
- Unit tests for `MarkdownStore` (save, list, delete, load)
- Unit tests for `OpenRouterClient` (request format, retry logic)
- UI tests for Quick Search flow
- UI tests for Deep Research flow (mocked network)

---

## Scope Boundaries (v1)

**In scope:**
- Quick Search with Exa `auto`
- Deep Research with Exa `deep-reasoning` + OpenRouter synthesis
- MD file save/load/delete/preview
- Settings: OpenRouter key management
- 4th tab in dock

**Out of scope (future):**
- Edit MD files in-app
- Folder/tag organization
- Export to PDF or other formats
- Search history
- Offline MD sync
- Multiple OpenRouter model selection
- Sub-query auto-generation from browsing history
