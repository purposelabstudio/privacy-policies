# Privacy Policies — PurposeLab

Public repository hosting privacy policies for all PurposeLab apps.

## Standalone setup

This static site has no package-manager dependencies. On a new laptop:

```sh
git clone https://github.com/purposelabstudio/privacy-policies.git
cd privacy-policies
bash check.sh
```

The check uses Bash and Python 3.9 or newer from the standard developer environment. It validates
every HTML page and prints the browser checks that still need a person.

## Optional PurposeLab connection

The site also supports the central PurposeLab harness. Clone PurposeLab beside this repository (or
point `PURPOSELAB_HOME` at another checkout), then run safe local preflight checks:

```sh
git clone https://github.com/purposelabstudio/purposelab.git ../purposelab
export PURPOSELAB_HOME=../purposelab
"$PURPOSELAB_HOME/pl" doctor
"$PURPOSELAB_HOME/pl" enable legal-publishing
"$PURPOSELAB_HOME/pl" render-adapters --write
"$PURPOSELAB_HOME/pl" activate github-copilot
"$PURPOSELAB_HOME/pl" activate gemini-cli
"$PURPOSELAB_HOME/pl" activate github-copilot --check
"$PURPOSELAB_HOME/pl" activate gemini-cli --check
"$PURPOSELAB_HOME/pl" guard
```

The default `core` profile exposes no non-core MCP servers. `enable` records the allowed
`legal-publishing` profile locally, `render-adapters --write` stages generated projections under
the ignored `.purposelab/` directory, and `activate` installs only the verified Copilot and Gemini
native configs at their ignored paths. The committed `mcp.template.json` and
`settings.template.json` remain capability-free onboarding templates.

Claude Code, Codex, Cursor, and Antigravity are explicit fallback clients: they use the committed
`AGENTS.md`/import adapter and `pl` because no verified native MCP schema is asserted. Generic
agents also use `AGENTS.md` plus `pl`.

## Apps

| App | Policy | Terms |
|-----|--------|-------|
| BP Log — Blood Pressure Tracker | [bplog.html](https://purposelabstudio.github.io/privacy-policies/bplog.html) | [bplog-terms.html](https://purposelabstudio.github.io/privacy-policies/bplog-terms.html) |
| Hushly — Baby Sleep Sounds | [hushly.html](https://purposelabstudio.github.io/privacy-policies/hushly.html) | [hushly-terms.html](https://purposelabstudio.github.io/privacy-policies/hushly-terms.html) |
| WaterWise — Drink Reminder | [waterwise.html](https://purposelabstudio.github.io/privacy-policies/waterwise.html) | [waterwise-terms.html](https://purposelabstudio.github.io/privacy-policies/waterwise-terms.html) |
| Folio — Daily Journal | [folio.html](https://purposelabstudio.github.io/privacy-policies/folio.html) | [folio-terms.html](https://purposelabstudio.github.io/privacy-policies/folio-terms.html) |
| Crumbs — Second Brain on WhatsApp | [crumbs.html](https://purposelabstudio.github.io/privacy-policies/crumbs.html) | [crumbs-terms.html](https://purposelabstudio.github.io/privacy-policies/crumbs-terms.html) |

> **Note on Crumbs.** Every other app here is offline-first, so its policy is short: nothing
> leaves the device. Crumbs is server-side by necessity (it receives your WhatsApp message,
> stores it, and sends the content to Google Gemini to understand it), so its policy discloses
> that explicitly. Keep it accurate if the architecture changes.

## URLs

- **Index**: https://purposelabstudio.github.io/privacy-policies/
- **BP Log**: https://purposelabstudio.github.io/privacy-policies/bplog.html
- **Hushly**: https://purposelabstudio.github.io/privacy-policies/hushly.html
- **WaterWise**: https://purposelabstudio.github.io/privacy-policies/waterwise.html
- **Folio**: https://purposelabstudio.github.io/privacy-policies/folio.html
- **Crumbs**: https://purposelabstudio.github.io/privacy-policies/crumbs.html

## Adding a New App

1. Verify the shipped app behavior and data flow.
2. Create `appname.html` and, when applicable, `appname-terms.html`.
3. Add the app and links to `index.html` and this README.
4. Run `bash check.sh`, then complete its manual browser checks.
5. Obtain explicit owner approval before merging, pushing, or publishing. GitHub Pages deploys
   approved changes from `main`.
