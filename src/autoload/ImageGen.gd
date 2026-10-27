extends Node
## 游戏内生图客户端（开发工具，正式版不要把 API key 打进包里）。
## 两种后端：
##  - openai：直接调 OpenAI Images API（gpt-image-2），返回 base64。
##  - drma：与 drma-web 的 videoApi.generate 流程一致：提交 t2i/i2i → 轮询记录 → 下载。
## 配置存在 user://imagegen.json（Profile 页可编辑）。

signal progress(msg: String)

const CFG_PATH := "user://imagegen.json"

var cfg: Dictionary = {
	"backend": "openai",
	"openai_base": "https://api.openai.com/v1",
	"openai_key": "",
	"openai_model": "gpt-image-2",
	"openai_quality": "medium",
	"drma_base": "https://video-api-tmp.deepthink.works",
	"drma_token": "",
	"drma_platform": "android",
	"drma_version_name": "2.0.6",
	"drma_version_code": "200060",
	"style": "乙女游戏插画风格，精致细腻的二次元半写实画风，柔和电影光，高质量",
}


func _ready() -> void:
	load_cfg()


func load_cfg() -> void:
	for path in [CFG_PATH, "res://assets/imagegen.json"]:
		if FileAccess.file_exists(path):
			var f := FileAccess.open(path, FileAccess.READ)
			if f != null:
				var parsed = JSON.parse_string(f.get_as_text())
				if typeof(parsed) == TYPE_DICTIONARY:
					for k in parsed.keys():
						cfg[k] = parsed[k]
			break


func save_cfg() -> void:
	var f := FileAccess.open(CFG_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(cfg, "\t"))


func configured() -> bool:
	if str(cfg.backend) == "drma":
		return str(cfg.drma_token) != ""
	return str(cfg.openai_key) != ""


## 生成一张图并保存为 user://gen/<key>.png，返回 {ok, texture, path, msg}。
func generate_to(key: String, prompt: String, ratio := "9:16") -> Dictionary:
	var full_prompt := "%s。%s" % [prompt, str(cfg.style)]
	var r: Dictionary
	if str(cfg.backend) == "drma":
		r = await _drma_generate(full_prompt, ratio)
	else:
		r = await _openai_generate(full_prompt, ratio)
	if not r.ok:
		return r
	var img: Image = r.image
	var dir := "user://gen/" + key.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var path := "user://gen/%s.png" % key
	var err := img.save_png(path)
	if err != OK:
		return {"ok": false, "msg": "保存失败 %d" % err}
	Data.invalidate(key)
	return {"ok": true, "path": path, "texture": ImageTexture.create_from_image(img)}


# ---------------- OpenAI gpt-image-2 ----------------

static func openai_size(ratio: String) -> String:
	match ratio:
		"9:16", "2:3", "3:4":
			return "1024x1536"
		"16:9", "3:2", "4:3":
			return "1536x1024"
	return "1024x1024"


func _openai_generate(prompt: String, ratio: String) -> Dictionary:
	if str(cfg.openai_key) == "":
		return {"ok": false, "msg": "未配置 OpenAI API key"}
	progress.emit("请求 gpt-image-2…")
	var body := {
		"model": str(cfg.openai_model),
		"prompt": prompt,
		"size": openai_size(ratio),
		"quality": str(cfg.openai_quality),
		"n": 1,
		"output_format": "png",
	}
	var headers := PackedStringArray([
		"Authorization: Bearer " + str(cfg.openai_key),
		"Content-Type: application/json",
	])
	var res := await _http(str(cfg.openai_base) + "/images/generations", headers, HTTPClient.METHOD_POST, JSON.stringify(body), 240.0)
	if not res.ok:
		return res
	var parsed = JSON.parse_string(res.text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "msg": "响应不是 JSON (HTTP %d)" % res.code}
	if parsed.has("error"):
		return {"ok": false, "msg": str(parsed.error.get("message", "OpenAI 错误"))}
	var data: Array = parsed.get("data", [])
	if data.is_empty() or not data[0].has("b64_json"):
		return {"ok": false, "msg": "响应里没有图片"}
	var bytes := Marshalls.base64_to_raw(str(data[0].b64_json))
	var img := Image.new()
	if img.load_png_from_buffer(bytes) != OK:
		return {"ok": false, "msg": "PNG 解析失败"}
	return {"ok": true, "image": img}


