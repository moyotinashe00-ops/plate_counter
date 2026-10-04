require('dotenv').config();
const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { z } = require('zod');
const db = require('./db');

const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-change-me';
const app = express();
app.use(cors({ origin: process.env.CORS_ORIGIN || '*' }));
app.use(express.json({ limit: '100kb' }));

// ---------- helpers ----------
const wrap = (fn) => (req, res) => {
  try { const r = fn(req, res); if (r !== undefined) res.json(r); }
  catch (e) {
    if (e instanceof z.ZodError) return res.status(400).json({ error: e.issues[0]?.message || 'Invalid input' });
    if (e.status) return res.status(e.status).json({ error: e.message });
    console.error(e); res.status(500).json({ error: 'Something went wrong' });
  }
};
const fail = (status, message) => { const e = new Error(message); e.status = status; throw e; };
const publicUser = (u) => ({ id: u.id, email: u.email, display_name: u.display_name, role: u.role, created_at: u.created_at });
const sign = (u) => jwt.sign({ sub: u.id }, JWT_SECRET, { expiresIn: '30d' });

function auth(req, res, next) {
  const h = req.headers.authorization || '';
  const token = h.startsWith('Bearer ') ? h.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'Unauthorized' });
  try {
    const { sub } = jwt.verify(token, JWT_SECRET);
    const u = db.prepare('SELECT * FROM users WHERE id = ?').get(sub);
    if (!u) return res.status(401).json({ error: 'Unauthorized' });
    req.user = u; next();
  } catch { res.status(401).json({ error: 'Unauthorized' }); }
}
const chefOnly = (req, res, next) =>
  req.user.role === 'chef' ? next() : res.status(403).json({ error: 'Only the chef can do this.' });

function range(q) {
  // ?from=YYYY-MM-DD&to=YYYY-MM-DD (inclusive) – defaults to today (UTC)
  const today = new Date().toISOString().slice(0, 10);
  const from = new Date(`${q.from || today}T00:00:00Z`);
  const to = new Date(`${q.to || q.from || today}T00:00:00Z`);
  to.setUTCDate(to.getUTCDate() + 1);
  return [from.toISOString(), to.toISOString()];
}
const bool = (r) => r && Object.fromEntries(Object.entries(r).map(([k, v]) =>
  [k, ['active', 'voided', 'allow_credit'].includes(k) ? !!v : v]));

// ---------- auth ----------
app.post('/auth/signup', wrap((req) => {
  const b = z.object({
    email: z.string().trim().email('Enter a valid email').max(255),
    password: z.string().min(6, 'Password must be at least 6 characters').max(100),
    display_name: z.string().trim().min(1, 'Enter your name').max(60),
  }).parse(req.body);
  if (db.prepare('SELECT 1 FROM users WHERE email = ?').get(b.email.toLowerCase())) fail(409, 'Email already registered');
  const first = db.prepare('SELECT COUNT(*) c FROM users').get().c === 0;
  const info = db.prepare('INSERT INTO users (email, password_hash, display_name, role) VALUES (?,?,?,?)')
    .run(b.email.toLowerCase(), bcrypt.hashSync(b.password, 10), b.display_name, first ? 'chef' : 'cashier');
  const u = db.prepare('SELECT * FROM users WHERE id = ?').get(info.lastInsertRowid);
  return { token: sign(u), user: publicUser(u) };
}));

app.post('/auth/login', wrap((req) => {
  const b = z.object({ email: z.string().trim().email(), password: z.string().min(1) }).parse(req.body);
  const u = db.prepare('SELECT * FROM users WHERE email = ?').get(b.email.toLowerCase());
  if (!u || !bcrypt.compareSync(b.password, u.password_hash)) fail(401, 'Invalid email or password');
  return { token: sign(u), user: publicUser(u) };
}));

app.get('/me', auth, wrap((req) => publicUser(req.user)));

// ---------- settings ----------
app.get('/settings', auth, wrap(() => bool(db.prepare('SELECT * FROM settings WHERE id = 1').get())));
app.patch('/settings', auth, chefOnly, wrap((req) => {
  const b = z.object({ allow_credit: z.boolean().optional(), currency: z.string().max(5).optional() }).parse(req.body);
  if (b.allow_credit !== undefined) db.prepare('UPDATE settings SET allow_credit = ? WHERE id = 1').run(b.allow_credit ? 1 : 0);
  if (b.currency !== undefined) db.prepare('UPDATE settings SET currency = ? WHERE id = 1').run(b.currency);
  return bool(db.prepare('SELECT * FROM settings WHERE id = 1').get());
}));

