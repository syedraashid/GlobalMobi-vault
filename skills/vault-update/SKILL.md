---
name: vault-update
description: After development is finished, propose and (once approved) save only the important lasting facts about the work into the TifoXR vault. Shows the files, tags and links first. Run only when the user asks for it.
disable-model-invocation: true
argument-hint: "[optional focus, for example: payments | friend requests | the whole branch]"
---

Update the TifoXR vault with what this development changed, so the notes stay a reliable memory. The vault folder is `$TIFOXR_VAULT`. Focus from the user (may be empty): $ARGUMENTS

The note-writing rules (folders, properties, tags, links, size) are in the `tifoxr:vault-notes` skill. Read and follow it before you write anything.

## Step 1: collect evidence from the code, not the chat
Use the repo you are in:
- `git status`, `git log --oneline origin/develop..HEAD` and `git diff origin/develop...HEAD --stat` (use the repo's real default branch if it is not `develop`)
- Read the changed files that matter. Confirm each fact in code before it can go into a note.

The chat is only a hint about what the work was for. **Never copy chat text, debugging steps, ticket discussion or code listings into the vault.** If a fact is only in the chat and you cannot confirm it in code, list it under "Needs your confirmation" and do not write it.

## Step 2: decide what is worth saving
Save only facts that are **lasting** and that someone starting related work would otherwise have to rediscover:
- a new or changed module, flow or integration, and who calls whom
- a change to a contract between the CMS, Unity and the API (endpoint shape, content file shape, queue message)
- a team decision with its reason (becomes an `ADR-NNNN` note, and a line in `Decision Log`)
- a status change (planned to in-development to live) in `Module Status`
- a new rule, limit or gotcha that cost real time
- open questions that remain

Do **not** save: how you debugged, every file touched, endpoint lists the code already shows, anything temporary, anything already in a note, secrets, or database tables and procedure bodies (the refresh command owns those).

Keep it small: at most 5 notes touched per run, and each addition a few lines (a table row, a short paragraph, or one numbered flow). Extend an existing note before creating a new one.

## Step 3: show the proposal, ask your questions, and wait
Search the vault first. For every note you would touch, **read it** so you can say what it says today. Then print the proposal below. **Write nothing to the vault in this step.**

```
VAULT UPDATE PROPOSAL   <repo> / <branch>   <date>

| # | File | Action | What it says now | What will change, or what the new file will contain | Evidence |
|---|---|---|---|---|---|
| 1 | 02-Architecture/Push Flows.md | update | Friend requests go through a queue; says nothing about how the result returns | Add a line: the result is sent over SyncResultHub (SyncSuccess or SyncError) | FriendController.cs:88, SyncResultHub.cs:14 |
| 2 | 03-Decisions/ADR-0003 Friend Results Over SignalR.md | new | (new file) | A decision note: why results return over SignalR, not in the API response | commit 3fa91c2 |
| 3 | 01-Project/Module Status.md | update | Friends: in-development | Friends: live | merge to develop |

QUESTIONS (I am not sure about these)
  1. <a fact you could not confirm in code, with the options you see>
  2. <a choice that changes what gets written, for example: new note or add to an existing one?>

Anything else to add or change before I finalize?
```

Rules for the proposal:
- Keep every table cell to one sentence. For a new file, the last-but-one column says **what the file will contain** in a few words (its sections), not "new".
- Quote or closely paraphrase **what the note says now**, taken from the note you read. Write "nothing on this yet" when the topic is absent.
- Ask a question whenever you are not 100 percent sure of a fact, a note name, where it should go, or whether it belongs in the vault at all. Never guess and never write an unconfirmed fact. If you have no questions, write "none".
- If there is nothing worth saving, say so and stop. Do not invent notes.

**Then stop and wait.** The user answers the questions and may add or drop items. Apply their answers and print the **updated proposal in the same format**, with the questions you still have (or "none"), and ask: "Approve and save?"

## Step 4: write only after an explicit approval
You may write to the vault only after the user replies with a clear approval of the **latest** proposal ("yes", "approved", "save it"). An answer to a question, a silence, or "looks fine so far" is not approval. If the proposal changes again, ask again. Never write on your own initiative.

After approval, write only what the approved table lists:
1. Write the notes following `tifoxr:vault-notes`. Update the parent or related note so every new note has an incoming link. Add a decision to `03-Decisions/Decision Log.md` if you created an ADR. Update `last_verified` only on notes you checked against code.
2. Run `node "$TIFOXR_VAULT/tools/build-index.js"` and `node "$TIFOXR_VAULT/tools/check-vault.js"`. Fix every error.
3. Report: the files written (as Obsidian links like `[[Push Flows]]`) and the check result. Do **not** commit or push. Tell the user to review and commit the vault themselves.
4. If the work changed the database, say so and suggest the user runs `/tifoxr:refresh-db`. Never run it yourself; ask first.

Use plain ASCII only in everything you write: no em dashes, curly quotes or arrows.
