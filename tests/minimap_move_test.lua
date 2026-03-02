-- Tests for minimap movement and taint behavior with BlizzMove

-- MinimapCluster existence
test("MinimapCluster frame exists", function()
    assertNotNil(MinimapCluster)
    assertTrue(MinimapCluster:IsObjectType("Frame"))
end)

test("Minimap frame exists as child of MinimapCluster", function()
    assertNotNil(Minimap)
    assertTrue(Minimap:IsObjectType("Minimap"))
end)

-- Movement basics
test("SetMovable and IsMovable work on MinimapCluster", function()
    local wasMovable = MinimapCluster:IsMovable()
    MinimapCluster:SetMovable(true)
    assertTrue(MinimapCluster:IsMovable())
    MinimapCluster:SetMovable(false)
    assertFalse(MinimapCluster:IsMovable())
    -- restore
    MinimapCluster:SetMovable(wasMovable)
end)

test("StartMoving succeeds when frame is movable", function()
    local f = CreateFrame("Frame", "BlizzMoveTestMover", UIParent)
    f:SetSize(100, 100)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    -- should not error
    f:StartMoving()
    f:StopMovingOrSizing()
end)

test("StartMoving is no-op when frame is not movable", function()
    local f = CreateFrame("Frame", "BlizzMoveTestNoMove", UIParent)
    f:SetSize(100, 100)
    f:SetPoint("CENTER")
    f:SetMovable(false)
    -- should not error, just silently do nothing
    f:StartMoving()
    f:StopMovingOrSizing()
end)

-- BlizzMove does not register MinimapCluster
test("BlizzMove does not register MinimapCluster by default", function()
    local frames = BlizzMoveAPI:GetRegisteredFrames("BlizzMove")
    assertNil(frames["MinimapCluster"])
end)

-- But we can register it via API
test("BlizzMoveAPI can register MinimapCluster", function()
    BlizzMoveAPI:RegisterFrames({
        ["MinimapCluster"] = {
            SubFrames = {
                ["MinimapContainer"] = { Detachable = true },
            },
        },
    })
    local frames = BlizzMoveAPI:GetRegisteredFrames("BlizzMove")
    assertNotNil(frames["MinimapCluster"])
end)

-- Taint checks
test("issecure returns false in addon context", function()
    -- Test code runs as addon (tainted), so issecure should be false
    assertFalse(issecure())
end)

test("SetMovable from addon code taints the variable", function()
    local f = CreateFrame("Frame", "BlizzMoveTaintTestFrame", UIParent)
    f:SetSize(50, 50)
    f:SetPoint("CENTER")
    f:SetMovable(true)

    -- The frame was created and modified by addon (tainted) code
    -- issecurevariable on the global should reflect taint
    local secure, taintSource = issecurevariable("BlizzMoveTaintTestFrame")
    assertFalse(secure)
    assertNotNil(taintSource)
end)

test("issecurevariable detects taint on addon-created globals", function()
    -- BlizzMoveAPI is set by BlizzMove addon code, should be tainted
    local secure, taintSource = issecurevariable("BlizzMoveAPI")
    assertFalse(secure)
    assertNotNil(taintSource)
end)

test("issecurevariable shows Blizzard globals as secure", function()
    -- UIParent is created by Blizzard code (untainted)
    local secure, taintSource = issecurevariable("UIParent")
    assertTrue(secure)
    assertNil(taintSource)
end)

test("hooksecurefunc works on global functions", function()
    local hookCalled = false
    hooksecurefunc("GetBuildInfo", function()
        hookCalled = true
    end)
    GetBuildInfo()
    assertTrue(hookCalled)
end)

-- ClearAllPoints / SetPoint from addon code (movement simulation)
test("ClearAllPoints and SetPoint work from addon code", function()
    local f = CreateFrame("Frame", "BlizzMoveMoveTest", UIParent)
    f:SetSize(100, 100)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    -- Simulate what BlizzMove does: clear points and reposition
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 50, -50)

    local point = f:GetPoint(1)
    assertEquals("TOPLEFT", point)
end)

test("Moving MinimapCluster via SetPoint works", function()
    local numPoints = MinimapCluster:GetNumPoints()
    -- Save original position
    local origPoint, origRelTo, origRelPoint, origX, origY
    if numPoints > 0 then
        origPoint, origRelTo, origRelPoint, origX, origY = MinimapCluster:GetPoint(1)
    end

    -- Move it like BlizzMove would
    MinimapCluster:ClearAllPoints()
    MinimapCluster:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -100)

    local point, _, relPoint, x, y = MinimapCluster:GetPoint(1)
    assertEquals("TOPLEFT", point)
    assertEquals("TOPLEFT", relPoint)
    assertEquals(100, x)
    assertEquals(-100, y)

    -- Restore
    MinimapCluster:ClearAllPoints()
    if origPoint then
        MinimapCluster:SetPoint(origPoint, origRelTo, origRelPoint, origX, origY)
    end
end)
