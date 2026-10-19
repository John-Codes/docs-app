# Branch Update Rules (applies ONLY to updates on NEW branches)

Do NOT refactor existing working code to comply with these rules. These rules apply exclusively to NEW branches and new changes.

1. **Keep each file under 100 lines of code** (counting real code lines). This is the hard limit per file.
2. **One feature per folder** — when adding a new feature, put it in its own folder under `lib/features/`.
3. **Follow SRP (Single Responsibility Principle)** — each file/class does one thing, with a clear purpose.
4. **Keep everything very simple** — prefer small, obvious solutions over clever ones.
5. **Use very clear names** — names must explain what is going on (files, classes, vars, fields).
6. **Additive & safe** — never break existing behavior; default new fields/values so old records/data remain compatible.
7. **End-to-end tests only** — always test against the real backend, real database, and real HTTP. Never mock or fake tests.
8. **Local test DB only** — never run tests, e2e, or review links against the production database. Locally use `scripts/local_stack.sh` (Docker Qdrant on `:6333`); CI uses a throwaway Qdrant container. The Qdrant Cloud cluster is production and is only touched by the deploy workflow's final prod check.

---

**Project note:** this app is FastAPI + Flutter web. "Database" means Qdrant: chunks, file bytes and document metadata live there. Never point tests at `QDRANT_URL` from `.env`; tests must use `QDRANT_TEST_URL` (default `http://localhost:6333`).
