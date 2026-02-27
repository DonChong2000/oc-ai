local ai = require("ai")
local google = require("ai.google")
local json = require("ai.utils.json")

local result = ai.generateObject({
  model = google("gemini-2.5-flash"),
  schema = {
    type = "object",
    properties = {
      name = { type = "string" },
      age = { type = "number" },
      occupation = { type = "string" },
      skills = {
        type = "array",
        items = { type = "string" },
      },
    },
    required = { "name", "age", "occupation", "skills" },
  },
  prompt = "Generate a fictional software developer profile.",
})

print("Name: " .. result.object.name)
print("Age: " .. result.object.age)
print("Occupation: " .. result.object.occupation)
print("Skills:")
for _, skill in ipairs(result.object.skills) do
  print("  - " .. skill)
end

print("")
print("--- Raw ---")
print(json.encode(result.object))
