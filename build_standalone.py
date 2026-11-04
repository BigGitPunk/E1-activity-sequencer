core = open("core.lua").read()
main = open("electra/main.lua").read()
assert main.startswith('local seq = require("core")\n')
main = main[len('local seq = require("core")\n'):]
standalone = 'local seq = (function()\n' + core + '\nend)()\n\n' + main
open("electra/main_standalone.lua", "w").write(standalone)
