# Branch Update Rules (applies ONLY to updates on NEW branches)

Do NOT refactor existing working code to comply with these rules. These rules apply exclusively to NEW branches and new changes.

1. **Isolated workspace FIRST — before touching any code.** Create a new git working tree with its branch (preferred), or a full copy of the project folder (fallback when git worktree is not available). Always place it **outside the project root**, in a sibling `worktrees/` folder next to the project:
   - Preferred: `git worktree add "../worktrees/<project-name>_<YYYY-MM-DD_HHMM>_<model-name>" -b <branch-name>`
   - Fallback (no git): copy the whole project folder to `../worktrees/<project-name>_<YYYY-MM-DD_HHMM>_<model-name>/`
   - Example: `../worktrees/docs-app_2026-10-20_1542_big-pickle`
   - All work happens inside that isolated workspace. Never work in the main project checkout.
2. **One branch = one working tree.** Every branch must work in its own separate git working tree to prevent agents from damaging the main code:
   - Never switch branches inside the shared main project checkout.
   - Never let two agents share one working tree; each agent works only inside its own worktree for all git operations (`git status`, `commit`, `checkout`, etc.).
   - Never create a worktree **inside** the project root — always outside, as a sibling.
   - Do **not** add worktree paths to the main project's `.gitignore` — they live outside the repository, so it has no effect and only creates confusion.
   - After the branch is merged, remove the working tree with `git worktree remove <path>`.
3. **Keep each file under 100 lines of code** (counting real code lines). This is the hard limit per file.
4. **One feature per folder** — when adding a new feature, put it in its own folder under `lib/features/`.
5. **Follow SRP (Single Responsibility Principle)** — each file/class does one thing, with a clear purpose.
6. **Keep everything very simple** — prefer small, obvious solutions over clever ones.
7. **Use very clear names** — names must explain what is going on (files, classes, vars, fields).
8. **Additive & safe** — never break existing behavior; default new fields/values so old records/data remain compatible.
9. **End-to-end tests only** — always test against the real backend, real database, and real HTTP. Never mock or fake tests.
10. **Local test DB only** — never run tests, e2e, or review links against the production database. Locally use `scripts/local_stack.sh` (Docker Qdrant on `:6333`); CI uses a throwaway Qdrant container. The Qdrant Cloud cluster is production and is only touched by the deploy workflow's final prod check.
11. **Send a public test link before the PR.** Run the app locally and expose it with a Cloudflare tunnel: `/home/aisurvivor/cloudflared tunnel --url http://localhost:<port>` (ngrok or Tailscale as fallback). Send the public link to humans for evaluation; humans decide the next step.
12. **Humans approve first, then PR.** Only after human approval: open the PR, merge to master, let the pipeline run, and return the results to the human.
13. **All code must be written in English, no spanglish.**

---

**Project note:** this app is FastAPI + Flutter web. "Database" means Qdrant: chunks, file bytes and document metadata live there. Never point tests at `QDRANT_URL` from `.env`; tests must use `QDRANT_TEST_URL` (default `http://localhost:6333`).

---

# Testing & Merge Policy

## 1. Test Real Behavior

Every new feature and bug fix MUST include automated tests proving its expected behavior and observable results. HTTP 200 responses, UI element existence, and method execution alone are insufficient.

## 2. E2E First, Integration Second

E2E tests MUST cover affected critical user workflows. Integration tests MUST cover backend behavior not adequately verified by E2E. Unit tests are NOT required. Tests MUST exercise real application components; mocking the system under test is prohibited.

## 3. Prove Tests Detect Failures

Every new test MUST fail when its targeted behavior is deliberately broken and pass when the behavior is correct. Tests that cannot detect the defect they claim to cover are invalid.

**Verification required before opening a PR:** Deliberately break the behavior the test covers (e.g., change the expected status code, remove the feature flag, invert a condition), run the test, confirm it fails. Restore the behavior, run the test, confirm it passes. Document this verification in the PR.

*Invalid example:* A test that only asserts `response.status_code == 200` or that a page contains a header — it still passes when the actual behavior is broken. Such a test does not satisfy this rule.

## 4. Automatic Test Discovery

Tests MUST remain in independent files and be automatically discovered by the test runner. Every PR MUST execute the required test suite through GitHub Actions. No manual test registration or file concatenation.

**This project's discovery:**
- Backend: `pytest tests/` auto-discovers all `test_*.py` files
- Flutter: `flutter test` discovers all `*_test.dart` files

## 5. No Green CI, No Merge

All required checks MUST pass before merging into `main`. Agents MUST NOT skip, delete, weaken, or bypass failing tests. Failures MUST be fixed at their source. Direct pushes to `main` are prohibited.

**Enforcement:** Configure GitHub repository rulesets to require pull requests and passing CI checks. The CI workflow must run the tests and fail on errors. Rules 1–3 also require automated test-quality checks or review; GitHub branch protection alone cannot verify their semantics.

Core principle: No demonstrated behavior, no merge.
