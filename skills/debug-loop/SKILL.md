---
name: debug-loop
description: Systematic debugging: reproduce, form hypotheses, test them cheaply, fix, verify. Use when something fails, crashes, or behaves wrongly and the cause is not yet known.
---

1. **Reproduce.** Get a failing command or test and its exact output. If it cannot be reproduced, say so and ask for what is missing.
2. **Hypotheses.** List the 2 to 3 most likely causes, ranked, each with the one check that would confirm or kill it.
3. **Test cheaply.** Run the cheapest check first (a print, a smaller input, `git bisect`, a debugger). Change one thing at a time.
4. **Fix the cause**, not the symptom. Keep the diff minimal.
5. **Verify.** Re-run the original failing case and the nearby tests. Add a regression test when practical.
6. **Stop rule.** After two failed hypotheses, write down what has been ruled out before continuing. If the user says this has already taken hours, recommend escalating the model (see CLAUDE.md) instead of guessing further.
