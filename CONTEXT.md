# Directed Art

A web app that generates and walks children (ages 4–10) through **directed drawings** — step-by-step guided drawings the child makes on physical paper. An AI agent helps the child plan a drawing through conversation, then the app renders the plan as a page-turning storybook of steps.

## Language

**Account**:
The adult-owned login (parent or teacher). Owns identity and one or more Profiles. The unit that authenticates.
_Avoid_: User (ambiguous — could mean the adult or the child)

**Profile**:
A child within an Account. Owns that child's Directed Drawings and progress. A session begins by choosing the active Profile.
_Avoid_: Kid, student, child user, sub-account

**Directed Drawing**:
A complete, ordered sequence of steps that guides a child to draw one subject on paper, from first mark to finished picture. The unit a child (Profile) creates, saves, and revisits.
_Avoid_: Tutorial, lesson, project, draw (as a noun)

**Step**:
One stage of a Directed Drawing. Adds new marks to the drawing and carries an instruction telling the child what to add. Step N's image is every prior step's marks plus this step's new marks.
_Avoid_: Page, frame, slide

**Primitive**:
A single drawing instruction in the constrained shape vocabulary the AI emits — e.g. circle, ellipse, line, arc, polygon — positioned on a fixed canvas. The atomic building block of a Step.
_Avoid_: Shape (ambiguous), element, mark (reserved for the child's physical pencil marks)

**Drawing Plan**:
The output of the planning conversation: the complete, frozen Primitive set for the finished picture plus the attributes that describe it (subject, action, mood, background, etc.). Confirmed by the child before it is partitioned into Steps.
_Avoid_: Spec, blueprint, design

**Subject**:
The thing a Directed Drawing depicts (e.g. "a dragon"). The one required Plan attribute and the one gated for age-appropriateness. Other attributes (action, mood, background) are optional and default sensibly.
_Avoid_: Topic, theme, object

**Artwork**:
A photo of the child's actual physical drawing (crayon/pencil/paint on paper) saved to their gallery. Distinct from the AI's rendered reference. A Directed Drawing can have many Artworks, because a child may repeat the steps and upload a new photo each time.
_Avoid_: Drawing (ambiguous with the rendered reference), photo, upload

**Narration**:
The spoken-audio reading of a Step's instruction, so a child who cannot yet read can follow the walkthrough. A first-class output of every Step, not an accessibility add-on.
_Avoid_: Voiceover, audio, text-to-speech (the mechanism, not the concept)

**Age Band**:
The coarse age grouping of a Profile (e.g. 4–6 vs 7–10) that drives a Directed Drawing's complexity: number of Steps, primitives per Step, and instruction wording. Derived, never asked of the child.
_Avoid_: Difficulty, level, grade

**Highlight**:
The visual emphasis (e.g. red/bold) applied to the Primitives a Step newly adds, distinguishing "what to draw now" from "what you've already drawn."
_Avoid_: New, active

**Walkthrough**:
The page-turning, book-style presentation of a Directed Drawing: a cover page (finished picture + title), one page per Step, and a finish/celebrate page. Navigated by next/prev controls and arrow keys.
_Avoid_: Storybook, book, slideshow, carousel
