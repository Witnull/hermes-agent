---
name: skill-creator
description: Create, test, update, merge, and link reusable skills. Use when the user wants to turn a workflow into a skill, improve or auto-update an existing skill, test whether a skill works by running it in a fresh agent, compare two skill versions, combine overlapping skills into one, connect skills into a chain, or fix a skill that fails to trigger. Make sure to use this whenever the user mentions skills, SKILL.md, making a workflow reusable, or checking how an agent behaves with some instructions, even if they don't say "skill creator." Do not use for one-off prompts that won't be reused.
---

# Skill Creator

A skill is a reusable instruction set for **one unique task**. Skills are meant to connect: the output of one skill can be the input of the next, so together they form a chain, and each skill suggests which skill to use next based on context.

The process:

1. Decide what the skill does and write a draft.
2. Test it: give test prompts to a fresh agent that has the skill, and watch how it acts.
3. Review the results with the user and improve the skill. Repeat.
4. Optionally tune the description, compare versions blind, update the skill from experience, merge it with an overlapping skill, and link it to related skills.

Work out where the user is in this process and help them from there. If they already have a draft, go straight to testing. If they want to work informally without a lot of testing, do that.

## Adapting to your environment

Testing needs a **fresh agent**: a new session or subagent that has not seen this conversation and does not know how the skill was written. Check what you have:

| If you lack... | Do this instead |
|---|---|
| A fresh agent | Run each test yourself: read the skill, then follow it to complete the prompt. This is weaker evidence, because you wrote the skill and you are running it with full context. Say so, skip baselines, and lean on the user's review. |
| A filesystem | Put file contents inline in the reply and show outputs in the conversation. |
| Code execution | Deliver a test plan and label the skill **untested**. |
| Automatic skill selection | Skip description optimization and say why. |

Never reference a file, script, or skill you have not confirmed exists. Never claim to have run a test, installed a skill, or saved a file unless you did.

## Communicating with the user

Users range from non-technical to expert, so watch for cues. "Test" and "iteration" are fine. Wait for clear signs before using "JSON," "assertion," or "baseline" without a short explanation.

---

## Creating a skill

### Capture intent

If the conversation already contains a workflow the user wants to capture ("turn this into a skill"), extract answers from it first: tools used, steps taken, corrections the user made, input and output formats. Then confirm with the user and fill the gaps.

1. What should this skill enable the assistant to do? (One task. If the answer is two tasks, make two skills and link them.)
2. When should it trigger? (user phrases, contexts, file types)
3. What is the expected output format?
4. Which other skills come before or after this one? What does it receive from them and hand to them?
5. Should we set up test cases? Skills with checkable outputs (file transforms, data extraction, code generation, fixed workflows) benefit from them. Skills with subjective outputs (writing style, art) often rely on the user's review. Suggest a default and let the user decide.

### Interview and research

Ask about edge cases, input and output formats, example files, success criteria, and dependencies before you write test prompts. If research tools are available (documentation, similar skills), use them so the user does less work.

### Write the SKILL.md

Fill in:

- **name:** the skill identifier.
- **description:** what the skill does and the specific contexts that should trigger it. This is the primary trigger, so put every "when to use" detail here, not in the body. Assistants tend to undertrigger skills, so make it a little pushy. Instead of "How to build a simple dashboard for internal data," write "How to build a simple dashboard for internal data. Make sure to use this whenever the user mentions dashboards, data visualization, internal metrics, or wants to display company data, even if they don't say 'dashboard.'" Add a short exclusion ("Do not use for X") so pushiness doesn't cause false triggers. Describe when to use the skill, not how it works; if the description summarizes the workflow, an agent may follow the summary and skip the body.
- **compatibility:** required tools or dependencies (optional, rarely needed).
- **body:** prerequisites and inputs, an ordered workflow, decision rules, output format, verification and failure handling (including what to do when an input or capability is missing), and a **Related skills** section (see "Linking skills").

