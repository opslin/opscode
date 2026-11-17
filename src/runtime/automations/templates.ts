// Starting points. "Use template" writes the automation file (and nothing else:
// the agents they use are built in, and a project file of the same name replaces one).

export interface Template {
  id: string;
  title: string;
  summary: string;
  name: string;
  text: string;
}

export const TEMPLATES: Template[] = [
  {
    id: "software-agency",
    title: "Software agency: brief to built app",
    summary: "Claude Code plans and builds, Codex does the UI, tests and a reviewer check it, you approve the plan first.",
    name: "build-from-brief",
    text: `version: 1
description: Build an app from a brief, reusing components we already have

inputs:
  brief:
    description: What to build, in your words (features, users, the feel of the UI)
    required: true
  requirements:
    description: Path of a requirements .md file in this project (optional)
    default: docs/requirements.md
  reuse_from:
    description: A folder in this project with components to reuse, e.g. vendor/grocery-app (optional)
    default: ""
  check:
    description: The command that proves it builds, e.g. npm run build
    default: npm run build

budget:
  tokens: 3000000
  turns: 40

steps:
  requirements:
    agent: planner
    engine: claude-code
    model: frontier
    access: edit
    prompt: >
      Write or update {{inputs.requirements}} from the brief: users, screens, features, data,
      and what is out of scope. Keep the brief's own words where they matter.

  plan:
    agent: planner
    needs: [requirements]
    engine: claude-code
    model: frontier
    approve: true
    prompt: >
      Read {{inputs.requirements}} and the code. If {{inputs.reuse_from}} is set, list the components
      there to reuse and how to wrap them. Split the work into a UI part (screens, components, styles)
      and a logic part (data, APIs, state). Write the plan to docs/plan.md.

  ui:
    agent: designer
    needs: [plan]
    engine: codex
    model: base
    access: edit
    prompt: Build the UI part of docs/plan.md. Reuse components from {{inputs.reuse_from}} where the plan says.
    checks:
      - "{{inputs.check}}"
    retries: 1

  build:
    agent: builder
    needs: [ui]
    engine: claude-code
    model: base
    access: edit
    prompt: Build the logic part of docs/plan.md and connect it to the UI that is already there.
    checks:
      - "{{inputs.check}}"
      - agent: reviewer
    retries: 2
    escalate: frontier
`,
  },
  {
    id: "fix-failing-tests",
    title: "Fix failing tests",
    summary: "Runs the tests; when they fail, a builder fixes them and a reviewer checks the fix.",
    name: "fix-tests",
    text: `version: 1
description: Run the tests and fix what fails

inputs:
  test:
    description: The test command
    default: npm test

steps:
  tests:
    run: "{{inputs.test}}"
  fix:
    if: { tests: failed }
    agent: builder
    engine: claude-code
    model: base
    access: edit
    prompt: The test command {{inputs.test}} fails. Find the cause and fix it without weakening the tests.
    checks:
      - "{{inputs.test}}"
      - agent: reviewer
    retries: 2
    escalate: [{ model: frontier }, { engine: codex, model: frontier }]
`,
  },
  {
    id: "daily-digest",
    title: "Morning digest",
    summary: "Weekdays at 09:00, a fast model summarises yesterday's commits and flags anything risky.",
    name: "morning-digest",
    text: `version: 1
description: Summarise yesterday's commits and flag anything risky

on:
  schedule: { at: "09:00", weekdays: [mon, tue, wed, thu, fri] }

budget:
  tokens: 200000

steps:
  log:
    run: git log --since=yesterday --stat --no-color | head -400
  digest:
    needs: [log]
    engine: codex
    model: fast
    prompt: Summarise the commits in the log step's result in five lines or fewer, and flag anything risky.
`,
  },
  {
    id: "launch-post",
    title: "Marketing: launch post",
    summary: "Reads what the app really does, writes a blog post and three social posts, a reviewer checks the claims.",
    name: "launch-post",
    text: `version: 1
description: Write a launch post and social posts from what the app really does

inputs:
  audience:
    description: Who it is for, e.g. grocery shop owners in Kolkata
    required: true
  tone:
    description: How it should sound
    default: plain, warm, specific

steps:
  facts:
    agent: explorer
    engine: codex
    model: fast
    prompt: List the app's real features and screens, with file paths as evidence. No guesses.
  write:
    agent: writer
    needs: [facts]
    engine: claude-code
    model: base
    access: edit
    prompt: >
      For {{inputs.audience}}, in a {{inputs.tone}} tone, write marketing/launch-post.md (about 500 words)
      and marketing/social.md (three short posts). Use only features from the facts step.
    checks:
      - agent: reviewer
    retries: 1
`,
  },
];
