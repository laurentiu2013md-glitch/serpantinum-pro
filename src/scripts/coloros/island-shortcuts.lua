-- Explicit keyboard access; hover does not grab the keyboard.
local shell = os.getenv("HOME") .. "/.local/share/serpantinum/src/quickshell/Shell.qml"
-- Release the previous music binding before assigning Super+S.
hl.unbind("SUPER + M")
for _, item in ipairs({{"S","music"},{"C","calendar"},{"B","bluetooth"},{"N","network"},{"D","shelf"}}) do
    hl.unbind("SUPER + " .. item[1])
    hl.bind("SUPER + " .. item[1], hl.dsp.exec_cmd('qs ipc -p "' .. shell .. '" call island keyboard ' .. item[2]))
end
hl.bind("SUPER + Escape", hl.dsp.exec_cmd('qs ipc -p "' .. shell .. '" call island close'))
-- Preserve access to the commands displaced by the island shortcuts.
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("serpantinum msg toggle clipboard"))
hl.bind("SUPER + SHIFT + B", hl.dsp.exec_cmd("serpantinum msg toggle system"))
hl.unbind("SUPER + SHIFT + D")
hl.unbind("SUPER + X")
hl.bind("SUPER + X", hl.dsp.exec_cmd("serpantinum msg toggle launcher"))

hl.unbind("SUPER + V")
hl.bind("SUPER + V", hl.dsp.exec_cmd("serpantinum msg toggle clipboard"))
