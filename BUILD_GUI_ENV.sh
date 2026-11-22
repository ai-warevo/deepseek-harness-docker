#!/bin/bash
set -e

echo "================================"
echo "Building DSH with GUI support..."
echo "================================"

# Build with Dockerfile.fix (includes GUI deps + /opt/deps pre-population)
docker compose -f compose.yaml -f compose.fix.yaml up --build -d

echo ""
echo "✅ DSH environment updated with GUI dependencies:"
echo "   • X11/OpenGL dev packages (libx11-dev, libgl1-mesa-dev, etc.)"
echo "   • GLFW 3.4 (pre-compiled in /opt/deps)"
echo "   • Dear ImGui docking branch (headers in /opt/deps/include/imgui)"
echo "   • Xvfb (for headless rendering)"
echo "   • AW_DEPS_DIR=/opt/deps (local-first dependency caching)"
echo "   • DISPLAY=:99 (Xvfb display)"
echo ""
echo "Next: Connect to DSH and run:"
echo "  cd ~/workspace/template_cpp"
echo "  make init TYPE=gui NAME=myapp NS=aw::myapp"
echo "  cmake --preset dev && cmake --build --preset dev"
echo "  ctest --preset dev"
echo ""
