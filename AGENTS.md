# TrackSmith Agent Policy

This repository is TrackSmith. Preserve legacy code, package, application, and bundle
identifiers unless a task explicitly authorizes renaming them.

## Mandatory Sol Advisor workflow

For every future TrackSmith task that creates, modifies, or deletes repository files
or generated project artifacts, explicitly invoke and follow
`$sol-advisor:orchestration` before implementation begins. This includes source code,
tests, documentation, schemas, research ingestion, generated knowledge, fixtures, and
build or release configuration.

Read-only inspection, explanation, planning, and status reporting do not require an
implementation lane. If a read-only task turns into a change, invoke the workflow
before making that change.

The Sol Advisor gates are mandatory:

- The primary session must satisfy the skill's Sol / High prerequisite.
- Run the companion-agent exactness check and require all three custom roles to be
  discoverable before delegation.
- Route implementation through the lane selected by the skill; do not silently
  substitute a built-in or differently configured agent.
- Preserve pre-existing and concurrent work, inspect the actual diff, and rerun the
  relevant verification in the primary session.
- Obtain a fresh `sol_advisor_sol_reviewer` verdict of `ship` before reporting a
  changed deliverable complete. A `fix-first` or `rethink` verdict is not completion.
- Report the reviewer's observed sandbox and permission profile, including any
  residual risk when read-only isolation was broadened by the host.

If the skill, pinned roles, routing evidence, required model/effort, or final review is
unavailable or inconsistent, stop the affected implementation lane and report the
actionable failure. Do not bypass the workflow or claim completion.