# ---------------- drma 后端（与 drma-web 一致） ----------------

func _drma_headers() -> PackedStringArray:
	return PackedStringArray([
		"platform: " + str(cfg.drma_platform),
		"version-name: " + str(cfg.drma_version_name),
		"version-code: " + str(cfg.drma_version_code),
		"region: CN",
		"language: zh",
		"token: " + str(cfg.drma_token),
		"Content-Type: application/json",
	])


func _drma_request(method: int, path: String, body: Variant = null) -> Dictionary:
	var payload := JSON.stringify(body) if body != null else ""
	var res := await _http(str(cfg.drma_base) + path, _drma_headers(), method, payload, 60.0)
	if not res.ok:
		return res
	var parsed = JSON.parse_string(res.text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "msg": "响应不是 JSON (HTTP %d)" % res.code}
	var code := int(parsed.get("code", -1))
	if code != 0 and code != 200:
		return {"ok": false, "code": code, "msg": str(parsed.get("msg", "业务错误 %d" % code))}
	return {"ok": true, "data": parsed.get("data")}


func _drma_generate(prompt: String, ratio: String) -> Dictionary:
	if str(cfg.drma_token) == "":
		return {"ok": false, "msg": "未配置 drma token"}
	progress.emit("提交生图任务…")
	var submit := await _drma_request(HTTPClient.METHOD_POST, "/videoAi/aiGenerate/add/new", {
		"modelBuildType": "t2i", "prompt": prompt, "ratio": ratio,
	})
	if not submit.ok:
		return submit
	var id := int(submit.data.get("id", 0))
	for i in 90:
		await get_tree().create_timer(2.0).timeout
		progress.emit("生成中… %d" % (i + 1))
		var q := await _drma_request(HTTPClient.METHOD_GET, "/videoAi/aiCall/aiGenerateRecord/info?aiGenerateRecordId=%d" % id)
		if not q.ok:
			continue
		var st := int(q.data.get("status", 0))
		if st == 2:
			var url := str(q.data.get("outputImageUrl", ""))
			var urls: Array = q.data.get("outputImageUrls", [])
			if url == "" and urls.size() > 0:
				url = str(urls[0])
			if url == "":
				return {"ok": false, "msg": "记录完成但没有图片地址"}
			return await _download(url)
		if st == 3:
			return {"ok": false, "msg": str(q.data.get("failureReason", "生成失败"))}
	return {"ok": false, "msg": "等待超时"}


func _download(url: String) -> Dictionary:
	progress.emit("下载图片…")
	var res := await _http(url, PackedStringArray(), HTTPClient.METHOD_GET, "", 120.0)
	if not res.ok:
		return res
	var img := Image.new()
	var bytes: PackedByteArray = res.bytes
	var err := img.load_png_from_buffer(bytes)
	if err != OK:
		err = img.load_jpg_from_buffer(bytes)
	if err != OK:
		err = img.load_webp_from_buffer(bytes)
	if err != OK:
		return {"ok": false, "msg": "无法解析图片"}
	return {"ok": true, "image": img}


# ---------------- HTTP ----------------

func _http(url: String, headers: PackedStringArray, method: int, body: String, timeout := 60.0) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = timeout
	add_child(http)
	var err := http.request(url, headers, method, body)
	if err != OK:
		http.queue_free()
		return {"ok": false, "msg": "请求发起失败 %d" % err}
	var res: Array = await http.request_completed
	http.queue_free()
	var result := int(res[0])
	var code := int(res[1])
	var bytes: PackedByteArray = res[3]
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "msg": "网络错误 %d" % result, "code": code}
	return {"ok": true, "code": code, "bytes": bytes, "text": bytes.get_string_from_utf8()}