Use YAML front matter only if the target environment supports it. Otherwise present the same information as plain text.

### Skill writing guide

**Anatomy:**

```
skill-name/
├── SKILL.md (required: name, description, instructions)
├── scripts/      optional: code for deterministic or repetitive work
├── references/   optional: docs loaded when needed
└── assets/       optional: templates and files used in output
```

**Progressive disclosure.** Skills load in three levels: metadata (name and description, always in context), the SKILL.md body (when the skill triggers, under about 500 lines), and bundled resources (only when needed). If the body nears the limit, move detail into `references/` and say when to read each file. Give reference files over about 300 lines a table of contents. When a skill covers several variants (frameworks, providers), keep the workflow and selection logic in SKILL.md and put one file per variant in `references/`, so only the relevant one is read.

**Lack of surprise.** A skill must not contain malware, exploit code, or anything that compromises security, and its behavior should not surprise the user given its description. Request only the tools and access the task needs, and require confirmation before destructive, irreversible, costly, or data-disclosing actions.

**Writing patterns.** Use the imperative form. Define output formats with a template:

```markdown
## Report structure
Use this exact template:
# [Title]
## Executive summary
## Key findings
## Recommendations
```

Show examples where requirements are ambiguous:

```markdown
## Commit message format
Input: Added user authentication with JWT tokens
Output: feat(auth): implement JWT-based authentication
```

**Writing style.** Explain why each instruction matters instead of relying on capitalized rules. If you write ALWAYS or NEVER in capitals, reframe it with the reason, and keep hard rules for true constraints such as safety. Make the skill general, not narrow to your examples. Give judgment tasks goals and rationale; give fragile, order-dependent steps exact sequences or a script. State what to assume when input is ambiguous and when a question is worth asking. Write a draft, then reread it with fresh eyes and improve it.

---

## Testing a skill

The test is simple: give a prompt to a fresh agent that has the skill, and watch how it acts.

### Test cases

Write 2-3 realistic prompts, the kind a real user would type. Share them: "Here are a few test cases I'd like to try. Do these look right, or do you want to add more?" Cover a typical request, an edge case, and, if boundaries matter, an out-of-scope or incomplete request. Save them to `evals/evals.json`:

```json
{
  "skill_name": "example-skill",
  "evals": [
    {
      "id": 1,
      "name": "descriptive-name",
      "prompt": "User's task prompt",
      "expected_behavior": "What the agent should do and produce",
      "files": []
    }
  ]
}
```

Write `expected_behavior` before you look at any output, so you are not fitting expectations to what you see.

### Workspace layout

Put results in `<skill-name>-workspace/`, next to the skill folder. Organize by iteration, and give each test case its own folder named for what it tests. Create folders as you go.

```
<skill-name>-workspace/
├── skill-snapshot/              copy of the skill before editing (for revisions)
├── iteration-1/
│   └── eval-<name>/
│       ├── with_skill/   outputs/, transcript.md, notes.md
│       └── without_skill/  (or old_skill/ for a revision)
├── iteration-2/ ...
├── comparisons/                 blind comparison results
└── description-tuning/          trigger query sets and scores
```

### Run

For each test case, start two fresh agents in the same turn so they finish together:

- **With the skill.** Give it only: the skill path, the task prompt, any input files, and where to save outputs. Do not hint at what the skill says or what you expect.
- **Baseline.** The same prompt with no skill for a new skill. For a revision, point it at the snapshot of the old version (copy the skill to `skill-snapshot/` before you edit it, or the baseline is lost).

Hold prompts, inputs, and settings constant across the two runs. Record the model used. If output varies from run to run, repeat the run before drawing conclusions.

### Observe how the agent acts

Save each agent's transcript and write a short `notes.md` per run. Read the transcript, not just the final output. Check:

