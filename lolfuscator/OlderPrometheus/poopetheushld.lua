local Pipeline  = require("./poopetheus/pipeline");
local highlight = require("./highlightlua");
local colors    = require("./colors");
local Logger    = require("./logger");
local Presets   = require("./presets");
local Config    = require("./config");
local util      = require("./poopetheus/util");
return {
    Pipeline  = Pipeline;
    colors    = colors;
    Config    = util.readonly(Config);     Logger    = Logger;
    highlight = highlight;
    Presets   = Presets;
}
