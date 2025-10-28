#!/bin/bash

echo "🔧 ghactions.nvim Installation Verification"
echo "=========================================="

# Check if plugin directory exists
if [ ! -d "$HOME/Personal/ghactions.nvim" ]; then
    echo "❌ Plugin directory not found"
    exit 1
fi

echo "✅ Plugin directory exists"

# Check if main files exist
FILES=(
    "lua/ghactions/init.lua"
    "lua/ghactions/config/init.lua"
    "lua/ghactions/cache/init.lua"
    "lua/ghactions/github/versions.lua"
    "lua/ghactions/telescope/extension.lua"
)

for file in "${FILES[@]}"; do
    if [ -f "$HOME/Personal/ghactions.nvim/$file" ]; then
        echo "✅ $file exists"
    else
        echo "❌ $file missing"
        exit 1
    fi
done

# Check basic syntax without loading dependencies
echo ""
echo "🔍 Checking basic Lua syntax..."
cd "$HOME/Personal/ghactions.nvim"

# Check just the versions.lua file for the specific syntax error we fixed
if lua -e "
    local content = io.open('lua/ghactions/github/versions.lua', 'r'):read('*all')
    local func, err = load(content, 'versions.lua')
    if not func then
        print('❌ Syntax error in versions.lua:', err)
        os.exit(1)
    end
    print('✅ versions.lua syntax OK')
" 2>/dev/null; then
    echo "✅ Core syntax checks passed"
else
    echo "❌ Syntax errors found"
    exit 1
fi

echo ""
echo "📋 Installation Instructions:"
echo "1. Copy lazy_plugin_spec.lua to ~/.config/nvim/lua/plugins/ghactions.lua"
echo "2. Restart Neovim completely"
echo "3. Test with: :GhActionsCacheStats"
echo ""
echo "🚀 Plugin is ready for installation!"
echo ""
echo "📝 Available Commands:"
echo "   :GhActions              - Show command menu"
echo "   :GhActionsVersions [action] - Browse versions"
echo "   :GhActionsSecure        - Secure action on current line"
echo "   :GhActionsUnsecure      - Unsecure action on current line"
echo "   :GhActionsSecureAll     - Secure all actions in buffer"
echo "   :GhActionsUnsecureAll   - Unsecure all actions in buffer"
echo "   :GhActionsCacheStats    - Show cache stats"
echo "   :GhActionsCachePurge    - Clear cache"