#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def test_web_export_preset_exists() -> None:
    presets = read("export_presets.cfg")
    assert 'name="Web"' in presets
    assert 'platform="Web"' in presets
    assert 'export_path="build/web/index.html"' in presets
    assert 'exclude_filter="build/**,addons/**,tests/**,tools/**,outputs/**,assets_work/**,.env"' in presets
    assert (ROOT / "build" / ".gdignore").exists()


def test_export_script_targets_web_build() -> None:
    script = read("tools/export_web.sh")
    assert "build/web/index.html" in script
    assert "--export-release" in script
    assert 'PRESET="${PRESET:-Web}"' in script


def test_server_binds_loopback_and_sets_headers() -> None:
    server = read("tools/serve_web.py")
    assert "127.0.0.1" in server
    assert "Cross-Origin-Opener-Policy" in server
    assert "Cross-Origin-Embedder-Policy" in server
    assert "application/wasm" in server


def test_chat_supports_pasted_image_attachments() -> None:
    server = read("tools/serve_web.py")
    page = read("tools/web_chat.html")
    assert "/api/chat/upload" in server
    assert "chat_uploads" in server
    assert "/chat-uploads/" in server
    assert "addEventListener('paste'" in page
    assert "/api/chat/upload" in page


def test_pixel_scaling_policy_is_documented_and_configured() -> None:
    project = read("project.godot")
    agents_path = ROOT / "AGENTS.md"
    if agents_path.exists():
        agents = read("AGENTS.md")
        assert "Do not use non-integer scaling" in agents
        assert "Do not use runtime fit scaling" in agents
        assert "viewport-only CSS zoom" in agents
    assert 'window/stretch/scale_mode="integer"' in project


def test_web_canvas_resize_is_controlled_by_pixel_viewport_shell() -> None:
    presets = read("export_presets.cfg")
    assert 'html/custom_html_shell="web/pixel_viewport_shell.html"' in presets
    assert "html/canvas_resize_policy=0" in presets


def test_pixel_viewport_shell_keeps_godot_canvas_fixed_size() -> None:
    shell = read("web/pixel_viewport_shell.html")
    assert '<div id="viewport">' in shell
    assert '<div id="world">' in shell
    assert '<canvas id="canvas" width="1280" height="720">' in shell
    assert "const BASE_WIDTH = 1280;" in shell
    assert "const BASE_HEIGHT = 720;" in shell
    assert "image-rendering: pixelated" in shell
    assert "image-rendering: crisp-edges" in shell
    assert "world.style.transform = `translate(${pan.x}px, ${pan.y}px) scale(${scale})`" in shell
    assert "addEventListener('wheel'" in shell


def test_title_cta_does_not_use_fractional_runtime_scale() -> None:
    title = read("src/view/screens/title_screen.gd")
    assert "CTA_SCALE" not in title
    assert 'tween_property(holder, "scale"' not in title
    assert "Vector2(1.02, 1.02)" not in title


if __name__ == "__main__":
    tests = [
        test_web_export_preset_exists,
        test_export_script_targets_web_build,
        test_server_binds_loopback_and_sets_headers,
        test_chat_supports_pasted_image_attachments,
        test_pixel_scaling_policy_is_documented_and_configured,
        test_web_canvas_resize_is_controlled_by_pixel_viewport_shell,
        test_pixel_viewport_shell_keeps_godot_canvas_fixed_size,
        test_title_cta_does_not_use_fractional_runtime_scale,
    ]
    for test in tests:
        test()
        print(f"ok {test.__name__}")