// ---------- food items / stock ----------
const itemSchema = z.object({
  name: z.string().trim().min(1, 'Enter a name (max 60 characters)').max(60, 'Enter a name (max 60 characters)'),
  unit: z.string().trim().max(20).optional().default('piece'),
  price: z.number({ invalid_type_error: 'Enter a valid price' }).min(0, 'Enter a valid price').max(1e6),
  low_stock_threshold: z.number().int().min(0).max(100000).default(5),
});
app.get('/food-items', auth, wrap(() => db.prepare('SELECT * FROM food_items ORDER BY name').all().map(bool)));
app.post('/food-items', auth, chefOnly, wrap((req) => {
  const b = itemSchema.extend({ stock: z.number().int().min(0).max(100000).default(0) }).parse(req.body);
  const info = db.prepare(`INSERT INTO food_items (name, unit, price, stock, prepared_today, low_stock_threshold)
    VALUES (?,?,?,?,?,?)`).run(b.name, b.unit || 'piece', b.price, b.stock, b.stock, b.low_stock_threshold);
  return bool(db.prepare('SELECT * FROM food_items WHERE id = ?').get(info.lastInsertRowid));
}));
app.patch('/food-items/:id', auth, chefOnly, wrap((req) => {
  const b = itemSchema.extend({ active: z.boolean().default(true) }).parse(req.body);
  const r = db.prepare(`UPDATE food_items SET name=?, unit=?, price=?, low_stock_threshold=?, active=? WHERE id=?`)
    .run(b.name, b.unit || 'piece', b.price, b.low_stock_threshold, b.active ? 1 : 0, req.params.id);
  if (!r.changes) fail(404, 'Not found');
  return bool(db.prepare('SELECT * FROM food_items WHERE id = ?').get(req.params.id));
}));
app.post('/food-items/:id/adjust', auth, chefOnly, wrap((req) => {
  const b = z.object({
    delta: z.number().int().refine((v) => v !== 0, 'Enter a quantity'),
    reason: z.string().max(200).optional(),
    is_prep: z.boolean().default(false),
  }).parse(req.body);
  return db.transaction(() => {
    const it = db.prepare('SELECT * FROM food_items WHERE id = ?').get(req.params.id);
    if (!it) fail(404, 'Not found');
    if (it.stock + b.delta < 0) fail(400, 'Stock cannot go below zero');
    db.prepare('UPDATE food_items SET stock = stock + ?, prepared_today = prepared_today + ? WHERE id = ?')
      .run(b.delta, b.is_prep && b.delta > 0 ? b.delta : 0, it.id);
    db.prepare('INSERT INTO stock_movements (item_id, delta, reason, kind, user_id) VALUES (?,?,?,?,?)')
      .run(it.id, b.delta, b.reason || null, b.is_prep ? 'prep' : 'correction', req.user.id);
    return bool(db.prepare('SELECT * FROM food_items WHERE id = ?').get(it.id));
  })();
}));
// Start a new day: resets "prepared today" counters (stock carries over)
app.post('/food-items/reset-day', auth, chefOnly, wrap(() => {
  db.prepare('UPDATE food_items SET prepared_today = stock').run(); return { ok: true };
}));

