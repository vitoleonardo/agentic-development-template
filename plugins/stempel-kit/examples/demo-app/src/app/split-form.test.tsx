import { renderToStaticMarkup } from "react-dom/server";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { SplitState } from "@/features/split/actions";
import { SplitForm } from "./split-form";

const form = vi.hoisted(() => ({ state: null as SplitState, pending: false }));

vi.mock("react", async (importOriginal) => ({
  ...(await importOriginal<typeof import("react")>()),
  useActionState: () => [form.state, () => {}, form.pending],
}));

const render = (state: SplitState, pending = false) => {
  form.state = state;
  form.pending = pending;
  return renderToStaticMarkup(<SplitForm />);
};

describe("SplitForm", () => {
  beforeEach(() => {
    form.state = null;
    form.pending = false;
  });

  it("shows only the field and the button before the first split", () => {
    const html = render(null);
    expect(html).toContain('<label for="expenses">Expenses</label>');
    expect(html).toContain(">Split</button>");
    expect(html).not.toContain("Who pays whom");
  });

  it("disables the button while splitting", () => {
    expect(render(null, true)).toContain('disabled="">Splitting…</button>');
  });

  it("SPLIT-AC1: lists each transfer in euros", () => {
    const html = render({ transfers: [{ from: "Bob", to: "Alice", amountCents: 1525 }] });
    expect(html).toContain("Who pays whom");
    expect(html).toContain("<li>Bob pays Alice 15.25</li>");
  });

  it("SPLIT-AC3: says everyone is even when there are no transfers", () => {
    expect(render({ transfers: [] })).toContain("Everyone is even.");
  });

  it("SPLIT-AC4: shows the error and no transfers", () => {
    const html = render({ error: "Line 2: amount must be more than 0" });
    expect(html).toContain('<p role="alert">Line 2: amount must be more than 0</p>');
    expect(html).not.toContain("Who pays whom");
  });
});
