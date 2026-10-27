extends Control
## 所有界面的基类：全屏、接收 Router 传入的 params，子类实现 build()。
## 从上层界面返回时会收到 on_resume(result)。

var params: Dictionary = {}


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS


func _ready() -> void:
	build()


func build() -> void:
	pass


func on_resume(_result: Variant) -> void:
	pass


## 清空并重建（界面数据变化时的简单刷新方式）。
func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	build()
