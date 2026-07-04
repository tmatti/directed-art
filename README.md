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

1. Install dependencies:
   ```bash
   bin/setup
   ```
2. Copy `.env.example` to `.env` and adjust as needed (e.g. LLM provider keys).
3. Start the server:
   ```bash
   bin/dev
   ```
4. Open http://localhost:3000

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
