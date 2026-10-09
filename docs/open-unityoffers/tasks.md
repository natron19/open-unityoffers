# UnityOffers Demo - Build Tracker

**Spec:** [`unityoffers-demo-spec.md`](unityoffers-demo-spec.md)
**Process:** `OPEN-SOURCE-PLAYBOOK.md` steps 4-12
**Boilerplate:** open-base (scaffolded with `new-open-app.sh unityoffers "UnityOffers" "..."`)

| # | Phase | Status |
|---|---|---|
| 1 | Branding and config: `.env(.example)`, layout fallback name, amber accent CSS, landing page | `[x]` |
| 2 | Models: `Need`, `RequestDraft` migrations, validations, constants, associations | `[x]` |
| 3 | Routes and controllers: `NeedsController` CRUD, `RequestDraftsController` (rate limit, rescues, index redirect); `DashboardController` removed | `[x]` |
| 4 | Views and Stimulus: dashboard, form, need page, result page, `generating`, `form_submit`, `download_markdown` | `[x]` |
| 5 | AI integration: `unityoffers_request_v1` prompt, parser, `BoardRulesCheck` | `[x]` |
| 6 | Seeds: template, recycling-centre example need with a completed draft, `demo_placeholder_v1` removed (seed and DB row) | `[x]` |
| 7 | Guardrails and evals: `config/ai_guards.yml`, `evals/cases/unityoffers_request_v1.yml` (8 cases), placeholder case removed | `[x]` |
| 8 | Specs: models, `BoardRulesCheck`, requests; `bundle exec rspec` green; `bin/rails evals:guardrails` PASS | `[x]` |
| 9 | README rewrite, UI journey manifest (port 3130), pre-publish check, local commit | `[x]` |

## Quick reference

```
needs_path                              GET  /needs   (also /dashboard)
new_need_path                           GET  /needs/new
need_path(n)                            GET  /needs/:id
edit_need_path(n)                       GET  /needs/:id/edit
need_request_drafts_path(n)             POST /needs/:id/drafts   (GET redirects to the need)
need_request_draft_path(n, d)           GET  /needs/:id/drafts/:id
```

```
Template:   unityoffers_request_v1   (gemini-2.5-flash, 8192 max tokens, temperature 0.5)
Variables:  rough_text, could_offer, time_window, hours, category_names
JSON:       request{title <=80, description, category from the list}, what_changed,
            missing_detail_question|null, swap_terms[2-3]{you_give, they_give, one_line}
Code rules: title length, category, term count, BoardRulesCheck (money, "fair"/"best", email, phone)
```

## Not done here (needs the owner)

- Live runs: `bin/rails evals:run` and `./ui-journey-fleet.sh --yes open-unityoffers` (real Gemini calls), and the free journeys `./ui-journey-fleet.sh --free open-unityoffers` (they start a server).
- `Open/README.md` app count and `git open repos.md` remote line (shared files, updated by the coordinator).
- GitHub repo creation and push.
