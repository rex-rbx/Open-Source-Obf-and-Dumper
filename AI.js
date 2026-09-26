const fs = require("fs");
const path = require("path");
const {
  Client,
  GatewayIntentBits,
  Partials
} = require("discord.js");
const axios = require("axios");
const luaparse = require("luaparse");
const luacodegen = require("luacodegen");
const CEREBRAS_KEY = process.env.CEREBRAS_API_KEY;
async function cerebras(sys, prompt) {
  try {
    const res = await axios.post("https://api.cerebras.ai/v1/chat/completions", {
      model: "zai-glm-4.7",
      messages: [{
        role: "system",
        content: sys
      }, {
        role: "user",
        content: prompt
      }],
      max_tokens: 64000,
      temperature: 0.1
    }, {
      headers: {
        Authorization: "Bearer ".concat(CEREBRAS_KEY),
        "Content-Type": "application/json"
      }
    });
    return res.data.choices[0].message.content;
  } catch (err) {
    console.error("Cerebras API Error:", err.response && err.response.data || err.message);
    throw err;
  }
}
function extractLocalVariablesWithContext(ast, code) {
  const vars = new Map();
  function walk(node) {
    if (!node || typeof node !== "object") return;
    if (node.type === "LocalStatement") {
      node.variables.forEach((v, index) => {
        if (v.type === "Identifier" && !vars.has(v.name)) {
          let usage = "";
          if (node.init && node.init[index]) {
            const start = node.init[index].range && node.init[index].range[0];
            const end = node.init[index].range && node.init[index].range[1];
            if (start != null && end != null) {
              usage = code.substring(start, end);
              if (usage.length > 100) usage = usage.substring(0, 100) + "...";
            }
          }
          vars.set(v.name, {
            name: v.name,
            usage,
            type: "local"
          });
        }
      });
    }
    if (node.type === "ForNumericStatement" && node.variable && node.variable.type === "Identifier") {
      if (!vars.has(node.variable.name)) {
        vars.set(node.variable.name, {
          name: node.variable.name,
          usage: "for loop counter",
          type: "loop"
        });
      }
    }
    if (node.type === "ForGenericStatement") {
      node.variables.forEach(v => {
        if (v.type === "Identifier" && !vars.has(v.name)) {
          vars.set(v.name, {
            name: v.name,
            usage: "for loop variable",
            type: "loop"
          });
        }
      });
    }
    if (node.type === "FunctionDeclaration") {
      if (node.isLocal && node.identifier && node.identifier.type === "Identifier") {
        vars.set(node.identifier.name, {
          name: node.identifier.name,
          usage: "local function",
          type: "function"
        });
      }
      if (node.parameters) {
        node.parameters.forEach(param => {
          if (param.type === "Identifier" && !vars.has(param.name)) {
            vars.set(param.name, {
              name: param.name,
              usage: "function parameter",
              type: "param"
            });
          }
        });
      }
    }
    for (const key of Object.keys(node)) {
      const child = node[key];
      if (Array.isArray(child)) {
        child.forEach(c => walk(c));
      } else if (child && typeof child === "object") {
        walk(child);
      }
    }
  }
  walk(ast);
  return Array.from(vars.values());
}
function buildPrompt(vars, context) {
  const varDescriptions = vars.map(v => "- ".concat(v.name).concat(v.usage ? " (used in: ".concat(v.usage, ")") : "")).join("\n");
  return "Local variables to rename:\n".concat(varDescriptions, "\n\nCode context:\n").concat(context.substring(0, 4000));
}
const SYSTEM_PROMPT = "\nYou are a Lua/Luau variable renamer. Rename ONLY local variables given.\n\nRules:\n1. Do NOT rename string literals\n2. Do NOT rename Roblox API objects (workspace, game, Players, etc.)\n3. Do NOT rename globals\n4. ONLY rename the variables listed\n5. Use PascalCase for most variables\n6. Local functions & parameters must also be renamed\n7. Do NOT duplicate names\n8. Make renames extremely accurate based on usage\n9. Focus on bad/unclear variable names\n10. If multiple functions do the same thing, number them (e.g., Orbfarm, Orbfarm1)\n\nRespond ONLY with a valid JSON Object. Example format:\n{\n  \"renames\": [\n    {\"old\": \"x\", \"new\": \"PlayerName\"},\n    {\"old\": \"tmp\", \"new\": \"TempValue\"}\n  ]\n}\n";
function applyRenamesToAST(ast, renameMap) {
  const lookup = new Map(renameMap.map(r => [r.old, r.new]));
  function traverse(node) {
    if (!node || typeof node !== "object") return;
    if (node.type === "Identifier" && lookup.has(node.name)) {
      node.name = lookup.get(node.name);
    }
    for (const key of Object.keys(node)) {
      const child = node[key];
      if (Array.isArray(child)) {
        child.forEach(c => traverse(c));
      } else if (child && typeof child === "object") {
        traverse(child);
      }
    }
  }
  traverse(ast);
}
async function renameLuaFile(code) {
  let ast;
  try {
    ast = luaparse.parse(code, {
      luaVersion: "5.1",
      ranges: true,
      comments: false
    });
  } catch (parseErr) {
    console.error("Lua parse error:", parseErr);
    throw new Error("Invalid Lua code (parse failed)");
  }
  const vars = extractLocalVariablesWithContext(ast, code);
  if (vars.length === 0) {
    return null;
  }
  const prompt = buildPrompt(vars, code);
  const output = await cerebras(SYSTEM_PROMPT, prompt);
  let jsonMatch = output.match(/\{[\s\S]*\}/);
  let json = jsonMatch && jsonMatch[0];
  if (!json) {
    console.warn("AI did not return valid JSON.");
    return null;
  }
  let renameMap = [];
  try {
    const parsed = JSON.parse(json);
    if (parsed.renames && Array.isArray(parsed.renames)) {
      renameMap = parsed.renames;
    } else {
      console.warn("AI response missing 'renames' array.");
      return null;
    }
  } catch (e) {
    console.error("Failed to parse AI response:", e);
    return null;
  }
  if (renameMap.length === 0) return null;
  applyRenamesToAST(ast, renameMap);
  try {
    const newCode = luacodegen(ast, {
      comments: false,
      indent: "    "
    });
    return newCode;
  } catch (genErr) {
    console.error("Error generating code from AST:", genErr);
    return null;
  }
}
module.exports = {
  renameLuaFile,
  cerebras
};