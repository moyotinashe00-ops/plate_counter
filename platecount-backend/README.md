# PlateCount Backend (Node.js + Express + SQLite)

REST API for the PlateCount Flutter app: food stock, one-tap sales, change & credit tracking,
daily dashboard, reports (with CSV export) and team roles. The **first account created becomes the chef**;
everyone after joins as a cashier.

## Run
```bash
cp .env.example .env      # set a strong JWT_SECRET
npm install
npm start                 # http://localhost:4000
```
The SQLite database file is created automatically on first start.

## Endpoints (all JSON, `Authorization: Bearer <token>` except auth/health)
| Method | Path | Who | Notes |
|---|---|---|---|
| POST | /auth/signup | anyone | `{email,password,display_name}` → `{token,user}` |
| POST | /auth/login | anyone | `{email,password}` |
| GET | /me | any | current user |
| GET/PATCH | /settings | any / chef | `{allow_credit,currency}` |
| GET | /food-items | any | |
| POST | /food-items | chef | `{name,unit,price,stock,low_stock_threshold}` |
| PATCH | /food-items/:id | chef | `{name,unit,price,low_stock_threshold,active}` |
| POST | /food-items/:id/adjust | chef | `{delta,reason,is_prep}` |
| POST | /food-items/reset-day | chef | resets "prepared today" |
| POST | /sales | any | `{item_id,qty,client_ref}` (idempotent by client_ref) |
| GET | /sales?from=&to= | any | cashiers see their own |
| POST | /sales/:id/void | chef | `{reason}` restores stock |
| GET/POST | /change, /change/:id/resolve | any | money we owe customers |
| GET/POST | /credit, /credit/:id/resolve | any | money customers owe us |
| GET | /dashboard | chef | today's overview |
| GET | /reports?from=YYYY-MM-DD&to=YYYY-MM-DD | chef | |
| GET | /reports.csv?from=&to= | chef | CSV download |
| GET | /team, POST /team/:id/role | chef | `{role:"chef"|"cashier"}` |

## Deploy
Any Node host with a persistent disk (Render, Railway, Fly.io, a VPS). Set `JWT_SECRET` and `DB_FILE`.
