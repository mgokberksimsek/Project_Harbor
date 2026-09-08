import fs from "node:fs";
import path from "node:path";
import assert from "node:assert/strict";

const root = path.resolve(import.meta.dirname, "..");

function read(file) {
  return fs.readFileSync(path.join(root, file), "utf8");
}

function gdscriptNumber(text, key) {
  const match = text.match(new RegExp(`^const ${key} := ([0-9.]+)$`, "m"));
  assert(match, `Missing GDScript numeric constant: ${key}`);
  return Number(match[1]);
}

const economySource = read("Scripts/autoload/economy_manager.gd");
const shipPriceLinearGrowth = gdscriptNumber(economySource, "SHIP_PRICE_LINEAR_GROWTH");
const shipPriceQuadraticGrowth = gdscriptNumber(
  economySource,
  "SHIP_PRICE_QUADRATIC_GROWTH",
);

function number(text, key, fallback = 0) {
  const match = text.match(new RegExp(`^${key} = ([0-9.]+)$`, "m"));
  return match ? Number(match[1]) : fallback;
}

function stringName(text, key) {
  return text.match(new RegExp(`^${key} = &"([^"]+)"$`, "m"))?.[1] ?? "";
}

function numbers(text, key) {
  const match = text.match(new RegExp(`^${key} = Array\\[[^\\]]+\\]\\(\\[([^\\]]*)\\]\\)$`, "m"));
  return match ? match[1].split(",").map((value) => Number(value.trim())) : [];
}

function names(text, key) {
  const match = text.match(new RegExp(`^${key} = Array\\[[^\\]]+\\]\\(\\[([^\\]]*)\\]\\)$`, "m"));
  return match ? [...match[1].matchAll(/&"([^"]+)"/g)].map((item) => item[1]) : [];
}

function resources(directory) {
  return fs.readdirSync(path.join(root, directory))
    .filter((file) => file.endsWith(".tres"))
    .map((file) => read(path.join(directory, file)));
}

const ports = new Map(resources("Resources/Ports").map((text) => {
  const port = {
    id: stringName(text, "id"),
    unlockCost: number(text, "base_unlock_cost"),
    companyValue: number(text, "base_company_value"),
    requiredLevel: number(text, "required_company_level", 1),
    tier: number(text, "economic_tier", 1),
    upgradeCosts: numbers(text, "level_upgrade_costs"),
    upgradeValues: numbers(text, "upgrade_company_values"),
    rewardMultipliers: numbers(text, "level_reward_multipliers"),
    handlingMultipliers: numbers(text, "level_handling_duration_multipliers"),
    unlocked: /^unlocked_by_default = true$/m.test(text),
  };
  return [port.id, port];
}));

const ships = resources("Resources/ships")
  .filter((text) => number(text, "purchase_cost") > 0)
  .map((text) => ({
    id: stringName(text, "id"),
    speed: number(text, "base_speed", 100),
    capacity: number(text, "cargo_capacity", 1),
    consumption: number(text, "fuel_consumption_per_distance"),
    purchaseCost: number(text, "purchase_cost"),
    requiredLevel: number(text, "required_company_level", 1),
    companyValue: number(text, "base_company_value"),
    capabilities: names(text, "cargo_capabilities"),
    speedUpgradeCost: number(text, "speed_upgrade_base_cost"),
    capacityUpgradeCost: number(text, "capacity_upgrade_base_cost"),
    speedUpgradeValue: number(text, "speed_upgrade_company_value"),
    capacityUpgradeValue: number(text, "capacity_upgrade_company_value"),
    maxSpeedLevel: number(text, "max_speed_level", 5),
    maxCapacityLevel: number(text, "max_capacity_level", 3),
  }));

const cargos = resources("Resources/cargo_types").map((text) => ({
  id: stringName(text, "id"),
  value: number(text, "base_value", 100),
  weight: number(text, "spawn_weight", 1),
  capabilities: names(text, "required_capabilities"),
}));

const graph = new Map([...ports.keys()].map((id) => [id, []]));
for (const text of resources("Resources/sea_routes")) {
  const from = stringName(text, "from_port_id");
  const to = stringName(text, "to_port_id");
  const distance = number(text, "gameplay_distance");
  graph.get(from).push({ to, distance });
  graph.get(to).push({ to: from, distance });
}

