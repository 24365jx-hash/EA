"use strict";

(function () {
  const KEY = "doc-studio-v1";
  const TITLES = { quote: "견 적 서", statement: "거래명세서", receipt: "영 수 증" };
  const SUBS = {
    quote: "아래와 같이 견적합니다.",
    statement: "아래와 같이 거래합니다.",
    receipt: "아래 금액을 영수합니다.",
  };
  const PREFIX = { quote: "Q", statement: "S", receipt: "R" };
  const PRESETS = {
    freelance: {
      bizType: "서비스",
      bizItem: "소프트웨어 개발",
      note: "수정 1회를 포함합니다.",
      items: [
        { name: "화면 설계", spec: "1식", qty: "1", price: "800000", note: "" },
        { name: "화면 구현", spec: "1식", qty: "1", price: "1500000", note: "" },
      ],
    },
    studio: {
      bizType: "제조",
      bizItem: "수공예",
      note: "납품 후 파손은 수령일로부터 7일 이내 교환합니다.",
      items: [
        { name: "도자기 머그", spec: "300ml", qty: "20", price: "18000", note: "" },
        { name: "선물 포장", spec: "", qty: "20", price: "1000", note: "" },
      ],
    },
    class: {
      bizType: "서비스",
      bizItem: "교육",
      note: "수업 시작 후 잔여 회차는 협의합니다.",
      items: [{ name: "월 수업료", spec: "4회", qty: "1", price: "200000", note: "" }],
    },
    repair: {
      bizType: "서비스",
      bizItem: "수리",
      note: "부품 가격은 당일 시세입니다.",
      items: [
        { name: "출장 점검", spec: "1회", qty: "1", price: "30000", note: "" },
        { name: "부품 교체", spec: "", qty: "1", price: "70000", note: "" },
      ],
    },
  };

  let state = defaultState();
  let memoryOnly = false;

  function todayISO(date) {
    const d = date || new Date();
    const m = String(d.getMonth() + 1).padStart(2, "0");
    const day = String(d.getDate()).padStart(2, "0");
    return d.getFullYear() + "-" + m + "-" + day;
  }

  function defaultState() {
    const now = new Date();
    return {
      seller: { name: "", owner: "", bizNo: "", address: "", bizType: "", bizItem: "", phone: "", email: "", bank: "" },
      buyer: { name: "", contact: "", phone: "", email: "" },
      doc: { type: "quote", date: todayISO(now), numberOverride: "", validUntil: "", note: "", vatMode: "exclusive" },
      items: [blankItem()],
      seq: { quote: 1, statement: 1, receipt: 1 },
      quote: { hourly: "", bufferPct: "10", marginPct: "20", feePct: "0", tasks: [blankTask()] },
      ledger: { year: now.getFullYear(), month: now.getMonth() + 1, entries: [] },
    };
  }

  function blankItem() {
    return { name: "", spec: "", qty: "", price: "", note: "" };
  }

  function blankTask() {
    return { name: "", hours: "" };
  }

  function load() {
    try {
      const raw = localStorage.getItem(KEY);
      if (!raw) return;
      state = sanitize(JSON.parse(raw));
    } catch (error) {
      state = defaultState();
    }
  }

  function save() {
    try {
      localStorage.setItem(KEY, JSON.stringify(state));
    } catch (error) {
      memoryOnly = true;
      const warning = document.getElementById("save-warning");
      if (warning) warning.hidden = false;
    }
  }

  function sanitize(data) {
    const base = defaultState();
    if (!data || typeof data !== "object") return base;
    const seller = Object.assign(base.seller, pick(data.seller, base.seller));
    const buyer = Object.assign(base.buyer, pick(data.buyer, base.buyer));
    const doc = Object.assign(base.doc, pick(data.doc, base.doc));
    if (!PREFIX[doc.type]) doc.type = "quote";
    if (!["exclusive", "inclusive", "exempt"].includes(doc.vatMode)) doc.vatMode = "exclusive";
    const items = Array.isArray(data.items) && data.items.length
      ? data.items.slice(0, 40).map((item) => Object.assign(blankItem(), pick(item, blankItem())))
      : [blankItem()];
    const seq = Object.assign(base.seq, pick(data.seq, base.seq));
    ["quote", "statement", "receipt"].forEach((key) => {
      const n = Number(seq[key]);
      seq[key] = Number.isFinite(n) && n > 0 ? Math.floor(n) : 1;
    });
    const quoteIn = data.quote && typeof data.quote === "object" ? data.quote : {};
    const quote = {
      hourly: String(quoteIn.hourly || ""),
      bufferPct: quoteIn.bufferPct == null ? "10" : String(quoteIn.bufferPct),
      marginPct: quoteIn.marginPct == null ? "20" : String(quoteIn.marginPct),
      feePct: quoteIn.feePct == null ? "0" : String(quoteIn.feePct),
      tasks: Array.isArray(quoteIn.tasks) && quoteIn.tasks.length
        ? quoteIn.tasks.slice(0, 40).map((task) => ({
          name: String(task && task.name || ""),
          hours: String(task && task.hours || ""),
        }))
        : [blankTask()],
    };
    const ledgerIn = data.ledger && typeof data.ledger === "object" ? data.ledger : {};
    const year = Number(ledgerIn.year) || base.ledger.year;
    const month = Number(ledgerIn.month) || base.ledger.month;
    const entries = Array.isArray(ledgerIn.entries) ? ledgerIn.entries.slice(0, 5000).map(cleanEntry).filter(Boolean) : [];
    return {
      seller, buyer, doc, items, seq, quote,
      ledger: { year, month: Math.min(12, Math.max(1, month)), entries },
    };
  }

  function cleanEntry(entry) {
    if (!entry || typeof entry !== "object") return null;
    const supply = DocCalc.won(entry.supply);
    return {
      id: String(entry.id || Date.now().toString(36) + Math.random().toString(36).slice(2, 6)),
      date: String(entry.date || ""),
      kind: entry.kind === "out" ? "out" : "in",
      party: String(entry.party || ""),
      memo: String(entry.memo || ""),
      supply,
      taxed: entry.taxed !== false,
    };
  }

  function pick(source, shape) {
    const out = {};
    if (!source || typeof source !== "object") return out;
    Object.keys(shape).forEach((key) => {
      if (source[key] != null) out[key] = String(source[key]);
    });
    return out;
  }

  function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text != null) node.textContent = text;
    return node;
  }

  function autoNumber() {
    return DocCalc.nextNumber(PREFIX[state.doc.type], state.doc.date, state.seq[state.doc.type] || 1);
  }

  function currentNumber() {
    return state.doc.numberOverride || autoNumber();
  }

  function formatDate(iso) {
    const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso || "");
    if (!match) return "";
    return match[1] + "년 " + Number(match[2]) + "월 " + Number(match[3]) + "일";
  }

  function setView(name) {
    ["doc", "quote", "ledger"].forEach((view) => {
      document.getElementById("view-" + view).classList.toggle("active", view === name);
      document.getElementById("tab-" + view).setAttribute("aria-selected", view === name ? "true" : "false");
    });
  }

  function bindStatic() {
    document.querySelectorAll("[data-seller]").forEach((input) => {
      input.addEventListener("input", () => {
        state.seller[input.dataset.seller] = input.value;
        save();
        updatePreview();
      });
    });
    document.querySelectorAll("[data-buyer]").forEach((input) => {
      input.addEventListener("input", () => {
        state.buyer[input.dataset.buyer] = input.value;
        save();
        updatePreview();
      });
    });
    document.querySelectorAll('input[name="docType"]').forEach((radio) => {
      radio.addEventListener("change", () => {
        if (!radio.checked) return;
        state.doc.type = radio.value;
        save();
        fillStatic();
        updatePreview();
      });
    });
    document.getElementById("doc-date").addEventListener("input", (event) => {
      state.doc.date = event.target.value;
      save();
      fillStatic();
      updatePreview();
    });
    document.getElementById("doc-number").addEventListener("input", (event) => {
      const value = event.target.value.trim();
      state.doc.numberOverride = value === autoNumber() ? "" : event.target.value;
      save();
      updatePreview();
    });
    document.getElementById("doc-valid").addEventListener("input", (event) => {
      state.doc.validUntil = event.target.value;
      save();
      updatePreview();
    });
    document.getElementById("doc-note").addEventListener("input", (event) => {
      state.doc.note = event.target.value;
      save();
      updatePreview();
    });
    document.getElementById("vat-mode").addEventListener("change", (event) => {
      state.doc.vatMode = event.target.value;
      save();
      updatePreview();
    });
    document.getElementById("next-number").addEventListener("click", () => {
      state.seq[state.doc.type] += 1;
      state.doc.numberOverride = "";
      save();
      fillStatic();
      updatePreview();
    });
    document.getElementById("fill-example").addEventListener("click", fillExample);
    document.getElementById("apply-preset").addEventListener("click", applyPreset);
    document.getElementById("add-item").addEventListener("click", () => {
      state.items.push(blankItem());
      save();
      renderItems();
      updatePreview();
    });
    document.getElementById("print-doc").addEventListener("click", () => {
      setView("doc");
      setTimeout(() => window.print(), 50);
    });
    document.getElementById("export-backup").addEventListener("click", exportBackup);
    document.getElementById("import-backup").addEventListener("click", () => {
      document.getElementById("import-file").click();
    });
    document.getElementById("import-file").addEventListener("change", importBackup);
    document.getElementById("reset-all").addEventListener("click", () => {
      const ok = window.confirm("입력한 문서함 데이터를 모두 지울까요? 백업하지 않은 내용은 되살릴 수 없습니다.");
      if (!ok) return;
      state = defaultState();
      try { localStorage.removeItem(KEY); } catch (error) { /* ignore */ }
      hydrate();
    });
    document.getElementById("add-task").addEventListener("click", () => {
      state.quote.tasks.push(blankTask());
      save();
      renderTasks();
      updateQuote();
    });
    ["hourly", "buffer", "margin", "fee"].forEach((id) => {
      document.getElementById(id).addEventListener("input", (event) => {
        const map = { hourly: "hourly", buffer: "bufferPct", margin: "marginPct", fee: "feePct" };
        state.quote[map[id]] = event.target.value;
        save();
        updateQuote();
      });
    });
    document.getElementById("quote-to-doc").addEventListener("click", quoteToDoc);
    document.getElementById("ledger-year").addEventListener("input", (event) => {
      const year = Number(event.target.value);
      if (Number.isFinite(year) && year > 1900 && year < 3000) state.ledger.year = Math.floor(year);
      save();
      renderLedger();
    });
    document.getElementById("ledger-month").addEventListener("change", (event) => {
      state.ledger.month = Number(event.target.value);
      save();
      renderLedger();
    });
    document.getElementById("add-entry").addEventListener("click", addEntry);
    document.getElementById("tab-doc").addEventListener("click", () => setView("doc"));
    document.getElementById("tab-quote").addEventListener("click", () => setView("quote"));
    document.getElementById("tab-ledger").addEventListener("click", () => setView("ledger"));
  }

  function fillStatic() {
    document.querySelectorAll("[data-seller]").forEach((input) => {
      input.value = state.seller[input.dataset.seller] || "";
    });
    document.querySelectorAll("[data-buyer]").forEach((input) => {
      input.value = state.buyer[input.dataset.buyer] || "";
    });
    document.querySelectorAll('input[name="docType"]').forEach((radio) => {
      radio.checked = radio.value === state.doc.type;
    });
    document.getElementById("doc-date").value = state.doc.date || "";
    document.getElementById("doc-number").value = currentNumber();
    document.getElementById("doc-valid").value = state.doc.validUntil || "";
    document.getElementById("doc-note").value = state.doc.note || "";
    document.getElementById("vat-mode").value = state.doc.vatMode;
    document.getElementById("valid-row").hidden = state.doc.type !== "quote";
    document.getElementById("hourly").value = state.quote.hourly;
    document.getElementById("buffer").value = state.quote.bufferPct;
    document.getElementById("margin").value = state.quote.marginPct;
    document.getElementById("fee").value = state.quote.feePct;
    const month = document.getElementById("ledger-month");
    if (!month.options.length) {
      for (let i = 1; i <= 12; i += 1) {
        const option = document.createElement("option");
        option.value = String(i);
        option.textContent = i + "월";
        month.append(option);
      }
    }
    document.getElementById("ledger-year").value = String(state.ledger.year);
    month.value = String(state.ledger.month);
  }

  function renderItems() {
    const box = document.getElementById("items");
    box.replaceChildren();
    state.items.forEach((item, index) => {
      const row = el("div", "item-row");
      ["name", "spec", "qty", "price", "note"].forEach((field) => {
        const input = document.createElement("input");
        input.value = item[field];
        input.autocomplete = "off";
        if (field === "qty" || field === "price") input.inputMode = "decimal";
        input.setAttribute("aria-label", field);
        input.addEventListener("input", () => {
          state.items[index][field] = input.value;
          save();
          updatePreview();
        });
        row.append(input);
      });
      const remove = el("button", "icon-btn danger", "삭제");
      remove.type = "button";
      remove.addEventListener("click", () => {
        state.items.splice(index, 1);
        if (!state.items.length) state.items.push(blankItem());
        save();
        renderItems();
        updatePreview();
      });
      row.append(remove);
      box.append(row);
    });
  }

  function renderTasks() {
    const box = document.getElementById("tasks");
    box.replaceChildren();
    state.quote.tasks.forEach((task, index) => {
      const row = el("div", "task-row");
      const name = document.createElement("input");
      name.value = task.name;
      name.placeholder = "작업 이름";
      name.autocomplete = "off";
      name.addEventListener("input", () => {
        state.quote.tasks[index].name = name.value;
        save();
        updateQuote();
      });
      const hours = document.createElement("input");
      hours.value = task.hours;
      hours.placeholder = "시간";
      hours.inputMode = "decimal";
      hours.autocomplete = "off";
      hours.addEventListener("input", () => {
        state.quote.tasks[index].hours = hours.value;
        save();
        updateQuote();
      });
      const remove = el("button", "icon-btn danger", "삭제");
      remove.type = "button";
      remove.addEventListener("click", () => {
        state.quote.tasks.splice(index, 1);
        if (!state.quote.tasks.length) state.quote.tasks.push(blankTask());
        save();
        renderTasks();
        updateQuote();
      });
      row.append(name, hours, remove);
      box.append(row);
    });
  }

  function visibleItems() {
    return state.items.filter((item) => item.name || item.spec || item.qty || item.price || item.note);
  }

  function updatePreview() {
    const summary = DocCalc.summarize(state.items, state.doc.vatMode);
    document.getElementById("total-supply").textContent = DocCalc.formatWon(summary.supply);
    document.getElementById("total-vat").textContent = DocCalc.formatWon(summary.vat);
    document.getElementById("total-grand").textContent = DocCalc.formatWon(summary.total);

    const sheet = document.getElementById("sheet");
    sheet.replaceChildren();
    const title = el("h1", state.doc.type === "statement" ? "compact" : "", TITLES[state.doc.type]);
    const sub = el("p", "subline", SUBS[state.doc.type]);
    const meta = el("div", "meta");
    meta.append(el("span", null, "문서번호 " + currentNumber()), el("span", null, formatDate(state.doc.date)));
    sheet.append(title, sub, meta);

    const parties = el("div", "parties");
    parties.append(
      party("공급받는 자", [
        ["상호", state.buyer.name],
        ["담당", state.buyer.contact],
        ["연락처", state.buyer.phone],
        ["이메일", state.buyer.email],
      ]),
      party("공급자", [
        ["상호", state.seller.name],
        ["대표", state.seller.owner],
        ["등록번호", state.seller.bizNo],
        ["주소", state.seller.address],
        ["업태/종목", [state.seller.bizType, state.seller.bizItem].filter(Boolean).join(" / ")],
        ["전화", state.seller.phone],
        ["이메일", state.seller.email],
        ["계좌", state.seller.bank],
      ])
    );
    sheet.append(parties);

    const amount = el("div", "amount-bar");
    const words = el("div", null, "일금 " + DocCalc.koreanWon(summary.total) + "정");
    const figure = el("strong", null, "₩ " + DocCalc.formatWon(summary.total));
    amount.append(words, figure);
    sheet.append(amount);

    const table = el("table", "items");
    const head = el("tr");
    const amountLabel = state.doc.vatMode === "inclusive" ? "금액" : "공급가액";
    ["품명", "규격", "수량", "단가", amountLabel, "비고"].forEach((label) => head.append(el("th", null, label)));
    const thead = el("thead");
    thead.append(head);
    const tbody = el("tbody");
    const rows = visibleItems();
    const source = rows.length ? rows : [blankItem()];
    source.forEach((item) => {
      const tr = el("tr");
      const qty = item.qty === "" ? "" : String(item.qty);
      const price = item.price === "" ? "" : DocCalc.formatWon(item.price);
      const line = item.qty === "" || item.price === "" ? "" : DocCalc.formatWon(DocCalc.lineAmount(item.qty, item.price));
      [item.name, item.spec].forEach((value) => tr.append(el("td", null, value || "")));
      tr.append(el("td", "center", qty));
      tr.append(el("td", "num", price));
      tr.append(el("td", "num", line));
      tr.append(el("td", null, item.note || ""));
      tbody.append(tr);
    });
    const tfoot = el("tfoot");
    const foot = el("tr");
    [
      ["공급가액", summary.supply],
      ["세액", summary.vat],
      ["합계", summary.total],
    ].forEach((pair) => {
      const cell = el("td", "num", pair[0] + "  " + DocCalc.formatWon(pair[1]));
      cell.colSpan = 2;
      foot.append(cell);
    });
    tfoot.append(foot);
    table.append(thead, tbody, tfoot);
    sheet.append(table);

    const modeLabel = { exclusive: "부가세 별도", inclusive: "부가세 포함", exempt: "면세" }[state.doc.vatMode];
    const noteText = [state.doc.note, state.doc.type === "quote" && state.doc.validUntil ? "유효기간 " + formatDate(state.doc.validUntil) : "", modeLabel]
      .filter(Boolean)
      .join("\n");
    const note = el("div", "note-block");
    note.append(el("b", null, "비고"));
    note.append(document.createTextNode(noteText));
    sheet.append(note);
  }

  function party(title, rows) {
    const wrap = el("section", "party");
    wrap.append(el("h2", "party-title", title));
    const table = el("table", "kv");
    rows.forEach((row) => {
      const tr = el("tr");
      tr.append(el("th", null, row[0]), el("td", null, row[1] || ""));
      table.append(tr);
    });
    wrap.append(table);
    return wrap;
  }

  function updateQuote() {
    const quote = DocCalc.projectQuote({
      tasks: state.quote.tasks,
      hourly: state.quote.hourly,
      bufferPct: state.quote.bufferPct,
      marginPct: state.quote.marginPct,
      feePct: state.quote.feePct,
    });
    document.getElementById("quote-suggested").textContent = quote.suggested == null ? "—" : DocCalc.formatWon(quote.suggested) + "원";
    const dl = document.getElementById("quote-lines");
    dl.replaceChildren();
    const rows = [
      ["작업 시간", quote.hours + "시간"],
      ["인건비", DocCalc.formatWon(quote.labor) + "원"],
      ["수정 여유 반영", DocCalc.formatWon(quote.buffered) + "원"],
      ["마진 반영", DocCalc.formatWon(quote.margined) + "원"],
    ];
    rows.forEach((row) => {
      dl.append(el("dt", null, row[0]), el("dd", null, row[1]));
    });
    document.getElementById("quote-msg").textContent = quote.error || "";
    document.getElementById("quote-to-doc").disabled = quote.suggested == null || quote.hours <= 0;
  }

  function quoteToDoc() {
    const split = DocCalc.distributeQuoteLines({
      tasks: state.quote.tasks,
      hourly: state.quote.hourly,
      bufferPct: state.quote.bufferPct,
      marginPct: state.quote.marginPct,
      feePct: state.quote.feePct,
    });
    if (!split.lines.length) return;
    state.doc.type = "quote";
    state.doc.vatMode = "exclusive";
    state.items = split.lines.map((line) => ({
      name: line.name,
      spec: line.hours + "시간",
      qty: "1",
      price: String(line.price),
      note: "",
    }));
    save();
    hydrate();
    setView("doc");
  }

  function monthPrefix() {
    return state.ledger.year + "-" + String(state.ledger.month).padStart(2, "0");
  }

  function monthEntries() {
    const prefix = monthPrefix();
    return state.ledger.entries.filter((entry) => String(entry.date || "").startsWith(prefix));
  }

  function renderLedger() {
    const entries = monthEntries();
    const totals = DocCalc.ledgerTotals(entries);
    document.getElementById("ledger-sales").textContent = DocCalc.formatWon(totals.salesTotal);
    document.getElementById("ledger-costs").textContent = DocCalc.formatWon(totals.costTotal);
    document.getElementById("ledger-net").textContent = DocCalc.formatWon(totals.net);
    document.getElementById("ledger-vat").textContent = DocCalc.formatWon(totals.vatGap);
    document.getElementById("ledger-count").value = entries.length + "건";
    document.getElementById("ledger-empty").hidden = entries.length > 0;
    const body = document.getElementById("ledger-rows");
    body.replaceChildren();
    entries.forEach((entry) => {
      const tr = document.createElement("tr");
      tr.append(cellInput(entry, "date", "date"));
      const kind = document.createElement("select");
      [["in", "매출"], ["out", "비용"]].forEach((pair) => {
        const option = document.createElement("option");
        option.value = pair[0];
        option.textContent = pair[1];
        kind.append(option);
      });
      kind.value = entry.kind;
      kind.addEventListener("change", () => {
        entry.kind = kind.value;
        save();
        renderLedger();
      });
      const kindCell = document.createElement("td");
      kindCell.append(kind);
      tr.append(kindCell);
      tr.append(cellInput(entry, "party", "text"));
      tr.append(cellInput(entry, "memo", "text"));
      tr.append(cellInput(entry, "supply", "number"));
      const taxed = document.createElement("select");
      [["yes", "과세"], ["no", "면세"]].forEach((pair) => {
        const option = document.createElement("option");
        option.value = pair[0];
        option.textContent = pair[1];
        taxed.append(option);
      });
      taxed.value = entry.taxed === false ? "no" : "yes";
      taxed.addEventListener("change", () => {
        entry.taxed = taxed.value === "yes";
        save();
        renderLedger();
      });
      const taxedCell = document.createElement("td");
      taxedCell.append(taxed);
      tr.append(taxedCell);
      const vat = entry.taxed === false ? 0 : DocCalc.won(DocCalc.won(entry.supply) * 0.1);
      const total = DocCalc.won(entry.supply) + vat;
      tr.append(el("td", null, DocCalc.formatWon(vat)));
      tr.append(el("td", null, DocCalc.formatWon(total)));
      const remove = el("button", "icon-btn danger", "삭제");
      remove.type = "button";
      remove.addEventListener("click", () => {
        state.ledger.entries = state.ledger.entries.filter((item) => item.id !== entry.id);
        save();
        renderLedger();
      });
      const cell = document.createElement("td");
      cell.append(remove);
      tr.append(cell);
      body.append(tr);
    });
  }

  function cellInput(entry, field, kind) {
    const td = document.createElement("td");
    const input = document.createElement("input");
    if (kind === "date") input.type = "date";
    if (kind === "number") input.inputMode = "decimal";
    input.value = kind === "number" ? String(entry[field] ?? "") : entry[field] || "";
    input.addEventListener("input", () => {
      if (kind === "number") entry[field] = DocCalc.won(input.value);
      else entry[field] = input.value;
      save();
      if (field === "date" && !String(entry.date).startsWith(monthPrefix())) {
        renderLedger();
        return;
      }
      if (field === "supply") {
        const row = input.closest("tr");
        const vat = entry.taxed === false ? 0 : DocCalc.won(DocCalc.won(entry.supply) * 0.1);
        const total = DocCalc.won(entry.supply) + vat;
        row.children[6].textContent = DocCalc.formatWon(vat);
        row.children[7].textContent = DocCalc.formatWon(total);
      }
      const entries = monthEntries();
      const totals = DocCalc.ledgerTotals(entries);
      document.getElementById("ledger-sales").textContent = DocCalc.formatWon(totals.salesTotal);
      document.getElementById("ledger-costs").textContent = DocCalc.formatWon(totals.costTotal);
      document.getElementById("ledger-net").textContent = DocCalc.formatWon(totals.net);
      document.getElementById("ledger-vat").textContent = DocCalc.formatWon(totals.vatGap);
    });
    td.append(input);
    return td;
  }

  function addEntry() {
    const supply = DocCalc.won(document.getElementById("entry-supply").value);
    const party = document.getElementById("entry-party").value.trim();
    const memo = document.getElementById("entry-memo").value.trim();
    if (!supply && !party && !memo) return;
    const date = document.getElementById("entry-date").value || monthPrefix() + "-01";
    state.ledger.entries.push({
      id: Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
      date,
      kind: document.getElementById("entry-kind").value,
      party,
      memo,
      supply,
      taxed: document.getElementById("entry-taxed").value === "yes",
    });
    const match = /^(\d{4})-(\d{2})-/.exec(date);
    if (match) {
      state.ledger.year = Number(match[1]);
      state.ledger.month = Number(match[2]);
    }
    document.getElementById("entry-supply").value = "";
    document.getElementById("entry-party").value = "";
    document.getElementById("entry-memo").value = "";
    save();
    fillStatic();
    renderLedger();
  }

  function applyPreset() {
    const preset = PRESETS[document.getElementById("preset").value];
    if (!preset) return;
    if (!state.seller.bizType) state.seller.bizType = preset.bizType;
    if (!state.seller.bizItem) state.seller.bizItem = preset.bizItem;
    state.items = preset.items.map((item) => Object.assign(blankItem(), item));
    if (!state.doc.note) state.doc.note = preset.note;
    save();
    hydrate();
  }

  function fillExample() {
    const later = new Date();
    later.setDate(later.getDate() + 14);
    state.seller = {
      name: "한결공방",
      owner: "김한결",
      bizNo: "123-45-67890",
      address: "서울특별시 종로구 청계천로 1",
      bizType: "제조",
      bizItem: "수공예",
      phone: "010-0000-0000",
      email: "studio@example.com",
      bank: "국민 000000-00-000000 김한결",
    };
    state.buyer = { name: "북촌카페", contact: "이서준", phone: "02-000-0000", email: "cafe@example.com" };
    state.doc.type = "quote";
    state.doc.date = todayISO();
    state.doc.validUntil = todayISO(later);
    state.doc.vatMode = "exclusive";
    state.doc.numberOverride = "";
    state.doc.note = "예시 데이터입니다. 실제 거래 전에 상호와 계좌를 바꾸세요.";
    state.items = PRESETS.studio.items.map((item) => Object.assign(blankItem(), item));
    save();
    hydrate();
    setView("doc");
  }

  function exportBackup() {
    const blob = new Blob([JSON.stringify(state, null, 2)], { type: "application/json" });
    const link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.download = "문서함-백업.json";
    link.click();
    setTimeout(() => URL.revokeObjectURL(link.href), 1000);
  }

  function importBackup(event) {
    const file = event.target.files && event.target.files[0];
    event.target.value = "";
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      try {
        state = sanitize(JSON.parse(String(reader.result || "")));
        save();
        hydrate();
      } catch (error) {
        window.alert("이 파일은 문서함 백업이 아닙니다.");
      }
    };
    reader.readAsText(file);
  }

  function hydrate() {
    fillStatic();
    renderItems();
    renderTasks();
    renderLedger();
    updateQuote();
    updatePreview();
  }

  load();
  bindStatic();
  hydrate();
  const dateInput = document.getElementById("entry-date");
  if (dateInput && !dateInput.value) dateInput.value = todayISO();
})();
