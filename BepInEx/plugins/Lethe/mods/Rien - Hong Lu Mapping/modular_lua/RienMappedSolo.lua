-- Solo-only, two-round variety check. No HP, coin or permanent power edits.
local INQUIRY = "CodexRienInquiry"

local function solo_clear()
    setldata("Self", "RienSoloStart", -1)
    setldata("Self", "RienSoloPlayer", "")
    setldata("Self", "RienSoloSkills", {})
    setldata("Self", "RienSoloPending", 0)
    setldata("Self", "RienSoloDue", -1)
    destroybuff("Self", INQUIRY, 2)
end

function rien_mapped_solo_init()
    solo_clear()
    setldata("Self", "RienSoloRound", -1)
    setldata("Self", "RienSoloEnd", -1)
    setldata("Self", "RienSoloWinningSkill", 0)
end

local function lone_player()
    local players = selecttargets("LivesEnemyNoParts99") or {}
    if #players ~= 1 then return nil end
    return players[1]
end

local function same_player(player)
    local prior = getldata("Self", "RienSoloPlayer")
    return prior ~= nil and prior ~= "" and issameunit(player, prior) == 1
end

local function wins()
    local skills = getldata("Self", "RienSoloSkills") or {}
    local count = 0
    for _, _ in pairs(skills) do count = count + 1 end
    return math.min(count, 2)
end

local function show_remaining()
    destroybuff("Self", INQUIRY, 2)
    local remaining = 2 - wins()
    if remaining > 0 then buff("Self", INQUIRY, remaining, 0, 0) end
end

function rien_mapped_solo_round()
    local round = getround()
    if getldata("Self", "RienSoloRound") == round then return end
    setldata("Self", "RienSoloRound", round)
    local player = lone_player()
    if player == nil then solo_clear(); return end
    if not same_player(player) then
        solo_clear()
        setldata("Self", "RienSoloPlayer", player)
    end
    local due = getldata("Self", "RienSoloDue") or -1
    local pending = getldata("Self", "RienSoloPending") or 0
    -- Never carry a missed judgment over a phase jump to an unrelated round.
    if due == round then
        if pending == 1 then
            buff("Self", "Vulnerable", 1, 0, 0)
        elseif pending == -1 then
            buff("Self", "ParryingResultUp", 2, 0, 0)
            shield("Self", 300)
        end
    end
    if due <= round then
        setldata("Self", "RienSoloPending", 0)
        setldata("Self", "RienSoloDue", -1)
    end
    if (getldata("Self", "RienSoloStart") or -1) < 0 then
        setldata("Self", "RienSoloStart", round)
        setldata("Self", "RienSoloSkills", {})
    end
    show_remaining()
end

function rien_mapped_solo_win()
    if (getldata("Self", "RienSoloStart") or -1) < 0 then return end
    local player = lone_player()
    if player == nil or not same_player(player) then solo_clear(); return end
    if issameunit(player, "TargetCore") ~= 1 then return end
    -- Populated from the REAL opposing BattleActionModel in managed Enact.
    -- A non-attack/invalid action is explicitly written as 0, never reused.
    local skill = getldata("Self", "RienSoloWinningSkill") or 0
    if skill <= 0 then return end
    local skills = getldata("Self", "RienSoloSkills") or {}
    if wins() < 2 then skills[tostring(skill)] = true end
    setldata("Self", "RienSoloSkills", skills)
    show_remaining()
end

function rien_mapped_solo_end()
    local round = getround()
    if getldata("Self", "RienSoloEnd") == round then return end
    setldata("Self", "RienSoloEnd", round)
    local player = lone_player()
    if player == nil or not same_player(player) then solo_clear(); return end
    local start = getldata("Self", "RienSoloStart") or -1
    if start < 0 or round < start + 1 then return end
    setldata("Self", "RienSoloPending", wins() >= 2 and 1 or -1)
    setldata("Self", "RienSoloDue", round + 1)
    setldata("Self", "RienSoloStart", -1)
    destroybuff("Self", INQUIRY, 2)
end