function distance(from, to) {
  const best = new Map([[from, 0]]);
  const queue = [from];
  while (queue.length) {
    queue.sort((a, b) => best.get(a) - best.get(b));
    const current = queue.shift();
    if (current === to) return best.get(current);
    for (const edge of graph.get(current)) {
      const candidate = best.get(current) + edge.distance;
      if (candidate < (best.get(edge.to) ?? Infinity)) {
        best.set(edge.to, candidate);
        if (!queue.includes(edge.to)) queue.push(edge.to);
      }
    }
  }
  throw new Error(`No route from ${from} to ${to}`);
}

const tierMultipliers = [1, 1.08, 1.16, 1.25];
const fuelUnitPrice = 2.5;
const durationScale = 10;
const minimumSailingDuration = 2;
const handlingDuration = 3;

function portMultiplier(port, level = 1) {
  const tier = tierMultipliers[Math.max(0, Math.min(port.tier - 1, tierMultipliers.length - 1))];
  const upgrade = port.rewardMultipliers[Math.min(level - 1, port.rewardMultipliers.length - 1)] ?? 1;
  return { tier, upgrade };
}

function reward(pickupId, deliveryId, cargo, amount, levels = {}) {
  const pickup = portMultiplier(ports.get(pickupId), levels[pickupId] ?? 1);
  const delivery = portMultiplier(ports.get(deliveryId), levels[deliveryId] ?? 1);
  const pairMultiplier = (pickup.tier + delivery.tier) * 0.5
    * (pickup.upgrade + delivery.upgrade) * 0.5;
  return Math.max(Math.round((cargo.value + distance(pickupId, deliveryId) * 0.5)
    * (1 + 0.25 * Math.max(amount - 1, 0)) * pairMultiplier), 1);
}

function operatingCost(originId, pickupId, deliveryId, ship) {
  let totalDistance = distance(pickupId, deliveryId);
  if (originId && originId !== pickupId) totalDistance += distance(originId, pickupId);
  return Math.max(Math.round(totalDistance * ship.consumption * fuelUnitPrice), 0);
}

function sailingDuration(routeDistance, speed, amount) {
  const multiplier = amount <= 0 ? 1.1 : 1 - Math.min(amount * 0.05, 0.2);
  return Math.max(routeDistance / (speed * multiplier) * durationScale, minimumSailingDuration);
}

function mission(originId, pickupId, deliveryId, ship, cargo, amount, speedLevel = 0, levels = {}) {
  const speed = ship.speed * (1 + 0.15 * speedLevel);
  const pickupLevel = levels[pickupId] ?? 1;
  const deliveryLevel = levels[deliveryId] ?? 1;
  const pickupHandling = ports.get(pickupId).handlingMultipliers[pickupLevel - 1] ?? 1;
  const deliveryHandling = ports.get(deliveryId).handlingMultipliers[deliveryLevel - 1] ?? 1;
  const emptyDuration = originId === pickupId ? 0 : sailingDuration(distance(originId, pickupId), speed, 0);
  const duration = emptyDuration
    + handlingDuration * pickupHandling
    + sailingDuration(distance(pickupId, deliveryId), speed, amount)
    + handlingDuration * deliveryHandling;
  const gross = reward(pickupId, deliveryId, cargo, amount, levels);
  const cost = operatingCost(originId, pickupId, deliveryId, ship);
  return { gross, cost, net: gross - cost, duration, perMinute: (gross - cost) / duration * 60 };
}

function compatibleCargos(ship) {
  return cargos.filter((cargo) => cargo.weight > 0
    && cargo.capabilities.every((capability) => ship.capabilities.includes(capability)));
}

function percentile(values, ratio) {
  const ordered = [...values].sort((a, b) => a - b);
  return ordered[Math.round((ordered.length - 1) * ratio)];
}

function shipPurchasePrice(baseCost, ownedShipCount) {
  const safeCount = Math.max(ownedShipCount, 0);
  const multiplier = 1
    + shipPriceLinearGrowth * safeCount
    + shipPriceQuadraticGrowth * safeCount ** 2;
  return Math.max(Math.round(baseCost * multiplier / 10) * 10, baseCost);
}

