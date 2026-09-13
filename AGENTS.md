# PurposeLab Legal Site

Model fit: Small for deterministic checks and bounded copy edits; Medium for multi-page factual
updates; Best for ambiguous privacy, compliance, publishing, or other high-consequence decisions.

## Authority and scope

- This repository is the public source for PurposeLab privacy policies and terms. Keep every claim
  faithful to the shipped app and current data flow; app code and verified service configuration
  are evidence, not assumptions.
- Map app changes to both documents: BP Log (`bplog*.html`), Hushly (`hushly*.html`), WaterWise
  (`waterwise*.html`), Folio/Zolio (`folio*.html`), and Crumbs (`crumbs*.html`). Update
  `index.html` and `README.md` when the public app list or links change.
- Do not invent legal guarantees, jurisdictions, retention periods, vendor behavior, or compliance
  claims. Flag uncertainty for qualified human review. Do not present repository work as legal
  advice.
- Preserve plain language and the meaning of approved policy text. Prefer small factual edits over
  broad rewrites.

## Workflow

1. Start task-facing output with the one-line `Model fit:` badge above.
2. Use the context ladder: L0 manifest and safety; L1 this file; L2 only the selected PurposeLab
   profile; L3 exact policy/app evidence; L4 broader history only with an explicit reason.
3. When the optional central harness is available, run the portable preflight from the repository
   root: `export PURPOSELAB_HOME="${PURPOSELAB_HOME:-../purposelab}"`, then
   `"$PURPOSELAB_HOME/pl" doctor`. Use `pl route`, `pl context`, and `pl guard` only while that
   harness is connected. A standalone checkout remains supported through `bash check.sh`.
4. When connected, enable and activate task capabilities in this order:
   `"$PURPOSELAB_HOME/pl" enable legal-publishing`,
   `"$PURPOSELAB_HOME/pl" render-adapters --write`,
   `"$PURPOSELAB_HOME/pl" activate github-copilot`, and
   `"$PURPOSELAB_HOME/pl" activate gemini-cli`. The committed
   `.vscode/mcp.template.json` and `.gemini/settings.template.json` stay capability-free; active
   native configs are local and ignored. Claude Code, Codex, Cursor, and Antigravity are explicit
   fallback clients: use their committed `AGENTS.md`/import adapter plus `pl`, not a guessed native
   MCP configuration. Generic agents use `AGENTS.md` plus `pl`.
5. Run `bash check.sh` after every HTML or policy-link change. Automated checks are necessary but
   do not replace the manual readability, keyboard, and contrast checks printed by the script.
6. Never publish, deploy, push, or otherwise write externally without explicit owner approval.
   Dry runs, local validation, and local file edits are allowed.
