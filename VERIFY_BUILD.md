# Dockerfile.fix GUI Build Verification

## Changes Summary

### ✅ Split into 3 Separate RUN Layers (Docker Cache Friendly)

**Layer 1: X11/OpenGL Dev Packages** (lines 52-68)
```dockerfile
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libx11-dev libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev \
        libgl1-mesa-dev libgl1-mesa-dri libglx-mesa0 \
        libglu1-mesa-dev mesa-common-dev mesa-utils \
        xvfb x11-utils && \
    rm -rf /var/lib/apt/lists/*
```
**Cache benefit:** ~1-2 min if unchanged ✅

---

**Layer 2: GLFW 3.4 Pre-compilation** (lines 71-85)
```dockerfile
RUN mkdir -p /opt/deps/src && \
    cd /opt/deps/src && \
    git clone --branch 3.4 --depth 1 https://github.com/glfw/glfw.git && \
    cd glfw && mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/opt/deps \
        -DGLFW_BUILD_DOCS=OFF \
        -DGLFW_BUILD_TESTS=OFF \
        -DGLFW_BUILD_EXAMPLES=OFF \
        -DGLFW_BUILD_WAYLAND=OFF \          # ← FIX: Disable Wayland (no wayland-scanner)
        -DGLFW_BUILD_X11=ON && \             # ← Only X11 backend
    cmake --build . --parallel $(nproc) &&   # ← FIX: Use all CPU cores
    cmake --install . && \
    cd / && rm -rf /opt/deps/src
```
**Cache benefit:** ~5-7 min if unchanged ✅  
**Fix:** `-DGLFW_BUILD_WAYLAND=OFF` prevents `wayland-scanner` error

---

**Layer 3: Dear ImGui Headers** (lines 87-92)
```dockerfile
RUN git clone --branch v1.91.8-docking --depth 1 https://github.com/ocornut/imgui.git /tmp/imgui && \
    mkdir -p /opt/deps/include/imgui && \
    cp /tmp/imgui/*.h /tmp/imgui/*.cpp /opt/deps/include/imgui/ && \
    cp /tmp/imgui/backends/imgui_impl_glfw.* /tmp/imgui/backends/imgui_impl_opengl3.* /opt/deps/include/imgui/ && \
    rm -rf /tmp/imgui
```
**Cache benefit:** ~30 sec if unchanged ✅

---

### ✅ compose.fix.yaml Environment Variables

```yaml
environment:
  DISPLAY: ":99"                     # Xvfb display
  LIBGL_ALWAYS_SOFTWARE: 1           # Mesa software rendering (no GPU)
  AW_DEPS_DIR: /opt/deps             # Local-first CMake cache
```

---

## Build & Verify

### 1. Full Build (First Time: ~10-15 min)

```bash
cd ~/workspace/deepseek-harness-docker
docker compose -f compose.yaml -f compose.fix.yaml build
```

**Expected layers:**
- Base image pull (cached if exists)
- GCC 15 + clang-18 install (~3 min)
- Agent tools (bat, fzf, gh) (~1 min)
- **X11/OpenGL dev packages (~2 min)** ← NEW
- **GLFW 3.4 build (~6 min)** ← NEW
- **ImGui headers (~30 sec)** ← NEW
- Xvfb wrapper + config (~30 sec)

### 2. Rebuild After Changes (Fast with Cache)

If you only change layer 3 (ImGui):
```bash
docker compose -f compose.yaml -f compose.fix.yaml build
# Layers 1-2 cached → only layer 3 rebuilds (~1 min)
```

If you change layer 1 (X11 packages):
```bash
docker compose -f compose.yaml -f compose.fix.yaml build
# Layer 1-3 rebuild (~9 min)
```

### 3. Verify /opt/deps Inside Container

```bash
docker compose -f compose.yaml -f compose.fix.yaml up -d
docker exec -it deepseek-harness-deepseek-harness-1 bash

# Check GLFW pre-compiled
ls -lh /opt/deps/lib/libglfw*
ls -lh /opt/deps/include/GLFW/glfw3.h

# Check ImGui headers cached
ls -lh /opt/deps/include/imgui/*.h
ls -lh /opt/deps/include/imgui/imgui_impl_glfw.h

# Check environment
env | grep -E 'DISPLAY|AW_DEPS_DIR|LIBGL'
```

**Expected output:**
```
/opt/deps/lib/libglfw3.a                    # Static library
/opt/deps/include/GLFW/glfw3.h              # Headers
/opt/deps/include/imgui/imgui.h             # ImGui core
/opt/deps/include/imgui/imgui_impl_glfw.h   # GLFW backend
/opt/deps/include/imgui/imgui_impl_opengl3.h # OpenGL3 backend

DISPLAY=:99
AW_DEPS_DIR=/opt/deps
LIBGL_ALWAYS_SOFTWARE=1
```

---

## Test GUI Template

```bash
cd ~/workspace/template_cpp

# Scaffold GUI project
make init TYPE=gui NAME=testgui NS=aw::testgui

# CMake should find GLFW in /opt/deps (offline, no network!)
cmake --preset dev

# Build all targets (core, ui, app, overlay)
cmake --build --preset dev

# Run headless unit tests (no Xvfb needed)
ctest --preset dev --output-on-failure

# (Optional) Run GUI app with Xvfb
Xvfb :99 -screen 0 1280x720x24 &
export DISPLAY=:99
./build-dev/testgui_app
```

---

## Troubleshooting

### Build fails at GLFW with "wayland-scanner not found"

**Cause:** `-DGLFW_BUILD_WAYLAND=OFF` not set  
**Fix:** Already fixed in Dockerfile.fix lines 81

### Build is slow every time

**Cause:** Docker not caching layers  
**Fix:** Don't change lines 1-51 in Dockerfile.fix → layers 1-3 will cache

### CMake doesn't find GLFW in /opt/deps

**Cause:** `AW_DEPS_DIR` not set or `aw_fetch_dependency()` not used  
**Fix:** Check `compose.fix.yaml` line 22 and `template_cpp/cmake/DependencyCache.cmake`

### Tests fail with "cannot open display"

**Cause:** Unit tests trying to initialize graphics (should be headless)  
**Fix:** Check `template_cpp/tests/*_tests.cpp` — they should NOT call `glfwInit()` or `ImGui::CreateContext()`

---

## Performance Comparison

| Scenario | Before (Single Layer) | After (3 Layers) |
|----------|----------------------|------------------|
| **First build** | ~15 min | ~10-15 min (same) |
| **Rebuild (no changes)** | Instant (cached) | Instant (cached) |
| **Rebuild (ImGui change)** | ~15 min (full rebuild) | ~1 min (layers 1-2 cached) ✅ |
| **Rebuild (GLFW change)** | ~15 min (full rebuild) | ~7 min (layer 1 cached) ✅ |
| **Rebuild after Dockerfile edit** | ~15 min | ~2-7 min (depending on layer) ✅ |

---

**Status:** ✅ Ready for build  
**Next:** Run `docker compose -f compose.yaml -f compose.fix.yaml build`
