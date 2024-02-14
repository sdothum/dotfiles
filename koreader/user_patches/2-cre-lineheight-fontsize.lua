-- koreader/patches
-- sdothum - 2016 (c) wtfpl
--
-- frontend/ui/data/creoptions.lua
--
-- extend line height and font size ranges

local CreOptions = require("ui/data/creoptions")

CreOptions[3].options[4].more_options_param.value_max = 250  -- extent "proof" mode line height range
CreOptions[4].options[2].more_options_param.value_min = 10   -- allow even smaller font size choices
