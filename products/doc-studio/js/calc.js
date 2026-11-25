"use strict";

(function (root, factory) {
  if (typeof module === "object" && module.exports) {
    module.exports = factory();
  } else {
    root.DocCalc = factory();
  }
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  function won(n) {
    const x = Number(n);
    if (!Number.isFinite(x)) return 0;
    return Math.sign(x) * Math.round(Math.abs(x));
  }

  function lineAmount(qty, price) {
    const q = Number(qty);
    const p = Number(price);
    if (!Number.isFinite(q) || !Number.isFinite(p)) return 0;
    return won(q * p);
  }

  function summarize(items, vatMode) {
    const lines = (items || []).map((item) => ({
      amount: lineAmount(item && item.qty, item && item.price),
    }));
    const base = lines.reduce((sum, line) => sum + line.amount, 0);
    let supply;
    let vat;
    let total;
    if (vatMode === "exempt") {
      supply = base;
      vat = 0;
      total = base;
    } else if (vatMode === "inclusive") {
      total = base;
      supply = won(total / 1.1);
      vat = total - supply;
    } else {
      supply = base;
      vat = won(supply * 0.1);
      total = supply + vat;
    }
    return { lines, supply, vat, total };
  }

  function formatWon(n) {
    const value = won(n);
    const sign = value < 0 ? "-" : "";
    return sign + Math.abs(value).toLocaleString("ko-KR");
  }

  function koreanWon(n) {
    const value = won(n);
    if (value < 0) return "마이너스 " + koreanWon(-value);
    if (value === 0) return "영원";
    const digits = ["", "일", "이", "삼", "사", "오", "육", "칠", "팔", "구"];
    const small = ["", "십", "백", "천"];
    const big = ["", "만", "억", "조", "경"];
    let rest = value;
    let group = 0;
    let out = "";
    while (rest > 0 && group < big.length) {
      const chunk = rest % 10000;
      if (chunk) {
        let text = "";
        let piece = chunk;
        for (let i = 0; i < 4; i += 1) {
          const digit = piece % 10;
          if (digit) {
            const name = digit === 1 && i > 0 ? "" : digits[digit];
            text = name + small[i] + text;
          }
          piece = Math.floor(piece / 10);
        }
        out = text + big[group] + out;
      }
      rest = Math.floor(rest / 10000);
      group += 1;
    }
    if (rest > 0) return formatWon(value) + "원";
    return out + "원";
  }

  function nextNumber(prefix, dateValue, seq) {
    let date = dateValue instanceof Date ? dateValue : new Date(String(dateValue) + "T00:00:00");
    if (Number.isNaN(date.getTime())) date = new Date();
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, "0");
    const d = String(date.getDate()).padStart(2, "0");
    const n = Number(seq);
    const safe = Number.isFinite(n) && n > 0 ? Math.floor(n) : 1;
    return prefix + "-" + y + m + d + "-" + String(safe).padStart(3, "0");
  }

  function projectQuote(input) {
    const tasks = (input && input.tasks) || [];
    const hourly = Number(input && input.hourly) || 0;
    const buffer = Number(input && input.bufferPct) || 0;
    const margin = Number(input && input.marginPct) || 0;
    const fee = Number(input && input.feePct) || 0;
    const hours = tasks.reduce((sum, task) => sum + (Number(task && task.hours) || 0), 0);
    const labor = won(hours * hourly);
    const buffered = won(labor * (1 + buffer / 100));
    const margined = won(buffered * (1 + margin / 100));
    if (fee >= 100) {
      return { hours, labor, buffered, margined, suggested: null, error: "수수료는 100% 미만이어야 합니다." };
    }
    const suggested = won(margined / (1 - fee / 100));
    return { hours, labor, buffered, margined, suggested, error: "" };
  }

  function distributeQuoteLines(input) {
    const quote = projectQuote(input);
    if (quote.error || quote.suggested == null) return { quote, lines: [] };
    const hourly = Number(input.hourly) || 0;
    const buffer = Number(input.bufferPct) || 0;
    const margin = Number(input.marginPct) || 0;
    const fee = Number(input.feePct) || 0;
    const factor = ((1 + buffer / 100) * (1 + margin / 100)) / (1 - fee / 100);
    const lines = (input.tasks || [])
      .filter((task) => Number(task && task.hours) > 0)
      .map((task) => ({
        name: String((task && task.name) || "작업"),
        hours: Number(task.hours),
        price: won(Number(task.hours) * hourly * factor),
      }));
    if (!lines.length) return { quote, lines: [] };
    const sum = lines.reduce((total, line) => total + line.price, 0);
    lines[lines.length - 1].price += quote.suggested - sum;
    return { quote, lines };
  }

  function ledgerTotals(entries) {
    const rows = entries || [];
    let salesSupply = 0;
    let salesVat = 0;
    let costSupply = 0;
    let costVat = 0;
    rows.forEach((entry) => {
      const supply = won(entry && entry.supply);
      const vat = entry && entry.taxed === false ? 0 : won(supply * 0.1);
      if (entry && entry.kind === "out") {
        costSupply += supply;
        costVat += vat;
      } else {
        salesSupply += supply;
        salesVat += vat;
      }
    });
    return {
      salesSupply,
      salesVat,
      salesTotal: salesSupply + salesVat,
      costSupply,
      costVat,
      costTotal: costSupply + costVat,
      net: salesSupply + salesVat - (costSupply + costVat),
      vatGap: salesVat - costVat,
    };
  }

  return {
    won,
    lineAmount,
    summarize,
    formatWon,
    koreanWon,
    nextNumber,
    projectQuote,
    distributeQuoteLines,
    ledgerTotals,
  };
});
