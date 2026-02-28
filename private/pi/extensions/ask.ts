import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type, type Static } from "@sinclair/typebox";

const AskOptionSchema = Type.Object({
  label: Type.String({ description: "Display label for the option" }),
  description: Type.Optional(Type.String({ description: "Optional extra context shown with the option" })),
});

const AskQuestionSchema = Type.Object({
  id: Type.String({ description: "Question ID (e.g. auth, cache, scope)" }),
  question: Type.String({ description: "Question text shown to the user" }),
  options: Type.Array(AskOptionSchema, {
    minItems: 1,
    description: "Available options. Do not include an 'Other' option; it is added automatically.",
  }),
  multi: Type.Optional(Type.Boolean({ description: "Allow selecting multiple options" })),
  recommended: Type.Optional(
    Type.Number({ description: "0-indexed recommended option used as default selection" }),
  ),
});

const AskParamsSchema = Type.Object({
  questions: Type.Array(AskQuestionSchema, {
    minItems: 1,
    description: "One or more questions to ask in sequence",
  }),
});

type AskQuestion = Static<typeof AskQuestionSchema>;
type AskParams = Static<typeof AskParamsSchema>;

type AskQuestionResult = {
  id: string;
  question: string;
  options: string[];
  multi: boolean;
  selectedOptions: string[];
  customInput?: string;
  cancelled: boolean;
};

type AskToolDetails = {
  cancelled: boolean;
  results: AskQuestionResult[];
};

type AskUi = {
  select: (
    prompt: string,
    options: string[],
    options_?: {
      initialIndex?: number;
    },
  ) => Promise<string | undefined>;
  input: (prompt: string, placeholder?: string) => Promise<string | undefined>;
};

const OTHER_OPTION_LABEL = "Other (type your own)";
const DONE_OPTION_LABEL = "Done selecting";
const CHECKED_PREFIX = "☑";
const UNCHECKED_PREFIX = "☐";
const RECOMMENDED_SUFFIX = " (Recommended)";

function normalizeRecommendedIndex(recommended: number | undefined, optionCount: number): number | undefined {
  if (recommended === undefined || !Number.isFinite(recommended)) return undefined;
  const normalized = Math.floor(recommended);
  if (normalized < 0 || normalized >= optionCount) return undefined;
  return normalized;
}

function formatOptionLabel(
  option: { label: string; description?: string },
  index: number,
  recommendedIndex: number | undefined,
): string {
  const description = option.description?.trim();
  const recommendedSuffix = recommendedIndex === index ? RECOMMENDED_SUFFIX : "";
  const withIndex = `${index + 1}. ${option.label}${recommendedSuffix}`;
  if (!description) return withIndex;
  return `${withIndex} — ${description}`;
}

function selectOptionLabels(question: AskQuestion, selectedIndices: Set<number>): string[] {
  return [...selectedIndices]
    .sort((a, b) => a - b)
    .map(index => question.options[index]?.label)
    .filter((value): value is string => Boolean(value));
}

async function askSingleChoice(
  question: AskQuestion,
  baseOptions: string[],
  recommendedIndex: number | undefined,
  ui: AskUi,
): Promise<{ selectedOptions: string[]; customInput?: string; cancelled: boolean }> {
  const choice = await ui.select(question.question, [...baseOptions, OTHER_OPTION_LABEL], {
    initialIndex: recommendedIndex,
  });

  if (choice === undefined) {
    return { selectedOptions: [], cancelled: true };
  }

  if (choice === OTHER_OPTION_LABEL) {
    const input = await ui.input("Enter your response:");
    const customInput = typeof input === "string" ? input.trim() : "";
    if (!customInput) {
      return { selectedOptions: [], cancelled: true };
    }
    return { selectedOptions: [], customInput, cancelled: false };
  }

  const selectedIndex = baseOptions.indexOf(choice);
  if (selectedIndex < 0) {
    return { selectedOptions: [], cancelled: true };
  }

  const selectedLabel = question.options[selectedIndex]?.label;
  if (!selectedLabel) {
    return { selectedOptions: [], cancelled: true };
  }

  return { selectedOptions: [selectedLabel], cancelled: false };
}

