extends Node
## Arayüzü gerçek pencerede dolaşıp ekran görüntüsü alır. Çalıştırma:
##   godot --path godot --resolution 390x844 res://tests/shots.tscn -- <çıktı klasörü>

var out_dir := ""
var main: Control

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else OS.get_user_data_dir()
	Progress.save_enabled = false
	Progress.p = Progress.fresh()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(1.2)
	shot("01_acilis")

	main.start_run("guard", true)
	await wait(2.2)
	shot("02_ogretici")
	main.run.tut_advance()
	main.refresh()
	await wait(1.0)
	for tid in ["n-red-4", "n-blue-6"]:
		for c in main.run.hand:
			if c.tid == tid:
				main._on_card(c.uid)
				break
	await wait(0.8)
	shot("03_secim")
	main._do_play()
	await wait(1.3)
	shot("04_skor_sayimi")
	await wait(3.5)
	shot("05_isabet_sonrasi")

	main.run.tut = {}
	main.run.gold = 22
	main.run.charms.append({"uid": 9001, "cid": "c_red", "state": {}})
	main.run.round_score = main.run.goal
	main.run._round_cleared()
	main.refresh()
	await wait(1.4)
	shot("06_ganimet")
	main.run.open_shop()
	main.refresh()
	await wait(1.0)
	shot("07_tuccar")
	main.run.modal = {}
	main.show_classes()
	await wait(0.8)
	shot("08_siniflar")

	main.show_builder("guard")
	await wait(0.8)
	shot("09_deste_sinif")
	main.B.list = main.B.list.slice(0, 22)
	main._builder_add("n-red-9", main.bui.cells.values()[0].view)
	main.B.open = true
	main._builder_update()
	await wait(0.6)
	shot("10_deste_liste")
	main.B.open = false
	main.B.tab = "neutral"
	main._builder_grid()
	await wait(0.6)
	shot("11_deste_notr")
	get_tree().quit()

func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("görüntü: ", name)
