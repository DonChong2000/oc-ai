-- examples/oc-code/basic.lua
-- Basic example of using oc-code programmatically

local occode = require("oc-code")

-- One-shot mode: ask a single question
print("Asking oc-code to list files...")
local response = occode.exec("List the files in the current directory")
print("Response:", response)