- **Trigger:** did it use the skill (when skills are selected automatically)?
- **Workflow:** did it follow the steps in order? Which did it skip or reorder?
- **Confusion:** where did it hesitate, ask a question, or guess? Each one marks an ambiguous instruction.
- **Waste:** did it take unproductive steps, or write the same helper code in several runs?
- **Output:** is it correct and in the specified format?
- **Constraints:** did it respect scope, confirmations, and safety rules?
- **Versus baseline:** what did the skill actually change?

A correct output reached by wasted steps, ignored instructions, or luck is a weak skill.

### Review with the user

Show the user each prompt, the output, and your observations before you fix anything yourself. If an output is a file, save it and say where. Ask for specific feedback on each case. Empty feedback means the user was satisfied; focus on cases with complaints. Save feedback in the iteration folder (`feedback.md`).

---

## Improving the skill

1. **Generalize from the feedback.** The skill must work across many future prompts, not only the few you are iterating on. Avoid fiddly, overfitted patches and rigid rules; if an issue persists, try a different framing or working pattern.
2. **Keep it lean.** Remove instructions that don't change behavior, especially those that cause wasted steps in the transcripts.
3. **Explain the why.** Work out what the user actually wants and put that understanding in the instructions, even when feedback is terse.
4. **Bundle repeated work.** If several runs independently wrote the same helper script or repeated the same multi-step procedure, put it in `scripts/` and tell the skill to use it.

Classify each failure before fixing it: unclear instruction, missing input, unavailable capability, bad test, or execution error. Then make the smallest relevant change.

**Iteration loop.** Apply the change, rerun all test cases in a new `iteration-<N+1>/` folder with baselines (for a new skill the baseline is always without the skill; for an existing skill, use the original version or the previous iteration and say which), show the results next to the previous iteration, collect feedback, and repeat. Stop when the user is happy, all feedback is empty, or you are no longer making progress. Before calling the skill finished, expand to a larger test set and keep some cases in reserve that you never tuned against, so you can check the skill generalizes.

---

## How the agent learns a skill (updating and auto-update)

A skill learns by turning observed experience into edits. Use this loop for any update, whether the user asked for it or the agent notices the issue while using the skill.

**Signals worth learning from:**

1. Confusion or failures in test transcripts.
2. User corrections during real use ("no, use X instead").
3. Repeated work (the same helper code or procedure showing up again).
4. Errors the skill's instructions did not anticipate.
5. A new related skill appearing (see "Linking skills").

**Procedure:**

1. **Record the observation:** what happened, what was expected, and the evidence, in one or two lines.
2. **Decide whether it is a lesson.** It is when it recurred (twice or more) or the user explicitly corrected it, and it generalizes beyond one file, name, or prompt. One-off quirks stay out. If unsure, add it to a `## Pending lessons` list in the skill (five lines at most) and promote it once it recurs.
3. **Write the lesson as a general instruction with its reason**, in the right section. Edit or merge with the existing instruction on the same point instead of appending a duplicate.
4. **Apply safeguards.** Snapshot the skill first, bump the version, add a one-line changelog entry, and retest the affected cases. If the file passes about 500 lines, move detail into `references/`.
5. **Choose the update path by size of change.**
   - *Minor* (clarify wording, add an example, fix an error, promote a confirmed lesson): the agent may apply it automatically if its environment allows editing the skill and the user has allowed auto-updates. Tell the user afterward.
   - *Major* (change scope, inputs, outputs, description or triggers, delete a rule, relax a safety or confirmation rule, change links to other skills): propose the change and wait for approval. Never relax a safety or confirmation rule automatically.

**When the user asks to update an existing skill:**

- Preserve the original name and directory name (`research-helper` stays `research-helper`, not `research-helper-v2`).
- Copy the skill to a writable location before editing, because the installed path may be read-only. Edit the copy and deliver from it.
- Snapshot the original into `skill-snapshot/` so you have a baseline.

---

## Combining skills

Merge skills when two or more do the **same task** with overlapping instructions, or when the user asks. First check the one-task rule: if they do different tasks, do not merge. Link them instead (see "Linking skills").

