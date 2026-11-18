# Mach Math: first playable version

A fast 2D platformer for practicing division with remainders.

## Open it
1. Unzip this folder somewhere easy to find, like Documents.
2. Open Godot. In the Project Manager, click **Import**, pick the `project.godot` file in this folder, then click **Import & Edit**.
3. Press **F5** (or the ▶ Play button at the top right) to play.

## How to play
- Move with **A/D** or the **arrow keys**. Jump with **Space**. Press **R** to restart. A controller also works.
- Each gate has three answers stacked on top of each other. The height you pass through picks your answer:
  - **LOW**: just keep running
  - **MIDDLE**: jump from the ground
  - **HIGH**: jump off the wooden ledge in front of the gate
- Right answers build your combo, and a bigger combo lets you run faster. Wrong answers slow you down and show the work, but you never lose a life.
- When you reach the GOAL, **MATH TIME** starts: race back to the START before the timer runs out. You get a rank from D up to P.
- The difficulty adjusts itself: 3 right in a row moves you up a level, and 2 wrong in a row moves you down.

## For parents
Every finished run adds a line to `progress.csv`. That line counts each kind of mistake: a remainder bigger than the divisor, a forgotten remainder, a quotient off by one, or a wrong remainder.
To find the file, open the Godot editor and go to **Project → Open User Data Folder**.

## Easy things to tweak
- `scripts/main.gd`, near the top: `STATION_COUNT` (number of gates), `ESCAPE_TIME`, `STATION_SPACING`
- `scripts/division_problem.gd`, in `make()`: the number ranges for each difficulty level
- `scripts/player.gd`: speed, jump height and gravity
