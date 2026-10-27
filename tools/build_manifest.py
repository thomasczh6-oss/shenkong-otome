#!/usr/bin/env python3
"""根据 data/*.json 生成 assets/manifest.json（每张图的 key、比例、提示词）。

manifest 是美术流水线的唯一清单：gen_assets.py 按它调用 image 2 出图，
make_placeholders.py 按它生成占位图，游戏内「AI 工坊」按它取提示词。
改了角色 / 卡牌 / 场景数据后重新跑一次即可。
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA = ROOT / "data"

STYLE_CHAR = (
    "乙女向恋爱手游的男性角色立绘，竖版构图，膝上景或半身，面向镜头，"
    "二次元偏写实的精致画风（接近《恋与深空》的质感），皮肤与发丝细节丰富，"
    "柔和电影级光影，背景为干净的深色渐变并带少量光斑，无文字无水印"
)
STYLE_BG = "乙女向恋爱手游场景背景图，无人物，竖版 9:16，电影感光影，精致写实的二次元场景，无文字无水印"
STYLE_CARD = "乙女向恋爱手游「思念卡」插画，男主角与场景的情绪化构图，竖版 3:4，二次元偏写实画风，柔和电影光，无文字无水印"
STYLE_ENEMY = "游戏敌人设定图，深色背景，中心构图，二次元偏写实，无文字无水印"
STYLE_BANNER = "乙女向恋爱手游抽卡卡池横幅，横版 16:9，华丽星海与潮汐光效，右侧留出放文字的空间，无文字无水印"
STYLE_MOMENT = "手机社交动态里的照片，真实感，横版 16:9，无人脸特写，无文字无水印"

EXPRESSIONS = {
    "calm": "平静、克制的神情，直视镜头",
    "smile": "温柔微笑，眼神里有光",
    "shy": "微微脸红、略显害羞地移开视线",
    "serious": "严肃凝重，蓄势待发，背景有能力光效",
}

BACKGROUNDS = {
    "title": "2049 年海滨都市澜城的夜晚，海面与星空在地平线交汇，一道幽蓝色的裂隙在远处海面若隐若现，前景是观测台栏杆",
    "harbor_night": "午夜的北港码头，停泊的科研船，湿漉漉的地面反射路灯，远处海面有一道幽蓝色的光缝，雾气",
    "research_lab": "清晨的海洋研究所深潜准备区，巨大的舷窗外是蓝色海水，墙上挂着潜航服和一枚贝壳，暖色灯光",
    "observatory": "深夜天文台内部，穹顶缓缓打开，整条银河倾泻而下，巨大的望远镜，桌上有热牛奶和甜甜圈",
    "night_sky_flight": "高空云层之上的夜空，流星划过，远处是城市灯火和一架悬停的搜救机的探照灯",
    "rooftop_concert": "旧城区天台上的小型演出现场，霓虹灯串、音箱、一排塑料椅，远处城市夜景",
    "highway_night": "凌晨空旷的高架桥，一辆改装机车停在路中央，远处高架被黑色潮影吞噬，火光与星空",
    "deep_sea": "三千米深海，潜航舱舷窗外是发光的水母群和幽蓝的深渊，神秘而温柔",
    "battle_rift": "虚潮裂隙前的战场，海面立起的水墙与黑色影子，幽蓝与暗红的光，紧张氛围",
}

ENEMIES = {
    "tide_shade": "名为「潮影」的怪物：黑色半透明的影子，形态像卷起的海浪，边缘有幽蓝色发光的颗粒，没有五官",
    "tide_wraith": "名为「潮魇」的巨型 BOSS：由无数潮影聚合而成的巨影，核心处有一枚搏动的幽蓝结晶，气势压迫",
}

MOMENTS = {
    "gu_ci_1": "天文台穹顶打开时拍下的银河，长曝光星轨",
    "shen_yan_1": "潜航舱舷窗外深蓝色的海面，远处有一轮月亮倒影",
    "lu_zhuo_1": "排练室墙上贴满的手写歌词纸，暖黄台灯",
}


def load(name):
    return json.loads((DATA / name).read_text(encoding="utf-8"))


def main():
    chars = load("characters.json")["characters"]
    cards = load("cards.json")["cards"]
    assets = []

    for key, desc in BACKGROUNDS.items():
        assets.append({"key": f"backgrounds/{key}", "ratio": "9:16", "prompt": f"{desc}。{STYLE_BG}"})

    for ch in chars:
        base_key = f"characters/{ch['id']}/calm"
        for expr, expr_desc in EXPRESSIONS.items():
            entry = {
                "key": f"characters/{ch['id']}/{expr}",
                "ratio": "9:16",
                "char": ch["id"],
                "prompt": f"{ch['name']}：{ch['visual']}。{expr_desc}。{STYLE_CHAR}",
            }
            if expr != "calm":
                # 用 calm 立绘做参考图（i2i / edits），保证同一角色多表情一致
                entry["ref"] = base_key
                entry["prompt"] = f"保持参考图中同一角色的脸型、发型、服装与画风不变，只改变表情与姿态：{expr_desc}。{STYLE_CHAR}"
            assets.append(entry)

    by_id = {c["id"]: c for c in chars}
    for card in cards:
        ch = by_id[card["char"]]
        assets.append({
            "key": f"cards/{card['id']}",
            "ratio": "3:4",
            "char": card["char"],
            "ref": f"characters/{card['char']}/calm",
            "prompt": f"{ch['name']}（{ch['visual']}）。场景：{card['visual']}。思念名「{card['name']}」。{STYLE_CARD}",
        })

    for key, desc in ENEMIES.items():
        assets.append({"key": f"enemies/{key}", "ratio": "1:1", "prompt": f"{desc}。{STYLE_ENEMY}"})

    assets.append({
        "key": "ui/banner_limited", "ratio": "16:9",
        "prompt": "三位男主（银灰发潜航员、黑发戴眼镜的飞行员、暗红发乐队主唱）并肩站在星海与潮汐交汇处，限定卡池氛围。" + STYLE_BANNER,
    })
    assets.append({
        "key": "ui/banner_standard", "ratio": "16:9",
        "prompt": "深空与海面之间漂浮的发光思念卡片，常驻卡池氛围，蓝金色调。" + STYLE_BANNER,
    })
    for key, desc in MOMENTS.items():
        assets.append({"key": f"moments/{key}", "ratio": "16:9", "prompt": f"{desc}。{STYLE_MOMENT}"})

    manifest = {
        "note": "由 tools/build_manifest.py 生成，不要手改；改 data/*.json 或脚本里的风格常量后重新生成。",
        "style_version": 1,
        "assets": assets,
    }
    out = ROOT / "assets" / "manifest.json"
    out.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"wrote {out} ({len(assets)} assets)")


if __name__ == "__main__":
    main()