function summarize(values, digits = 0) {
  const format = (value) => Number(value).toFixed(digits);
  return `${format(Math.min(...values))}/${format(percentile(values, 0.5))}/${format(Math.max(...values))}`;
}

const orderedExpansions = [...ports.values()]
  .filter((port) => !port.unlocked)
  .sort((a, b) => a.requiredLevel - b.requiredLevel || a.unlockCost - b.unlockCost);
const stages = [
  { name: "Başlangıç", unlocked: [...ports.values()].filter((port) => port.unlocked).map((port) => port.id) },
];
for (const port of orderedExpansions) {
  stages.push({ name: `${port.id} sonrası`, unlocked: [...stages.at(-1).unlocked, port.id] });
}

console.log("STAGE_BALANCE min/median/max (local pickup, level-1 ports)");
const stageSummaries = [];
for (const [stageIndex, stage] of stages.entries()) {
  const companyLevel = Math.min(stageIndex + 1, 15);
  const availableShips = ships.filter((ship) => ship.requiredLevel <= companyLevel);
  const scenarios = [];
  for (const ship of availableShips) {
    for (const pickup of stage.unlocked) {
      for (const delivery of stage.unlocked) {
        if (pickup === delivery) continue;
        for (const cargo of compatibleCargos(ship)) {
          for (let amount = 1; amount <= ship.capacity; amount += 1) {
            scenarios.push(mission(pickup, pickup, delivery, ship, cargo, amount));
          }
        }
      }
    }
  }
  assert(scenarios.every((scenario) => scenario.net > 0), `${stage.name}: non-positive mission net`);
  assert(scenarios.every((scenario) => scenario.cost / scenario.gross <= 0.30), `${stage.name}: operating cost above 30%`);
  stageSummaries.push({ stage, scenarios });
  console.log(`${stage.name.padEnd(20)} level=${String(companyLevel).padStart(2)} ports=${String(stage.unlocked.length).padStart(2)} net=${summarize(scenarios.map((x) => x.net))} duration=${summarize(scenarios.map((x) => x.duration), 1)}s ppm=${summarize(scenarios.map((x) => x.perMinute), 1)}`);
}

const starter = ships.find((ship) => ship.id === "starter_freighter");
const startPorts = stages[0].unlocked;
const startMissions = [];
for (const pickup of startPorts) {
  for (const delivery of startPorts) {
    if (pickup === delivery) continue;
    for (const cargo of compatibleCargos(starter)) startMissions.push(mission(pickup, pickup, delivery, starter, cargo, 1));
  }
}
const startNet = startMissions.map((item) => item.net);
const firstPortMissions = [
  Math.ceil(750 / Math.max(...startNet)),
  Math.ceil(750 / percentile(startNet, 0.5)),
  Math.ceil(750 / Math.min(...startNet)),
];
assert(firstPortMissions[0] >= 3 && firstPortMissions[2] <= 5, "Antalya must take 3-5 starting missions");
console.log(`\nEARLY_TARGET Antalya 750: best/median/worst missions=${firstPortMissions.join("/")}`);

const earlyPorts = stages[1].unlocked;
const refrigerated = ships.find((ship) => ship.id === "refrigerated_freighter");
const afterAntalyaStarter = [];
for (const pickup of earlyPorts) {
  for (const delivery of earlyPorts) {
    if (pickup === delivery) continue;
    for (const cargo of compatibleCargos(starter)) {
      afterAntalyaStarter.push(mission(pickup, pickup, delivery, starter, cargo, 1));
    }
  }
}
const afterAntalyaNet = afterAntalyaStarter.map((item) => item.net);
const secondShipPrice = shipPurchasePrice(refrigerated.purchaseCost, 1);
const secondShipMissions = [
  Math.ceil(secondShipPrice / Math.max(...afterAntalyaNet)),
  Math.ceil(secondShipPrice / percentile(afterAntalyaNet, 0.5)),
  Math.ceil(secondShipPrice / Math.min(...afterAntalyaNet)),
];
assert(secondShipMissions[0] >= 4 && secondShipMissions[2] <= 8, "Second ship must take 4-8 post-Antalya missions");
console.log(`EARLY_TARGET second ship ${secondShipPrice}: best/median/worst missions=${secondShipMissions.join("/")}`);

