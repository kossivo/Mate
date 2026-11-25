# Architecture & Commercial Decision Records (ADRs)

## ADR-001: Product Identity & Naming
- **Status**: Approved
- **Context**: Working title in the brief was "Pally". The product owner explicitly directed: *"the appp Mate, (not pally)"*.
- **Decision**: The product name is officially **Mate**. All module namespaces, bundle identifiers (`com.mate.app`), documentation, and UI strings use Mate.

---

## ADR-002: Deterministic Scheduling Engine vs. Generative LLM
- **Status**: Approved
- **Context**: LLMs are non-deterministic, prone to hallucination, slow (>1-3s), drain battery on mobile devices, and Apple does not provide a public raw text-generation LLM API for arbitrary prompting.
- **Decision**: All scheduling math, time calculations, conflict detection, buffer calculations, and deadline evaluations are implemented as **100% deterministic Swift algorithms** (`SmartSchedulingEngine`). Natural language is parsed through deterministic tokenization/NLTagger, and Apple Intelligence is leveraged through official **AppIntents** and **AppShortcuts**.

---

## ADR-003: Commercial Strategy & StoreKit 2 Monetization Architecture
- **Status**: Approved for Review
- **Context**: The user specified *"with no lifetime subsciption"*. In utility software, this either denotes:
  1. No lifetime option (i.e. standard auto-renewing subscription like \$1.99/mo or \$9.99/yr), OR
  2. No subscription at all (i.e. pure one-time non-consumable purchase).
- **Decision**: The `StoreKitManager` is engineered using StoreKit 2 (`Transaction.currentEntitlements`) to abstract whether the product identifier is a non-consumable or an auto-renewable subscription. This allows the product owner to switch or test either model in App Store Connect without refactoring the application code.

---

## ADR-004: Zero-Backend Infrastructure
- **Status**: Approved
- **Context**: The product vision requires minimal recurring infrastructure expenditure and maximum user privacy.
- **Decision**: Mate has zero dedicated web servers, databases, or API keys. Sync is delegated to the user's private iCloud database via CloudKit, eliminating operational costs.
