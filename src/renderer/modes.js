// Permission modes: what an agent may do in a chat without asking.
export const MODES = [
  { id: "read", label: "Read-only", short: "Read-only", icon: "eye", description: "Looks around only. No edits, commands or tools." },
  { id: "supervised", label: "Supervised", short: "Supervised", icon: "shield", description: "Asks before each edit, command or tool." },
  { id: "auto_edits", label: "Auto-accept edits", short: "Auto edits", icon: "compose", description: "Edits go ahead. Commands and tools still ask." },
  { id: "full", label: "Full access", short: "Full access", icon: "zap", description: "Nothing asks. Still limited to this project folder." },
];
export const modeInfo = (id) => MODES.find((m) => m.id === id) ?? MODES[1];
