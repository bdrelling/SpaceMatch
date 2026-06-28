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

const { Diagram, HBOX } = require("../scripts/build.js");
const ext = t => "extends " + t;

const TREE = {
  n: "Entity", f: ["id : int", "base_stats : StatBlock", "current_stats : StatBlock", "statuses : Array[StatusStack]"], kids: [
    { n: "StatBlock", f: ["get_stat(name) : Variant", "set_stat(name, value)", "stat_names() : Array[StringName]"], note: "abstract — games subclass", fromRow: 1 },
    { n: "StatusStack", f: ["status : Status", "count : int"], fromRow: 2, kids: [
      { n: "Status", fromRow: 0,
        f: ["name : StringName", "sign : Sign", "cap : int", "stack_rule : StackRule", "decay_rule : DecayRule", "effects : Array[TriggeredEffect]", "modifiers : Array[Modifier]"],
        kids: [
          { n: "Sign", f: ["POSITIVE", "NEGATIVE"], note: "enum", fromRow: 1 },
          { n: "StackRule", note: "base", fromRow: 3, riders: [
            { n: "StackStackRule", note: ext("StackRule") }, { n: "KeepHighestStackRule", note: ext("StackRule") } ] },
          { n: "DecayRule", note: "base", fromRow: 4, riders: [
            { n: "TimingDecayRule", f: ["phase : Phase", "quantity : int"], note: ext("DecayRule") },
            { n: "TriggerDecayRule", f: ["hook : Hook", "quantity : int"], note: ext("DecayRule") },
            { n: "ThresholdDecayRule", f: ["value : int", "quantity : int"], note: ext("DecayRule") } ] },
          { spacer: true, spacerW: 210 },
          { n: "TriggeredEffect", f: ["trigger : Trigger", "effects : Array[Effect]"], fromRow: 5, kids: [
            { n: "Trigger", note: "base", fromRow: 0, riders: [
              { n: "PhaseTrigger", f: ["phase : Phase"], note: ext("Trigger") },
              { n: "HookTrigger", f: ["hook : Hook"], note: ext("Trigger") },
              { n: "CountTrigger", f: ["value : int"], note: ext("Trigger") } ] },
            { n: "Effect", f: ["target : Target", "action : Action", "conditions : Array[Condition]"], fromRow: 1, kids: [
              { n: "Condition", note: "base", fromRow: 2, riders: [
                { n: "HasStatus", f: ["target : Target", "status : StringName"], note: ext("Condition") },
                { n: "StatThreshold", f: ["target : Target", "stat : StringName", "comparison : Comparison", "value : int"], note: ext("Condition") } ] },
              { n: "Target", note: "base", fromRow: 0, riders: [
                { n: "SelfTarget", note: ext("Target") }, { n: "EnemyTarget", note: ext("Target") },
                { n: "AllEnemiesTarget", note: ext("Target") }, { n: "AttackerTarget", note: ext("Target") },
                { n: "SidesTarget", f: ["radius : int"], note: ext("Target") } ] },
              { n: "Action", note: "base", fromRow: 1, riders: [
                { n: "DealDamage", f: ["amount : Amount", "damage_type : StringName"], note: ext("Action") },
                { n: "Heal", f: ["amount : Amount"], note: ext("Action") },
                { n: "ApplyStatus", f: ["status : StringName", "count : int"], note: ext("Action") },
                { n: "RemoveStatus", f: ["status : StringName"], note: ext("Action") },
                { n: "Gain", f: ["resource : StringName", "amount : Amount"], note: ext("Action") } ] } ] } ] },
          { n: "Modifier", f: ["stat : StringName", "operation : Operation", "amount : float"], fromRow: 6, kids: [
            { n: "Operation", f: ["ADD", "MULTIPLY"], note: "enum", fromRow: 1 } ] } ] } ] } ] };

const d = new Diagram();
d.layoutTree(TREE);

// shared leaves
const spacer = TREE.kids[1].kids[0].kids[3];
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
d.place("Amount", amtX, amtCy - HBOX([], "base") / 2, amtW, [], "base");
d.stack(amtX, amtW, d.box.Amount.bottom + d.rvgap, [
  { n: "ConstantAmount", f: ["value : int"], note: ext("Amount") }, { n: "StatAmount", f: ["stat : StringName"], note: ext("Amount") }]);

d.place("Ability", d.box.TriggeredEffect.right + 24, d.box.TriggeredEffect.top, 200, ["name : StringName", "cost : int", "effects : Array[Effect]"]);

// Comparison enum — referenced by StatThreshold (an enum, like Sign / Operation)
d.place("Comparison", d.box.StatThreshold.left, d.box.StatThreshold.bottom + 18, 170, ["LESS", "EQUAL", "GREATER"], "enum");

// edges
d.treeEdges(TREE);
d.fk("Ability", 2, "Effect");
d.fk("TimingDecayRule", 0, "Phase"); d.fk("PhaseTrigger", 0, "Phase");
d.fk("TriggerDecayRule", 0, "Hook"); d.fk("HookTrigger", 0, "Hook");
d.fk("DealDamage", 0, "Amount"); d.fk("Heal", 0, "Amount"); d.fk("Gain", 1, "Amount");
d.fk("StatThreshold", 2, "Comparison");

d.title("Effect System", "mirrors notes/effect-system.md  ·  composition flows top-down");
d.key([["root", "Root — base type"], ["sub", "Subtype — extends a root"], ["enum", "Enum"]]);

console.log("boxes:", Object.keys(d.box).length);
console.log("wrote", d.write("effect-system"));
