#!/usr/bin/env python3
"""用 image 2 批量生成游戏美术（按 assets/manifest.json）。

默认走 OpenAI 兼容网关（Thomas 的 ai-gateway），也可切到 drma 后端：
调用方式参考 drma-web 的 videoApi.generate / client.ts —— 提交任务 → 轮询记录 → 下载落盘。

环境变量（也可用命令行参数覆盖）：
  IMAGE_API_BASE   网关地址，默认 https://ai-gateway.deepthink.works（会自动补 /v1）
  IMAGE_API_KEY    网关密钥（也接受 OPENAI_API_KEY）
  IMAGE_MODEL      模型标识，默认 gpt-image-2
  DRMA_API_BASE / DRMA_TOKEN   走 drma 后端时使用

用法：
  python tools/gen_assets.py                      # 生成清单里还没有正式图的条目
  python tools/gen_assets.py --only characters/   # 只生成某个前缀
  python tools/gen_assets.py --force --only cards/shen_yan_5_1
  python tools/gen_assets.py --probe              # 列出网关可用模型（确认 image 2 的模型名）
  python tools/gen_assets.py --dry-run            # 只打印计划
  python tools/gen_assets.py --backend drma --drma-token xxx

输出：assets/gen/<key>.png，并在 assets/gen/_meta.json 记录提示词、模型与时间；
同名的占位 .jpg 会被删除。表情立绘 / 思念卡带 ref 时，用 /v1/images/edits 以 calm 立绘为参考图，保证同一角色一致。
"""
import argparse
import base64
import io
import json
import os
import pathlib
import sys
import time

import requests

try:
    from PIL import Image
except ImportError:  # 没有 PIL 也能跑，只是不转码
    Image = None

ROOT = pathlib.Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "assets" / "manifest.json"
OUT_DIR = ROOT / "assets" / "gen"
META = OUT_DIR / "_meta.json"

DEFAULT_GATEWAY = "https://ai-gateway.deepthink.works"
USER_AGENT = "shenkong-otome-assets/1.0"
DEFAULT_DRMA = "https://video-api-tmp.deepthink.works"

# OpenAI image 2 的尺寸：两边为 16 的倍数、长边 ≤ 3840、比例 ≤ 3:1
SIZES = {"9:16": "1024x1536", "2:3": "1024x1536", "3:4": "1024x1536", "1:1": "1024x1024", "16:9": "1536x1024", "3:2": "1536x1024"}


def log(msg):
    print(msg, flush=True)


# ---------------- OpenAI 兼容网关（image 2） ----------------

class OpenAIBackend:
    def __init__(self, base, key, model, quality):
        base = base.rstrip("/")
        if not base.endswith("/v1"):
            base += "/v1"
        self.base = base
        self.key = key
        self.model = model
        self.quality = quality
        self.session = requests.Session()
        self.session.headers["Authorization"] = f"Bearer {key}"
        # 网关前的阿里云 WAF 会拦截 python-requests 默认 UA，返回 HTML 挑战页
        self.session.headers["User-Agent"] = USER_AGENT

    def probe(self):
        r = self.session.get(f"{self.base}/models", timeout=60)
        r.raise_for_status()
        data = r.json()
        ids = [m.get("id") for m in data.get("data", [])]
        return ids

    def _decode(self, payload):
        data = payload.get("data") or []
        if not data:
            raise RuntimeError(f"响应里没有图片: {json.dumps(payload, ensure_ascii=False)[:300]}")
        item = data[0]
        if item.get("b64_json"):
            return base64.b64decode(item["b64_json"])
        if item.get("url"):
            r = self.session.get(item["url"], timeout=120)
            r.raise_for_status()
            return r.content
        raise RuntimeError("响应既无 b64_json 也无 url")

    def generate(self, prompt, ratio, ref_path=None):
        size = SIZES.get(ratio, "1024x1024")
        if ref_path is not None:
            files = {"image": (ref_path.name, ref_bytes(ref_path), "image/png")}
            data = {"model": self.model, "prompt": prompt, "size": size, "n": "1"}
            if self.quality:
                data["quality"] = self.quality
            r = self.session.post(f"{self.base}/images/edits", data=data, files=files, timeout=300)
        else:
            body = {"model": self.model, "prompt": prompt, "size": size, "n": 1, "output_format": "png"}
            if self.quality:
                body["quality"] = self.quality
            r = self.session.post(f"{self.base}/images/generations", json=body, timeout=300)
        if r.status_code >= 400:
            raise RuntimeError(f"HTTP {r.status_code}: {r.text[:400]}")
        return self._decode(r.json())


