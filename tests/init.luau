--!strict
-- Lune test runner: `lune run tests`
local process = require("@lune/process")

local suites = {
	{ name = "Format", run = require("./Format.spec") },
	{ name = "Value", run = require("./Value.spec") },
	{ name = "Roll", run = require("./Roll.spec") },
	{ name = "Progression", run = require("./Progression.spec") },
	{ name = "EventSchedule", run = require("./EventSchedule.spec") },
	{ name = "Products", run = require("./Products.spec") },
	{ name = "OfflinePlan", run = require("./OfflinePlan.spec") },
}

local failures = 0
for _, suite in suites do
	local ok, err = pcall(suite.run :: any)
	if ok then
		print("PASS  " .. suite.name)
	else
		failures += 1
		print("FAIL  " .. suite.name .. "\n      " .. tostring(err))
	end
end

if failures > 0 then
	print(string.format("\n%d suite(s) failed", failures))
	process.exit(1)
end
print("\nAll tests passed")
