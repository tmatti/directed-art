# Plan 001: Artwork uploads are validated for content type and size, and a fileless upload can't brick a drawing page

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 38eecae..HEAD -- app/controllers/directed_drawings/artworks_controller.rb app/models/artwork.rb test/integration/directed_drawings/artworks_test.rb`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: security
- **Planned at**: commit `38eecae`, 2026-07-08
- **Issue**: https://github.com/tmatti/directed-art/issues/37

## Why this matters

The Artwork photo upload accepts any file with no content-type or size limit,
and — worse — a POST with no `photo` param creates an Artwork row with no
attachment. The gallery and walkthrough then call `url_for(artwork.photo)` on
that fileless record, which raises `ArgumentError`, **permanently 500-ing that
child's walkthrough page** on every load. The browser's `accept="image/*"` is
client-side only and trivially bypassed by a direct request. This is a
child-facing app storing uploads on Cloudflare R2; unbounded file types and
sizes are a storage-cost and content-safety gap. After this plan, only
reasonably-sized image files are accepted and a missing/invalid file is
rejected cleanly with no orphan record.

## Current state

- `app/controllers/directed_drawings/artworks_controller.rb` — the upload
  endpoint; passes `params[:photo]` straight into `create!` with no guard:
  ```ruby
  # app/controllers/directed_drawings/artworks_controller.rb:12-16
  def create
    drawing = Current.active_profile.directed_drawings.confirmed.find(params[:directed_drawing_id])
    drawing.artworks.create!(photo: params[:photo])
    redirect_to directed_drawing_path(drawing)
  end
  ```
- `app/models/artwork.rb` — the model; has the attachment but no validation:
  ```ruby
  # app/models/artwork.rb:8-12
  class Artwork < ApplicationRecord
    belongs_to :directed_drawing
    has_one_attached :photo
  end
  ```
- The fileless-record hazard lives in the reader path
  `app/controllers/directed_drawings_controller.rb:40-42`
  (`url_for(artwork.photo)`), which is why an Artwork must never persist
  without an attached, valid photo.

Repo conventions to follow:
- Rails 8.1 with Minitest. This project uses **Active Storage's built-in
  attachment validations** (`has_one_attached :photo` is already present).
  Rails 8 ships `validates :photo, content_type:`/`size:` support natively — no
  extra gem needed.
- The frontend submits the file under the param name `photo` (see
  `app/javascript/pages/directed_drawings/show.tsx:72` —
  `data.append("photo", file)`). Do not rename it.
- Existing tests use `fixture_file_upload("test.png", "image/png")` (see the
  in-scope test file). A `test/fixtures/files/test.png` already exists.
- The controller redirects on success and must degrade gracefully (not raise)
  on a bad upload — mirror the gentle-redirect philosophy used elsewhere in the
  app (e.g. the planning chat re-renders with a flash rather than erroring).

## Commands you will need

| Purpose   | Command                                                        | Expected on success |
|-----------|----------------------------------------------------------------|---------------------|
| Tests (this area) | `bin/rails test test/integration/directed_drawings/artworks_test.rb test/models/artwork_test.rb` | all pass |
| Full Ruby tests | `bin/rails test`                                          | all pass |
| RuboCop   | `bin/rubocop app/controllers/directed_drawings/artworks_controller.rb app/models/artwork.rb` | no offenses |

(If `bin/rails test` cannot connect to PostgreSQL, STOP and report — do not try
to create databases.)

## Scope

**In scope** (the only files you should modify or create):
- `app/models/artwork.rb`
- `app/controllers/directed_drawings/artworks_controller.rb`
- `test/models/artwork_test.rb` (create)
- `test/integration/directed_drawings/artworks_test.rb` (extend)

**Out of scope** (do NOT touch):
- `app/javascript/pages/directed_drawings/show.tsx` — the client `accept` hint
  stays; it is UX, not a security boundary.
- `app/controllers/directed_drawings_controller.rb` — the reader path; this
  plan removes the fileless-record hazard at the source, so the reader needs no
  change.
- Active Storage / R2 configuration.

## Git workflow

- Branch: `advisor/001-artwork-upload-validation`
- Commit style matches `git log` (short imperative subject, e.g. "Validate
  Artwork uploads for content type and size").
- Do NOT push or open a PR unless the operator instructs it.

## Steps

### Step 1: Add attachment validations to the Artwork model

In `app/models/artwork.rb`, constrain the photo to common image types and a
sane size ceiling. Target shape:

```ruby
class Artwork < ApplicationRecord
  belongs_to :directed_drawing

  has_one_attached :photo

  validates :photo, attached: true,
    content_type: %w[image/png image/jpeg image/webp image/heic image/heif],
    size: { less_than: 15.megabytes }