async function askMultiChoice(
  question: AskQuestion,
  baseOptions: string[],
  recommendedIndex: number | undefined,
  ui: AskUi,
): Promise<{ selectedOptions: string[]; customInput?: string; cancelled: boolean }> {
  const selectedIndices = new Set<number>();
  let customInput: string | undefined;
  let cursorIndex = recommendedIndex ?? 0;

  while (true) {
    const choices = baseOptions.map((option, index) => {
      const checkbox = selectedIndices.has(index) ? CHECKED_PREFIX : UNCHECKED_PREFIX;
      return `${checkbox} ${option}`;
    });

    if (selectedIndices.size > 0) {
      choices.push(DONE_OPTION_LABEL);
    }
    choices.push(OTHER_OPTION_LABEL);

    const safeCursor = Math.max(0, Math.min(cursorIndex, choices.length - 1));
    const prefix = selectedIndices.size > 0 ? `(${selectedIndices.size} selected) ` : "";

    const choice = await ui.select(`${prefix}${question.question}`, choices, {
      initialIndex: safeCursor,
    });

    if (choice === undefined || choice === DONE_OPTION_LABEL) {
      break;
    }

    if (choice === OTHER_OPTION_LABEL) {
      const input = await ui.input("Enter your response:");
      const trimmed = typeof input === "string" ? input.trim() : "";
      if (trimmed) customInput = trimmed;
      break;
    }

    const selectedIndex = choices.indexOf(choice);
    if (selectedIndex < 0 || selectedIndex >= baseOptions.length) {
      continue;
    }

    cursorIndex = selectedIndex;

    if (selectedIndices.has(selectedIndex)) {
      selectedIndices.delete(selectedIndex);
    } else {
      selectedIndices.add(selectedIndex);
    }
  }

  const selectedOptions = selectOptionLabels(question, selectedIndices);
  const cancelled = selectedOptions.length === 0 && !customInput;

  return { selectedOptions, customInput, cancelled };
}

async function askQuestion(
  question: AskQuestion,
  ui: AskUi,
): Promise<AskQuestionResult> {
  const recommendedIndex = normalizeRecommendedIndex(question.recommended, question.options.length);
  const baseOptions = question.options.map((option, index) => formatOptionLabel(option, index, recommendedIndex));
  const multi = question.multi === true;

  const result = multi
    ? await askMultiChoice(question, baseOptions, recommendedIndex, ui)
    : await askSingleChoice(question, baseOptions, recommendedIndex, ui);

  return {
    id: question.id,
    question: question.question,
    options: question.options.map(option => option.label),
    multi,
    selectedOptions: result.selectedOptions,
    customInput: result.customInput,
    cancelled: result.cancelled,
  };
}

function formatQuestionResult(result: AskQuestionResult): string {
  if (result.customInput && result.selectedOptions.length > 0) {
    return `${result.id}: [${result.selectedOptions.join(", ")}] + "${result.customInput}"`;
  }

  if (result.customInput) {
    return `${result.id}: "${result.customInput}"`;
  }

  if (result.selectedOptions.length > 0) {
    if (result.multi) {
      return `${result.id}: [${result.selectedOptions.join(", ")}]`;
    }
    return `${result.id}: ${result.selectedOptions[0]}`;
  }

  return `${result.id}: (cancelled)`;
}

function formatSingleQuestionOutput(result: AskQuestionResult): string {
  if (result.customInput && result.selectedOptions.length > 0) {
    return `User selected: ${result.selectedOptions.join(", ")}; custom input: ${result.customInput}`;
  }

  if (result.customInput) {
    return `User provided custom input: ${result.customInput}`;
  }

  if (result.selectedOptions.length > 0) {
    return result.multi
      ? `User selected: ${result.selectedOptions.join(", ")}`
      : `User selected: ${result.selectedOptions[0]}`;
  }

  return "User cancelled the selection";
}

const ASK_TOOL_DESCRIPTION =
  "Ask the user structured follow-up questions when a decision is required to proceed. Supports multiple-choice options with descriptions, multi-select via multi=true, and multi-part questionnaires via questions[]. Do not include an 'Other' option in your inputs.";

export default function ask(pi: ExtensionAPI) {
  const registerAskTool = (name: string, label: string, description: string) => {
    pi.registerTool({
      name,
      label,
      description,
      parameters: AskParamsSchema,

      async execute(_toolCallId, params: AskParams, _signal, _onUpdate, ctx) {
        if (!ctx.hasUI) {
          return {
            content: [{ type: "text", text: "Error: ask requires interactive mode with UI." }],
            details: { cancelled: true, results: [] } as AskToolDetails,
            isError: true,
          };
        }

        if (params.questions.length === 0) {
          return {
            content: [{ type: "text", text: "Error: questions must not be empty." }],
            details: { cancelled: true, results: [] } as AskToolDetails,
            isError: true,
          };
        }

        const ui = ctx.ui as AskUi;
        const results: AskQuestionResult[] = [];
        let cancelled = false;

        for (const question of params.questions) {
          if (question.options.length === 0) {
            return {
              content: [{ type: "text", text: `Error: question '${question.id}' has no options.` }],
              details: { cancelled: true, results } as AskToolDetails,
              isError: true,
            };
          }

          const result = await askQuestion(question, ui);
          results.push(result);

          if (result.cancelled) {
            cancelled = true;
            break;
          }
        }

        const details: AskToolDetails = {
          cancelled,
          results,
        };

        if (results.length === 1) {
          return {
            content: [{ type: "text", text: formatSingleQuestionOutput(results[0]) }],
            details,
          };
        }

        const summary = results.map(formatQuestionResult).join("\n");
        return {
          content: [{ type: "text", text: `User answers:\n${summary}` }],
          details,
        };
      },
    });
  };

  registerAskTool("ask", "Ask", ASK_TOOL_DESCRIPTION);
  registerAskTool(
    "AskUserQuestion",
    "AskUserQuestion",
    "Alias for ask. Use this when a skill references AskUserQuestion.",
  );
}
