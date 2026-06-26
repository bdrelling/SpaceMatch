**Reading**

- **["Designing Video Game Puzzles"](https://www.gamedeveloper.com/design/designing-video-game-puzzles)** by Sean Noonan (Game Developer / Gamasutra) — concrete techniques from a working puzzle designer. The "trap the player, then design the exit" framing alone is worth it.
- **["How are puzzle games designed?"](https://wikis.nyu.edu/download/attachments/82051977/How%20are%20puzzle%20games%20designed_%20(Introduction)%20_%20Dev.Mag.pdf)** (Dev.Mag, three-part series, free PDF) — splits puzzle games into procedural, combinatorial, and handmade, then walks through the design loop for each. The most practical thing on this list for someone in your position.
- **["Match Game Mechanics: An Exhaustive Survey"](https://www.gamedeveloper.com/design/match-game-mechanics-an-exhaustive-survey)** (Game Developer) — taxonomy of every match-3 piece type across Bejeweled, Candy Crush, Triple Town, Threes, etc. Reading it as a catalog of *atoms* is a cheat code for spotting unexplored combinations.
- **["Puzzle Game Design (Principles, Levels, Template)"](https://gamedesignskills.com/game-design/puzzle/)** at gamedesignskills.com — solid overview, but really there for its reading list (Schell, Salen/Zimmerman, *Game Mechanics: Advanced Game Design* by Adams/Dormans).
- **[Jonathan Blow + Marc ten Bosch, "Designing to Reveal the Nature of the Universe"](https://www.gamedeveloper.com/design/indiecade-inside-jonathan-blow-s-puzzle-design-process)** (GDC talk on YouTube) — the canonical talk on how to extract puzzles *from* a mechanic rather than invent them. Pair with Blow's IndieCade write-up on Gamasutra. (The actual GDC talk is on YouTube — search "Jonathan Blow Marc ten Bosch Designing to Reveal the Nature of the Universe".)

**Watching**

- **[Game Maker's Toolkit](https://www.youtube.com/@GMTK)** — Mark Brown's "Puzzle Solving vs. Problem Solving," "The 4 Step Level Design" episode, and his entire Mind Over Magnet devlog series. The devlog is especially good for you: he agonizes about exactly the "I can't invent mechanics" feeling. (Mind Over Magnet devlog playlist is the one you want.)
- **[Adam Millard / The Architect of Games](https://www.youtube.com/@ArchitectofGames)** — episodes on Baba Is You and Stephen's Sausage Roll are some of the best puzzle dissections on YouTube.

---

**Advice — and I think this is where your real problem is.**

1. **Stop trying to invent a mechanic. Pick a verb and exhaust it.** This is the Blow/ten Bosch method, and it's the most important thing on this page. A good puzzle game isn't a clever idea — it's a humble verb (swap two tiles, draw a line, push a box, point a hose) explored until it tells you what it can and can't do. Your Rustworld hose is a perfect example: "drag a path from the edge to a target" is a verb. What does it mean for the path to bend? Cross itself? Have a max length? Be blocked? Each answer is a puzzle. You don't need a new mechanic, you need to interrogate the one you have.

2. **You're not bad at this — you're skipping the boring middle step.** Twenty years of gamedev experience makes you good at *recognizing* good mechanics, which makes you brutal on your own half-formed ones. The middle step is making 50 ugly puzzles with a dumb mechanic and seeing which 5 surprise you. Designers like Alan Hazelden (Stephen's Sausage Roll, A Monster's Expedition) talk constantly about how the good puzzles are *discovered*, not designed — you stumble on them while exhausting the space. You're trying to skip to step 47.

3. **Combine two boring mechanics before inventing one exciting one.** Match-3 + falling = Bejeweled. Bejeweled + objectives = Candy Crush. Sokoban + "you are the rules" = Baba Is You. Almost every great puzzle game is an unexpected collision of two understood things. Make a list of ten mechanics you understand cold (gravity, rotation, color matching, pathfinding, line-of-sight, swap, push, fall, link, cut) and try every pair. Most pairs are nothing. Two or three will be a game.

4. **Build the puzzle backwards from the "aha."** Designing forward ("what if I add X?") almost never produces good puzzles. Designing backward does: imagine the moment of clarity you want the player to have ("oh — I can solvent the goo to *create* a path of goo, then trigger it as a chain"), then engineer the board state that forces them to discover it. Puzzles are written like jokes — punchline first, setup second.

5. **The mechanic is the question; the puzzle is one good answer.** Every puzzle should pose a question only this mechanic can ask. If a puzzle could be solved by guessing or by a generic "logic" skill, it's not really about your mechanic — it's filler. Quick test: can you describe what the puzzle is *about* in one sentence that names the mechanic? "This one is about realizing you have to splash goo onto goo to clear a wider area than one solvent can reach." If you can't, it's not pulling its weight.