console.log("\nSHIP_PRICE_CURVE global owned fleet => starter/refrigerated/bulk");
const priceCurveModels = ["starter_freighter", "refrigerated_freighter", "bulk_carrier"]
  .map((modelId) => ships.find((ship) => ship.id === modelId));
for (const ownedShipCount of [0, 1, 2, 3, 4, 5, 7, 10, 15]) {
  const prices = priceCurveModels.map(
    (ship) => shipPurchasePrice(ship.purchaseCost, ownedShipCount),
  );
  console.log(`${String(ownedShipCount).padStart(2)} ships => ${prices.join("/")}`);
}
assert(
  priceCurveModels.every(
    (ship) => shipPurchasePrice(ship.purchaseCost, 0) === ship.purchaseCost,
  ),
  "Every first ship price must equal its base cost",
);
assert(
  secondShipPrice >= 1200 && secondShipPrice <= 1400,
  "Second ship price must remain near 1300",
);

console.log("\nUPGRADE_PAYBACK at Antalya stage, continuous local missions");
for (const ship of ships.filter((item) => item.requiredLevel <= 2)) {
  const cargo = compatibleCargos(ship);
  const base = [];
  const faster = [];
  const capacity = [];
  for (const pickup of earlyPorts) {
    for (const delivery of earlyPorts) {
      if (pickup === delivery) continue;
      for (const cargoType of cargo) {
        for (let amount = 1; amount <= ship.capacity; amount += 1) {
          base.push(mission(pickup, pickup, delivery, ship, cargoType, amount));
          faster.push(mission(pickup, pickup, delivery, ship, cargoType, amount, 1));
        }
        for (let amount = 1; amount <= ship.capacity + 1; amount += 1) {
          capacity.push(mission(pickup, pickup, delivery, ship, cargoType, amount));
        }
      }
    }
  }
  const hourly = (items) => items.reduce((sum, item) => sum + item.perMinute * 60, 0) / items.length;
  const baseHourly = hourly(base);
  const speedGain = hourly(faster) - baseHourly;
  const capacityGain = hourly(capacity) - baseHourly;
  console.log(`${ship.id}: speed L1 ${ship.speedUpgradeCost} => ${(ship.speedUpgradeCost / speedGain * 60).toFixed(1)} min; capacity L1 ${ship.capacityUpgradeCost} => ${(ship.capacityUpgradeCost / capacityGain * 60).toFixed(1)} min`);
}

console.log("\nPORT_UPGRADE_PAYBACK level 1->2 at each unlock stage");
for (const stage of stages.slice(0, 7)) {
  const targetId = stage.unlocked.at(-1);
  const target = ports.get(targetId);
  if (!target.upgradeCosts.length) continue;
  const before = [];
  const after = [];
  const focusedBefore = [];
  const focusedAfter = [];
  for (const pickup of stage.unlocked) {
    for (const delivery of stage.unlocked) {
      if (pickup === delivery) continue;
      for (const cargo of compatibleCargos(starter)) {
        before.push(mission(pickup, pickup, delivery, starter, cargo, 1));
        after.push(mission(pickup, pickup, delivery, starter, cargo, 1, 0, { [targetId]: 2 }));
        if (pickup === targetId || delivery === targetId) {
          focusedBefore.push(before.at(-1));
          focusedAfter.push(after.at(-1));
        }
      }
    }
  }
  const average = (items) => items.reduce((sum, item) => sum + item.perMinute, 0) / items.length;
  const gainPerMinute = average(after) - average(before);
  const focusedGainPerMinute = average(focusedAfter) - average(focusedBefore);
  console.log(`${targetId.padEnd(12)} cost=${target.upgradeCosts[0]} random_payback=${(target.upgradeCosts[0] / gainPerMinute).toFixed(1)}m focused_payback=${(target.upgradeCosts[0] / focusedGainPerMinute).toFixed(1)}m`);
}

