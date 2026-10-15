---
name: vault-update
description: After development is finished, propose and (once approved) save only the important lasting facts into the TifoXR vault. Writes a draft proposal file to review in Obsidian, asks the user questions, and saves only after approval. Run only when the user asks for it.
disable-model-invocation: true
argument-hint: "[optional focus, for example: payments | friend requests | the whole branch]"
---

Update the TifoXR vault with what this development produced, so the notes stay a reliable memory. The vault folder is `$TIFOXR_VAULT`. Focus from the user (may be empty): $ARGUMENTS

The note-writing rules (folders, properties, tags, links, size) are in the `tifoxr:vault-notes` skill. Read and follow it before you write any vault note.

**You may not change any vault note until the user has approved the final proposal (Step 5).** The only file you may create before that is the draft proposal in `_proposals/`.

## Step 1: collect from three sources
1. **This chat.** Decisions the user made and why, rules they stated, corrections, resolved questions, names they chose. This is a valid source for decisions and intent.
2. **Git.** In the repo you are in: `git status`, `git log --oneline origin/develop..HEAD` and `git diff origin/develop...HEAD --stat` (use the repo's real default branch if it is not `develop`). If the vault itself has uncommitted changes, check `git status` there too.
3. **Code.** Read the changed files that matter.

Label every candidate fact with where it came from: `chat`, `code` or `both`. **A fact about how the code or the system behaves must be confirmed in code.** If it is only in the chat, do not write it: turn it into a question.

Never copy back-and-forth discussion, debugging steps, ticket talk, code listings or your own guesses.

## Step 2: decide what is worth saving
Save only facts that are **lasting** and that someone starting related work would otherwise have to rediscover:
- a new or changed module, flow or integration, and who calls whom
- a change to a contract between the CMS, Unity and the API (endpoint shape, content file shape, queue message)
- a team decision with its reason (an `ADR-NNNN` note and a line in `Decision Log`)
- a status change in `Module Status`
- a new rule, limit or gotcha that cost real time
- open questions that remain

Do **not** save: how something was debugged, every file touched, anything the code already shows, anything temporary, anything already in a note, secrets, or database tables and procedure bodies (the refresh command owns those).

Keep it small: at most 5 notes touched per run, each addition a few lines. Search the vault first and extend an existing note before creating a new one. **Read every note you would touch** so you can say what it says today.

If nothing is worth saving, say so and stop. Do not invent notes.

## Step 3: write the draft proposal file
Create `$TIFOXR_VAULT/_proposals/vault-update-<yyyy-mm-dd-hhmm>.md` (no spaces in the name, so the path stays one clickable link). The folder is git-ignored and skipped by the vault checks. Use this shape, plain ASCII only:

```
# Vault update proposal   <date>   <repo> / <branch>
Status: waiting for you      Sources: chat, git (<n> commits), code

> [!summary] <n> changes (<x> updates, <y> new notes), <q> questions

## Change 1: update [[Note Name]]
| | |
|---|---|
| Says now | one sentence quoted or closely paraphrased from the note, or "nothing on this yet" |
| Will become | one or two sentences: the exact addition or edit |
| Source | chat, code or both, with the file and line for code facts |
- [ ] Include this change

## Change 2: new [[New Note Name]]
| | |
|---|---|
| Will contain | its sections in a few words |
| Where | folder |
| Source | chat, code or both |
- [ ] Include this change

## Questions
> [!question] 1. <the question>
> Why I am asking: <what is not confirmed>
> Options: <A> / <B> / <C>   (recommended: <A>)
> Your answer:

## Anything to add?
Write extra items here, or tell Claude.
```

Rules: every table cell is one sentence. Ask a question whenever you are not 100 percent sure of a fact, a note name, where it belongs, or whether it belongs in the vault at all. Write "none" under Questions if you have none.

## Step 4: show the path and ask
Print only a short block, then ask the questions:

```
VAULT UPDATE PROPOSAL ready   <n> changes, <q> questions
Review: <absolute path of the file>
Obsidian: obsidian://open?path=<the absolute path, URL-encoded>
```

Ask each question with the AskUserQuestion tool (at most 4 per call, 2 to 4 options each, recommended option first). Also ask "Anything to add or change before I finalize?" The user may answer in the question box, edit the file in Obsidian and say "done", or both. When they say "done", **re-read the file** and use their version.

Update the file with the answers, then ask with AskUserQuestion: "Approve and save?" (options: Approve and save / Change something / Cancel). If they ask for changes, update the file and ask again.

## Step 5: write only after an explicit approval
Only the answer "Approve and save?" with an approval counts. An answer to a question, silence, or "looks fine so far" is not approval. Never write on your own initiative.

After approval, write only the changes that are ticked or approved in the file:
1. Write the notes following `tifoxr:vault-notes`. Update the parent or a related note so every new note has an incoming link. Add a line to `03-Decisions/Decision Log.md` for every new ADR. Update `last_verified` only on notes you checked against code.
2. Run `node "$TIFOXR_VAULT/tools/build-index.js"` and then `node "$TIFOXR_VAULT/tools/check-vault.js"`. Fix every error.
3. **Delete the proposal file.** It is scratch. Also delete it if the user cancels.
4. Report: the files written (as Obsidian links like `[[Push Flows]]`), the index result (`updated` or `current`) and the check result. Do **not** commit or push; tell the user to review and commit the vault themselves.
5. If the work changed the database, say so and suggest the user runs `/tifoxr:refresh-db`. Never run it yourself; ask first.

Use plain ASCII only in everything you write: no em dashes, curly quotes or arrows.
