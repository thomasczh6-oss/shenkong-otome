#!/usr/bin/env python3
"""生成角色配音与 BGM（和 gen_assets.py 走同一个网关、同一个密钥）。

- 配音：MiniMax speech-2.8-hd（OpenAI 兼容 /v1/audio/speech）。遍历 data/story.json、data/dates.json、
  data/messages.json（电话）、data/characters.json（主页问候）里男主说的每一句，输出
  assets/audio/voice/<id>.mp3。<id> = md5("角色|台词") 前 16 位，游戏里用同样的算法找文件，
  所以改了台词只会重新生成改过的那几句。
- BGM：Mureka 纯音乐（网关 /mureka/v1/instrumental/generate → query 轮询 → 下载 mp3），
  曲目与提示词在 data/audio.json，输出 assets/audio/bgm/<key>.mp3。
  下载地址在 cdn.mureka.ai，环境需要放行这个域名。

用法：
  python tools/gen_audio.py voice              # 生成缺失的配音
  python tools/gen_audio.py voice --only gu_ci # 只生成某位男主
  python tools/gen_audio.py bgm                # 生成缺失的 BGM
  python tools/gen_audio.py voice --dry-run
"""
import argparse
import hashlib
import json
import os
import pathlib
import sys
import time

import requests

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
OUT = ROOT / "assets" / "audio"
DEFAULT_GATEWAY = "https://ai-gateway.deepthink.works"
USER_AGENT = "shenkong-otome-assets/1.0"
CHARS = ("shen_yan", "gu_ci", "lu_zhuo")


def load(name):
    return json.loads((DATA / name).read_text(encoding="utf-8"))


def voice_id(who, text):
    """与 src/autoload/Audio.gd 的 voice_id() 保持一致。"""
    return hashlib.md5(f"{who}|{text}".encode("utf-8")).hexdigest()[:16]


def collect_lines():
    """返回 [(who, text)]，去重。"""
    out = []

    def walk(lines):
        for l in lines:
            t = l.get("t", "say")
            if t == "say" and l.get("who") in CHARS:
                out.append((l["who"], l["text"]))
            elif t == "choice":
                for o in l.get("options", []):
                    walk(o.get("lines", []))
            elif t == "touch":
                for sp in l.get("spots", []):
                    out.append((l["who"], sp["text"]))

    for ch in load("story.json")["chapters"]:
        for sc in ch["scenes"]:
            walk(sc["lines"])
    for d in load("dates.json")["dates"]:
        walk(d["lines"])
    for cid, call in load("messages.json").get("calls", {}).items():
        for text in call.get("lines", []):
            out.append((cid, text))
    for c in load("characters.json")["characters"]:
        if c.get("greet"):
            out.append((c["id"], c["greet"]))
    for cid, groups in load("companion.json")["lines"].items():
        for texts in groups.values():
            for text in texts:
                out.append((cid, text))
    for card in load("cards.json")["cards"]:
        if card.get("whisper"):
            out.append((card["char"], card["whisper"]))
    seen, uniq = set(), []
    for who, text in out:
        if (who, text) not in seen:
            seen.add((who, text))
            uniq.append((who, text))
    return uniq


class Gateway:
    def __init__(self, base, key):
        self.base = base.rstrip("/").removesuffix("/v1")
        self.s = requests.Session()
        self.s.headers["Authorization"] = f"Bearer {key}"
        self.s.headers["User-Agent"] = USER_AGENT  # 网关前的 WAF 会拦 python-requests 默认 UA

    def tts(self, text, voice, model):
        r = self.s.post(f"{self.base}/v1/audio/speech", json={"model": model, "input": text, "voice": voice, "response_format": "mp3"}, timeout=120)
        if r.status_code >= 400 or "audio" not in r.headers.get("content-type", ""):
            raise RuntimeError(f"HTTP {r.status_code}: {r.text[:300]}")
        return r.content

    def instrumental(self, prompt, model):
        r = self.s.post(f"{self.base}/mureka/v1/instrumental/generate", json={"model": model, "prompt": prompt}, timeout=120)
        if r.status_code >= 400:
            raise RuntimeError(f"HTTP {r.status_code}: {r.text[:300]}")
        tid = r.json()["id"]
        for _ in range(90):
            time.sleep(10)
            q = self.s.get(f"{self.base}/mureka/v1/instrumental/query/{tid}", timeout=60).json()
            st = q.get("status")
            if st == "succeeded":
                url = q["choices"][0]["url"]
                d = requests.get(url, timeout=300, headers={"User-Agent": USER_AGENT})
                d.raise_for_status()
                return d.content
            if st in ("failed", "timeouted", "cancelled"):
                raise RuntimeError(f"生成失败: {q.get('failed_reason') or st}")
        raise RuntimeError("等待超时")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("what", choices=["voice", "bgm"])
    ap.add_argument("--base", default=os.environ.get("IMAGE_API_BASE", DEFAULT_GATEWAY))
    ap.add_argument("--key", default=os.environ.get("IMAGE_API_KEY") or os.environ.get("OPENAI_API_KEY", ""))
    ap.add_argument("--only", default="")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    if not args.key and not args.dry_run:
        sys.exit("缺少 IMAGE_API_KEY")
    gw = Gateway(args.base, args.key)
    cfg = load("audio.json")

    if args.what == "voice":
        voices = {c["id"]: c.get("voice", {}) for c in load("characters.json")["characters"]}
        lines = [(w, t) for w, t in collect_lines() if w.startswith(args.only)]
        out_dir = OUT / "voice"
        out_dir.mkdir(parents=True, exist_ok=True)
        todo = [(w, t) for w, t in lines if args.force or not (out_dir / f"{voice_id(w, t)}.mp3").exists()]
        print(f"台词 {len(lines)} 句，待生成 {len(todo)} 句", flush=True)
        if args.dry_run:
            return
        ok = fail = 0
        for i, (who, text) in enumerate(todo, 1):
            v = voices.get(who, {})
            spoken = text.replace("{name}", "观测员")
            for attempt in range(3):
                try:
                    raw = gw.tts(spoken, v.get("id", "male-qn-jingying"), cfg.get("voice_model", "speech-2.8-hd"))
                    (out_dir / f"{voice_id(who, text)}.mp3").write_bytes(raw)
                    ok += 1
                    break
                except Exception as e:  # noqa: BLE001
                    print(f"  [{i}] 第 {attempt + 1} 次失败: {e}", flush=True)
                    time.sleep(2 * (attempt + 1))
            else:
                fail += 1
            if i % 20 == 0:
                print(f"  {i}/{len(todo)}", flush=True)
        print(f"完成：成功 {ok}，失败 {fail}")
    else:
        out_dir = OUT / "bgm"
        out_dir.mkdir(parents=True, exist_ok=True)
        for key, t in cfg["bgm"].items():
            if not key.startswith(args.only):
                continue
            p = out_dir / f"{key}.mp3"
            if p.exists() and not args.force:
                continue
            print(f"BGM {key}", flush=True)
            if args.dry_run:
                continue
            try:
                p.write_bytes(gw.instrumental(t["prompt"], cfg.get("bgm_model", "mureka-7.5")))
            except Exception as e:  # noqa: BLE001
                print(f"  失败: {e}", flush=True)


if __name__ == "__main__":
    main()
