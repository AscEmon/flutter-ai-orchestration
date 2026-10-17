---
description: Turn a feature request or BRD section into a testable spec with numbered acceptance criteria (docs/specs/<feature>.md)
argument-hint: <feature-name> <request, BRD path, or Figma link>
---
Create `docs/specs/$1.md` from: $ARGUMENTS

1. Read the source (BRD file, Figma via MCP, or the text above). Do not write code.
2. Write the spec with these sections:
   - **Goal** — one sentence.
   - **Acceptance criteria** — numbered `AC-01`, `AC-02`… each as Given / When / Then. Include error, empty, and loading states.
   - **API contract** — endpoint, request, response fields (use `[PLACEHOLDER]` for any real URL, key, or sample customer data).
   - **Non-functional** — security (PII handled? logged?), performance, offline behaviour.
   - **Compliance flags** — PII / financial data touched; Bangladesh Bank or PCI-DSS considerations.
   - **Open questions** — anything ambiguous.
   - **Task breakdown** — files per layer following `.claude/rules/PROJECT_CONVENTIONS.md` → New Feature Checklist, and which ACs each task covers.
3. Show me the open questions and STOP. Do not continue until I approve the spec.
