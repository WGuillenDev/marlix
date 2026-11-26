# Marlix development context

## 1. Goal and scope

Marlix is an Android companion app with an animated mascot. The app is built with Flutter and Riverpod, the API runs on Node.js and Express, and Supabase provides authentication and Postgres. The backend is deployed on Render.

Start with the [v0.2 Execution Plan](plans/execution-plan.md). It records the release scope, phase order, current status, exit criteria and where to resume.

## 2. Engineering rules

Follow the [engineering rules](design/architecture.md#engineering-rules). Use the plan's approved scope, tools and fallbacks. Preserve existing work and verify behavior through the normal entry point. Write repository artifacts in English and app copy in Spanish.

## 3. Architecture and stack

Marlix follows **Clean Architecture** and **Domain-Driven Design (DDD)**. The API is organized by business capability in `api/src/modules/` and the Flutter app by feature in `app/lib/features/`. The API and app assemble dependencies in their respective `bootstrap/` folders. The backend owns model calls and database access. See [architecture](design/architecture.md).

## 4. Product flows

Use the [v0.2 design](design/marlix-v0-2.md) for product behavior and acceptance criteria. Start with the flows affected by the current phase, including account access, chat, voice, help and the mascot. Apply the release scope and phase order from the execution plan.

## 5. Conversation model and budget

Use the model, spending ceiling, fallback and rollout conditions in the [execution plan](plans/execution-plan.md#2-dependency-compatibility-and-selected-tools). See the [system prompt](design/system-prompt.md) for conversation behavior.

## 6. Voice and mascot

Read the [mascot design](design/avatar.md) and the corresponding voice and mascot phases in the [execution plan](plans/execution-plan.md#4-phases). Use the phase gates for hardware checks, offline behavior and reduced motion.

## 7. Persistence and contracts

Read the [API contract](design/api-contract.md), [data model](design/erd.md) and [memory design](design/memory.md) when the change affects their behavior. Use the versioned [migrations](migrations/) with the [schema](schema.sql) and [migration verification](verify-migrations.sql).

## 8. UI and UX

Use the visual direction and prototype approval recorded under [Phase 6](plans/execution-plan.md#phase-6-three-prototypes). Apply the plan's accessibility and platform checks to the affected flows.

## 9. Docker and local development

Use the [development guide](operations/development.md) for setup, builds and staging. The plan records the [Docker and continuous verification](plans/execution-plan.md#5-docker-and-continuous-verification) gates. [Backup and restore](operations/backups.md) covers the restore drill.

## 10. Safety, privacy and observability

The crisis filter runs before the conversation model, including when the daily interaction limit is reached. Follow the [crisis protocol](design/crisis-protocol.md), the [retention rules in the plan](plans/execution-plan.md#budget-and-privacy-contract-for-v02) and the [monitoring guide](operations/monitoring.md).

## 11. QA and acceptance

The phase exit gate defines what to verify. Record commands, actual results and pending checks in [QA evidence](qa/). Record durable technical decisions in [Decisions](adr/decisions.md) and link both from the relevant phase when they affect its execution.

## 12. Execution sequence for Claude Code

Use the [execution plan](plans/execution-plan.md#where-to-resume) for the authorized phase and the technical references above for its implementation. Follow the local agent workflow when the checkout provides it.
