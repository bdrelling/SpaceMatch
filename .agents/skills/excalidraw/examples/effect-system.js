// Worked reference: the Effect System ER/composition diagram, built with the build.js engine.
// This is the canonical example for the excalidraw skill AND its smoke test — it exercises every
// engine feature: a composition TREE, vertically-stacked `riders` (extends-a-base), a `spacer`
// lane, manually-placed shared leaves (Phase/Hook/Amount/Ability), direction-aware `fk` reference
// arrows, the title/subtitle, and the boxed key.
//
// Run it to (re)generate docs/obsidian/drawings/effect-system.excalidraw.md:
//   node .agents/skills/excalidraw/examples/effect-system.js
//
// To draw a DIFFERENT diagram, copy this shape: describe your boxes/fields/edges as a TREE +
// a few manual placements, then feed them to the same engine. The data is per-drawing and
// throwaway; the engine (../scripts/build.js) is what's reusable. Source can be a markdown
// note OR a conversation — the engine doesn't care where the data came from.

const { Diagram, HBOX, boxW } = require("../scripts/build.js");
const E = require("../excalidraw.js");
const ext = t => "extends " + t;

const TREE = {
  n: "Entity", f: ["id : int", "base_stats : StatBlock", "current_stats : StatBlock", "statuses : Array[StatusStack]"], children: [
    { n: "StatusStack", f: ["status : Status", "count : int"], fromRow: 2, children: [
      { n: "Status", fromRow: 0,
        f: ["name : StringName", "sign : Sign", "cap : int", "stack_rule : StackRule", "decay_rule : DecayRule", "effects : Array[TriggeredEffect]", "modifiers : Array[Modifier]", "damage_steps : Array[DamageStep]"],
        children: [
          { n: "Sign", f: ["POSITIVE", "NEGATIVE"], note: "enum", fromRow: 1 },
          { n: "StackRule", note: "base", fromRow: 3, riders: [
            { n: "StackStackRule", note: ext("StackRule") }, { n: "KeepHighestStackRule", note: ext("StackRule") } ] },
          { n: "DecayRule", note: "base", fromRow: 4, riders: [
            { n: "TimingDecayRule", f: ["phase : Phase", "quantity : int"], note: ext("DecayRule") },
            { n: "TriggerDecayRule", f: ["hook : Hook", "quantity : int"], note: ext("DecayRule") },
            { n: "ThresholdDecayRule", f: ["value : int", "quantity : int"], note: ext("DecayRule") } ] },
          { spacer: true, spacerW: 210 },
          { n: "TriggeredEffect", f: ["trigger : Trigger", "effects : Array[Effect]"], fromRow: 5, children: [
            { n: "Trigger", note: "base", fromRow: 0, riders: [
              { n: "PhaseTrigger", f: ["phase : Phase"], note: ext("Trigger") },
              { n: "HookTrigger", f: ["hook : Hook"], note: ext("Trigger") },
              { n: "CountTrigger", f: ["value : int"], note: ext("Trigger") } ] },
            { n: "Effect", f: ["target : Target", "action : Action", "conditions : Array[Condition]", "resolve(ctx)"], fromRow: 1, children: [
              { n: "Condition", f: ["holds(ctx) : bool"], note: "base", fromRow: 2, riders: [
                { n: "HasStatus", f: ["target : Target", "status : StringName"], note: ext("Condition") },
                { n: "StatThreshold", f: ["target : Target", "stat : StringName", "comparison : Comparison", "value : int"], note: ext("Condition") } ] },
              { n: "Target", f: ["resolve(ctx) : Array[Entity]"], note: "base", fromRow: 0, riders: [
                { n: "SelfTarget", note: ext("Target") }, { n: "EnemyTarget", note: ext("Target") },
                { n: "AllEnemiesTarget", note: ext("Target") }, { n: "AttackerTarget", note: ext("Target") },
                { n: "SidesTarget", f: ["radius : int"], note: ext("Target") },
                { n: "RandomEnemyTarget", note: ext("Target") }, { n: "ChosenTarget", note: ext("Target") } ] },
              { n: "Action", f: ["resolve(ctx, target)"], note: "base", fromRow: 1, riders: [
                { n: "DealDamage", f: ["amount : Amount", "damage_type : StringName"], note: ext("Action") },
                { n: "Heal", f: ["amount : Amount"], note: ext("Action") },
                { n: "ApplyStatus", f: ["status : StringName", "count : int"], note: ext("Action") },
                { n: "RemoveStatus", f: ["status : StringName"], note: ext("Action") },
                { n: "Gain", f: ["resource : StringName", "amount : Amount"], note: ext("Action") } ] } ] } ] },
          { n: "Modifier", f: ["stat : StringName", "operation : Operation", "amount : float"], fromRow: 6, children: [
            { n: "Operation", f: ["ADD", "MULTIPLY"], note: "enum", fromRow: 1 } ] } ] } ] } ] };

