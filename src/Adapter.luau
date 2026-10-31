local Rules = require(script.Parent.Rules)
local Scope = require(script.Parent.Scope)
local Adapter = {}
local twoAttachmentConstraints = {
    HingeConstraint = true, BallSocketConstraint = true, RopeConstraint = true,
    RodConstraint = true, SpringConstraint = true, RigidConstraint = true,
}

local function properties(object)
    if object:IsA("ObjectValue") then return { { "Value" } } end
    if object:IsA("Model") then
        return if object.PrimaryPart then { { "PrimaryPart", "BasePart", true } } else {}
    end
    if object:IsA("Beam") or object:IsA("Trail") or twoAttachmentConstraints[object.ClassName] then
        return { { "Attachment0", "Attachment" }, { "Attachment1", "Attachment" } }
    end
    if object:IsA("JointInstance") or object:IsA("WeldConstraint") or object:IsA("NoCollisionConstraint") then
        return { { "Part0", "BasePart" }, { "Part1", "BasePart" } }
    end
    return {}
end

function Adapter.scan(roots, reportUnset)
    local objects, scanned = Scope.collect(roots, true, function() return true end, {
        maxNodes = 20000, maxTargets = 20000, allowServices = true,
    })
    local records = {}
    for _, object in ipairs(objects) do
        local fields = properties(object)
        if #fields > 0 then
            local references = {}
            for _, field in ipairs(fields) do
                local value = object[field[1]]
                table.insert(references, {
                    property = field[1], present = value ~= nil,
                    attached = value ~= nil and (value == game or value:IsDescendantOf(game)),
                    validType = value == nil or field[2] == nil or value:IsA(field[2]),
                    withinOwner = value == nil or not field[3] or value:IsDescendantOf(object),
                })
            end
            table.insert(records, {
                target = object, path = object:GetFullName(), references = references,
                sameEndpoints = #fields == 2 and object[fields[1][1]] ~= nil and object[fields[1][1]] == object[fields[2][1]],
                pair = if #fields == 2 then fields[1][1] .. " / " .. fields[2][1] else "",
            })
        end
    end
    local result = Rules.analyze(records, reportUnset, 100)
    result.scanned = scanned
    result.checked = #records
    return result
end

return Adapter