// ---------- sales ----------
app.post('/sales', auth, wrap((req) => {
  const b = z.object({ item_id: z.number().int(), qty: z.number().int().min(1).max(1000), client_ref: z.string().max(64).optional() })
    .parse(req.body);
  return db.transaction(() => {
    if (b.client_ref) {
      const dup = db.prepare('SELECT * FROM sales WHERE client_ref = ?').get(b.client_ref);
      if (dup) return bool(dup); // idempotent retry
    }
    const it = db.prepare('SELECT * FROM food_items WHERE id = ? AND active = 1').get(b.item_id);
    if (!it) fail(404, 'Item not on the menu');
    if (it.stock < b.qty) fail(400, it.stock === 0 ? 'Sold out' : `Only ${it.stock} left`);
    db.prepare('UPDATE food_items SET stock = stock - ? WHERE id = ?').run(b.qty, it.id);
    const info = db.prepare(`INSERT INTO sales (item_id, item_name, qty, unit_price, total, cashier_id, client_ref)
      VALUES (?,?,?,?,?,?,?)`).run(it.id, it.name, b.qty, it.price, +(it.price * b.qty).toFixed(2), req.user.id, b.client_ref || null);
    return bool(db.prepare('SELECT * FROM sales WHERE id = ?').get(info.lastInsertRowid));
  })();
}));
app.get('/sales', auth, wrap((req) => {
  const [from, to] = range(req.query);
  const mine = req.user.role !== 'chef' || req.query.mine === '1';
  const rows = db.prepare(`SELECT s.*, u.display_name AS cashier_name FROM sales s JOIN users u ON u.id = s.cashier_id
    WHERE s.created_at >= ? AND s.created_at < ? ${mine ? 'AND s.cashier_id = ?' : ''}
    ${req.query.cashier_id && !mine ? 'AND s.cashier_id = ?' : ''}
    ORDER BY s.created_at DESC LIMIT 1000`)
    .all(...[from, to, ...(mine ? [req.user.id] : []), ...(req.query.cashier_id && !mine ? [req.query.cashier_id] : [])]);
  return rows.map(bool);
}));
app.post('/sales/:id/void', auth, chefOnly, wrap((req) => {
  const b = z.object({ reason: z.string().trim().min(1, 'Enter a reason').max(200) }).parse(req.body);
  return db.transaction(() => {
    const s = db.prepare('SELECT * FROM sales WHERE id = ?').get(req.params.id);
    if (!s) fail(404, 'Not found');
    if (s.voided) fail(400, 'Already voided');
    db.prepare('UPDATE sales SET voided = 1, void_reason = ? WHERE id = ?').run(b.reason, s.id);
    db.prepare('UPDATE food_items SET stock = stock + ? WHERE id = ?').run(s.qty, s.item_id);
    db.prepare('INSERT INTO stock_movements (item_id, delta, reason, kind, user_id) VALUES (?,?,?,?,?)')
      .run(s.item_id, s.qty, `Void sale #${s.id}: ${b.reason}`, 'void', req.user.id);
    return { ok: true };
  })();
}));

// ---------- change & credit ----------
const ledger = (table, open, closed, guard) => {
  const path = table === 'change_records' ? '/change' : '/credit';
  app.get(path, auth, wrap(() => db.prepare(`SELECT r.*, u.display_name AS created_by_name FROM ${table} r
    LEFT JOIN users u ON u.id = r.created_by ORDER BY r.status = '${open}' DESC, r.created_at DESC LIMIT 500`).all()));
  app.post(path, auth, wrap((req) => {
    if (guard) guard();
    const b = z.object({
      reference: z.string().trim().min(1, 'Enter a name or reference').max(80),
      amount: z.number({ invalid_type_error: 'Enter an amount' }).positive('Enter an amount').max(1e6),
    }).parse(req.body);
    const info = db.prepare(`INSERT INTO ${table} (reference, amount, created_by) VALUES (?,?,?)`).run(b.reference, b.amount, req.user.id);
    return db.prepare(`SELECT * FROM ${table} WHERE id = ?`).get(info.lastInsertRowid);
  }));
  app.post(`${path}/:id/resolve`, auth, wrap((req) => {
    const r = db.prepare(`UPDATE ${table} SET status = '${closed}', resolved_at = strftime('%Y-%m-%dT%H:%M:%fZ','now')
      WHERE id = ? AND status = '${open}'`).run(req.params.id);
    if (!r.changes) fail(404, 'Not found or already settled');
    return { ok: true };
  }));
};
ledger('change_records', 'pending', 'given');
ledger('credit_records', 'outstanding', 'repaid', () => {
  if (!db.prepare('SELECT allow_credit FROM settings WHERE id = 1').get().allow_credit) fail(403, 'Credit is turned off by the chef.');
});