console.log("\nLARGE_CONTRACT same two legs, local pickup (gross bonus vs normal total)");
const contractAdvantages = [];
for (const stage of stages.slice(3, 7)) {
  const ids = stage.unlocked;
  const ratios = [];
  for (const a of ids) for (const b of ids) for (const c of ids) {
    if (a === b || b === c || a === c) continue;
    const cargo = compatibleCargos(starter)[0];
    const first = mission(a, a, b, starter, cargo, 1);
    const second = mission(b, b, c, starter, cargo, 1);
    const contractNet = Math.round((first.gross + second.gross) * 1.08) - first.cost - second.cost;
    ratios.push(contractNet / (first.net + second.net));
  }
  contractAdvantages.push(...ratios.map((ratio) => (ratio - 1) * 100));
  console.log(`${stage.name.padEnd(20)} net advantage=${summarize(ratios.map((ratio) => (ratio - 1) * 100), 1)}%`);
}

assert(Math.min(...contractAdvantages) >= 8 && Math.max(...contractAdvantages) <= 10,
  "Large Contract net advantage must remain a restrained 8-10%");
assert(Math.max(...stageSummaries[0].scenarios.map((item) => item.duration)) < 30,
  "Starting local missions must stay under 30 seconds in the prototype");
assert(Math.max(...stageSummaries[6].scenarios.map((item) => item.duration)) >= 90,
  "The Pire stage must introduce medium-duration missions");

const levelThresholds = [0, 1000, 2400, 4800, 8000, 13000, 20000, 30000, 43000, 60000, 82000, 109000, 142000, 183000, 235000];
const fleetCapacity = [2, 3, 4, 5, 6, 8, 10, 12, 14, 16, 17, 18, 19, 20, 21];
const progression = {
  elapsedMinutes: 0,
  earnedAndSpent: 0,
  companyValue: [...ports.values()].filter((port) => port.unlocked).reduce((sum, port) => sum + port.companyValue, 0),
  unlocked: new Set([...ports.values()].filter((port) => port.unlocked).map((port) => port.id)),
  portLevels: Object.fromEntries([...ports.keys()].map((id) => [id, 1])),
  fleet: [],
  milestones: [],
};

function companyLevel() {
  let level = 1;
  for (let index = 0; index < levelThresholds.length; index += 1) {
    if (progression.companyValue < levelThresholds[index]) break;
    level = index + 1;
  }
  return level;
}

function shipIncomePerMinute(runtime) {
  const ids = [...progression.unlocked];
  const scenarios = [];
  const ship = runtime.model;
  for (const pickup of ids) {
    for (const delivery of ids) {
      if (pickup === delivery) continue;
      for (const cargo of compatibleCargos(ship)) {
        for (let amount = 1; amount <= ship.capacity + runtime.capacityLevel; amount += 1) {
          scenarios.push(mission(
            pickup,
            pickup,
            delivery,
            ship,
            cargo,
            amount,
            runtime.speedLevel,
            progression.portLevels,
          ));
        }
      }
    }
  }
  return scenarios.reduce((sum, scenario) => sum + scenario.perMinute, 0) / scenarios.length;
}

function fleetIncomePerMinute() {
  return progression.fleet.reduce((sum, runtime) => sum + shipIncomePerMinute(runtime), 0);
}

function pay(cost) {
  const income = fleetIncomePerMinute();
  assert(income > 0, "Progression cannot earn cash without a ship");
  progression.elapsedMinutes += cost / income;
  progression.earnedAndSpent += cost;
}

function purchaseShip(model, useStartingCash = false) {
  const price = shipPurchasePrice(model.purchaseCost, progression.fleet.length);
  if (!useStartingCash) pay(price);
  progression.fleet.push({ model, speedLevel: 0, capacityLevel: 0 });
  progression.companyValue += model.companyValue;
  return price;
}

function unlockPort(port) {
  assert(companyLevel() >= port.requiredLevel, `${port.id} is still level-gated`);
  pay(port.unlockCost);
  progression.unlocked.add(port.id);
  progression.companyValue += port.companyValue;
}

