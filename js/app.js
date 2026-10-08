// OnboardPilot AI — DOM glue. Requires window.OnboardPilot (js/logic.js).
(function () {
  "use strict";
  const OP = window.OnboardPilot;

  // ---- persistence ----
  function load() {
    try {
      const raw = localStorage.getItem(OP.STORAGE_KEY);
      if (raw) return OP.deserialize(raw);
    } catch (e) { /* fall through */ }
    return OP.blankState();
  }
  function save() {
    try { localStorage.setItem(OP.STORAGE_KEY, OP.serialize(state)); } catch (e) { /* ignore */ }
  }
  let state = load();
  let selectedHireId = null;
  let dashQuery = "";
  let dashSort = "name";

  // ---- helpers ----
  function el(id) { return document.getElementById(id); }
  function esc(s) {
    return String(s == null ? "" : s).replace(/[&<>"']/g, c =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  }
  function phaseBar(hire, phase) {
    const c = OP.countsFor(hire, phase);
    return `<div class="phase-head"><strong>${OP.PHASE_LABELS[phase]}</strong>
      <span class="small muted">${c.done}/${c.total} · ${OP.progressFor(hire, phase)}%</span></div>`;
  }
  function buddyOptions(selected) {
    return `<option value="">— none —</option>` + state.buddies.map(b =>
      `<option value="${b.id}"${b.id === selected ? " selected" : ""}>${esc(b.name)}${b.role ? " (" + esc(b.role) + ")" : ""}</option>`).join("");
  }
  function roleOptions(selected) {
    return OP.allRoles(state).map(r =>
      `<option value="${esc(r)}"${r === selected ? " selected" : ""}>${esc(r)}</option>`).join("");
  }

  // ---- navigation ----
  document.querySelectorAll(".nav button").forEach(btn => {
    btn.addEventListener("click", () => {
      document.querySelectorAll(".nav button").forEach(b => b.classList.remove("active"));
      document.querySelectorAll(".view").forEach(v => v.classList.remove("active"));
      btn.classList.add("active");
      el("view-" + btn.dataset.view).classList.add("active");
      render();
    });
  });

  // ---- views ----
  function renderDashboard() {
    const v = el("view-dashboard");
    const all = OP.dashboard(state);
    const rows = OP.sortHires(OP.searchHires(all, dashQuery), dashSort, dashSort === "progress" ? "desc" : "asc");
    const archived = OP.archivedHires(state);
    const toolbar = `<div class="card"><h2>Dashboard</h2>
      <div class="form-row">
        <input id="dashSearch" placeholder="Search hires by name or role…" value="${esc(dashQuery)}" style="min-width:220px">
        <label class="small">Sort by
          <select id="dashSort" style="flex:none">
            ${[["name", "Name"], ["startDate", "Start date"], ["progress", "Progress"], ["overdue", "Overdue first"]].map(o =>
              `<option value="${o[0]}"${dashSort === o[0] ? " selected" : ""}>${o[1]}</option>`).join("")}
          </select>
        </label>
        <button class="btn ghost" id="csvBtn">Export CSV</button>
      </div>
      <p class="muted small">${all.length} active hire(s)${dashQuery ? ` · filtered to ${rows.length}` : ""}.</p></div>`;
    if (!rows.length && !archived.length) {
      v.innerHTML = toolbar + `<div class="card"><p class="muted">${dashQuery ? "No hires match that search." : "No hires yet. Add your first new hire to generate their onboarding checklist."}</p></div>`;
      wireDashToolbar();
      return;
    }
    const cards = rows.map((r, i) => {
      const badges = (r.overdue ? `<span class="badge overdue">Day-1 items overdue</span>` : "") +
        (r.progress.overall === 100 ? `<span class="badge done">✓ Complete</span>` : "");
      const initial = esc((r.name || "?").trim().charAt(0).toUpperCase());
      const hire = OP.getHire(state, r.id);
      const start = hire ? OP.startLabel(hire) : "";
      return `<div class="card hire-card" data-hire="${r.id}" style="animation-delay:${Math.min(i * 50, 300)}ms">
        <div class="bp-stub"><div class="bp-avatar">${initial}</div><div class="bp-name">${esc(r.name)}</div></div>
        <div class="bp-body">
          <h3>${esc(r.role)}</h3>
          <div class="small muted">started ${esc(r.startDate || "—")} · ${esc(start)} · buddy: ${esc(r.buddy || "—")}</div>
          <div class="bar"><div style="width:${r.progress.overall}%"></div></div>
          <div class="bp-status"><span class="small">Overall <strong>${r.progress.overall}%</strong></span> ${badges}</div>
        </div>
      </div>`;
    }).join("");
    v.innerHTML = toolbar + `<div class="grid">${cards}</div>` +
      (archived.length ? `<div class="card"><h3>Archived (${archived.length})</h3>` +
        archived.map(h => `<div class="list-item"><span><strong>${esc(h.name)}</strong> <span class="muted small">${esc(h.role)}</span></span>
          <button class="btn ghost" data-unarchive="${h.id}">Restore</button></div>`).join("") + `</div>` : "") +
      `<div id="hireDetail"></div>`;
    wireDashToolbar();
    v.querySelectorAll(".hire-card").forEach(c =>
      c.addEventListener("click", () => { selectedHireId = c.dataset.hire; renderHireDetail(); }));
    v.querySelectorAll("[data-unarchive]").forEach(b =>
      b.addEventListener("click", (e) => { e.stopPropagation(); OP.unarchiveHire(state, b.dataset.unarchive); save(); renderDashboard(); }));
    if (selectedHireId) renderHireDetail();
  }

  function wireDashToolbar() {
    const s = el("dashSearch");
    if (s) s.addEventListener("input", () => { dashQuery = s.value; clearTimeout(s._t); s._t = setTimeout(renderDashboard, 220); });
    const so = el("dashSort");
    if (so) so.addEventListener("change", () => { dashSort = so.value; renderDashboard(); });
    const cb = el("csvBtn");
    if (cb) cb.addEventListener("click", () => {
      const rows = OP.sortHires(OP.searchHires(OP.dashboard(state), dashQuery), dashSort, dashSort === "progress" ? "desc" : "asc");
      const blob = new Blob([OP.hiresToCSV(rows)], { type: "text/csv" });
      const a = document.createElement("a");
      a.href = URL.createObjectURL(blob); a.download = "onboardpilot-hires.csv"; a.click();
      setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 500);
    });
  }

  function renderHireDetail() {
    const d = el("hireDetail");
    if (!d) return;
    const hire = OP.getHire(state, selectedHireId);
    if (!hire) { d.innerHTML = ""; return; }
    const overall = OP.progressFor ? OP.progressFor(hire) : null;
    const phases = OP.PHASES.map(ph => {
      const c = OP.countsFor(hire, ph);
      return { ph, label: OP.PHASE_LABELS[ph], done: c.done, total: c.total, pct: OP.progressFor(hire, ph) };
    });
    const firstOpen = phases.findIndex(p => p.pct < 100);
    const stations = phases.map((p, i) =>
      `<div class="station ${p.pct === 100 ? "done" : i === firstOpen ? "now" : ""}">
        <span class="pin" aria-hidden="true"></span>
        <div class="s-label">${esc(p.label)}</div>
        <div class="s-count">${p.done}/${p.total}</div>
      </div>`).join("");
    const initial = esc((hire.name || "?").trim().charAt(0).toUpperCase());
    let html = `<div class="card">
      <div class="detail-head">
        <div class="detail-avatar" aria-hidden="true">${initial}</div>
        <div><h2>${esc(hire.name)}</h2><div class="small muted">${esc(hire.role)} · started ${esc(hire.startDate || "—")}</div></div>
        ${overall !== null ? `<div class="detail-progress"><div class="small muted">Journey progress · <strong>${overall}%</strong></div><div class="bar"><div style="width:${overall}%"></div></div></div>` : ""}
      </div>
      <div class="journey" aria-label="Onboarding journey">${stations}</div>
      <div class="form-row">
        <label class="small">Buddy:
          <select id="detailBuddy">${buddyOptions(hire.buddyId)}</select>
        </label>
        <button class="btn ghost" id="welcomeBtn">Draft welcome message</button>
        <button class="btn ghost" id="archiveHireBtn">Archive hire</button>
        <button class="btn danger" id="deleteHireBtn">Remove hire</button>
      </div>
      <div id="welcomeOut"></div>`;
    let hasDoc = false;
    for (const ph of OP.PHASES) {
      html += phaseBar(hire, ph);
      const items = hire.checklist.filter(t => t.phase === ph);
      for (const t of items) {
        if (t.doc) hasDoc = true;
        html += `<div class="task${t.done ? " done" : ""}">
          <input type="checkbox" data-task="${t.id}"${t.done ? " checked" : ""}>
          <div><div class="t-title">${esc(t.title)}</div>
          <div class="meta">${esc(t.category)} · ${esc(t.owner)}${t.guidance ? ` · <em>${esc(t.guidance)}</em>` : ""}</div></div></div>`;
      }
    }
    if (hasDoc) html = `<div class="doc-note"><strong>Document checklist note:</strong> items marked above are generic guidance only — not legal or tax advice. ${esc(OP.GENERIC_NOTE)}</div>` + html;
    html += `</div>`;
    d.innerHTML = html;
    d.querySelectorAll("input[type=checkbox]").forEach(cb =>
      cb.addEventListener("change", () => {
        OP.setItemDone(state, hire.id, cb.dataset.task, cb.checked);
        save(); renderDashboard(); renderHireDetail();
      }));
    el("detailBuddy").addEventListener("change", e => {
      OP.assignBuddy(state, hire.id, e.target.value || null);
      save(); renderDashboard();
    });
    el("deleteHireBtn").addEventListener("click", () => {
      if (confirm("Remove " + hire.name + "?")) {
        OP.removeHire(state, hire.id); selectedHireId = null; save(); render();
      }
    });
    el("archiveHireBtn").addEventListener("click", () => {
      OP.archiveHire(state, hire.id); selectedHireId = null; save(); renderDashboard();
    });
    el("welcomeBtn").addEventListener("click", async () => {
      const out = el("welcomeOut");
      out.innerHTML = `<div class="welcome-box"><span class="muted">Drafting…</span></div>`;
      let result;
      if (state.settings.openaiKey) {
        try {
          result = await OP.openaiWelcomeMessage(fetch, state.settings.openaiKey, hire, OP.getBuddyName(state, hire.id));
        } catch (e) { result = OP.draftWelcomeMessage(state, hire.id); }
      } else {
        result = OP.draftWelcomeMessage(state, hire.id);
      }
      out.innerHTML = `<div class="welcome-box"><strong>${result.source === "ai" ? "AI welcome" : "Template welcome"}:</strong><br>${esc(result.message)}</div>`;
    });
  }

  function renderHires() {
    el("view-hires").innerHTML = `<div class="card"><h2>Add a new hire</h2>
      <div class="form-row">
        <input id="hireName" placeholder="Full name">
        <select id="hireRole">${roleOptions()}</select>
        <input id="hireStart" type="date">
        <select id="hireBuddy">${buddyOptions(null)}</select>
        <button class="btn" id="addHireBtn">Create checklist</button>
      </div>
      <p class="muted small">A checklist is generated from the selected role template (Day 1 / Week 1 / Day 30).</p>
    </div>`;
    el("addHireBtn").addEventListener("click", () => {
      const name = el("hireName").value.trim();
      const hire = OP.addHire(state, name, el("hireRole").value, el("hireStart").value, el("hireBuddy").value || null);
      if (!hire) { alert("Please enter a name and choose a role."); return; }
      save(); selectedHireId = hire.id; render();
      document.querySelector('[data-view="dashboard"]').click();
    });
  }

  function renderBuddies() {
    const items = state.buddies.map(b =>
      `<div class="list-item"><span><strong>${esc(b.name)}</strong> <span class="muted small">${esc(b.role)}</span></span>
       <button class="btn ghost" data-del-buddy="${b.id}">Remove</button></div>`).join("") ||
      `<p class="muted">No buddies yet — add experienced team members who can mentor new hires.</p>`;
    el("view-buddies").innerHTML = `<div class="card"><h2>Buddies / mentors</h2>
      <div class="form-row">
        <input id="buddyName" placeholder="Buddy name">
        <input id="buddyRole" placeholder="Their role (optional)">
        <button class="btn" id="addBuddyBtn">Add buddy</button>
      </div>${items}</div>`;
    el("addBuddyBtn").addEventListener("click", () => {
      const n = el("buddyName").value.trim();
      if (!n) { alert("Enter a name."); return; }
      OP.addBuddy(state, n, el("buddyRole").value.trim());
      save(); render();
    });
    el("view-buddies").querySelectorAll("[data-del-buddy]").forEach(btn =>
      btn.addEventListener("click", () => { OP.removeBuddy(state, btn.dataset.delBuddy); save(); render(); }));
  }

  function renderRoles() {
    const builtIn = Object.keys(OP.ROLE_TEMPLATES).map(r =>
      `<div class="list-item"><span><strong>${esc(r)}</strong> <span class="badge">built-in</span></span>
       <span class="small muted">${OP.PHASES.map(p => (OP.ROLE_TEMPLATES[r][p] || []).length).join(" / ")} tasks (Day 1 / Week 1 / Day 30)</span></div>`).join("");
    const custom = Object.keys(state.customRoles).map(r =>
      `<div class="list-item"><span><strong>${esc(r)}</strong> <span class="badge">custom</span></span>
       <button class="btn danger" data-del-role="${esc(r)}">Delete</button></div>`).join("") ||
      `<p class="muted">No custom roles yet.</p>`;
    const phaseSelects = OP.PHASES.map(p =>
      `<label class="small">${OP.PHASE_LABELS[p]}<br><textarea id="cr-${p}" rows="4" cols="34" placeholder="One task per line"></textarea></label>`).join("");
    el("view-roles").innerHTML = `<div class="card"><h2>Role templates</h2>${builtIn}</div>
      <div class="card"><h2>Custom roles</h2>${custom}
      <h3>Create a custom role</h3>
      <div class="form-row"><input id="crName" placeholder="Role name"></div>
      <div class="form-row">${phaseSelects}</div>
      <button class="btn" id="createRoleBtn">Create role</button>
      <p class="muted small">Enter one task per line in each phase box. Tasks default to Training / Manager.</p></div>`;
    el("createRoleBtn").addEventListener("click", () => {
      const name = el("crName").value.trim();
      if (!name) { alert("Enter a role name."); return; }
      const tasks = {};
      for (const p of OP.PHASES) {
        tasks[p] = el("cr-" + p).value.split("\n").map(s => s.trim()).filter(Boolean).map(title => ({ title }));
      }
      OP.createCustomRole(state, name, tasks);
      save(); render();
    });
    el("view-roles").querySelectorAll("[data-del-role]").forEach(btn =>
      btn.addEventListener("click", () => { OP.removeCustomRole(state, btn.dataset.delRole); save(); render(); }));
  }

  function renderSettings() {
    el("view-settings").innerHTML = `<div class="card"><h2>Settings</h2>
      <div class="form-row">
        <input id="openaiKey" type="password" placeholder="OpenAI API key (optional)" value="${esc(state.settings.openaiKey)}" style="min-width:320px">
        <button class="btn" id="saveKeyBtn">Save key</button>
        <button class="btn ghost" id="clearKeyBtn">Clear</button>
      </div>
      <p class="muted small">The key is stored only in this browser's localStorage. If set, "Draft welcome message" uses the OpenAI API; otherwise a local template is used. The app works fully without a key.</p>
    </div>
    <div class="card"><h2>Data</h2>
      <div class="form-row">
        <button class="btn ghost" id="exportBtn">Export data (JSON)</button>
        <button class="btn danger" id="wipeBtn">Erase all data</button>
      </div>
      <p class="muted small">All data stays local in this browser — nothing is sent anywhere except the optional OpenAI call.</p>
    </div>`;
    el("saveKeyBtn").addEventListener("click", () => {
      state.settings.openaiKey = el("openaiKey").value.trim(); save(); render();
    });
    el("clearKeyBtn").addEventListener("click", () => {
      state.settings.openaiKey = ""; save(); render();
    });
    el("exportBtn").addEventListener("click", () => {
      const blob = new Blob([OP.serialize(state)], { type: "application/json" });
      const a = document.createElement("a");
      a.href = URL.createObjectURL(blob); a.download = "onboardpilot-backup.json"; a.click();
    });
    el("wipeBtn").addEventListener("click", () => {
      if (confirm("Erase all OnboardPilot data?")) {
        state = OP.blankState(); selectedHireId = null; save(); render();
      }
    });
  }

  function render() {
    renderDashboard(); renderHires(); renderBuddies(); renderRoles(); renderSettings();
  }
  render();
})();
