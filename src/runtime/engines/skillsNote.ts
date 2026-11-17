// The skills a Claude Code or Codex chat can use: one line each (name, when to use it, where the
// file is). The AI opens a skill's file only when a task matches, so unused skills cost one line.

export function skillsNote(files: readonly { name: string; description: string; path: string }[]): string {
  if (!files.length) return "";
  return [
    "Skills: short how-to files for common jobs. When a task matches one, read its file first and follow it; skip the ones that do not fit.",
    ...files.map((f) => `- ${f.name}: ${f.description.replace(/\s+/g, " ").slice(0, 200)} (${f.path})`),
  ].join("\n");
}
