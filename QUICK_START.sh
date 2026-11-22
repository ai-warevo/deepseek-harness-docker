#!/bin/bash
set -e

echo "================================"
echo "DSH + GUI Template Quick Start"
echo "================================"
echo ""

# Step 1: Show current state
echo "✅ Step 1: Verifying files..."
[ -f Dockerfile.fix ] && echo "   ✓ Dockerfile.fix exists (216 lines)"
[ -f compose.fix.yaml ] && echo "   ✓ compose.fix.yaml exists (31 lines)"
[ -f GUI_UPDATES.md ] && echo "   ✓ GUI_UPDATES.md (documentation)"
[ -f VERIFY_BUILD.md ] && echo "   ✓ VERIFY_BUILD.md (build verification guide)"
echo ""

# Step 2: Check Docker available
echo "✅ Step 2: Checking Docker..."
docker --version | head -1
docker compose version | head -1
echo ""

# Step 3: Show what will be built
echo "✅ Step 3: Build breakdown:"
echo "   Layer 1 (3 RUN): GCC 15 + tools (~2 min cached)"
echo "   Layer 2 (1 RUN): X11/OpenGL dev packages (~2 min)"
echo "   Layer 3 (1 RUN): GLFW 3.4 pre-compiled (~6 min)"
echo "   Layer 4 (1 RUN): Dear ImGui docking headers (~1 min)"
echo "   Total: ~10-15 minutes (first time)"
echo ""

# Step 4: Ready?
echo "✅ Step 4: Ready to build?"
echo ""
echo "   Run:"
echo "   cd ~/workspace/deepseek-harness-docker"
echo "   docker compose -f compose.yaml -f compose.fix.yaml build"
echo ""
echo "   Or use the helper:"
echo "   ./BUILD_GUI_ENV.sh"
echo ""
