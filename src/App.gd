extends Control
## 应用根节点：把界面容器和浮层交给 Router，然后进入标题页。
## 命令行 `-- --shots=<目录>` 走自动截图（src/dev/ShotRunner.gd），`-- --test` 跑逻辑测试（tests/TestRunner.gd）。

func _ready() -> void:
	Router.setup($ScreenHost, $Overlay)
	var shots_dir := ""
	var run_tests := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
		elif arg == "--test":
			run_tests = true
	if run_tests:
		add_child(load("res://tests/TestRunner.gd").new())
	elif shots_dir != "":
		var runner: Node = load("res://src/dev/ShotRunner.gd").new()
		runner.out_dir = shots_dir
		add_child(runner)
	else:
		Router.go("Title")
