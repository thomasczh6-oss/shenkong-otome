#!/usr/bin/env python3
"""把角色立绘抠成透明背景（image 2 不支持透明背景输出，所以出图后本地抠图）。

依赖：pip install "rembg[cpu]"（首次运行会下载 BiRefNet-portrait 模型，约 1GB）。
用法：
  python tools/cutout.py                         # 处理 manifest 里所有 cutout=true 的条目
  python tools/cutout.py --only characters/gu_ci  # 只处理某个前缀
已经是透明背景的图会跳过（--force 强制重抠）。
"""
import argparse
import json
import pathlib
import subprocess
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "assets" / "manifest.json"
OUT_DIR = ROOT / "assets" / "gen"
MODEL = "birefnet-portrait"

_session = None


def is_cut(img):
    if img.mode != "RGBA":
        return False
    lo, _ = img.getchannel("A").getextrema()
    return lo < 10


def cut(path, force=False):
    """抠一张图，返回是否处理了。"""
    global _session
    img = Image.open(path)
    if is_cut(img) and not force:
        return False
    from rembg import new_session, remove
    if _session is None:
        _session = new_session(MODEL)
    out = remove(img.convert("RGB"), session=_session)
    out.save(path, "PNG", optimize=True)
    return True


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", default="")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--single", default="", help=argparse.SUPPRESS)
    args = ap.parse_args()
    if args.single:
        cut(pathlib.Path(args.single), force=True)
        return
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    n = 0
    for e in manifest["assets"]:
        if not e.get("cutout") or not e["key"].startswith(args.only):
            continue
        p = OUT_DIR / f"{e['key']}.png"
        if not p.exists() or (is_cut(Image.open(p)) and not args.force):
            continue
        # 每张图单独开一个进程：BiRefNet 在同一进程里连续推理时偶尔会被系统杀掉
        r = subprocess.run([sys.executable, __file__, "--single", str(p)])
        if r.returncode == 0:
            n += 1
            print("cut", e["key"], flush=True)
        else:
            print("失败", e["key"], r.returncode, flush=True)
    print(f"完成：抠图 {n} 张")


if __name__ == "__main__":
    main()