### What counts as "good"

Break each skill into **elements**: trigger phrases, inputs, workflow steps, decision rules, output formats and templates, examples, scripts, exclusions, and links. Keep an element only if it meets all of these:

1. **Changes behavior.** Removing it would change what the agent does or produces. (Test it: remove it and rerun a case, or ask whether any step depends on it.)
2. **Specific and checkable.** It names an action, format, threshold, or condition. "Be thorough" fails; "list every column with more than 20% missing values" passes.
3. **Backed by evidence.** It fixed an observed failure, passed a test, or the user stated it.
4. **General.** It applies to the class of requests, not one example, file, person, or company.
5. **Carries its reason** when it affects judgment.
6. **Safe and consistent.** It does not conflict with safety or confirmation rules or with other kept elements, and every file it references exists.

Drop elements that fail these tests: filler, vague advice, overfitted patches, and references to things that don't exist. Note the reason for each drop in one line.

### Procedure

1. **Inventory** the elements of each skill.
2. **Score** each element against the six tests above.
3. **Group same-meaning elements.** Two elements are the same when they share the same trigger condition and require the same behavior, whatever the wording. Elements with similar wording but different conditions or thresholds are different. In each group, keep the clearest version (one with a reason and an example beats a specific one, and a specific one beats a vague one), and fold in any unique detail from the others.
4. **Resolve conflicts** (same condition, different behavior): prefer the behavior with test or user-correction evidence; otherwise the safer, more conservative one; otherwise ask the user. Record each decision in the changelog.
5. **Merge descriptions:** take the union of triggers and remove duplicates. Keep each exclusion unless the other skill's scope now covers it. Keep it to a short paragraph.
6. **Build one workflow** from the kept steps in a sensible order. Keep one version of any script that does the same job.
7. **Re-check the one-task rule.** If the merged skill now covers distinct tasks, split it into two skills and link them.
8. **Verify** with a blind comparison (below): run the merged skill and each original on each original's test prompts. The merged skill must be at least as good as each original on that original's cases. Keep the originals until it is; then archive them, and delete only with the user's approval.
9. **Fix links:** update any skill that pointed to a retired skill name.

---

## Linking skills: the skill network

Each skill does one unique task, and skills connect into chains. A skill suggests the next skill based on context, so the user (or agent) can move through a multi-step job one skill at a time.

### Sync procedure

Run this whenever you create or update a skill, or when a new skill appears in the environment.

1. **List the available skills** (names and descriptions).
2. **For each other skill, check three relationships:**
   - *Next:* does this skill's output feed the other skill's input?
   - *Before:* does the other skill's output feed this skill's input?
   - *Works with:* does this skill support a step inside the other skill?
   If none apply, do not link. Links without a real handoff just add noise.
3. **Add a Related skills section** to the skill you are editing. For the other skill, add the reverse link only where it helps, and treat it as an edit to that skill: minor edits follow the auto-update policy, and anything larger needs the user's approval.
4. **Write each link with a trigger and a handoff**, in this format:

```markdown
## Related skills
- **Next:** `<skill-name>`. Use when <context signal, e.g. "the user asks to share the report" or "the output file exists and needs review">. Pass: <the artifact or input it needs>.
- **Before:** `<skill-name>`. Expect to receive: <what it hands over>. If it is missing, suggest running that skill first.
- **Works with:** `<skill-name>`. Use during <step> when <condition>.
```

### Rules

- Link only skills that exist, and confirm each name before writing it.
- Keep it to about three links per direction. More dilutes the suggestion.
- Do not copy the other skill's instructions. Point to it.
- Avoid cycles unless the loop is intentional and has an exit condition.
- Links are suggestions. Ask before switching skills unless the user asked for the whole chain.
- Base the suggestion on context (what the user just asked, what output now exists), not on the mere presence of a skill.

### Verify