end
```

Notes:
- `attached: true` is what prevents the orphan fileless record.
- `content_type` and `size` are the Rails 8 built-in Active Storage validators.
  If `bin/rails runner "Artwork.validators"` shows these are NOT recognized
  (older Active Storage), STOP and report — do not add a third-party gem
  without confirmation.
- HEIC/HEIF are included because `capture="environment"` on iOS produces them.

**Verify**: `bin/rails runner "puts Artwork.new.tap(&:valid?).errors.full_messages"` → includes a "Photo" error (proving the attached/validation wiring is live).

### Step 2: Make the controller degrade gracefully instead of raising

`create!` will now raise `ActiveRecord::RecordInvalid` on a bad or missing
upload. Convert that into a friendly redirect so a bad request never 500s.
Target shape:

```ruby
def create
  drawing = Current.active_profile.directed_drawings.confirmed.find(params[:directed_drawing_id])
  drawing.artworks.create!(photo: params[:photo])
  redirect_to directed_drawing_path(drawing)
rescue ActiveRecord::RecordInvalid
  redirect_to directed_drawing_path(drawing),
    inertia: { errors: { photo: "Please choose an image under 15 MB." } }
end
```

Keep the `find` (and its `ActiveRecord::RecordNotFound` → 404) exactly as-is —
scoping behavior must not change. The `rescue` covers only the invalid-photo
case.

**Verify**: covered by Step 4 tests.

### Step 3: Add a model unit test

Create `test/models/artwork_test.rb`, modeled structurally on
`test/models/profile_test.rb` (same `ActiveSupport::TestCase` style,
`fixture_file_upload` for attachments). Cover:
- a valid PNG passes validation,
- an Artwork with no attached photo is invalid,
- an oversized attachment is invalid (build a blob over the limit),
- a disallowed content type (e.g. `application/pdf`) is invalid.

Use `test/fixtures/files/test.png` for the valid case. For the bad-type case
attach `fixture_file_upload` with an explicit non-image content type. If no
suitable fixture exists for the bad-type/oversize cases, attach a
`StringIO`-backed blob via `ActiveStorage::Blob.create_and_upload!` with the
chosen `content_type`/byte size rather than committing new binary fixtures.

**Verify**: `bin/rails test test/models/artwork_test.rb` → all pass.

### Step 4: Extend the integration test for the controller

In `test/integration/directed_drawings/artworks_test.rb`, add tests under a new
`# --- Upload validation ---` section:
- POST with no `photo` param creates **no** Artwork and does not 500 (assert
  `assert_no_difference` on `@drawing.artworks.count` and a redirect, not a
  `500`).
- POST with a non-image file (e.g. a text file uploaded as `text/plain`)
  creates no Artwork.

Reuse the existing `photo_upload` helper as the happy-path pattern; add a
`bad_upload` helper following the same `fixture_file_upload` shape. The
existing "POST create saves an Artwork" test must still pass unchanged.

**Verify**: `bin/rails test test/integration/directed_drawings/artworks_test.rb` → all pass, including the new cases.

## Test plan

- New file `test/models/artwork_test.rb`: valid image passes; missing
  attachment invalid; oversize invalid; wrong content type invalid.
- Extended `test/integration/directed_drawings/artworks_test.rb`: fileless POST
  → no record, no 500; non-image POST → no record. Existing scoping/guard tests
  unchanged and green.
- Verification: `bin/rails test test/integration/directed_drawings/artworks_test.rb test/models/artwork_test.rb` → all pass.

## Done criteria

ALL must hold:

- [ ] `bin/rails test` exits 0; new `artwork_test.rb` exists and passes.
- [ ] `bin/rubocop app/models/artwork.rb app/controllers/directed_drawings/artworks_controller.rb` → no offenses.
- [ ] A POST to the artworks endpoint without a `photo` param returns a redirect (not 500) and creates no Artwork (asserted by a test).
- [ ] `Artwork.new.valid?` is false with a "Photo … can't be blank"/attachment error.
- [ ] No files outside the in-scope list are modified (`git status`).
- [ ] `plans/README.md` status row updated.

## STOP conditions

Stop and report (do not improvise) if:

- The `content_type:`/`size:` Active Storage validators are not available in
  this Rails/Active Storage version (Step 1 verify fails) — do not add a gem.
- The code at the "Current state" locations doesn't match the excerpts.
- `bin/rails test` cannot reach PostgreSQL.
- Making the fileless case not-500 appears to require editing
  `directed_drawings_controller.rb` (it should not — the model validation
  prevents the orphan record).

## Maintenance notes

- If a future feature adds server-side image processing/variants, revisit the
  allowed `content_type` list and consider re-encoding uploads.
- A reviewer should confirm the `rescue` catches only `RecordInvalid` and that
  the profile/confirmed scoping on `find` is untouched (still 404s for other
  profiles/accounts).
- Deferred: virus/content scanning of uploads is out of scope here; note it as
  a future consideration if the app opens uploads beyond a trusted parent.
