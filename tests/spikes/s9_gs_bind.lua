for _, k in ipairs({ "ALT_L", "ALT_R", "ALT + F10" }) do pcall(hl.unbind, k) end
hl.bind("ALT_L", hl.dsp.global("omahopspike:alt"), { ignore_mods = true, non_consuming = true })
hl.bind("ALT_R", hl.dsp.global("omahopspike:alt"), { ignore_mods = true, non_consuming = true })
hl.bind("ALT + F10", hl.dsp.global("omahopspike:f10"), { repeating = true })
