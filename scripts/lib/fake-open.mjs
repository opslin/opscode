#!/usr/bin/env node
// A stand-in for `open <url>`: records the link instead of opening a browser.
import { appendFileSync } from "node:fs";
if (process.env.OPSCODE_FAKE_OPEN_LOG) appendFileSync(process.env.OPSCODE_FAKE_OPEN_LOG, JSON.stringify({ argv: process.argv.slice(2) }) + "\n");
