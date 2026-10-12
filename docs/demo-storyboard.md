# Demo video storyboard (about 3 minutes)

A script for recording the app on a phone or emulator against the seeded demo
data. Every step uses real screens and real API responses; nothing is staged.

**Before recording:** `npx prisma migrate deploy`, `npx prisma db seed`,
`npm run seed:history`, `npm run seed:images`, `npm run seed:work-orders`, then
start the API and the app (Thai by default; switch in Profile if needed).

| # | Time | Who | Show | Say (one line) |
|---|---|---|---|---|
| 1 | 0:00 | — | Login screen, demo account chips, language toggle | "One app for the warehouse and field technicians, in Thai or English." |
| 2 | 0:10 | Admin | Dashboard: KPIs, 7-day chart, field-jobs card | "Stock and job numbers come from server-side aggregates." |
| 3 | 0:25 | Admin | Jobs → New work order: title, site, checklist template, technician, required photos, materials | "A job snapshots its checklist, so later template edits can't change it." |
| 4 | 0:50 | Technician | Bell with a badge → inbox → open the new job | "The technician is notified, in the same transaction as the assignment." |
| 5 | 1:05 | Technician | Start work; turn on airplane mode; tick two items | "Offline, ticks are kept on the device and marked as waiting to sync." |
| 6 | 1:20 | Technician | Submit is disabled; airplane mode off; items sync | "Submit waits until the server has the checklist. An outdated edit is refused, never overwritten." |
| 7 | 1:40 | Technician | Add an after-work photo; submit | "Photos go straight to Cloudinary with a server-signed, size-limited upload." |
| 8 | 1:55 | Supervisor | Review queue → job → request changes with a reason | "The supervisor sends it back with a required reason." |
| 9 | 2:10 | Technician | Notification → reason banner → fix → resubmit | "History keeps both submissions." |
| 10 | 2:25 | Supervisor | Approve → activity timeline | "Approval is a state transition with reviewer and time, recorded once." |
| 11 | 2:40 | Warehouse | Scan a barcode into an issue linked to the job; admin confirms | "Stock changes only on confirm, can't go below zero, and links to the job." |
| 12 | 2:55 | — | GitHub Actions run (green) | "Every push runs unit, API and widget tests and builds the APK." |

Keep the phone in light mode, notifications muted, and record at 1080p.