// House convention (settled in notes/effect-system.md header + notes/effect-system-mermaid.md):
// base + structural types keep the default color; every concrete variant ("kind of" a base) =
// amber shipped example; enums = purple. root stays the engine default.
const AMBER = { strokeColor: "#e0a96d", headColor: "#4a3520", titleColor: "#f0d4ac" };
const PURPLE = { strokeColor: "#b39ddb", headColor: "#2f2747", titleColor: "#d9caf0" };
const d = new Diagram({ kinds: { sub: AMBER, enum: PURPLE } });
d.layoutTree(TREE);

// StatBlock is Entity's other child, but its subtree is tiny next to StatusStack's huge one, so
// the auto-layout would strand it at the far-left edge. Place it by hand, below-left of Entity.
const sbF = ["get_stat(name) : Variant", "set_stat(name, value)", "stat_names() : Array[StringName]"];
const sbNote = "abstract — games subclass";
const sbW = boxW("StatBlock", sbF, sbNote);
d.place("StatBlock", d.box.Entity.left - sbW - 170, d.box.Entity.bottom + 50, sbW, sbF, sbNote);
d.stack(d.box.StatBlock.left, sbW, d.box.StatBlock.bottom + d.rvgap, [
  { n: "ShipStats", f: ["hull : int", "tactical_systems : int"], note: ext("StatBlock") }]);

// shared leaves
const spacer = TREE.children[0].children[0].children[3];
const laneCx = spacer._cx, laneW = 205;
const phaseTop = (d.box.TimingDecayRule.cy + d.box.PhaseTrigger.cy) / 2 - HBOX(["a"], "enum") / 2;
d.place("Phase", laneCx - laneW / 2, phaseTop, laneW, ["TURN_START", "TURN_END", "ROUND_END"], "enum");
const hookTop = Math.max((d.box.TriggerDecayRule.cy + d.box.HookTrigger.cy) / 2 - HBOX([], "base") / 2, d.box.Phase.bottom + 16);
d.place("Hook", laneCx - laneW / 2, hookTop, laneW, [], "base");
d.stack(laneCx - laneW / 2, laneW, d.box.Hook.bottom + d.rvgap, [
  { n: "WhenHitHook", note: ext("Hook") }, { n: "OnAttackHook", note: ext("Hook") }, { n: "OnApplyHook", note: ext("Hook") },
  { n: "DamageReceivedHook", f: ["amount : int", "damage_type : StringName", "attacker : Entity"], note: ext("Hook") }]);

const amtW = 200, amtX = d.box.Action.right + 70;
const amtCy = (d.box.DealDamage.cy + d.box.Heal.cy + d.box.Gain.cy) / 3;
const amtF = ["evaluate(ctx) : int"];
d.place("Amount", amtX, amtCy - HBOX(amtF, "base") / 2, amtW, amtF, "base");
d.stack(amtX, amtW, d.box.Amount.bottom + d.rvgap, [
  { n: "ConstantAmount", f: ["value : int"], note: ext("Amount") }, { n: "StatAmount", f: ["stat : StringName"], note: ext("Amount") }]);

d.place("Ability", d.box.TriggeredEffect.right + 24, d.box.TriggeredEffect.top, 200, ["name : StringName", "cost : int", "effects : Array[Effect]"]);

// Comparison enum — referenced by StatThreshold (an enum, like Sign / Operation)
d.place("Comparison", d.box.StatThreshold.left, d.box.StatThreshold.bottom + 18, 170, ["LESS", "EQUAL", "GREATER"], "enum");

// ── Runtime layer: resolution context + damage pipeline ──────────────
// The runtime types from effect-system.md (stat awareness & runtime targeting).
// Placed in a band below the tree, then wired back via the references the doc
// spells out (see the linkBoxes/fk calls under "edges").
const bandY = Math.max(...Object.values(d.box).map(b => b.bottom)) + 90;
const GAP = 64;
let bx = d.box.Condition.left;   // start the band under the Effect subtree, near its anchors

