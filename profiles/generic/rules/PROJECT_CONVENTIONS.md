<!-- ai-orch:unlearned — /bootstrap replaces this file with conventions learned from the codebase. Keep this line until then. -->
# Project Conventions — NOT LEARNED YET

> Profile **generic**: this project's conventions have not been documented yet.
> **AI agents: do not write feature code yet.** Ask the user to run `/bootstrap` (Claude Code), which reads the codebase and fills this file in for review.

When `/bootstrap` fills this file, it uses exactly these sections:

## Stack
Language/SDK, state management, HTTP client, DI, routing, JSON/serialization, error type, localization, secrets mechanism — each with the package and version found in `pubspec.yaml`.

## Architecture & Folder Layout
Feature-first or layer-first, the real folder tree for one representative feature, and where shared code lives.

## Naming
File, class and test naming with real examples from this repo.

## Layer Rules
What each layer may import; where business logic lives; how data is mapped from API to UI.

## Shared Widgets & UI
Project widgets that must be used instead of raw Flutter widgets (if any), theming/colors, sizing approach, asset references.

## Error Handling
How errors travel from network to UI (exceptions, `Either`, `Result`, sealed states…), with one real example.

## Dependency Injection
How dependencies are registered and resolved.

## Secrets
How the app reads keys and environment config (e.g. `--dart-define`, `envied`, flavors) — never the values.

## Testing
Test folder layout, mocking library, existing helpers/fakes, how to run.

## New Feature Checklist (used by `/feature`)
Numbered steps to add a feature the way this codebase does it (scaffolding command if any, files per layer, DI registration, routes, assets, code generation).

## Do / Don't
Short list of patterns to follow and anti-patterns seen in review.
