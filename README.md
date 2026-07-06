# Directed Art

A web app that generates and walks children (ages 4–10) through **directed
drawings** — step-by-step guided drawings the child makes on physical paper. An
AI agent helps the child plan a drawing through conversation, then the app
renders the plan as a page-turning storybook of steps.

## Stack

- [Rails](https://rubyonrails.org) backend with [Inertia.js](https://inertia-rails.dev)
- [React](https://react.dev) + [TypeScript](https://www.typescriptlang.org) frontend
- [Vite](https://vitejs.dev) via [rails_vite](https://github.com/skryukov/rails_vite)
- [shadcn/ui](https://ui.shadcn.com) components on [Tailwind CSS](https://tailwindcss.com)
- [RubyLLM](https://github.com/Shopify/ruby_llm) as the LLM seam behind drawing generation
- PostgreSQL, Active Storage (Cloudflare R2 in production), Solid Queue/Cache/Cable
- [Kamal](https://kamal-deploy.org) for deployment

## Setup

### Prerequisites

- [mise](https://mise.jdx.dev) — installs the pinned Ruby, Node, and pnpm
  versions from [`mise.toml`](./mise.toml):
  ```bash
  mise install
  ```
  (Without mise, install the versions listed in `mise.toml` yourself.)
- PostgreSQL running locally, e.g. on macOS:
  ```bash
  brew install postgresql@17
  brew services start postgresql@17
  ```
  The app connects to `localhost` as your OS user by default; override with
  `DB_HOST`, `DB_USERNAME`, and `DB_PASSWORD` if your setup differs.

### Install and run

1. Copy `.env.example` to `.env` and add an LLM provider key —
   `ANTHROPIC_API_KEY` or `OPENAI_API_KEY` (`bin/dev` loads `.env` for you):
   ```bash
   cp .env.example .env
   ```
   The app boots without a key, but planning a drawing and generating steps
   won't work until one is set.
2. Run setup — installs gems and pnpm packages, prepares and seeds the
   database, then starts the dev server:
   ```bash
   bin/setup
   ```
   (Pass `--skip-server` to stop before starting the server; later, start it
   with `bin/dev`.)
3. Open http://localhost:3000 and sign in with the seeded demo account:
   `demo@example.com` / `Secret1*3*5*`. It comes with a demo kid profile and
   one ready-made drawing.

### Tests

```bash
bin/rails test
```

## How it works

1. **Pick a profile** — a session starts by choosing which child is drawing.
2. **Plan a drawing** — a guided chat assembles a Drawing Plan (subject, mood,
   background) for the active profile's age band.
3. **Generate** — the plan is sent to an LLM which returns a step-by-step
   drawing as structured primitives, then a confirmation gate previews the
   finished picture.
4. **Walkthrough** — a page-turning book: a cover, one page per step with
   narration, and a finish page.
5. **Capture** — photograph the child's real paper drawing into their gallery.
   A drawing can be repeated to collect many artworks.

See [`CONTEXT.md`](./CONTEXT.md) for the ubiquitous language and
[`docs/adr/`](./docs/adr/) for architectural decisions.

## License

Available as open source under the terms of the [MIT License](./LICENSE).
