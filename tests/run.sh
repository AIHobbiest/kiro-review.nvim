#!/bin/sh
# Run the whole test-suite (requires plenary.nvim; set PLENARY_DIR if it is
# not in the default lazy.nvim location).
cd "$(dirname "$0")/.." || exit 1
exec nvim --headless -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua', sequential = true }"