For each link, write one scenario where the next skill should be suggested and one near-miss where it should not. Run both in a fresh agent and check that it suggests the skill at the right time and only then.

---

## Description optimization

The description decides whether a skill is ever used. After the skill works, offer to optimize it. This applies only where skills are selected automatically from descriptions.

### How triggering works

Skills appear in the agent's list with their name and description, and the agent decides whether to consult one from that description. Agents only consult a skill for tasks they can't easily handle alone. Simple one-step requests such as "read this PDF" may not trigger a skill even with a perfect description. So test with substantive, multi-step, or specialized queries.

### Step 1: Write trigger queries

Write 20 queries, half that should trigger the skill and half that should not. Save them to `description-tuning/queries.json`:

```json
[
  {"query": "the user prompt", "should_trigger": true},
  {"query": "another prompt", "should_trigger": false}
]
```

Queries must be realistic and specific: file paths, job context, column names, company names, a little backstory. Mix lengths, and include some lowercase, abbreviated, or typo-ridden ones.

- Bad: `"Format this data"`
- Good: `"ok so my boss sent me this xlsx (its in my downloads, called something like 'Q4 sales final FINAL v2.xlsx') and she wants a column showing profit margin as a percentage. revenue is col C and costs col D i think"`

**Should-trigger (8-10):** different phrasings of the same intent, formal and casual; cases where the user never names the skill or file type; uncommon uses; cases where this skill competes with another but should win.

**Should-not-trigger (8-10):** near-misses that share keywords or concepts but need something else: adjacent domains, ambiguous phrasing, tasks where another tool fits better. Obvious negatives ("write a fibonacci function" for a PDF skill) test nothing.

### Step 2: Review with the user

Show the queries as a table in the conversation and ask the user to edit, add, remove, or flip any of them. Bad queries lead to bad descriptions.

### Step 3: Run and refine

1. Split the queries about 60% for tuning and 40% held out.
2. Run each query about 3 times in a fresh agent that has the skill list, and record the trigger rate (times triggered out of runs).
3. Revise the description: add triggers to fix misses, add exclusions or specificity to fix false triggers.
4. Rerun on both sets. Repeat up to 5 rounds.
5. Choose the final description by **held-out** score, not tuning score, to avoid overfitting.
6. Show the user the before and after descriptions and the scores. Save everything in `description-tuning/`.

If skills are linked or merged, also check for conflicts: queries that match two skills should reach the right one, and each description should say what to do when two match.

---

## Blind comparison

Use this to answer "is the new version actually better?", and to verify merged skills.

1. Run both versions on the same prompts in fresh agents.
2. Give the two outputs to an independent judge (a fresh agent, or the user if none is available) labeled only A and B, with a clear rubric (correctness, format compliance, completeness, absence of wasted steps). Do not say which is which.
3. Randomize which version is A across cases to avoid position bias.
4. Ask the judge for a winner per case with a short explanation.
5. Unblind, tally the results, and analyze why the winner won. Save everything in `comparisons/`.

This needs independent runs. Without them, say a blind comparison isn't possible and rely on the user's review. Most users won't need it; the review loop is usually enough.

---

## Deliver

Deliver the skill folder (or a zip of it) in whatever format the user's environment accepts. Include:

- the final skill and any supporting files
- a short summary of what changed
- test results and their limits, with anything not run labeled **untested**
- the version number and a one-line changelog entry
- the Related skills links you added, and any edits you proposed to other skills

Confirm that the files exist before announcing them.

## Core loop (recap)

- Figure out what the one task is, and what comes before and after it
- Draft the skill
- Test it: run prompts in a fresh agent and observe how it acts
- Review with the user, improve, and repeat in new iteration folders
- Learn from experience and update, with safeguards
- Merge overlapping skills by keeping the "good" elements and combining same-meaning ones
- Link the skill into the network and verify the handoffs
- Optionally tune the description and compare versions blind
- Deliver with honest notes on what was and wasn't tested
