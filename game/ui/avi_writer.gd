class_name AviWriter
extends RefCounted
## Writes a video file: an AVI holding one JPEG per frame (Motion JPEG, the format
## Godot's own movie recorder writes). VLC, Windows Media Player and most editors
## play it. No sound.
##
##   var avi := AviWriter.new(1280, 720, 30)
##   avi.add_frame(image)          # once per frame, any size (scaled to fit)
##   avi.save("C:/.../clip.avi")

var width := 0
var height := 0
var fps := 30
var quality := 0.85              ## JPEG quality, 0..1
var frames: Array[PackedByteArray] = []


func _init(w: int, h: int, frames_per_second: int = 30) -> void:
	width = w
	height = h
	fps = frames_per_second


## Adds a frame. Converted to the video's size and to 8-bit colour if it is not already.
func add_frame(image: Image) -> void:
	var img := image
	if img.get_width() != width or img.get_height() != height:
		img = img.duplicate()
		img.resize(width, height, Image.INTERPOLATE_BILINEAR)
	if img.get_format() != Image.FORMAT_RGB8:
		if img == image:
			img = img.duplicate()
		img.convert(Image.FORMAT_RGB8)
	frames.append(img.save_jpg_to_buffer(quality))


func frame_count() -> int:
	return frames.size()


## Seconds of video so far.
func length() -> float:
	return float(frames.size()) / fps


## The whole file, as bytes.
func to_bytes() -> PackedByteArray:
	var biggest := 0
	var total := 0
	for f in frames:
		biggest = maxi(biggest, f.size())
		total += f.size()
	# The frames ('00dc' chunks, padded to an even size) and the index pointing at them.
	var movi := PackedByteArray()
	var index := PackedByteArray()
	for f in frames:
		index.append_array("00dc".to_ascii_buffer())
		index.append_array(_u32(0x10))                # a key frame
		index.append_array(_u32(movi.size() + 4))     # from the 'movi' tag
		index.append_array(_u32(f.size()))
		movi.append_array(_chunk("00dc", f))
	var micro := int(round(1000000.0 / fps))
	var avih := PackedByteArray()
	for v in [micro, int(total * fps / maxi(frames.size(), 1)), 0, 0x10, frames.size(), 0, 1, biggest, width, height, 0, 0, 0, 0]:
		avih.append_array(_u32(v))
	var strh := PackedByteArray()
	strh.append_array("vids".to_ascii_buffer())
	strh.append_array("MJPG".to_ascii_buffer())
	for v in [0, 0, 0, 1, fps, 0, frames.size(), biggest, 0xFFFFFFFF, 0]:
		strh.append_array(_u32(v))
	for v in [0, 0, width, height]:
		strh.append_array(_u16(v))
	var strf := PackedByteArray()
	for v in [40, width, height]:
		strf.append_array(_u32(v))
	strf.append_array(_u16(1))       # planes
	strf.append_array(_u16(24))      # bits per pixel
	strf.append_array("MJPG".to_ascii_buffer())
	for v in [width * height * 3, 0, 0, 0, 0]:
		strf.append_array(_u32(v))
	var strl := _list("strl", _chunk("strh", strh) + _chunk("strf", strf))
	var hdrl := _list("hdrl", _chunk("avih", avih) + strl)
	var body := "AVI ".to_ascii_buffer() + hdrl + _list("movi", movi) + _chunk("idx1", index)
	return "RIFF".to_ascii_buffer() + _u32(body.size()) + body


## Writes the file. Returns OK or the error.
func save(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(to_bytes())
	file.close()
	return OK


static func _u32(v: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(4)
	b.encode_u32(0, v & 0xFFFFFFFF)
	return b


static func _u16(v: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(2)
	b.encode_u16(0, v & 0xFFFF)
	return b


static func _chunk(tag: String, data: PackedByteArray) -> PackedByteArray:
	var out := tag.to_ascii_buffer() + _u32(data.size()) + data
	if data.size() % 2 == 1:
		out.append(0)
	return out


static func _list(tag: String, data: PackedByteArray) -> PackedByteArray:
	return "LIST".to_ascii_buffer() + _u32(data.size() + 4) + tag.to_ascii_buffer() + data