function progressionInvestmentCandidates() {
  const level = companyLevel();
  const candidates = [];
  if (progression.fleet.length < fleetCapacity[level - 1]) {
    for (const model of ships.filter((ship) => ship.requiredLevel <= level)) {
      const cost = shipPurchasePrice(model.purchaseCost, progression.fleet.length);
      candidates.push({
        name: `buy ${model.id}`,
        cost,
        value: model.companyValue,
        apply: () => purchaseShip(model),
      });
    }
  }
  for (const [index, runtime] of progression.fleet.entries()) {
    if (runtime.speedLevel < runtime.model.maxSpeedLevel) {
      const cost = Math.round(runtime.model.speedUpgradeCost * 1.7 ** runtime.speedLevel / 10) * 10;
      candidates.push({
        name: `ship ${index + 1} speed`,
        cost,
        value: runtime.model.speedUpgradeValue,
        apply: () => {
          pay(cost);
          runtime.speedLevel += 1;
          progression.companyValue += runtime.model.speedUpgradeValue;
        },
      });
    }
    if (runtime.capacityLevel < runtime.model.maxCapacityLevel) {
      const cost = Math.round(runtime.model.capacityUpgradeCost * 1.8 ** runtime.capacityLevel / 10) * 10;
      candidates.push({
        name: `ship ${index + 1} capacity`,
        cost,
        value: runtime.model.capacityUpgradeValue,
        apply: () => {
          pay(cost);
          runtime.capacityLevel += 1;
          progression.companyValue += runtime.model.capacityUpgradeValue;
        },
      });
    }
  }
  for (const portId of progression.unlocked) {
    const port = ports.get(portId);
    const currentLevel = progression.portLevels[portId];
    if (currentLevel <= port.upgradeCosts.length) {
      const cost = port.upgradeCosts[currentLevel - 1];
      const value = port.upgradeValues[currentLevel - 1];
      candidates.push({
        name: `${portId} level ${currentLevel + 1}`,
        cost,
        value,
        apply: () => {
          pay(cost);
          progression.portLevels[portId] += 1;
          progression.companyValue += value;
        },
      });
    }
  }
  return candidates.filter((candidate) => candidate.value > 0)
    .sort((a, b) => a.cost / a.value - b.cost / b.value || a.cost - b.cost);
}

function advanceToLevel(targetLevel) {
  while (companyLevel() < targetLevel) {
    const investment = progressionInvestmentCandidates()[0];
    assert(investment, `No investment can reach Company Level ${targetLevel}`);
    investment.apply();
  }
}

function milestone(name) {
  progression.milestones.push({
    name,
    minutes: progression.elapsedMinutes,
    level: companyLevel(),
    companyValue: progression.companyValue,
    fleet: progression.fleet.length,
    income: fleetIncomePerMinute(),
  });
}

purchaseShip(starter, true);
milestone("İlk gemi");
unlockPort(ports.get("antalya"));
milestone("Antalya");
purchaseShip(refrigerated);
milestone("Soğutmalı ikinci gemi");
for (const target of [
  { port: "canakkale", level: 3 },
  { port: "istanbul", level: 4 },
  { port: "samsun", level: 5 },
]) {
  advanceToLevel(target.level);
  unlockPort(ports.get(target.port));
  milestone(target.port);
}
advanceToLevel(6);
purchaseShip(ships.find((ship) => ship.id === "bulk_carrier"));
milestone("İlk Dökme Yük Gemisi");
for (const target of [
  { port: "trabzon", level: 6 },
  { port: "pire", level: 7 },
  { port: "varna", level: 8 },
]) {
  advanceToLevel(target.level);
  unlockPort(ports.get(target.port));
  milestone(target.port);
}

console.log("\nDETERMINISTIC_GROWTH CV-efficient investments, continuous average local missions");
for (const item of progression.milestones) {
  console.log(`${item.name.padEnd(24)} t=${item.minutes.toFixed(1).padStart(5)}m level=${item.level} CV=${String(item.companyValue).padStart(5)} fleet=${item.fleet} fleet_ppm=${item.income.toFixed(1)}`);
}
assert(progression.milestones.find((item) => item.name === "Antalya").minutes < 2,
  "Antalya should remain an early-session goal in the prototype");
assert(progression.milestones.find((item) => item.name === "Soğutmalı ikinci gemi").minutes < 5,
  "The second ship should remain an early-session goal in the prototype");
assert(companyLevel() >= 8 && progression.unlocked.has("varna"),
  "The measured growth path must reach the end of the middle-game scope");
console.log("\nECONOMY_BALANCE_AUDIT PASS");
