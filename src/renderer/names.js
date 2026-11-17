// The words the interface uses for things that have an internal name. Change them here only.
// (Internal ids and RPC methods stay `chief.*`.)

/** A standing helper chat that runs other chats for you and keeps a board. Was "Chief". */
export const CHIEF_NAME = { one: "Manager", many: "Managers", article: "a Manager", the: "the Manager" };

/** What a helper or mode chat is called in lists. A mode chat (GODMODE, WARLORD, SHINOBI) is named after its task; until it has one it is "New chat". */
export function chiefLabel(c) {
  if (c.mode) return c.title || "New chat";
  return c.name.replace(/^Chief\b/, CHIEF_NAME.one);
}
