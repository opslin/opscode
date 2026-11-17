// Opscode's own small skills, written into the person's skills folder on start when missing (an
// edited copy is never overwritten). Chats see only their name and one line; the AI opens the file
// when a task matches, so an unused skill costs a line, not its text.

import { existsSync } from "node:fs";
import { join } from "node:path";
import { writeSkill } from "./skills";

const FIX_BUG = `How to fix a bug (keep it small and proven):
1. Check the real system first, read only: call the public API, read logs, run a SELECT. Never change anything while checking. Until you have seen it fail on the real system, say "likely cause", not "root cause".
2. Never rule a cause out from an assumption about what the person sees; check it or say it is unchecked.
3. Look at the code that actually runs (right folder, branch and copy; repos often keep old copies under _reference or backup folders).
4. Go to the first error, not the last. Classify it: code bug, data/config, or environment.
5. Make the smallest fix where the cause is (code, data or setting). Data or server changes: follow the server-change skill.
6. Test when it matters: a code change gets a test if the project can run one (create a temporary local database only if the test needs one). If you cannot test, say "not tested" plainly.
7. End with: Found (cause and proof), Changed (what, where), Check (what you ran and saw), Left (what is not done or not checked).`;

const CHECK_ON_SCREEN = `How to check a change on screen:
1. Run the app locally the way the project does (web build, dev server or simulator), pointed at the API the person uses for testing (often the real API; see the project's notes).
2. Open the exact screen the change is about and use it like a customer: tap through the main path and one wrong path.
3. Look for errors on the page and in the console or logs while you do it.
4. Take a screenshot of the result and put it in the reply so the person can see it.
5. Stop the processes you started. Report what you checked, what passed and what looked wrong.`;

const SERVER_CHANGE = `How to change a live server or database safely:
1. Before running anything that changes data or the server, write a short note in the project at docs/opscode/changes/<date>.md: what you will run, why, and exactly how to undo it.
2. Prefer the project's own scripts and migrations over hand-written changes. Read a script before you run it.
3. Change the smallest thing. Never delete data or drop tables unless the person asked for exactly that.
4. Check the result on the real system (API call or SELECT) and add it to the note.
5. If you changed code directly on the server, list the files in the note and remind the person to push the same change to GitHub so the server and the repository stay the same.`;

export const BUILTIN_SKILLS = [
  { name: "fix-bug", description: "Fixing a bug or error: check the real system first (read only), smallest fix, test when it matters, report Found/Changed/Check/Left.", body: FIX_BUG },
  { name: "check-on-screen", description: "Checking a fix or new feature in the running app: run it locally, use the screen like a customer, send a screenshot.", body: CHECK_ON_SCREEN },
  { name: "server-change", description: "Before changing a live server or database: write what you will run and how to undo it, then remind to push server code changes to GitHub.", body: SERVER_CHANGE },
];

/** Writes the built-in skills that are missing (never overwrites one the person has, edited or not). */
export function seedBuiltinSkills(userDir: string): string[] {
  const added: string[] = [];
  for (const s of BUILTIN_SKILLS) {
    if (existsSync(join(userDir, s.name, "SKILL.md"))) continue;
    writeSkill(userDir, { name: s.name, description: s.description, body: s.body });
    added.push(s.name);
  }
  return added;
}
