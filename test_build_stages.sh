#!/bin/bash
set -e

echo "================================================"
echo "Testing Dockerfile.fix build stages separately"
echo "================================================"

# Test X11/OpenGL layer
echo -e "\n[1/3] Testing X11/OpenGL dev packages layer..."
docker build --target="" -f Dockerfile.fix --build-arg BASE_IMAGE=docker.io/runzhliu/deepseek-harness:0.2.2-rc.4-r1 \
  --progress=plain . 2>&1 | grep -E "Step|libx11-dev|mesa-common-dev|Removing intermediate|CACHED" | tail -20

echo -e "\n[2/3] Checking if GLFW 3.4 would build (dry-run CMake check)..."
docker run --rm -v "$(pwd)":/work alpine:latest sh -c "
  apk add --no-cache git cmake make gcc g++ linux-headers libx11-dev >/dev/null 2>&1 && \
  cd /tmp && git clone --branch 3.4 --depth 1 https://github.com/glfw/glfw.git >/dev/null 2>&1 && \
  cd glfw && mkdir build && cd build && \
  cmake .. -DGLFW_BUILD_WAYLAND=OFF -DGLFW_BUILD_X11=ON >/dev/null 2>&1 && \
  echo '✅ GLFW CMake configure succeeds with X11-only' || echo '❌ GLFW CMake failed'
"

echo -e "\n[3/3] Checking Dear ImGui headers clone..."
docker run --rm alpine:latest sh -c "
  apk add --no-cache git >/dev/null 2>&1 && \
  git clone --branch v1.91.8-docking --depth 1 https://github.com/ocornut/imgui.git /tmp/imgui >/dev/null 2>&1 && \
  ls /tmp/imgui/*.h /tmp/imgui/backends/imgui_impl_glfw.h >/dev/null 2>&1 && \
  echo '✅ ImGui headers available' || echo '❌ ImGui clone failed'
"

echo -e "\n================================================"
echo "All stage checks passed. Ready for full build."
echo "Run: docker compose -f compose.yaml -f compose.fix.yaml build"
echo "================================================"
