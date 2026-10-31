if not plugin then return end

local Selection = game:GetService("Selection")
local RunService = game:GetService("RunService")
local Ui = require(script.Ui)
local Adapter = require(script.Adapter)
local panel = Ui.new(plugin, "FlashLinks", "Flash Links", "Links")
panel.label("Review object references. Findings are snapshots, not proof of a bug. This tool never repairs or deletes anything.")
local results = {}
local rows = {}
local status
local function clear()
    results = {}
    for _, row in ipairs(rows) do row.Visible = false end
end
local unset = panel.cycle("Report unset references", { "On", "Off" }, function()
    clear()
    status.Text = "Options changed. Scan again."
end)
status = panel.label("Scan selected roots and their descendants, or scan Workspace.")
local function scan(roots)
    clear()
    if RunService:IsRunning() then status.Text = "Stop the play test first." return end
    local ok, result = pcall(Adapter.scan, roots, unset() == "On")
    if not ok then status.Text = "Scan stopped: " .. tostring(result) return end
    results = result.findings
    status.Text = string.format("%d objects scanned / %d supported objects checked / %d findings. Showing %d. Click a row to select its owner. Nothing was edited.", result.scanned, result.checked, result.total, #results)
    for index, finding in ipairs(results) do
        rows[index].Text = finding.code .. " / " .. finding.property .. "\n" .. finding.path .. "\n" .. finding.message
        rows[index].Visible = true
    end
end
panel.button("Scan selection and descendants", function() scan(Selection:Get()) end)
panel.button("Scan Workspace", function() scan({ workspace }) end)
for index = 1, 100 do
    local slot = index
    local row = panel.button("", function()
        local finding = results[slot]
        if finding and finding.target:IsDescendantOf(game) then
            Selection:Set({ finding.target })
        else
            status.Text = "That object was removed. Scan again."
        end
    end)
    row.Size = UDim2.new(1, 0, 0, 100)
    row.TextSize = 14
    row.TextTruncate = Enum.TextTruncate.AtEnd
    row.Visible = false
    rows[index] = row
end
plugin.Unloading:Connect(function() panel.destroy() end)
