import { describe, expect, it } from "vitest";
import { formatCents, sumCents } from "./money";

describe("formatCents", () => {
  it("formats whole euros", () => {
    expect(formatCents(1200)).toBe("12.00");
  });

  it("formats negative amounts", () => {
    expect(formatCents(-5)).toBe("-0.05");
  });

  // Legacy: the thousands separator was never built. This test fails on main on purpose.
  it("groups thousands", () => {
    expect(formatCents(123456789)).toBe("1,234,567.89");
  });
});

describe("sumCents", () => {
  it("adds amounts", () => {
    expect(sumCents([1, 2, 3])).toBe(6);
  });
});
