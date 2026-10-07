-- Independent encounter only. Called by 9461xx/9462xx custom passives.
-- Phase is supplied by the passive belonging to the actual current phase.
-- No HP threshold guesses, global state, filesystem access or coin edits.
local DEBT = "CodexRienDebt"
local GRACE = "BlessingOfIndexPrescriptEnemy"
local MARK = "IndexPrescriptTargetToPersonality"
local SPECIAL = "StackRienSpecialSkill"

function rien_mapped_init()
    -- MSS keeps its pointer-keyed Lua dictionary globally: explicitly reset
    -- on the first-phase passive's native OnInit, never on second-phase Init.
    setldata("Self", "RienHardDebt", 2)
    setldata("Self", "RienHardRound", -1)
    setldata("Self", "RienHardPursuit", -1)
    setldata("Self", "RienHardWrong", 0)
    setldata("Self", "RienHardRight", 0)
    setldata("Self", "RienHardPreviousTargets", {})
end

local function stacks(keyword)
    local best = getbuff("Self", keyword, "stack") or 0
    local parts = {}
    if type(parts) == "table" then
        for _, part in ipairs(parts) do
            best = math.max(best, getbuff(part, keyword, "stack") or 0)
        end
    end
    return best
end

local function debt()
    return math.max(0, math.min(6, getldata("Self", "RienHardDebt") or 2))
end

local function put_debt(value)
    value = math.max(0, math.min(6, value))
    setldata("Self", "RienHardDebt", value)
    destroybuff("Self", DEBT, 2)
    if value > 0 then buff("Self", DEBT, value, 0, 0) end
end

local function once_per_round(key)
    local current = getround()
    if getldata("Self", key) == current then return false end
    setldata("Self", key, current)
    return true
end

function rien_mapped_round(phase)
    if not once_per_round("RienHardRound") then return end
    put_debt(debt() + 1)
    setldata("Self", "RienHardWrong", 0)
    setldata("Self", "RienHardRight", 0)
    local grace = math.min(stacks(GRACE), 9)
    local speed = math.min(math.floor(grace / 3) + math.floor(debt() / 3), 5)
    if speed > 0 then
        addability("Self", "MinSpeedAdder", speed, 1, 0)
        addability("Self", "MaxSpeedAdder", speed, 1, 0)
    end
    refreshspeed("Self")
    if phase == 2 then
        local amount = math.min(600, grace * 40 + debt() * 40)
        if amount > 0 then shield("Self", amount) end
    end
end

function rien_mapped_clash(phase)
    resetadders()
    local base = phase == 1 and -1 or 0
    clash(base)
    if (getbuff("Target", MARK, "stack") or 0) > 0 then return end
    clash(base + (phase == 2 and 3 or 2) + math.floor(debt() / 3))
    local wrong = getldata("Self", "RienHardWrong") or 0
    if wrong < 3 then
        setldata("Self", "RienHardWrong", wrong + 1)
        put_debt(debt() + 1)
    end
end

function rien_mapped_defeated()
    if (getbuff("Target", MARK, "stack") or 0) <= 0 then return end
    local right = getldata("Self", "RienHardRight") or 0
    if right >= 3 then return end
    setldata("Self", "RienHardRight", right + 1)
    put_debt(debt() - 2)
end

function rien_mapped_damage(phase)
    resetadders()
    -- StackRienSpecialSkill IS the actual Hermes counter. The reference mod's
    -- ProcurationHermesRien name was a nonexistent placeholder, not a second buff.
    local unit = phase == 2 and 8 or 5
    local limit = phase == 2 and 24 or 15
    local amount = math.min(math.floor(stacks(SPECIAL) / 3) * unit, limit) + debt() * 3
    if amount > 0 then dmgmult(amount) end
end

function rien_mapped_pursuit(phase)
    if not once_per_round("RienHardPursuit") then return end
    local karma = stacks(phase == 2 and "KarmaOfIndexRien_2Phase" or "KarmaOfIndexRien")
    local amount = 0
    if phase == 1 and karma >= 20 then amount = karma >= 40 and 2 or 1 end
    if phase == 2 and karma >= 60 then amount = math.min(3, math.floor(karma / 60)) end
    if amount == 0 then return end
    local previous = getldata("Self", "RienHardPreviousTargets") or {}
    local candidates = {}
    local all = selecttargets("LivesEnemyNoCores99") or {}
    for _, target in ipairs(all) do
        local seen = false
        for _, prior in ipairs(previous) do
            if issameunit(target, prior) == 1 then seen = true end
        end
        if not seen then candidates[#candidates + 1] = target end
    end
    -- If every surviving Sinner was selected last time, deliberately skip once.
    -- Do not punish a solo/two-Sinner team with unavoidable repeated targeting.
    local selected = {}
    for _ = 1, amount do
        if #candidates == 0 then break end
        local idx = random(1, #candidates)
        local target = candidates[idx]
        buff(target, "Binding", phase == 2 and 2 or 1, 0, 1)
        if debt() >= 4 then buff(target, "Vulnerable", phase == 2 and 2 or 1, 0, 1) end
        selected[#selected + 1] = target
        table.remove(candidates, idx)
    end
    setldata("Self", "RienHardPreviousTargets", selected)
end

function rien_mapped_noop() end
