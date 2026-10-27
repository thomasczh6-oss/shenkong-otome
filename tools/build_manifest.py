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
STYLE_ENEMY = ("乙女向手游战斗怪物设定立绘，全身完整入画、居中、占画面约 85%，轮廓清晰有压迫感，带发光的核心或眼睛，"
               "暗黑奇幻二次元偏写实画风，背景必须是纯色 #00FF00 绿幕（均匀无渐变、无阴影、无地面），无文字无水印")
STYLE_BANNER = "乙女向恋爱手游抽卡卡池横幅，横版 16:9，华丽星海与潮汐光效，右侧留出放文字的空间，无文字无水印"
STYLE_CG = (
    "乙女向恋爱手游剧情 CG 插画，竖版 9:16 全屏构图，女主角是一位深棕色长发的年轻女性，只以背影、侧后方或局部（手、肩、发梢）入画、不露正脸，"
    "男主角是画面焦点，二次元偏写实的精致画风（接近《恋与深空》的质感），电影级光影与景深，情绪浓烈，无文字无水印"
)
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
    "bureau_archive": "深空潮汐局地下档案室，一排排高耸的铁质档案柜，冷白色顶灯一盏盏延伸到黑暗里，桌上摊开一份泛黄的纸质档案",
    "submarine_cabin": "深潜器驾驶舱内部，圆形舷窗外是幽深的深海和远处发光的水母，仪表盘闪着蓝绿色微光，狭小而安静",
    "rescue_hangar": "深夜的搜救基地机库，一架白色搜救直升机停在中央，只亮着一盏顶灯，机翼上放着一张手绘旧星图",
    "rehearsal_room": "旧城区地下乐队排练室，墙上贴满手写歌词纸，鼓组、电吉他、音箱，暖黄色台灯与霓虹灯串",
    "aquarium": "闭馆后的海洋水族馆海底隧道，头顶是巨大的弧形玻璃，一群银色的鱼游过，只有水槽的蓝光照明，安静浪漫",
    "record_store": "老城区巷子深处的老唱片店，满墙黑胶唱片，木质试听台上放着唱机与一副耳机，暖黄色灯光",
    "bookstore_rain": "下雨天街角的旧书店内部，高高的木书架，窗外雨幕与霓虹倒影，柜台上摊着一张旧地图，温暖灯光",
    "camp_meteor": "城郊山顶露营地的夜晚，一顶亮着暖灯的帐篷和两条毯子，漫天流星雨划过银河，远处城市灯火",
    "beach_fireworks": "夜晚无人的海边沙滩，漫天绚烂的烟花倒映在海面上，沙滩上摆着一排排烟火筒，浪漫热烈",
    "subway_zero": "废弃多年的地下地铁站台，站台电子屏停在一个旧日期，时钟指向 00:17，幽蓝色的冷光与积水，隧道深处一列车的灯光",
    "mirror_city": "倒影之城：与海滨都市一模一样却上下颠倒的城市，海面像镜子一样映出另一座城，寂静无声，灰蓝色调，超现实",
    "mirror_starless": "没有一颗星星的漆黑夜空下，寂静的天文台旧址天台，只有地面微弱的冷光，压抑而孤独",
    "silent_theater": "旧城区老剧场内部，舞台空无一人，只有一支话筒和一套鼓，观众席坐满半透明的人影，暖色舞台灯与灰暗观众席",
    "echo_plaza": "寂静城市中央广场，一座古老钟楼的指针停在 00:17，四周漂浮着发光的回响光点，黎明前的深蓝色",
    "lighthouse": "海边废弃灯塔遗址，残破的灯塔上方海面与夜空同时裂开一道幽蓝色裂隙，碎石台阶，黎明前的深蓝色调",
}

