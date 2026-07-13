---
name: skill-creator
description: Create new skills, modify and improve existing skills, and measure skill performance. Use when users want to create a skill from scratch, edit, or optimize an existing skill, run evals to test a skill, benchmark skill performance with variance analysis, or optimize a skill's description for better triggering accuracy.
---

# Skill Creator

A skill for creating new skills and iteratively improving them.

Core loop: decide what the skill does → write draft → run test prompts → evaluate results → rewrite → repeat.

Your job is to figure out where the user is in this process and jump in. If they say "I want a skill for X", start from the beginning. If they have a draft, go straight to eval/iterate. If they say "just vibe with me", skip the formal eval loop.

## Communicating with the user

Pay attention to technical fluency. "evaluation" and "benchmark" are borderline OK. "JSON" and "assertion" — check for cues before using without explaining.

---

## Creating a skill

### Capture Intent

Extract from conversation history first (tools used, sequence, corrections, input/output formats). Fill gaps with the user. Confirm before proceeding.

1. What should this skill enable Claude to do?
2. When should it trigger?
3. What's the expected output format?
4. Should we set up test cases? (Skills with objectively verifiable outputs benefit. Subjective skills often don't need them.)

### Interview and Research

Ask about edge cases, input/output formats, example files, success criteria, dependencies. Research via subagents if MCPs are useful. Come prepared with context.

### Write the SKILL.md

Components:
- **name**: Skill identifier
- **description**: When to trigger + what it does. Primary triggering mechanism — include both action and context. Make it slightly "pushy" to combat undertriggering. All "when to use" info goes here, not in the body.
- **the rest of the skill**

### SKILL.md Writing Guide

**Anatomy:**
```
skill-name/
├── SKILL.md (required)
│   ├── YAML frontmatter (name, description required)
│   └── Markdown instructions
└── Bundled Resources (optional)
    ├── scripts/    - Deterministic/repetitive code
    ├── references/ - Docs loaded as needed
    └── assets/     - Templates, icons, fonts
```

**Progressive Disclosure:**
1. Metadata (name + description) — always in context (~100 words)
2. SKILL.md body — in context when triggered (<500 lines ideal)
3. Bundled resources — as needed (unlimited)

Keep SKILL.md under 500 lines. For large reference needs, add a `references/` file and point to it clearly. For multi-domain skills, organize by variant in `references/`.

**Writing Style:**
- Imperative form
- Explain the *why* behind instructions — LLMs respond better to reasoning than rigid MUSTs
- Keep the prompt lean; remove things not pulling their weight
- Read transcripts from test runs, not just final outputs

**Output format pattern:**
```markdown
## Report structure
ALWAYS use this exact template:
# [Title]
## Executive summary
```

---

## Test Cases

Write 2-3 realistic test prompts. Share with user for confirmation. Save to `evals/evals.json`:

```json
{
  "skill_name": "example-skill",
  "evals": [
    {"id": 1, "prompt": "User's task prompt", "expected_output": "Description", "files": []}
  ]
}
```

See `references/schemas.md` for full schema including the `assertions` field.

---

## Running Evals

Read `references/eval-runner.md` for the full step-by-step process (spawning runs, assertions, grader, benchmark aggregation, viewer, feedback loop).

Do NOT use `/skill-test` or any other testing skill.

Put results in `<skill-name>-workspace/` as sibling to the skill directory. Organize by iteration (`iteration-1/`, `iteration-2/`) then test case.

---

## Improving the Skill

After the user reviews results:

1. **Generalize from feedback.** The skill will be used across many prompts — avoid overfitting to the test examples. If something is stubborn, try different metaphors or patterns rather than adding rigid constraints.

2. **Keep the prompt lean.** Remove what isn't working. Transcripts reveal wasted effort the final output hides.

3. **Explain the why.** Rigid ALWAYS/NEVER in all-caps is a yellow flag — reframe with reasoning instead.

4. **Bundle repeated work.** If all 3 test cases had the subagent writing the same helper script, bundle it in `scripts/`.

---

## Description Optimization

After creating or improving a skill, offer to optimize the description for better triggering. Read `references/description-optimization.md` for the process.

Quick checks:
- `disable-model-invocation: true` → skip entirely
- Use `--model claude-haiku-4-5-20251001`, `--max-iterations 2`, `--runs-per-query 2` as defaults

---

## Environment-Specific

- **Claude.ai:** read `references/claudeai.md` before starting
- **Cowork:** read `references/cowork.md` before starting

---

## Reference Files

- `references/eval-runner.md` — full eval execution workflow (steps, code, viewer)
- `references/schemas.md` — JSON schemas for evals.json, grading.json, benchmark.json
- `references/description-optimization.md` — description optimizer workflow
- `agents/grader.md` — how to evaluate assertions
- `agents/comparator.md` — blind A/B comparison
- `agents/analyzer.md` — benchmark analysis
