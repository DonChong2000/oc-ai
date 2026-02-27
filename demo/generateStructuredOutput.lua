local ai = require("ai")
local json = require("ai.utils.json")

local result = ai.generateText({
  model = "openai/gpt-4o-mini",
  output = ai.Output.object({
    schema = {
      type = "object",
      properties = {
        recipe = {
          type = "object",
          properties = {
            name = { type = "string" },
            ingredients = {
              type = "array",
              items = {
                type = "object",
                properties = {
                  name = { type = "string" },
                  amount = { type = "string" },
                },
              },
            },
            steps = {
              type = "array",
              items = { type = "string" },
            },
          },
        },
      },
    },
  }),
  prompt = "Generate a lasagna recipe.",
})

print("Recipe: " .. result.output.recipe.name)
print("")
print("Ingredients:")
for _, ing in ipairs(result.output.recipe.ingredients) do
  print("  - " .. ing.amount .. " " .. ing.name)
end
print("")
print("Steps:")
for i, step in ipairs(result.output.recipe.steps) do
  print("  " .. i .. ". " .. step)
end

print("")
print("--- Raw ---")
print(result.text)
