-- BlizzMove addon integration tests

-- Addon loaded successfully
test("BlizzMove addon is loaded", function()
    local loaded = C_AddOns.IsAddOnLoaded("BlizzMove")
    assertTrue(loaded)
end)

-- LibStub available (Ace3 dependency)
test("LibStub is available", function()
    assertNotNil(LibStub)
    assertType("table", LibStub)
end)

-- Ace3 core libs loaded
test("AceAddon-3.0 is loaded", function()
    local addon = LibStub("AceAddon-3.0", true)
    assertNotNil(addon)
end)

test("AceEvent-3.0 is loaded", function()
    local lib = LibStub("AceEvent-3.0", true)
    assertNotNil(lib)
end)

test("AceHook-3.0 is loaded", function()
    local lib = LibStub("AceHook-3.0", true)
    assertNotNil(lib)
end)

-- BlizzMove addon object exists
test("BlizzMove addon object exists via AceAddon", function()
    local addon = LibStub("AceAddon-3.0"):GetAddon("BlizzMove")
    assertNotNil(addon)
end)

-- BlizzMoveAPI global
test("BlizzMoveAPI global is available", function()
    assertNotNil(BlizzMoveAPI)
    assertType("table", BlizzMoveAPI)
end)

test("BlizzMoveAPI:GetVersion returns version string", function()
    local rawVersion, mayor, minor, patch, versionInt = BlizzMoveAPI:GetVersion()
    assertNotNil(rawVersion)
    assertType("string", rawVersion)
end)

-- FakeUIParent created
test("BlizzMove_FakeUIParent frame exists", function()
    local fake = _G["BlizzMove_FakeUIParent"]
    assertNotNil(fake)
    assertTrue(fake:IsObjectType("Frame"))
end)

-- Frame registration API
test("BlizzMoveAPI:GetRegisteredAddOns returns a table", function()
    local addons = BlizzMoveAPI:GetRegisteredAddOns()
    assertNotNil(addons)
    assertType("table", addons)
end)

test("BlizzMove registers Blizzard frames from Frames.lua", function()
    local addons = BlizzMoveAPI:GetRegisteredAddOns()
    -- BlizzMove registers frames under its own name for FrameXML frames
    assertNotNil(addons["BlizzMove"])
end)

test("BlizzMoveAPI:GetRegisteredFrames returns known frames", function()
    local frames = BlizzMoveAPI:GetRegisteredFrames("BlizzMove")
    assertNotNil(frames)
    assertType("table", frames)
    -- AddonList is one of the basic frames registered in Frames.lua
    assertNotNil(frames["AddonList"])
end)

-- RegisterFrames API
test("BlizzMoveAPI:RegisterFrames registers a custom frame", function()
    BlizzMoveAPI:RegisterFrames({
        ["BlizzMoveTestFrame1"] = {},
    })
    local frames = BlizzMoveAPI:GetRegisteredFrames("BlizzMove")
    assertNotNil(frames["BlizzMoveTestFrame1"])
end)

-- RegisterAddOnFrames API
test("BlizzMoveAPI:RegisterAddOnFrames registers addon frames", function()
    BlizzMoveAPI:RegisterAddOnFrames({
        ["TestAddon_BlizzMove"] = {
            ["TestAddonFrame1"] = {},
        },
    })
    local addons = BlizzMoveAPI:GetRegisteredAddOns()
    assertNotNil(addons["TestAddon_BlizzMove"])

    local frames = BlizzMoveAPI:GetRegisteredFrames("TestAddon_BlizzMove")
    assertNotNil(frames["TestAddonFrame1"])
end)

-- Frame disable/enable
test("BlizzMoveAPI:IsFrameDisabled returns false for enabled frame", function()
    local disabled = BlizzMoveAPI:IsFrameDisabled("BlizzMove", "AddonList")
    assertFalse(disabled)
end)

test("BlizzMoveAPI:SetFrameDisabled can disable and re-enable", function()
    BlizzMoveAPI:SetFrameDisabled("BlizzMove", "AddonList", true)
    assertTrue(BlizzMoveAPI:IsFrameDisabled("BlizzMove", "AddonList"))

    BlizzMoveAPI:SetFrameDisabled("BlizzMove", "AddonList", false)
    assertFalse(BlizzMoveAPI:IsFrameDisabled("BlizzMove", "AddonList"))
end)

-- Frame validation (via internal addon object)
test("BlizzMove validates frame names", function()
    local addon = LibStub("AceAddon-3.0"):GetAddon("BlizzMove")
    assertTrue(addon:ValidateFrameName("SomeFrame"))
    assertFalse(addon:ValidateFrameName(""))
end)

test("BlizzMove validates frame data with SubFrames", function()
    local addon = LibStub("AceAddon-3.0"):GetAddon("BlizzMove")
    local valid = addon:ValidateFrame("ParentFrame", {
        SubFrames = {
            ["ChildFrame"] = { Detachable = true },
        },
    })
    assertTrue(valid)
end)

test("BlizzMove rejects invalid SubFrames type", function()
    local addon = LibStub("AceAddon-3.0"):GetAddon("BlizzMove")
    -- BlizzMove calls pairs() on SubFrames before type-checking, so it errors
    assertError(function()
        addon:ValidateFrame("BadFrame", {
            SubFrames = "not a table",
        })
    end)
end)

test("BlizzMove validates version range constraints", function()
    local addon = LibStub("AceAddon-3.0"):GetAddon("BlizzMove")

    -- Valid range
    local valid = addon:ValidateFrame("RangeFrame", {
        VersionRanges = { { Min = 100000, Max = 120000 } },
    })
    assertTrue(valid)

    -- Invalid: Max < Min
    valid = addon:ValidateFrame("BadRange", {
        VersionRanges = { { Min = 120000, Max = 100000 } },
    })
    assertFalse(valid)
end)