LOGOS = {
    "logo_1": "优雅的中文书法体标题，笔画末端化作星光与浪花，月白色字体镶玫瑰金描边，「空」字上点缀一颗四芒星",
    "logo_2": "精致的衬线宋体标题，背后是一枚由星轨圆环、贝壳与新月组成的徽记，淡紫色与香槟金配色",
    "logo_3": "柔美的手写花体标题，缠绕一条珍珠缎带，字间有小小的水母与星星，粉色到天蓝色的渐变",
    "logo_4": "古典烫金标题，金属质感浮雕字，两侧是交错的海浪与星轨花纹，像一枚华丽的徽章，深海蓝与金色",
}

CGS = {
    "ch1_shen_yan_shell": ("shen_yan", "深潜准备区的舷窗前，他低头把一枚用细绳系着的旧贝壳放进女主摊开的手心，手指轻轻覆在她手上，窗外是蓝色海水的光"),
    "ch1_gu_ci_star": ("gu_ci", "天文台穹顶下，他站在女主身后，弯腰握着她的手一起指向银河里一颗星星，侧脸带着温柔的笑，星光洒满画面"),
    "ch1_lu_zhuo_song": ("lu_zhuo", "旧城区天台夜里，他坐在音箱上抱着吉他对着唯一的观众唱歌，眼神直直看向镜头前的女主，霓虹灯串与城市夜景，火星飘散"),
    "ch2_shen_yan_dive": ("shen_yan", "三千米深海，他穿着潜航服悬浮在深潜器舷窗外，掌心隔着玻璃贴住女主贴在窗内的手，身后是成千上万只发光水母"),
    "ch2_gu_ci_cockpit": ("gu_ci", "云层之上的搜救机驾驶舱，熄灯后只有仪表盘微光照亮他的侧脸，他转头看向副驾驶的女主微笑，挡风玻璃外是整片星海"),
    "ch2_lu_zhuo_fire": ("lu_zhuo", "燃烧的高架桥上，他半跪在地，手臂缠绕着橙红色火焰，女主握住他燃烧的手，火焰被幽蓝的回响光芒安抚，他抬头看着她，又惊讶又动容"),
    "ch3_shen_yan_mirror": ("shen_yan", "镜面般的寂静海边，他站在浪花里，身旁是十二岁时的自己（银灰发少年）正在挥手告别，女主站在他身边，海面第一次泛起浪声的光纹"),
    "ch3_gu_ci_light": ("gu_ci", "漆黑无星的天台上，他举起手把星光推向天空，夜幕上正一颗接一颗亮起星星，女主握着他的另一只手，星光照亮他含泪的笑"),
    "ch3_lu_zhuo_voice": ("lu_zhuo", "老剧场舞台上，他握着话筒唱歌，女主站在他身旁一起唱和声，观众席坐满半透明的人影，第一排有人拿着鼓棒，舞台火光与金色光点"),
}
CG_GROUP = {
    "ch3_finale": "寂静城市的中央广场，钟楼指针刚刚走动，无数发光的人影回响在空中化作光点，一位穿白风衣的男人跪在地上，女主的背影与银灰发潜航员、黑发戴眼镜的飞行员、暗红发乐队主唱站在一起，黎明的光",
    "ch2_finale": "黎明前的海边灯塔遗址，女主的背影站在中央，银灰短发的潜航员、黑色微卷发戴眼镜的飞行员、暗红发的乐队主唱三位男性围在她身边，"
                  "幽蓝色的裂隙结晶在头顶碎裂成漫天光点，海平线透出第一缕晨光",
}

