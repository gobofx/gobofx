#!/usr/bin/env bash
# Source this (`source tools/gpu-env.sh`) before `gobofx render|verify` on a
# Linux box with no GPU: it points the Vulkan loader at a SwiftShader ICD so
# wgpu gets a (software) adapter. A no-op on macOS/Windows and on Linux boxes
# that already have a Vulkan driver.
#
# SwiftShader is looked up in $SWIFTSHADER_DIR, then in Playwright's bundled
# Chromium (which ships libvk_swiftshader.so + vk_swiftshader_icd.json).
# The bundled ICD json uses a relative library_path that the loader only
# resolves from Chromium's own directory, so an absolute-path copy is written
# to target/swiftshader_icd.json.

gobofx_gpu_env() {
  case "$(uname -s)" in
    Linux) ;;
    *) return 0 ;;
  esac
  if [ -n "${VK_ICD_FILENAMES:-}" ] || [ -n "${VK_DRIVER_FILES:-}" ]; then
    return 0
  fi
  if ls /usr/share/vulkan/icd.d/*.json /etc/vulkan/icd.d/*.json >/dev/null 2>&1; then
    return 0   # a system Vulkan driver exists; let the loader use it
  fi
  local here root candidates lib dir
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  root="$(cd "$here/.." && pwd)"
  candidates=()
  [ -n "${SWIFTSHADER_DIR:-}" ] && candidates+=("$SWIFTSHADER_DIR")
  local pw="${PLAYWRIGHT_BROWSERS_PATH:-$HOME/.cache/ms-playwright}"
  for dir in "$pw"/chromium-*/chrome-linux "$pw"/chromium_headless_shell-*/chrome-linux /opt/pw-browsers/chromium-*/chrome-linux; do
    [ -d "$dir" ] && candidates+=("$dir")
  done
  for dir in "${candidates[@]}"; do
    lib="$dir/libvk_swiftshader.so"
    if [ -f "$lib" ]; then
      mkdir -p "$root/target"
      printf '{"file_format_version":"1.0.0","ICD":{"library_path":"%s","api_version":"1.3.0"}}\n' "$lib" > "$root/target/swiftshader_icd.json"
      export VK_ICD_FILENAMES="$root/target/swiftshader_icd.json"
      export VK_DRIVER_FILES="$VK_ICD_FILENAMES"
      echo "gpu-env: using SwiftShader from $dir" >&2
      return 0
    fi
  done
  echo "gpu-env: no Vulkan driver and no SwiftShader found; set SWIFTSHADER_DIR to a folder with libvk_swiftshader.so" >&2
  return 1
}
gobofx_gpu_env
