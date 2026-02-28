import { generateSummary, type ExtensionAPI, type SessionEntry } from "@mariozechner/pi-coding-agent";
import {
  buildCustomInstructions,
  collectCompleteTurns,
  collectMessages,
  findLatestCompactionIndex,
  minimumTurnsRequired,
  parseCommandArgs,
  parseInstructions,
  type SessionEntryLike,
} from "./front-compaction-core";

function cancelWithReason(
  ctx: { hasUI: boolean; ui: { notify: (message: string, level: "error") => void } },
  reason: string,
) {
  if (ctx.hasUI) {
    ctx.ui.notify(reason, "error");
  }
  return { cancel: true as const };
}

export default function frontCompaction(pi: ExtensionAPI) {
  const registerFrontCompactionCommand = (name: string, description: string) => {
    pi.registerCommand(name, {
      description,
      handler: async (args, ctx) => {
        const parsedArgs = parseCommandArgs(args);

        if (parsedArgs.error) {
          if (ctx.hasUI) {
            ctx.ui.notify(`front-compaction: ${parsedArgs.error}`, "error");
          }
          return;
        }

        if (ctx.hasUI) {
          ctx.ui.notify(`Compacting the oldest ${parsedArgs.percent}% of complete turns...`, "info");
        }

        ctx.compact({
          customInstructions: buildCustomInstructions(parsedArgs.percent, parsedArgs.focus),
          onComplete: () => {
            if (ctx.hasUI) {
              ctx.ui.notify(`Front compaction (${parsedArgs.percent}%) completed.`, "info");
            }
          },
          onError: error => {
            if (!ctx.hasUI) {
              return;
            }
            if (error.message !== "Compaction cancelled") {
              ctx.ui.notify(`Front compaction failed: ${error.message}`, "error");
            }
          },
        });
      },
    });
  };

  registerFrontCompactionCommand(
    "pi-front-compaction",
    "Compact the oldest N% of complete user+assistant turns (default: 30)",
  );
  registerFrontCompactionCommand(
    "front-compaction",
    "Alias for /pi-front-compaction (backward compatibility)",
  );
  registerFrontCompactionCommand(
    "front-compaction-pi",
    "Alias for /pi-front-compaction (legacy compatibility)",
  );

  pi.on("session_before_compact", async (event, ctx) => {
    const parsed = parseInstructions(event.customInstructions);
    if (!parsed.enabled) {
      return;
    }

    const entries = event.branchEntries;
    const latestCompactionIndex = findLatestCompactionIndex(entries as unknown as SessionEntryLike[]);
    const startIndex = latestCompactionIndex >= 0 ? latestCompactionIndex + 1 : 0;

    const turns = collectCompleteTurns(entries as unknown as SessionEntryLike[], startIndex, entries.length);
    const turnsToCompact = Math.floor((turns.length * parsed.percent) / 100);

    if (turnsToCompact < 1) {
      const requiredTurns = minimumTurnsRequired(parsed.percent);
      return cancelWithReason(
        ctx,
        `Unsupported: front compaction at ${parsed.percent}% requires at least ${requiredTurns} complete user+assistant turns since the last compaction.`,
      );
    }

    if (turnsToCompact >= turns.length) {
      return cancelWithReason(
        ctx,
        `Unsupported: front compaction at ${parsed.percent}% would compact the entire conversation segment.`,
      );
    }

    const boundaryTurn = turns[turnsToCompact];
    if (!boundaryTurn) {
      return cancelWithReason(ctx, "Unsupported: could not determine the front compaction boundary.");
    }

    const firstKeptEntry = entries[boundaryTurn.start];
    if (!firstKeptEntry?.id) {
      return cancelWithReason(ctx, "Unsupported: could not resolve first kept entry ID for front compaction.");
    }

    const messagesToSummarize = collectMessages(
      entries as unknown as SessionEntryLike[],
      startIndex,
      boundaryTurn.start,
    );
    if (messagesToSummarize.length === 0) {
      return cancelWithReason(ctx, "Unsupported: nothing to compact in the requested front segment.");
    }

    const model = ctx.model;
    if (!model) {
      return cancelWithReason(ctx, "Unsupported: no active model selected for compaction.");
    }

    const apiKey = await ctx.modelRegistry.getApiKey(model);
    if (!apiKey) {
      return cancelWithReason(ctx, `Unsupported: no API key available for ${model.provider}.`);
    }

    const previousSummary =
      latestCompactionIndex >= 0 && entries[latestCompactionIndex].type === "compaction"
        ? entries[latestCompactionIndex].summary
        : undefined;

    try {
      const summary = await generateSummary(
        messagesToSummarize as SessionEntry["message"][],
        model,
        event.preparation.settings.reserveTokens,
        apiKey,
        event.signal,
        parsed.focus,
        previousSummary,
      );

      if (!summary.trim()) {
        return cancelWithReason(ctx, "Unsupported: compaction summary was empty.");
      }

      return {
        compaction: {
          summary,
          firstKeptEntryId: firstKeptEntry.id,
          tokensBefore: event.preparation.tokensBefore,
          details: {
            mode: "front-compaction",
            percent: parsed.percent,
            totalTurns: turns.length,
            compactedTurns: turnsToCompact,
          },
        },
      };
    } catch (error) {
      if (event.signal.aborted) {
        return { cancel: true };
      }
      const message = error instanceof Error ? error.message : String(error);
      return cancelWithReason(ctx, `Unsupported: front compaction failed (${message}).`);
    }
  });
}
