-- Solo-only, two-round variety check. No HP, coin or permanent power edits.
local INQUIRY = "CodexRienInquiry"

local function solo_clear()
    setldata("SelfCore", "RienSoloStart", -1)
    setldata("SelfCore", "RienSoloPlayer", "")
    setldata("SelfCore", "RienSoloSkills", {})
    setldata("SelfCore", "RienSoloPending", 0)
    setldata("SelfCore", "RienSoloDue", -1)
    destroybuff("SelfCore", INQUIRY, 2)
end

function rien_solo_init()
    solo_clear()
    setldata("SelfCore", "RienSoloRound", -1)
    setldata("SelfCore", "RienSoloEnd", -1)
    setldata("SelfCore", "RienSoloWinningSkill", 0)
end

local function lone_player()
    local players = selecttargets("LivesEnemy99") or {}
    if #players ~= 1 then return nil end
    return players[1]
end

local function same_player(player)
    local prior = getldata("SelfCore", "RienSoloPlayer")
    return prior ~= nil and prior ~= "" and issameunit(player, prior) == 1
end

local function wins()
    local skills = getldata("SelfCore", "RienSoloSkills") or {}
    local count = 0
    for _, _ in pairs(skills) do count = count + 1 end
    return math.min(count, 2)
end

local function show_remaining()
    destroybuff("SelfCore", INQUIRY, 2)
    local remaining = 2 - wins()
    if remaining > 0 then buff("SelfCore", INQUIRY, remaining, 0, 0) end
end

function rien_solo_round()
    local round = getround()
    if getldata("SelfCore", "RienSoloRound") == round then return end
    setldata("SelfCore", "RienSoloRound", round)
    local player = lone_player()
    if player == nil then solo_clear(); return end
    if not same_player(player) then
        solo_clear()
        setldata("SelfCore", "RienSoloPlayer", player)
    end
    local due = getldata("SelfCore", "RienSoloDue") or -1
    local pending = getldata("SelfCore", "RienSoloPending") or 0
    -- Never carry a missed judgment over a phase jump to an unrelated round.
    if due == round then
        if pending == 1 then
            buff("SelfCore", "Vulnerable", 1, 0, 0)
        elseif pending == -1 then
            buff("SelfCore", "ParryingResultUp", 2, 0, 0)
            shield("SelfCore", 300)
        end
    end
    if due <= round then
        setldata("SelfCore", "RienSoloPending", 0)
        setldata("SelfCore", "RienSoloDue", -1)
    end
    if (getldata("SelfCore", "RienSoloStart") or -1) < 0 then
        setldata("SelfCore", "RienSoloStart", round)
        setldata("SelfCore", "RienSoloSkills", {})
    end
    show_remaining()
end

function rien_solo_win()
    if (getldata("SelfCore", "RienSoloStart") or -1) < 0 then return end
    local player = lone_player()
    if player == nil or not same_player(player) then solo_clear(); return end
    if issameunit(player, "Target") ~= 1 then return end
    -- Populated from the REAL opposing BattleActionModel in managed Enact.
    -- A non-attack/invalid action is explicitly written as 0, never reused.
    local skill = getldata("SelfCore", "RienSoloWinningSkill") or 0
    if skill <= 0 then return end
    local skills = getldata("SelfCore", "RienSoloSkills") or {}
    if wins() < 2 then skills[tostring(skill)] = true end
    setldata("SelfCore", "RienSoloSkills", skills)
    show_remaining()
end

function rien_solo_end()
    local round = getround()
    if getldata("SelfCore", "RienSoloEnd") == round then return end
    setldata("SelfCore", "RienSoloEnd", round)
    local player = lone_player()
    if player == nil or not same_player(player) then solo_clear(); return end
    local start = getldata("SelfCore", "RienSoloStart") or -1
    if start < 0 or round < start + 1 then return end
    setldata("SelfCore", "RienSoloPending", wins() >= 2 and 1 or -1)
    setldata("SelfCore", "RienSoloDue", round + 1)
    setldata("SelfCore", "RienSoloStart", -1)
    destroybuff("SelfCore", INQUIRY, 2)
end
