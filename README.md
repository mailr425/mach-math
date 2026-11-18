# Mach Math

A fast 2D platformer for practicing division with remainders, built in Godot 4.

## Open it
1. Clone this repo (GitHub Desktop: **File → Clone repository**), or download it.
2. Open Godot. In the Project Manager, click **Import**, pick `project.godot`, then click **Import & Edit**.
3. Press **F5** (or the ▶ Play button at the top right) to play.

## Keep it synced with GitHub
Double-click `autosync.bat` and leave its window open. It pulls new changes from GitHub every 60 seconds, and closing the window stops it. It only fast-forwards, so it never overwrites edits you haven't pushed.

## Controls
| Action | Keyboard | Controller |
|---|---|---|
| Move | A/D or arrow keys | Left stick / d-pad |
| Jump | Space (hold to jump higher) | A |
| Pick a door | E (or Down/S) | X |
| Attack: slash, chop, mine | J, F, or left click | B |
| Throw a dagger | Hold attack and let go, or press K | Y |
| Restart | R | |

## How a run works
- A run is **3 stages**. Each stage is a random environment with 3 math gates.
- Before each stage you visit the **Crafting Table**.
- After stage 3, **MATH TIME** starts: race back to the start. The clock stops while you're at a gate, so speed comes from running, not from rushing the math. You get a rank from D up to P.

### Math gates
- A wall blocks the way, and three doors show answers. Walk up to a door and press E to pick it. There's no timer while you think.
- First wrong pick: a hint (without the answer). Second wrong pick: the work is shown and the right door turns gold.
- The wall opens once you pick the right answer. Getting it on the first try is what builds your **combo**, and a bigger combo lets you run faster.
- The difficulty adjusts itself: 3 first-try rights in a row moves you up a level, and 2 misses in a row moves you down.

### Enemies (they never hurt you)
- **Stomp** them: hold jump to bounce higher. Stomps chained without landing score more each time.
- **Mach run** through them: with a combo going, run at full speed straight into them.
- **Slash** them, or **throw a dagger** that slices through every enemy in a line. Daggers are limited; find dagger pickups or craft more.
- In the Dungeon, look out for baby dragons (100 points).

### Hearts and hazards
- You have 3 red hearts per stage. Falling into a hazard (lava, quicksand, poison swamp, freezing water, the sea, craters, pits, spike pits) costs a heart and puts you back at the last safe spot.
- **Armor** adds blue shield hearts that get used up first. They refill every stage.
- Out of hearts restarts the stage. Your gear is kept.

### Gathering and crafting (Minecraft-style)
- **Trees:** slash them for wood. Without an axe it takes 3 hits; a Wooden Axe chops in one hit and gives more wood.
- **Ore blocks:** slash with a pickaxe. Each pickaxe mines the next ore: Wooden → stone, Stone → iron (tan specks), Iron → diamond (blue specks). Without the right pickaxe, ore is just something to jump over.
- **Crafting Table recipes:** axe, pickaxes, daggers, and bark, iron and diamond armor (helmet, chestplate, boots).
- Your materials and gear are saved between runs.

## The 15 environments
| Environment | Quirk |
|---|---|
| The Plains | Easy warm-up, lots of trees |
| The Forest | Tons of wood, bouncy mushrooms |
| The Desert | Quicksand pits, cacti, fast scorplings |
| Hell | Lava pits, flying imps, good ore |
| The Moon | Low gravity, craters, moon hoppers |
| Snowy Wonderland | Slippery ice, freezing water, snowfall |
| The Village | Bouncy haystacks |
| London | Rain, buses to hop over, a clock tower |
| The Giant Garden | You're tiny; giant bouncy flowers, beetles |
| The Caves | Dark, lots of ore (diamonds!), bats |
| The Dungeon | Spike pits, baby dragons, dim torchlight |
| Tropical Rainforest | Poison swamps, rain, dart frogs |
| The Beach | Bouncy beach balls, fast crabs |
| The Sea | Island hopping over the water |
| The Giant Tree | Running along a branch, leaf platforms |

## For parents
Every finished run adds a line to `progress.csv`. That line counts each kind of mistake: a remainder bigger than the divisor, a forgotten remainder, a quotient off by one, or a wrong remainder. Gear is saved in `save.json`; delete it to start fresh.
To find both files, open the Godot editor and go to **Project → Open User Data Folder**.

## Where things live
- `scripts/main.gd`: the run (stages, gates, hearts, crafting screen, Math Time, results)
- `scripts/stage.gd`: builds one environment (floor, hazards, trees, ore, enemies, daggers)
- `scripts/biomes.gd`: all 15 environments. Copy an entry to make a new one.
- `scripts/inventory.gd`: materials, recipes, armor, save file
- `scripts/player.gd`: movement, jumping, attacks
- `scripts/division_problem.gd`: the math problems and hints
