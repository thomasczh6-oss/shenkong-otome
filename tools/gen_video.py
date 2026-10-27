#!/usr/bin/env python3
"""动态思念：把 5★ 思念卡的插画用图生视频做成 5 秒循环动态卡面。

模型：Seedance 2.0 fast（网关 /v1/video/generations，提交 → 轮询 → 下载 mp4），密钥同 IMAGE_API_KEY。
下载后用 ffmpeg 转成 Godot 能直接播放的 Ogg Theora（去掉音轨，540 宽），输出 assets/video/cards/<卡 id>.ogv。

用法：
  python tools/gen_video.py                 # 生成所有缺失的 5★ 动态卡面
  python tools/gen_video.py --only gu_ci    # 只生成某个前缀
  python tools/gen_video.py --model MiniMax-H3 --force
"""
import argparse
import base64
import io
import json
import os
import pathlib
import subprocess
import sys
import time

import requests
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "video" / "cards"
RAW = ROOT / "assets" / "video" / "_raw"  # 原始 mp4（不入库）
DEFAULT_GATEWAY = "https://ai-gateway.deepthink.works"
USER_AGENT = "shenkong-otome-assets/1.0"
MOTION = ("镜头极缓慢地推近，人物保持原有姿势，只有细微自然的动作：呼吸、眨眼、发丝和衣角被风轻轻吹动，"
          "光影与粒子缓缓流动，画面与人物外观保持不变，适合首尾循环播放，无文字无水印")


class Gateway:
    def __init__(self, base, key):
        self.base = base.rstrip("/").removesuffix("/v1")
        self.s = requests.Session()
        self.s.headers["Authorization"] = f"Bearer {key}"
        self.s.headers["User-Agent"] = USER_AGENT

    def i2v(self, image_path, prompt, model, duration=5):
        im = Image.open(image_path).convert("RGB")
        im.thumbnail((768, 1024))
        buf = io.BytesIO()
        im.save(buf, "JPEG", quality=90)
        uri = "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()
        r = self.s.post(f"{self.base}/v1/video/generations",
                        json={"model": model, "prompt": prompt, "image": uri, "duration": duration}, timeout=120)
        if r.status_code >= 400:
            raise RuntimeError(f"HTTP {r.status_code}: {r.text[:300]}")
        tid = r.json()["task_id"]
        for _ in range(120):
            time.sleep(10)
            d = self.s.get(f"{self.base}/v1/video/generations/{tid}", timeout=60).json().get("data", {})
            st = d.get("status")
            if st == "SUCCESS":
                v = self.s.get(self.base + d["result_url"], timeout=300)
                v.raise_for_status()
                return v.content
            if st in ("FAILURE", "FAILED"):
                raise RuntimeError(d.get("fail_reason") or "生成失败")
        raise RuntimeError("等待超时")


def to_ogv(mp4, ogv):
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(mp4), "-an", "-vf", "scale=540:-2,fps=24",
                    "-c:v", "libtheora", "-q:v", "7", str(ogv)], check=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--base", default=os.environ.get("IMAGE_API_BASE", DEFAULT_GATEWAY))
    ap.add_argument("--key", default=os.environ.get("IMAGE_API_KEY", ""))
    ap.add_argument("--model", default=os.environ.get("VIDEO_MODEL", "dreamina-seedance-2-0-fast-260128"))
    ap.add_argument("--only", default="")
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()
    if not args.key:
        sys.exit("缺少 IMAGE_API_KEY")
    gw = Gateway(args.base, args.key)
    cards = json.loads((ROOT / "data" / "cards.json").read_text(encoding="utf-8"))["cards"]
    OUT.mkdir(parents=True, exist_ok=True)
    RAW.mkdir(parents=True, exist_ok=True)
    for c in cards:
        if int(c.get("rarity", 3)) != 5 or not c["id"].startswith(args.only):
            continue
        ogv = OUT / f"{c['id']}.ogv"
        if ogv.exists() and not args.force:
            continue
        print(f"动态思念 {c['id']} {c['name']}", flush=True)
        for attempt in range(3):
            try:
                raw = gw.i2v(ROOT / "assets" / "gen" / "cards" / f"{c['id']}.png", f"{c.get('visual', '')}。{MOTION}", args.model)
                mp4 = RAW / f"{c['id']}.mp4"
                mp4.write_bytes(raw)
                to_ogv(mp4, ogv)
                print(f"  ok {ogv.stat().st_size // 1024} KB", flush=True)
                break
            except Exception as e:  # noqa: BLE001
                print(f"  第 {attempt + 1} 次失败: {e}", flush=True)
                time.sleep(5)


if __name__ == "__main__":
    main()
