extends Node
## The checks for tests/character_showcase_test.gd (a Node, so it can use the autoloads).

var _fails: Array[String] = []


func run() -> void:
	var robots := []
	for c in CharacterShowcase.CAST:
		var id: String = c[0]
		if not Characters.has(id):
			_fails.append("%s is not a character" % id)
		if CustomCharacter.is_custom(id) and CustomCharacter.normalize(id) != id:
			_fails.append("%s reads back as %s" % [id, CustomCharacter.normalize(id)])
		if c[1] != "none" and not c[1] in WeaponData.IDS:
			_fails.append("%s holds an unknown weapon %s" % [id, c[1]])
		if not CustomCharacter.is_custom(id):
			robots.append(id)
	for id in Characters.ids():
		if not id in robots:
			_fails.append("robot %s is not in the showcase" % id)
	var showcase := CharacterShowcase.new()
	showcase.size = Vector2(1000, 900)
	add_child(showcase)
	var mine := "custom:n=Sir Bolt|l=frog|t=templar|h=goblin|p=gold"
	showcase.start([mine])
	await get_tree().process_frame
	if showcase.cast_size() != CharacterShowcase.CAST.size() + 1:
		_fails.append("with one of your own the cast is %d, not %d" % [showcase.cast_size(), CharacterShowcase.CAST.size() + 1])
	showcase.skip(1)
	await get_tree().process_frame
	for i in showcase.cast_size() + 1:
		showcase.skip()
		await get_tree().process_frame
		showcase._process(CharacterShowcase.SHOT * 0.5)
		await get_tree().process_frame
	if showcase.current() != 2 % showcase.cast_size():
		_fails.append("after going round once it is on %d" % showcase.current())
	showcase.queue_free()
	await get_tree().process_frame
	if _fails.is_empty():
		print("PASS character showcase: %d in the cast, every robot, all real" % CharacterShowcase.CAST.size())
	else:
		print("FAIL:\n  " + "\n  ".join(_fails))
	get_tree().quit(1 if not _fails.is_empty() else 0)