const rcF = ["source : Entity", "allies : Array[Entity]", "enemies : Array[Entity]", "attacker : Entity", "rng : RandomNumberGenerator", "chooser : EffectChooser", "health_stat : StringName"];
d.place("ResolutionContext", bx, bandY, boxW("ResolutionContext", rcF), rcF);
bx = d.box.ResolutionContext.right + GAP;

const chF = ["choose(candidates, source) : Entity"];
const chW = boxW("EffectChooser", chF, "base");
d.place("EffectChooser", bx, bandY, chW, chF, "base");
d.stack(bx, chW, d.box.EffectChooser.bottom + d.rvgap, [{ n: "AutoChooser", note: ext("EffectChooser") }]);

// damage-pipeline cluster, to the right so it sits roughly under DealDamage / Action
bx = d.box.EffectChooser.right + GAP * 2;
const pktF = ["source : Entity", "target : Entity", "amount : int", "damage_type : StringName"];
d.place("DamagePacket", bx, bandY, boxW("DamagePacket", pktF), pktF);
bx = d.box.DamagePacket.right + GAP;

const pipeF = ["resolve(packet, ctx) : int"];
d.place("DamagePipeline", bx, bandY, boxW("DamagePipeline", pipeF), pipeF);
bx = d.box.DamagePipeline.right + GAP;

const dsF = ["phase() : DamageStep.Phase", "modify(packet, ctx)"];
const dsW = boxW("DamageStep", dsF, "base");
d.place("DamageStep", bx, bandY, dsW, dsF, "base");
d.stack(bx, dsW, d.box.DamageStep.bottom + d.rvgap, [
  { n: "MultiplierStep", f: ["factor : float"], note: ext("DamageStep") },
  { n: "FlatMitigationStep", f: ["stat : StringName"], note: ext("DamageStep") },
  { n: "AbsorbStep", f: ["stat : StringName"], note: ext("DamageStep") },
  { n: "ClampStep", f: ["minimum : int", "maximum : int"], note: ext("DamageStep") }]);

const phF = ["AMPLIFY", "MITIGATE", "ABSORB", "CLAMP"];
d.place("DamageStep.Phase", d.box.DamageStep.right + GAP, bandY, boxW("DamageStep.Phase", phF, "enum"), phF, "enum");

// edges
d.treeEdges(TREE);
d.linkDown("Entity", "StatBlock");   // Entity -> manually-placed StatBlock
d.fk("Ability", 2, "Effect");
d.fk("TimingDecayRule", 0, "Phase"); d.fk("PhaseTrigger", 0, "Phase");
d.fk("TriggerDecayRule", 0, "Hook"); d.fk("HookTrigger", 0, "Hook");
d.fk("DealDamage", 0, "Amount"); d.fk("Heal", 0, "Amount"); d.fk("Gain", 1, "Amount");
d.fk("StatThreshold", 2, "Comparison");

// wire the runtime band back into the tree (relationships per effect-system.md)
const linkBoxes = (a, b) => {
  const A = d.box[a], B = d.box[b];
  if (B.top >= A.bottom) d.els.push(E.link(A.cx, A.bottom, B.cx, B.top));
  else if (B.left >= A.right) d.els.push(E.link(A.right, A.cy, B.left, B.cy));
  else if (B.right <= A.left) d.els.push(E.link(A.left, A.cy, B.right, B.cy));
  else d.els.push(E.link(A.cx, A.top, B.cx, B.bottom));
};
d.fk("ResolutionContext", 5, "EffectChooser");   // chooser : EffectChooser
d.fk("DamageStep", 0, "DamageStep.Phase");        // phase() : DamageStep.Phase
linkBoxes("ChosenTarget", "EffectChooser");       // ChosenTarget resolves through ctx.chooser
linkBoxes("DealDamage", "DamagePipeline");        // DealDamage builds a packet, runs the pipeline
linkBoxes("DamagePipeline", "DamagePacket");      // ... mutating the packet
linkBoxes("DamagePipeline", "DamageStep");        // ... through each step

d.title("Effect System", "mirrors notes/effect-system.md  ·  composition flows top-down");
d.key([["root", "Base / structural type"], ["sub", "Variant — shipped example"], ["enum", "Enum"]]);

console.log("boxes:", Object.keys(d.box).length);
console.log("wrote", d.write("effect-system"));