// ---------- dashboard & reports (chef) ----------
function summary(from, to) {
  const sales = db.prepare(`SELECT s.*, u.display_name AS cashier_name FROM sales s JOIN users u ON u.id = s.cashier_id
    WHERE s.created_at >= ? AND s.created_at < ? ORDER BY s.created_at DESC`).all(from, to).map(bool);
  const live = sales.filter((s) => !s.voided);
  const byItem = {}; const byCashier = {};
  for (const s of live) {
    (byItem[s.item_name] ??= { item: s.item_name, qty: 0, revenue: 0 });
    byItem[s.item_name].qty += s.qty; byItem[s.item_name].revenue += s.total;
    (byCashier[s.cashier_name] ??= { cashier: s.cashier_name, transactions: 0, revenue: 0 });
    byCashier[s.cashier_name].transactions += 1; byCashier[s.cashier_name].revenue += s.total;
  }
  const sum = (sql, ...a) => db.prepare(sql).get(...a).t || 0;
  return {
    revenue: live.reduce((a, s) => a + s.total, 0),
    transactions: live.length,
    plates_sold: live.reduce((a, s) => a + s.qty, 0),
    by_item: Object.values(byItem).sort((a, b) => b.revenue - a.revenue),
    by_cashier: Object.values(byCashier).sort((a, b) => b.revenue - a.revenue),
    change_open: sum(`SELECT SUM(amount) t FROM change_records WHERE status='pending' AND created_at >= ? AND created_at < ?`, from, to),
    change_paid: sum(`SELECT SUM(amount) t FROM change_records WHERE status='given' AND created_at >= ? AND created_at < ?`, from, to),
    credit_issued: sum(`SELECT SUM(amount) t FROM credit_records WHERE created_at >= ? AND created_at < ?`, from, to),
    credit_repaid: sum(`SELECT SUM(amount) t FROM credit_records WHERE status='repaid' AND created_at >= ? AND created_at < ?`, from, to),
    sales,
  };
}
app.get('/dashboard', auth, chefOnly, wrap((req) => {
  const [from, to] = range(req.query);
  const s = summary(from, to);
  return {
    ...s,
    change_owed: db.prepare(`SELECT COALESCE(SUM(amount),0) t FROM change_records WHERE status='pending'`).get().t,
    credit_owed: db.prepare(`SELECT COALESCE(SUM(amount),0) t FROM credit_records WHERE status='outstanding'`).get().t,
    items: db.prepare('SELECT * FROM food_items ORDER BY name').all().map(bool),
  };
}));
app.get('/reports', auth, chefOnly, wrap((req) => { const [f, t] = range(req.query); return summary(f, t); }));
app.get('/reports.csv', auth, chefOnly, (req, res) => {
  const [f, t] = range(req.query);
  const rows = summary(f, t).sales;
  const esc = (v) => `"${String(v ?? '').replace(/"/g, '""')}"`;
  const csv = ['Date,Time,Item,Qty,Unit price,Total,Cashier,Voided,Void reason',
    ...rows.map((s) => [s.created_at.slice(0, 10), s.created_at.slice(11, 19), s.item_name, s.qty, s.unit_price, s.total,
      s.cashier_name, s.voided ? 'yes' : 'no', s.void_reason].map(esc).join(','))].join('\n');
  res.setHeader('Content-Type', 'text/csv');
  res.setHeader('Content-Disposition', `attachment; filename="platecount-${req.query.from || 'today'}.csv"`);
  res.send(csv);
});

// ---------- team ----------
app.get('/team', auth, chefOnly, wrap(() => db.prepare('SELECT * FROM users ORDER BY created_at').all().map(publicUser)));
app.post('/team/:id/role', auth, chefOnly, wrap((req) => {
  const { role } = z.object({ role: z.enum(['chef', 'cashier']) }).parse(req.body);
  if (role === 'cashier' && db.prepare(`SELECT COUNT(*) c FROM users WHERE role='chef'`).get().c <= 1 &&
      db.prepare('SELECT role FROM users WHERE id = ?').get(req.params.id)?.role === 'chef') fail(400, 'You need at least one chef.');
  const r = db.prepare('UPDATE users SET role = ? WHERE id = ?').run(role, req.params.id);
  if (!r.changes) fail(404, 'Not found');
  return { ok: true };
}));

app.get('/health', (_, res) => res.json({ ok: true }));
const port = process.env.PORT || 4000;
app.listen(port, () => console.log(`PlateCount API on http://localhost:${port}`));
