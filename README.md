# Mach Math: first playable version

A fast 2D platformer for practicing division with remainders.

## Open it
1. Unzip this folder somewhere easy to find, like Documents.
2. Open Godot. In the Project Manager, click **Import**, pick the `project.godot` file in this folder, then click **Import & Edit**.
3. Press **F5** (or the ▶ Play button at the top right) to play.

## Keep it synced with GitHub
Double-click `autosync.bat` and leave its window open. It pulls new changes from GitHub every 60 seconds, and closing the window stops it. It only fast-forwards, so it never overwrites edits you haven't pushed.

## How to play
- Move with **A/D** or the **arrow keys**. Jump with **Space**. Pick a door with **E** (or Down/S). Press **R** to restart. A controller also works: A to jump, X to pick a door.
- **Run** between gates: hop the hurdles and grab gems. Right answers build your combo, and a bigger combo lets you run faster.
- **Enemies** patrol between gates. They never hurt you, and beating them gives points:
  - **Stomp** one by landing on its head. Hold jump to bounce higher. Stomping several in a row without landing is worth more each time (+50, +100, +150...).
  - **Mach run** through one: with a combo going, run at top speed straight into it. Right answers on the first try are what make you fast enough.
  - Bumping into one at normal speed is harmless; it just turns around. Enemies come back for Math Time.
- **Think** at gates: a wall blocks the way, and three doors show answers. Walk up to a door and press E to pick it. There's no timer while you think.
  - First wrong pick: a hint (without the answer). Try another door.
  - Second wrong pick: the full work is shown and the right door turns gold.
  - The wall opens once you pick the right answer. Getting it on the first try is what builds your combo.
  - Answering within 10 seconds of reaching the gate gives a +50 bonus. It's optional.
- When you reach the GOAL, **MATH TIME** starts: race back to the START. The clock only counts running and stops while you're at a gate. You get a rank from D up to P.
- The difficulty adjusts itself: 3 first-try rights in a row moves you up a level, and 2 misses in a row moves you down.

## For parents
Every finished run adds a line to `progress.csv`. That line counts each kind of mistake: a remainder bigger than the divisor, a forgotten remainder, a quotient off by one, or a wrong remainder.
To find the file, open the Godot editor and go to **Project → Open User Data Folder**.

## Easy things to tweak
- `scripts/main.gd`, near the top: `STATION_COUNT` (number of gates), `ESCAPE_TIME`, `STATION_SPACING`, `QUICK_BONUS_SECONDS`
- `scripts/division_problem.gd`, in `make()`: the number ranges for each difficulty level
- `scripts/player.gd`: speed, jump height and gravity
