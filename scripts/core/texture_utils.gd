class_name TextureUtils

static func load_png(path: String) -> Texture2D:
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(path))
	if error != OK:
		push_warning("Nao foi possivel carregar textura de teste: %s" % path)
		return null
	return ImageTexture.create_from_image(image)
