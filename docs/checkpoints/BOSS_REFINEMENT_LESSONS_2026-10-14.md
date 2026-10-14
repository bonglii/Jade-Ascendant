# Lessons — Boss refinement

- Symptom "player and boss both stationary" required comparing player target radius with boss stop radius. Do not disguise an AI engagement gap with idle animation or widen player range silently.
- An atlas generated as a grid may contain touching alpha fringes/uneven margins. Inspect it, clean noisy output with imagegen, isolate/pack poses and share row scale/feet pivot; validate the entire PNG before import. Write packed PNG atomically before starting importer/consumers; a partial PNG caused one failed import in the temporary QA cache, which was rebuilt.
- A ternary expression of array literals was untyped in Godot and failed runtime assignment to Array[int]. Use a plain Array for this internal animation-index sequence; actual indexes remain integers, and real UI/runtime loading is required in validation.
- Real gameplay QA must explicitly release tutorial-owned pause. A timer advancing does not prove physics is running; assert unpaused before movement tests. Use fresh isolated profiles for tutorial-first-run regression.
- Expanding profile coverage from3 to5realms requires expanding fixture palettes/roster and instantiating the production RealmBoss subclass; checking radius on a legacy RectangleShape was an invalid fixture, not an excuse to change production colliders.
- Stop failed/hanging test processes before reusing logs, or use unique output filenames. Overlapping old/new processes produced sparse/mixed temporary logs. Accepted final suites have identified results and zero failed assertions.
- Keep shared LESSONS/BACKLOG files out of independently applied game patches; dedicated checkpoint/lesson files avoid the user's repeated shared-document patch conflicts.
- Preserve Indonesian in progress messages; accidental language switches add confusion.
