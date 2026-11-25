"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const calc = require("../js/calc.js");

test("exclusive VAT rounds half away from zero", () => {
  const result = calc.summarize(
    [
      { qty: 2, price: 10000 },
      { qty: 1, price: 333 },
    ],
    "exclusive"
  );
  assert.equal(result.supply, 20333);
  assert.equal(result.vat, 2033);
  assert.equal(result.total, 22366);
});

test("inclusive VAT is backed out of the gross sum", () => {
  const result = calc.summarize(
    [
      { qty: 1, price: 11000 },
      { qty: 2, price: 1100 },
    ],
    "inclusive"
  );
  assert.equal(result.total, 13200);
  assert.equal(result.supply, 12000);
  assert.equal(result.vat, 1200);
});

test("won rounding on a repeating inclusive total", () => {
  const result = calc.summarize([{ qty: 1, price: 10000 }], "inclusive");
  assert.equal(result.total, 10000);
  assert.equal(result.supply, 9091);
  assert.equal(result.vat, 909);
});

test("exempt has no tax", () => {
  const result = calc.summarize([{ qty: 3, price: 1500 }], "exempt");
  assert.deepEqual(
    { supply: result.supply, vat: result.vat, total: result.total },
    { supply: 4500, vat: 0, total: 4500 }
  );
});

test("empty and invalid lines contribute zero", () => {
  const result = calc.summarize([{ qty: "", price: "" }, { qty: "x", price: 5 }], "exclusive");
  assert.equal(result.total, 0);
});

test("negative half rounds away from zero", () => {
  assert.equal(calc.won(-1.5), -2);
  assert.equal(calc.won(1.5), 2);
});

test("korean amount reading", () => {
  assert.equal(calc.koreanWon(0), "영원");
  assert.equal(calc.koreanWon(11), "십일원");
  assert.equal(calc.koreanWon(21), "이십일원");
  assert.equal(calc.koreanWon(101), "백일원");
  assert.equal(calc.koreanWon(1001), "천일원");
  assert.equal(calc.koreanWon(10000), "일만원");
  assert.equal(calc.koreanWon(10001), "일만일원");
  assert.equal(calc.koreanWon(100000), "십만원");
  assert.equal(calc.koreanWon(1234567), "백이십삼만사천오백육십칠원");
  assert.equal(calc.koreanWon(100000000), "일억원");
  assert.equal(calc.koreanWon(-1500), "마이너스 천오백원");
});

test("document numbers", () => {
  assert.equal(calc.nextNumber("Q", "2026-11-25", 1), "Q-20261125-001");
  assert.equal(calc.nextNumber("S", "2026-01-02", 12), "S-20260102-012");
  assert.equal(calc.nextNumber("R", "not-a-date", 0).startsWith("R-"), true);
});

test("project quote grosses up a platform fee and balances lines", () => {
  const input = {
    tasks: [
      { name: "설계", hours: 1 },
      { name: "구현", hours: 1 },
    ],
    hourly: 10000,
    bufferPct: 10,
    marginPct: 20,
    feePct: 10,
  };
  const quote = calc.projectQuote(input);
  assert.equal(quote.hours, 2);
  assert.equal(quote.labor, 20000);
  assert.equal(quote.buffered, 22000);
  assert.equal(quote.margined, 26400);
  assert.equal(quote.suggested, 29333);
  const split = calc.distributeQuoteLines(input);
  const sum = split.lines.reduce((total, line) => total + line.price, 0);
  assert.equal(sum, 29333);
  assert.equal(split.lines[0].name, "설계");
});

test("fee of 100 percent is rejected", () => {
  const quote = calc.projectQuote({
    tasks: [{ name: "작업", hours: 2 }],
    hourly: 10000,
    bufferPct: 0,
    marginPct: 0,
    feePct: 100,
  });
  assert.equal(quote.suggested, null);
  assert.match(quote.error, /100/);
});

test("ledger totals keep exempt lines at zero tax", () => {
  const totals = calc.ledgerTotals([
    { kind: "in", supply: 100000, taxed: true },
    { kind: "out", supply: 30000, taxed: true },
    { kind: "out", supply: 5000, taxed: false },
  ]);
  assert.equal(totals.salesSupply, 100000);
  assert.equal(totals.salesVat, 10000);
  assert.equal(totals.costSupply, 35000);
  assert.equal(totals.costVat, 3000);
  assert.equal(totals.net, 110000 - 38000);
  assert.equal(totals.vatGap, 7000);
});
