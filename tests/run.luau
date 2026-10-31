local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Rules = require("../src/Rules")
local count = 0
local function test(name, callback)
    local ok, err = pcall(callback)
    assert(ok, name .. ": " .. tostring(err))
    count += 1
    print("PASS " .. name)
end
local function rejects(callback)
    assert(not pcall(callback), "expected an error")
end
for _, name in ipairs(fs.readDir("src")) do
    if name:match("%.luau$") then luau.compile(fs.readFile("src/" .. name)) end
end


local gameRoot = { Name = "Game", children = {} }
function gameRoot:IsA(class) return class == "DataModel" end
local function object(name, parent, class)
    local node = { Name = name, Parent = parent, ClassName = class or "Folder", children = {}, tags = {}, Locked = false, CollisionGroup = "Default" }
    function node:IsA(candidate)
        if candidate == self.ClassName then return true end
        if candidate == "BasePart" then return self.ClassName == "Part" end
        if candidate == "WorldRoot" then return self.ClassName == "WorldModel" or self.ClassName == "Workspace" end
        if candidate == "Model" then return self.ClassName == "WorldModel" or self.ClassName == "Workspace" end
        if candidate == "JointInstance" then return self.ClassName == "Weld" or self.ClassName == "Motor6D" end
        return false
    end
    function node:IsDescendantOf(ancestor)
        local cursor = self.Parent
        while cursor do if cursor == ancestor then return true end cursor = cursor.Parent end
        return false
    end
    function node:FindFirstAncestorWhichIsA(class)
        local cursor = self.Parent
        while cursor do if cursor:IsA(class) then return cursor end cursor = cursor.Parent end
        return nil
    end
    function node:GetChildren() return self.children end
    function node:GetFullName()
        local names, cursor = {}, self
        while cursor and cursor ~= gameRoot do table.insert(names, 1, cursor.Name) cursor = cursor.Parent end
        return table.concat(names, ".")
    end
    function node:HasTag(tag) return self.tags[tag] == true end
    function node:AddTag(tag) self.tags[tag] = true end
    function node:RemoveTag(tag) self.tags[tag] = nil end
    if parent then table.insert(parent.children, node) end
    return node
end
local world = object("Workspace", gameRoot, "Workspace")
local groups = { Default = true, Scenery = true }
local function readGroups()
    local result = {}
    for name in pairs(groups) do table.insert(result, { name = name, mask = 0 }) end
    return result
end
function world:GetRegisteredCollisionGroups() return readGroups() end
function gameRoot:GetService(name)
    assert(name == "PhysicsService")
    return { GetRegisteredCollisionGroups = readGroups }
end
local Scope = luau.load(fs.readFile("src/Scope.luau"), { environment = { game = gameRoot } })()
local modules = { Rules = Rules, Scope = Scope }
local Adapter = luau.load(fs.readFile("src/Adapter.luau"), { environment = {
    require = function(name) assert(modules[name]) return modules[name] end,
    script = { Parent = { Rules = "Rules", Scope = "Scope" } }, game = gameRoot, workspace = world,
} })()

test("scope deduplicates overlapping roots", function()
    local folder = object("Folder", world)
    local a, b = object("A", folder), object("B", folder)
    local targets, scanned = Scope.collect({ folder, a }, true, function() return true end)
    assert(#targets == 3 and scanned == 3 and targets[1] == folder and targets[2] == b and targets[3] == a)
    local only = Scope.collect({ folder }, false, function() return true end)
    assert(#only == 1)
end)
test("scope rejects detached roots, services and empty selections", function()
    rejects(function() Scope.collect({}, true, function() return true end) end)
    rejects(function() Scope.collect({ world }, true, function() return true end) end)
    rejects(function() Scope.collect({ object("Detached", nil) }, true, function() return true end) end)
end)
test("scope limits discovered objects before returning partial results", function()
    local folder = object("Folder", world)
    object("A", folder) object("B", folder)
    rejects(function() Scope.collect({ folder }, true, function() return false end, { maxNodes = 2, maxTargets = 2 }) end)
end)
test("scope target limit is independent of scan limit", function()
    local folder = object("Folder", world)
    object("A", folder) object("B", folder)
    rejects(function() Scope.collect({ folder }, true, function() return true end, { maxNodes = 10, maxTargets = 2 }) end)
end)

test("unset ObjectValues are optional review findings", function()
    local folder = object("Folder", world)
    object("Link", folder, "ObjectValue")
    assert(Adapter.scan({ folder }, true).findings[1].code == "UNSET")
    assert(Adapter.scan({ folder }, false).total == 0)
end)
test("valid references outside the scanned scope are accepted", function()
    local folder = object("Folder", world)
    local link = object("Link", folder, "ObjectValue")
    link.Value = object("Elsewhere", world, "Part")
    assert(Adapter.scan({ folder }, true).total == 0)
    link.Value = gameRoot
    assert(Adapter.scan({ folder }, true).total == 0)
end)
test("detached reference targets are reported without modifying them", function()
    local link = object("Link", world, "ObjectValue")
    local target = object("Detached", nil)
    link.Value = target
    local result = Adapter.scan({ link }, true)
    assert(result.findings[1].code == "DETACHED" and link.Value == target and target.Parent == nil)
end)
test("models without PrimaryPart are not treated as broken", function()
    local model = object("Model", world, "Model")
    assert(Adapter.scan({ model }, true).total == 0)
    model.PrimaryPart = object("Outside", world, "Part")
    assert(Adapter.scan({ model }, true).findings[1].code == "OUTSIDE_MODEL")
end)
test("beam and weld same-endpoint findings are reported once", function()
    local beam = object("Beam", world, "Beam")
    local attachment = object("Attachment", world, "Attachment")
    beam.Attachment0 = attachment beam.Attachment1 = attachment
    local result = Adapter.scan({ beam }, true)
    assert(result.total == 1 and result.findings[1].code == "SAME_ENDPOINT")
    local weld = object("Weld", world, "Weld")
    local part = object("Part", world, "Part")
    weld.Part0 = part weld.Part1 = part
    assert(Adapter.scan({ weld }, true).findings[1].code == "SAME_ENDPOINT")
end)
test("supported two-attachment constraints are checked", function()
    local hinge = object("Hinge", world, "HingeConstraint")
    assert(Adapter.scan({ hinge }, true).total == 2)
    local align = object("Align", world, "AlignPosition")
    assert(Adapter.scan({ align }, true).total == 0)
end)
test("reported findings are capped while total counts stay accurate", function()
    local folder = object("Folder", world)
    for index = 1, 105 do object(tostring(index), folder, "ObjectValue") end
    local result = Adapter.scan({ folder }, true)
    assert(result.total == 105 and #result.findings == 100 and result.checked == 105 and result.scanned == 106)
end)
test("wrong reference types are classified by the pure rules", function()
    local result = Rules.analyze({ { target = {}, path = "Example", references = {
        { property = "Part0", present = true, attached = true, validType = false, withinOwner = true },
    } } }, true, 1)
    assert(result.findings[1].code == "WRONG_TYPE")
    rejects(function() Rules.analyze({}, true, 0) end)
end)

print(string.format("%d checks passed", count))