def ref_bytes(path):
    """参考图字节。透明背景的立绘先垫上深色底：edits 接口会把透明区域当成蒙版。"""
    raw = path.read_bytes()
    if Image is None:
        return raw
    img = Image.open(io.BytesIO(raw))
    if img.mode != "RGBA":
        return raw
    bg = Image.new("RGBA", img.size, (12, 14, 28, 255))
    bg.alpha_composite(img)
    buf = io.BytesIO()
    bg.convert("RGB").save(buf, "PNG")
    return buf.getvalue()


# ---------------- drma 后端（与 drma-web 一致） ----------------

class DrmaBackend:
    """POST /videoAi/aiGenerate/add/new → GET /videoAi/aiCall/aiGenerateRecord/info 轮询 → 下载。"""

    def __init__(self, base, token):
        self.base = base.rstrip("/")
        self.session = requests.Session()
        self.session.headers.update({
            "platform": "android", "version-name": "2.0.6", "version-code": "200060",
            "region": "CN", "language": "zh", "token": token,
        })

    def probe(self):
        r = self.session.get(f"{self.base}/videoAi/aiCall/modelDefault", timeout=60)
        return r.json()

    def _envelope(self, r):
        r.raise_for_status()
        env = r.json()
        code = env.get("code")
        if code not in (0, 200):
            raise RuntimeError(f"业务错误 {code}: {env.get('msg')}")
        return env.get("data")

    def upload(self, path):
        with path.open("rb") as f:
            data = self._envelope(self.session.post(f"{self.base}/videoAi/common/upload", files={"file": (path.name, f, "image/png")}, data={"path": "image"}, timeout=120))
        return data["resultUrl"]

    def generate(self, prompt, ratio, ref_path=None):
        body = {"modelBuildType": "i2i" if ref_path else "t2i", "prompt": prompt, "ratio": ratio}
        if ref_path:
            body["inputImageUrlList"] = [self.upload(ref_path)]  # drma 后端直接传原图
        rec = self._envelope(self.session.post(f"{self.base}/videoAi/aiGenerate/add/new", json=body, timeout=60))
        rid = rec["id"]
        for _ in range(150):
            time.sleep(2)
            info = self._envelope(self.session.get(f"{self.base}/videoAi/aiCall/aiGenerateRecord/info", params={"aiGenerateRecordId": rid}, timeout=60))
            status = info.get("status")
            if status == 2:
                url = info.get("outputImageUrl") or (info.get("outputImageUrls") or [None])[0]
                if not url:
                    raise RuntimeError("记录完成但没有图片地址")
                r = self.session.get(url, timeout=120)
                r.raise_for_status()
                return r.content
            if status == 3:
                raise RuntimeError(info.get("failureReason") or "生成失败")
        raise RuntimeError("等待超时")


# ---------------- 主流程 ----------------

