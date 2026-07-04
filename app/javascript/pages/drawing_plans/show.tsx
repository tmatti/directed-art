import { Form, Head, router } from "@inertiajs/react"
import { ArrowRight, Palette, Sparkles } from "lucide-react"

import Heading from "@/components/heading"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Spinner } from "@/components/ui/spinner"
import AppLayout from "@/layouts/app-layout"
import { ageBandLabel } from "@/lib/age-bands"
import drawingPlansGenerations from "@/routes/DrawingPlans/GenerationsController"
import drawingPlans from "@/routes/DrawingPlansController"
import type { AgeBand } from "@/types"

interface ChatAnswer {
  key: string
  question: string
  value: string
}

interface ChatQuestion {
  key: string
  prompt: string
  suggestions: string[]
  optional: boolean
}

interface RedirectNotice {
  message: string
}

interface PlanSummary {
  subject: string
  action: string
  mood: string
  background: string
  age_band: AgeBand
}

interface PlanChat {
  id: number
  status: "building" | "completed" | "generating" | "ready" | "failed"
  answers: ChatAnswer[]
  question: ChatQuestion | null
  plan: PlanSummary | null
  redirect: RedirectNotice | null
}

export default function Show({ plan }: { plan: PlanChat }) {
  return (
    <AppLayout>
      <Head title="Let's make a drawing" />

      <div className="mx-auto flex h-full w-full max-w-2xl flex-1 flex-col gap-6 p-4 pt-8">
        <Heading
          title="Let's make a drawing!"
          description="Answer a few quick questions and we'll plan your picture."
        />

        <div className="flex flex-1 flex-col gap-4">
          {plan.answers.map((answer) => (
            <Exchange
              key={answer.key}
              question={answer.question}
              answer={answer.value}
            />
          ))}

          {plan.redirect && <Redirect notice={plan.redirect} />}

          {plan.question && <Question plan={plan} question={plan.question} />}

          {plan.plan && <Summary planId={plan.id} plan={plan.plan} />}
        </div>
      </div>
    </AppLayout>
  )
}

// A gentle nudge shown when a free-text Subject was off-limits: the child is
// steered back to the curated chips rather than told they did something wrong
// (ADR-0003). The off-limits text is never echoed back.
function Redirect({ notice }: { notice: RedirectNotice }) {
  return (
    <div className="flex items-start gap-2 rounded-2xl bg-amber-50 px-4 py-3 text-sm font-medium text-amber-900 dark:bg-amber-950/40 dark:text-amber-100">
      <Sparkles className="mt-0.5 size-4 shrink-0" />
      <p>{notice.message}</p>
    </div>
  )
}

// A completed question-and-answer pair in the transcript.
function Exchange({ question, answer }: { question: string; answer: string }) {
  return (
    <div className="flex flex-col gap-2">
      <p className="text-muted-foreground text-sm">{question}</p>
      <div className="bg-primary text-primary-foreground self-end rounded-2xl rounded-br-sm px-4 py-2 font-medium">
        {answer}
      </div>
    </div>
  )
}

// The current question: a friendly prompt, tappable suggestion chips, a
// free-text entry, and — for optional slots — a Skip.
function Question({
  plan,
  question,
}: {
  plan: PlanChat
  question: ChatQuestion
}) {
  return (
    <Card className="border-primary/30">
      <CardContent className="flex flex-col gap-4">
        <p className="text-lg font-semibold">{question.prompt}</p>

        <div className="flex flex-wrap gap-2">
          {question.suggestions.map((suggestion) => (
            <Form
              key={suggestion}
              action={drawingPlans.update(plan.id)}
              resetOnSuccess
            >
              {/* Curated chips are safe by construction and bypass the safety
                  gate (ADR-0003, layer 1); `from_chip` marks the answer as
                  curated so the server skips the classifier. */}
              <input type="hidden" name="answer" value={suggestion} />
              <input type="hidden" name="from_chip" value="1" />
              <Button
                type="submit"
                variant="outline"
                size="lg"
                className="rounded-full"
              >
                {suggestion}
              </Button>
            </Form>
          ))}
        </div>

        <Form
          action={drawingPlans.update(plan.id)}
          resetOnSuccess
          disableWhileProcessing
          className="flex gap-2"
        >
          {({ processing, errors }) => (
            <>
              <div className="flex flex-1 flex-col gap-1">
                <div className="flex gap-2">
                  <Input
                    name="answer"
                    type="text"
                    autoFocus
                    placeholder="…or type your own"
                    aria-label={question.prompt}
                  />
                  <Button
                    type="submit"
                    size="icon-lg"
                    disabled={processing}
                    aria-label="Send"
                  >
                    {processing ? <Spinner /> : <ArrowRight />}
                  </Button>
                </div>
                {errors.answer && (
                  <p className="text-destructive text-sm">{errors.answer}</p>
                )}
              </div>
            </>
          )}
        </Form>

        {question.optional && (
          <Form action={drawingPlans.update(plan.id)}>
            <input type="hidden" name="skip" value="1" />
            <Button
              type="submit"
              variant="ghost"
              size="sm"
              className="text-muted-foreground"
            >
              Skip this one
            </Button>
          </Form>
        )}
      </CardContent>
    </Card>
  )
}

// The assembled Drawing Plan, shown once every slot is filled. Complexity is
// derived from the Profile's Age Band (ADR-0003), shown here, never asked.
function Summary({ planId, plan }: { planId: number; plan: PlanSummary }) {
  const rows: [string, string][] = [
    ["Subject", plan.subject],
    ["Action", plan.action],
    ["Mood", plan.mood],
    ["Background", plan.background],
    ["Level", ageBandLabel(plan.age_band)],
  ]

  return (
    <Card className="border-primary/30">
      <CardContent className="flex flex-col gap-4">
        <div className="flex items-center gap-2 text-lg font-semibold">
          <Sparkles className="text-primary size-5" /> Your drawing plan is
          ready!
        </div>

        <dl className="grid grid-cols-[7rem_1fr] gap-x-4 gap-y-2 text-sm">
          {rows.map(([label, value]) => (
            <div key={label} className="contents">
              <dt className="text-muted-foreground">{label}</dt>
              <dd className="font-medium">{value}</dd>
            </div>
          ))}
        </dl>

        <div className="flex flex-col gap-2">
          <Button
            onClick={() =>
              router.post(drawingPlansGenerations.create(planId).url)
            }
            size="lg"
          >
            <Sparkles /> Make my drawing!
          </Button>
          <Button
            onClick={() => router.post(drawingPlans.create().url)}
            variant="ghost"
            size="lg"
          >
            <Palette /> Plan another drawing
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}
