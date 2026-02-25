import {
  buildCustomInstructions,
  collectCompleteTurns,
  findLatestCompactionIndex,
  minimumTurnsRequired,
  parseCommandArgs,
  parseInstructions,
} from "../extensions/front-compaction-core";

function assert(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(message);
  }
}

function test_parseCommandArgs(): void {
  const defaultArgs = parseCommandArgs("");
  assert(defaultArgs.percent === 30, "default percent should be 30");

  const withPercent = parseCommandArgs("50 focus on unresolved TODOs");
  assert(withPercent.percent === 50, "percent 50 should be parsed");
  assert(withPercent.focus === "focus on unresolved TODOs", "focus should be parsed");

  const focusOnly = parseCommandArgs("focus only mode");
  assert(focusOnly.percent === 30, "focus-only input should use default percent");
  assert(focusOnly.focus === "focus only mode", "focus-only input should keep full text");

  const invalidPercent = parseCommandArgs("0");
  assert(Boolean(invalidPercent.error), "invalid percent should produce an error");
}

function test_parseInstructions(): void {
  const raw = buildCustomInstructions(40, "check edge cases");
  const parsed = parseInstructions(raw);
  assert(parsed.enabled === true, "marker instructions should enable front compaction");
  assert(parsed.percent === 40, "instructions should parse percent");
  assert(parsed.focus === "check edge cases", "instructions should parse focus");

  const disabled = parseInstructions("some-other-instructions");
  assert(disabled.enabled === false, "non-marker instructions should be disabled");

  const fallback = parseInstructions("__PI_FRONT_COMPACTION__\n{not-json}");
  assert(fallback.enabled === true, "marker with invalid json should stay enabled");
  assert(fallback.percent === 30, "invalid payload should fall back to default percent");
}

function test_collectCompleteTurns(): void {
  const entries = [
    { type: "message", id: "m1", message: { role: "user", content: "u1" } },
    { type: "message", id: "m2", message: { role: "assistant", content: "a1" } },
    { type: "message", id: "m3", message: { role: "user", content: "u2" } },
    { type: "message", id: "m4", message: { role: "assistant", content: "a2" } },
    { type: "message", id: "m5", message: { role: "user", content: "u3" } },
    { type: "message", id: "m6", message: { role: "assistant", content: "a3" } },
  ];

  const turns = collectCompleteTurns(entries, 0, entries.length);
  assert(turns.length === 3, "should detect 3 complete turns");
  assert(turns[0]?.start === 0 && turns[0]?.end === 2, "turn 1 boundary mismatch");
  assert(turns[1]?.start === 2 && turns[1]?.end === 4, "turn 2 boundary mismatch");
  assert(turns[2]?.start === 4 && turns[2]?.end === 6, "turn 3 boundary mismatch");
}

function test_findLatestCompactionIndex(): void {
  const entries = [
    { type: "message", id: "m1", message: { role: "user", content: "u1" } },
    { type: "compaction", summary: "s1" },
    { type: "message", id: "m2", message: { role: "assistant", content: "a1" } },
    { type: "compaction", summary: "s2" },
  ];

  const latest = findLatestCompactionIndex(entries);
  assert(latest === 3, "latest compaction index should be 3");
}

function test_minimumTurnsRequired(): void {
  assert(minimumTurnsRequired(30) === 4, "30% should require 4 turns");
  assert(minimumTurnsRequired(50) === 2, "50% should require 2 turns");
}

function main(): void {
  test_parseCommandArgs();
  test_parseInstructions();
  test_collectCompleteTurns();
  test_findLatestCompactionIndex();
  test_minimumTurnsRequired();
  console.log("PASS: front-compaction core helpers");
}

main();