def to_png(raw):
    if Image is None:
        return raw
    img = Image.open(io.BytesIO(raw))
    buf = io.BytesIO()
    img.convert("RGB").save(buf, "PNG", optimize=True)
    return buf.getvalue()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--backend", choices=["openai", "drma"], default=os.environ.get("IMAGE_BACKEND", "openai"))
    ap.add_argument("--base", default=os.environ.get("IMAGE_API_BASE", DEFAULT_GATEWAY))
    ap.add_argument("--key", default=os.environ.get("IMAGE_API_KEY") or os.environ.get("OPENAI_API_KEY", ""))
    ap.add_argument("--model", default=os.environ.get("IMAGE_MODEL", "gpt-image-2"))
    ap.add_argument("--quality", default=os.environ.get("IMAGE_QUALITY", "medium"), help="low / medium / high，留空则不传")
    ap.add_argument("--drma-base", default=os.environ.get("DRMA_API_BASE", DEFAULT_DRMA))
    ap.add_argument("--drma-token", default=os.environ.get("DRMA_TOKEN", ""))
    ap.add_argument("--only", default="", help="只处理 key 以此开头的条目")
    ap.add_argument("--force", action="store_true", help="已有正式图也重新生成")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--probe", action="store_true", help="列出网关模型后退出")
    ap.add_argument("--no-ref", action="store_true", help="忽略参考图，全部按文生图处理")
    ap.add_argument("--retries", type=int, default=3)
    args = ap.parse_args()

    if args.backend == "drma":
        if not args.drma_token:
            sys.exit("缺少 DRMA_TOKEN / --drma-token")
        backend = DrmaBackend(args.drma_base, args.drma_token)
    else:
        if not args.key:
            sys.exit("缺少 IMAGE_API_KEY（或 OPENAI_API_KEY）/ --key")
        backend = OpenAIBackend(args.base, args.key, args.model, args.quality)

    if args.probe:
        log(json.dumps(backend.probe(), ensure_ascii=False, indent=2))
        return

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    meta = json.loads(META.read_text(encoding="utf-8")) if META.exists() else {}
    todo = []
    for entry in manifest["assets"]:
        key = entry["key"]
        if args.only and not key.startswith(args.only):
            continue
        out = OUT_DIR / f"{key}.png"
        if out.exists() and not args.force and meta.get(key, {}).get("generated"):
            continue
        todo.append(entry)
    # 有参考图的排在被参考的之后
    todo.sort(key=lambda e: 1 if e.get("ref") else 0)
    log(f"待生成 {len(todo)} 张（backend={args.backend} model={args.model}）")
    if args.dry_run:
        for e in todo:
            log(f"  {e['key']}  [{e.get('ratio', '9:16')}]  ref={e.get('ref', '-')}")
        return

    ok = fail = 0
    for i, entry in enumerate(todo, 1):
        key = entry["key"]
        out = OUT_DIR / f"{key}.png"
        ref_path = None
        if entry.get("ref") and not args.no_ref:
            cand = OUT_DIR / f"{entry['ref']}.png"
            if cand.exists():
                ref_path = cand
            else:
                log(f"  参考图缺失 {entry['ref']}，改为文生图")
        log(f"[{i}/{len(todo)}] {key}")
        last_err = None
        for attempt in range(1, args.retries + 1):
            try:
                raw = backend.generate(entry["prompt"], entry.get("ratio", "9:16"), ref_path)
                out.parent.mkdir(parents=True, exist_ok=True)
                out.write_bytes(to_png(raw))
                if entry.get("cutout"):
                    try:
                        import cutout  # 同目录的 tools/cutout.py
                        cutout.cut(out, force=True)
                    except ImportError:
                        log("  未安装 rembg，跳过抠图（之后可运行 tools/cutout.py）")
                jpg = out.with_suffix(".jpg")
                for stale in (jpg, jpg.with_name(jpg.name + ".import")):
                    if stale.exists():
                        stale.unlink()
                meta[key] = {"generated": True, "model": args.model, "backend": args.backend, "ratio": entry.get("ratio"),
                             "ref": entry.get("ref"), "prompt": entry["prompt"], "time": time.strftime("%Y-%m-%d %H:%M:%S")}
                META.write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
                ok += 1
                last_err = None
                break
            except Exception as e:  # noqa: BLE001
                last_err = e
                log(f"  第 {attempt} 次失败: {e}")
                time.sleep(2 * attempt)
        if last_err is not None:
            fail += 1
    log(f"完成：成功 {ok}，失败 {fail}。Godot 打开工程后会自动导入新图片。")


if __name__ == "__main__":
    main()