ENEMIES = {
    "tide_shade": "名为「潮影」的怪物：黑色半透明的影子，形态像卷起的海浪，边缘有幽蓝色发光的颗粒，没有五官",
    "tide_wraith": "名为「潮魇」的巨型 BOSS：由无数潮影聚合而成的巨影，核心处有一枚搏动的幽蓝结晶，气势压迫",
    "star_shade": "名为「星影」的怪物：从星空裂隙落下的黑色碎片聚成的飞鸟状影子，羽翼边缘闪着冷白色星光，没有五官",
    "echo_colossus": "名为「回响巨像」的 BOSS：由无数半透明人影的回响聚合成的没有脸的巨人，身上流淌着幽蓝与白色的光纹，悲伤而压迫",
    "rift_heart": "名为「裂隙之心」的最终 BOSS：悬浮在海天之间的巨大幽蓝结晶，被黑色潮水与星光碎片环绕，结晶内隐约可见一个沉睡女人的剪影",
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
                "cutout": True,  # 出图后用 tools/cutout.py 抠成透明背景
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

    for key, (cid, desc) in CGS.items():
        ch = by_id[cid]
        assets.append({
            "key": f"cg/{key}", "ratio": "9:16", "char": cid, "ref": f"characters/{cid}/calm",
            "prompt": f"{ch['name']}（{ch['visual']}）。{desc}。{STYLE_CG}",
        })
    for date in load("dates.json")["dates"]:
        ch = by_id[date["char"]]
        assets.append({
            "key": f"date/{date['id']}", "ratio": "9:16", "char": date["char"], "ref": f"characters/{date['char']}/calm",
            "prompt": f"{ch['name']}（{ch['visual']}）。{date['cg_prompt']}。{STYLE_CG}",
        })
    for key, desc in CG_GROUP.items():
        assets.append({"key": f"cg/{key}", "ratio": "9:16", "prompt": f"{desc}。{STYLE_CG}"})

    for key, desc in ENEMIES.items():
        # 绿幕出图，tools/cutout.py 用色键抠成透明（怪物多为半透明烟雾状，人像抠图模型抠不干净）
        assets.append({"key": f"enemies/{key}", "ratio": "1:1", "prompt": f"{desc}。{STYLE_ENEMY}", "cutout": "chroma"})

    assets.append({
        "key": "ui/banner_limited", "ratio": "16:9",
        "prompt": "三位男主（银灰发潜航员、黑发戴眼镜的飞行员、暗红发乐队主唱）并肩站在星海与潮汐交汇处，限定卡池氛围。" + STYLE_BANNER,
    })
    assets.append({
        "key": "ui/banner_standard", "ratio": "16:9",
        "prompt": "深空与海面之间漂浮的发光思念卡片，常驻卡池氛围，蓝金色调。" + STYLE_BANNER,
    })
    # Logo：绿幕出图后色键抠成透明，游戏里叠在标题 KV 上（四版供挑选，选中的写进 data/characters.json 的 logo 字段）
    for key, desc in LOGOS.items():
        assets.append({"key": f"ui/{key}", "ratio": "3:2", "cutout": "chroma",
                       "prompt": f"手游标题 Logo 设计，中文主标题「深与空恋」四个字必须清晰准确，下方一行小号英文「DEEP & SKY LOVE」。{desc}。"
                                 "面向女性玩家的乙女恋爱手游，精致、浪漫、高级，居中构图，四周留白，"
                                 "背景必须是纯色 #00FF00 绿幕（均匀无渐变），Logo 本身不要使用绿色，不要外发光和投影，无其他文字无水印"})
    assets.append({"key": "ui/title_kv", "ratio": "9:16",
                   "prompt": "乙女恋爱手游主视觉海报：银灰短发的潜航员、黑色微卷发戴细框眼镜的飞行员、暗红发戴耳钉的乐队主唱三位俊美男性，"
                             "站在海面与星空交汇的梦幻夜色里，月光、星河、潮汐与发光水母，玫瑰粉与月白、淡紫、香槟金的柔和配色，"
                             "画面上方三分之一留出干净的星空用于放 Logo，下方留出深色空间放按钮，二次元偏写实精致画风，浪漫唯美，无文字无水印"})
    assets.append({"key": "ui/app_icon", "ratio": "1:1",
                   "prompt": "乙女恋爱手游的手机 App 图标，方形满版构图：一枚珍珠白与香槟金的新月，环抱一颗粉色心形星光，"
                             "下方是泛着月光的海浪与一只小小的发光水母，背景是玫瑰粉到深紫的星空渐变，细碎星点，"
                             "精致梦幻，高级感，居中构图，四周留少量边距适配圆角裁切，无文字无水印"})
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
