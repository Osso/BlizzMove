-- Combat lockdown tests for protected frame enforcement
--
-- Test matrix:
--   protected + combat + insecure caller → BLOCKED
--   protected + combat + secure caller  → ALLOWED (not testable from addon code)
--   protected + no combat               → ALLOWED
--   non-protected + combat              → ALLOWED

-- Helper: create a test frame and optionally protect it
local function make_test_frame(name, protected)
    local f = CreateFrame("Frame", name, UIParent)
    f:SetSize(100, 100)
    f:SetPoint("CENTER")
    if protected then
        A_Admin.SetFrameProtected(name, true)
    end
    return f
end

-- ---------------------------------------------------------------------------
-- InCombatLockdown / IsProtected basics
-- ---------------------------------------------------------------------------

test("InCombatLockdown returns false by default", function()
    assertFalse(InCombatLockdown())
end)

test("A_Admin.SetInCombat toggles InCombatLockdown", function()
    A_Admin.SetInCombat(true)
    assertTrue(InCombatLockdown())
    A_Admin.SetInCombat(false)
    assertFalse(InCombatLockdown())
end)

test("A_Admin.SetFrameProtected marks frame as protected", function()
    local f = make_test_frame("LockdownProtectTest", true)
    local fromInsecure, isProtected = f:IsProtected()
    assertTrue(isProtected)
end)

test("IsProtected returns same values regardless of combat state", function()
    local f = make_test_frame("LockdownInsecureTest", true)
    -- Out of combat
    local isProtected, isExplicit = f:IsProtected()
    assertTrue(isProtected)
    assertTrue(isExplicit)
    -- In combat: same values (IsProtected is a static property, not combat-dependent)
    A_Admin.SetInCombat(true)
    isProtected, isExplicit = f:IsProtected()
    assertTrue(isProtected)
    assertTrue(isExplicit)
    A_Admin.SetInCombat(false)
end)

-- ---------------------------------------------------------------------------
-- SetPoint blocked on protected frame in combat
-- ---------------------------------------------------------------------------

test("SetPoint works on protected frame outside combat", function()
    local f = make_test_frame("LockdownSetPointOOC", true)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -10)
    local point = f:GetPoint(1)
    assertEquals("TOPLEFT", point)
end)

test("SetPoint blocked on protected frame in combat", function()
    local f = make_test_frame("LockdownSetPointIC", true)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    A_Admin.SetInCombat(true)
    -- Try to move it — should silently fail
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 50, -50)
    -- ClearAllPoints was also blocked, so original point should remain
    local point, _, _, x, y = f:GetPoint(1)
    assertEquals("CENTER", point)
    assertEquals(0, x)
    assertEquals(0, y)
    A_Admin.SetInCombat(false)
end)

test("SetPoint works on non-protected frame in combat", function()
    local f = make_test_frame("LockdownSetPointNonProt", false)
    A_Admin.SetInCombat(true)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -20)
    local point = f:GetPoint(1)
    assertEquals("TOPLEFT", point)
    A_Admin.SetInCombat(false)
end)

-- ---------------------------------------------------------------------------
-- Show/Hide blocked on protected frame in combat
-- ---------------------------------------------------------------------------

test("Show/Hide work on protected frame outside combat", function()
    local f = make_test_frame("LockdownVisOOC", true)
    f:Show()
    assertTrue(f:IsShown())
    f:Hide()
    assertFalse(f:IsShown())
    f:Show()
end)

test("Hide blocked on protected frame in combat", function()
    local f = make_test_frame("LockdownHideIC", true)
    f:Show()
    assertTrue(f:IsShown())
    A_Admin.SetInCombat(true)
    f:Hide() -- should be blocked
    assertTrue(f:IsShown()) -- still shown
    A_Admin.SetInCombat(false)
end)

test("Show blocked on protected frame in combat", function()
    local f = make_test_frame("LockdownShowIC", true)
    f:Hide()
    assertFalse(f:IsShown())
    A_Admin.SetInCombat(true)
    f:Show() -- should be blocked
    assertFalse(f:IsShown()) -- still hidden
    A_Admin.SetInCombat(false)
end)

test("SetShown blocked on protected frame in combat", function()
    local f = make_test_frame("LockdownSetShownIC", true)
    f:Show()
    A_Admin.SetInCombat(true)
    f:SetShown(false) -- should be blocked
    assertTrue(f:IsShown())
    A_Admin.SetInCombat(false)
end)

-- ---------------------------------------------------------------------------
-- StartMoving blocked on protected frame in combat
-- ---------------------------------------------------------------------------

test("StartMoving works on protected frame outside combat", function()
    local f = make_test_frame("LockdownMoveOOC", true)
    f:SetMovable(true)
    f:StartMoving()
    f:StopMovingOrSizing()
end)

test("StartMoving blocked on protected frame in combat", function()
    local f = make_test_frame("LockdownMoveIC", true)
    f:SetMovable(true)
    A_Admin.SetInCombat(true)
    f:StartMoving() -- should be blocked (no error, just no-op)
    f:StopMovingOrSizing()
    A_Admin.SetInCombat(false)
end)

-- ---------------------------------------------------------------------------
-- Strata/level blocked on protected frame in combat
-- ---------------------------------------------------------------------------

test("SetFrameStrata blocked on protected frame in combat", function()
    local f = make_test_frame("LockdownStrataIC", true)
    f:SetFrameStrata("MEDIUM")
    A_Admin.SetInCombat(true)
    f:SetFrameStrata("HIGH") -- should be blocked
    assertEquals("MEDIUM", f:GetFrameStrata())
    A_Admin.SetInCombat(false)
end)

test("SetFrameLevel blocked on protected frame in combat", function()
    local f = make_test_frame("LockdownLevelIC", true)
    f:SetFrameLevel(5)
    A_Admin.SetInCombat(true)
    f:SetFrameLevel(99) -- should be blocked
    assertEquals(5, f:GetFrameLevel())
    A_Admin.SetInCombat(false)
end)

-- ---------------------------------------------------------------------------
-- ADDON_ACTION_BLOCKED event fires
-- ---------------------------------------------------------------------------

test("ADDON_ACTION_BLOCKED fires when action is blocked", function()
    local f = make_test_frame("LockdownEventTest", true)
    f:Show()

    local blocked_addon, blocked_func
    local listener = CreateFrame("Frame")
    listener:RegisterEvent("ADDON_ACTION_BLOCKED")
    listener:SetScript("OnEvent", function(self, event, addon, func)
        blocked_addon = addon
        blocked_func = func
    end)

    A_Admin.SetInCombat(true)
    f:Hide() -- should be blocked and fire event
    A_Admin.SetInCombat(false)

    assertNotNil(blocked_func)
    assertContains(blocked_func, "Hide")
    listener:UnregisterEvent("ADDON_ACTION_BLOCKED")
end)

-- ---------------------------------------------------------------------------
-- Cleanup: make sure combat is off at end of test file
-- ---------------------------------------------------------------------------

test("combat state is clean after tests", function()
    A_Admin.SetInCombat(false)
    assertFalse(InCombatLockdown())
end)
