# DSH GUI Environment Updates

## Summary

Updated the DeepSeek Harness Docker environment to support GUI development with the new `template_cpp` GUI template (C++23 + Dear ImGui + GLFW).

## Changes

### 1. Dockerfile.fix (Lines 38-88)

Added GUI development stack:

```dockerfile
# GUI Development: X11, OpenGL, GLFW, Dear ImGui headers, Xvfb
apt-get update && \
apt-get install -y --no-install-recommends \
    libx11-dev \
    libxrandr-dev \
    libxinerama-dev \
    libxcursor-dev \
    libxi-dev \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    mesa-common-dev \
    xvfb \
    x11-utils && \
rm -rf /var/lib/apt/lists/* && \
\
# Pre-populate /opt/deps with stable GUI dependencies
mkdir -p /opt/deps/src && \
cd /opt/deps/src && \
# GLFW 3.4 (pre-compiled)
git clone --branch 3.4 --depth 1 https://github.com/glfw/glfw.git && \
cd glfw && mkdir build && cd build && \
cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/deps \
    -DGLFW_BUILD_DOCS=OFF -DGLFW_BUILD_TESTS=OFF -DGLFW_BUILD_EXAMPLES=OFF && \
cmake --build . --parallel && cmake --install . && \
cd /opt/deps/src && rm -rf glfw && \
# Dear ImGui docking branch (headers only)
git clone --branch v1.91.8-docking --depth 1 https://github.com/ocornut/imgui.git && \
mkdir -p /opt/deps/include/imgui && \
cp imgui/*.h imgui/*.cpp /opt/deps/include/imgui/ && \
cp imgui/backends/imgui_impl_glfw.* imgui/backends/imgui_impl_opengl3.* /opt/deps/include/imgui/ && \
rm -rf imgui && \
# Cleanup
cd / && rm -rf /opt/deps/src
```

**Benefits:**
- Pre-compiled GLFW 3.4 in `/opt/deps` → fast CMake `find_package()` resolution
- Dear ImGui headers cached → FetchContent fallback only if needed
- Xvfb for headless CI/testing

### 2. compose.fix.yaml (Lines 14-19)

Added environment variables:

```yaml
environment:
  DOCKER_HOST: ${DOCKER_HOST:-unix:///var/run/docker.sock}
  HOME: /home/node
  DSH_HOME: /home/node/.dsh
  XDG_CONFIG_HOME: /home/node/.config
  GITHUB_TOKEN: ${GITHUB_TOKEN}
  DISPLAY: ${DISPLAY:-:99}                      # ← NEW: Xvfb display
  LIBGL_ALWAYS_SOFTWARE: ${LIBGL_ALWAYS_SOFTWARE:-1}  # ← NEW: Software rendering
  AW_DEPS_DIR: /opt/deps                        # ← NEW: Local-first deps cache
```

**Benefits:**
- `AW_DEPS_DIR=/opt/deps` → CMake `aw_fetch_dependency()` checks this path first
- `DISPLAY=:99` → Xvfb display for headless GUI testing
- `LIBGL_ALWAYS_SOFTWARE=1` → Mesa software rendering fallback

## Usage

### Rebuild DSH Container

```bash
cd ~/workspace/deepseek-harness-docker
./BUILD_GUI_ENV.sh
```

Or manually:

```bash
docker compose -f compose.yaml -f compose.fix.yaml up --build -d
```

### Verify GUI Dependencies

```bash
# Connect to DSH container
docker exec -it deepseek-harness-deepseek-harness-1 zsh

# Check GLFW pre-installed
ls -la /opt/deps/lib/libglfw* /opt/deps/include/GLFW/

# Check Dear ImGui headers cached
ls -la /opt/deps/include/imgui/

# Check environment
env | grep -E 'DISPLAY|AW_DEPS_DIR|LIBGL'
```

Expected output:
```
AW_DEPS_DIR=/opt/deps
DISPLAY=:99
LIBGL_ALWAYS_SOFTWARE=1
```

### Test GUI Template

```bash
cd ~/workspace/template_cpp

# Scaffold GUI project
make init TYPE=gui NAME=testapp NS=aw::testapp

# Configure (will use /opt/deps GLFW)
cmake --preset dev

# Build
cmake --build --preset dev

# Run headless tests (no Xvfb needed for unit tests)
ctest --preset dev

# (Optional) Run app with Xvfb
Xvfb :99 -screen 0 1024x768x24 &
export DISPLAY=:99
./build-dev/testapp_app
```

## Dependency Resolution Order

The CMake helper `aw_fetch_dependency()` (in `template_cpp/cmake/DependencyCache.cmake`) resolves in this order:

1. **Explicit override**: `FETCHCONTENT_SOURCE_DIR_<NAME>` (user-provided path)
2. **Docker cache**: `/opt/deps` (pre-populated in Dockerfile.fix) ✅
3. **User cache**: `$AW_DEPS_DIR` (environment variable)
4. **System install**: `find_package(... QUIET)`
5. **Network fallback**: `FetchContent` download

**Result**: GLFW 3.4 and Dear ImGui are available offline instantly.

## File Changes Summary

| File | Status | Lines Changed |
|------|--------|---------------|
| `Dockerfile.fix` | Updated | +50 (GUI deps + /opt/deps pre-population) |
| `compose.fix.yaml` | Updated | +3 (DISPLAY, LIBGL_ALWAYS_SOFTWARE, AW_DEPS_DIR) |
| `BUILD_GUI_ENV.sh` | New | Helper script for rebuilding |
| `GUI_UPDATES.md` | New | This documentation |

## Next Steps

1. **Rebuild DSH container** (see Usage above)
2. **Test GUI template scaffolding** in `template_cpp`
3. **Verify CMake finds GLFW** in `/opt/deps` without network
4. **Run headless unit tests** with `ctest`
5. **(Optional) Run GUI app with Xvfb** if interactive testing needed

## Notes

- **Xvfb** is installed but not auto-started (tests don't need it)
- **Mesa software rendering** (`LIBGL_ALWAYS_SOFTWARE=1`) works without GPU
- **Pre-compiled GLFW** speeds up every GUI project build
- **Dear ImGui headers** cached but still fetched per-project (header-only lib)
- **aw::tpl** and **aw::tobus** are NOT cached (actively developed, always fetch fresh)

---

**Status**: ✅ Ready for GUI development in DSH

**Date**: 2026-11-23  
**Author**: AI Assistant (Kiro)
