local Rules = {}

function Rules.analyze(records, reportUnset, maxResults)
    assert(type(maxResults) == "number" and maxResults % 1 == 0 and maxResults >= 1 and maxResults <= 500, "Result limit must be 1-500.")
    local findings, total = {}, 0
    local function emit(record, property, code, message)
        total += 1
        if #findings < maxResults then
            table.insert(findings, { target = record.target, path = record.path, property = property, code = code, message = message })
        end
    end
    for _, record in ipairs(records) do
        for _, reference in ipairs(record.references) do
            if not reference.present then
                if reportUnset then emit(record, reference.property, "UNSET", "No target is assigned. This may be intentional.") end
            elseif not reference.attached then
                emit(record, reference.property, "DETACHED", "The target is outside the open DataModel.")
            elseif not reference.validType then
                emit(record, reference.property, "WRONG_TYPE", "The target does not have the expected class.")
            elseif not reference.withinOwner then
                emit(record, reference.property, "OUTSIDE_MODEL", "The PrimaryPart is not inside its owning Model.")
            end
        end
        if record.sameEndpoints then
            emit(record, record.pair, "SAME_ENDPOINT", "Both endpoints use the same target. Check whether that is intentional.")
        end
    end
    return { findings = findings, total = total }
end

return Rules
