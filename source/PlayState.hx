package;

import haxe.io.Path;
import lime.system.FileWatcher;
import flixel.util.FlxSave;
import openfl.display.BitmapData;
import openfl.filters.ShaderFilter;
import openfl.display.StageQuality;
import flixel.addons.ui.FlxInputText;
import flixel.system.FlxAssets;
import flixel.ui.FlxButton;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.FlxCamera;
import flixel.math.FlxMath;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.FlxState;

#if sys
import systools.Dialogs;
#end

class Colors
{
	public static var DARKGREY = 0xff212121;
	public static var MEDGREY = 0xff303030;
	public static var GREY = 0xff424242;
}

class PlayState extends FlxState
{
	var save_file:FlxSave;

	var save_slot:String = 'app';

	var file_path(default, set):String;

	var sprite_width(default, set):Int;

	var sprite_height(default, set):Int;

	var sprite_offset(default, set):Float = 1;

	var sprite_rotation(default, set):Float;

	var rotation_speed:Float = 5;

	var sprites:FlxTypedGroup<FlxSprite>;

	var default_sprites:FlxTypedGroup<FlxSprite>;

	var sprites_camera:FlxCamera;

	var ui_height = 60;

	var ui_padding = 4;

	var zoom:Float;

	var last_mouse_x:Float;

	var scroll_speed:Float = 20;

	var lerp:Float = 0.15;

	var file_watcher:FileWatcher;

	override public function create():Void
	{
		super.create();

		FlxAssets.FONT_DEFAULT = AssetPaths.SharpRetro__ttf;

		FlxG.mouse.useSystemCursor = true;
		FlxG.autoPause = false;

		sprites_camera = new FlxCamera(0, 0, FlxG.width, FlxG.height - ui_height);
		sprites_camera.bgColor = Colors.DARKGREY;
		sprites_camera.setFilters([new ShaderFilter(new FlxShader())]);
		FlxG.cameras.add(sprites_camera);
		FlxCamera.defaultCameras = [sprites_camera];
		FlxG.game.stage.quality = StageQuality.LOW;
		FlxG.resizeWindow(480, 480);

		zoom = 3;

		sprites = new FlxTypedGroup();
		default_sprites = new FlxTypedGroup();
		
		for (i in 0...16)
		{
			var sprite = default_sprites.recycle(FlxSprite);
			sprite.loadGraphic(AssetPaths.chair__png, true, 10, 10);
			sprite.animation.frameIndex = i;
			sprite.x = FlxG.width * 0.5 - sprite.width * 0.5;
			sprite.y = sprites_camera.height * 0.5 - sprite.height * 0.5;
			sprite.y -= i * sprite_offset;
		}

		add(sprites);
		add(default_sprites);

		save_file = new FlxSave();
		save_file.bind(save_slot);

		sprite_width = save_file.data.sprite_width == null ? 8 : save_file.data.sprite_width;
		sprite_height = save_file.data.sprite_height == null ? 8 : save_file.data.sprite_height;
		file_path = save_file.data.file_path;

		init_ui();

		refresh_sprite();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// Camera controls

		// Drag your mouse to Rotate the Sprites' angle
		sprite_rotation -= FlxG.mouse.pressed ? FlxG.mouse.x - last_mouse_x : rotation_speed * elapsed; 
		last_mouse_x = FlxG.mouse.x;

		// Arrow keys to scroll the cam
		var up:Bool = false;
		var down:Bool = false;
		var left:Bool = false;
		var right:Bool = false;

		if (FlxG.keys.pressed.UP) up = true;
		if (FlxG.keys.pressed.DOWN) down = true;
		if (FlxG.keys.pressed.LEFT) left = true;
		if (FlxG.keys.pressed.RIGHT) right = true;

		if (up && down) up = down = false;
		if (left && right) left = right = false;

		if (up) sprites_camera.scroll.y -= scroll_speed * elapsed;
		if (down) sprites_camera.scroll.y += scroll_speed * elapsed;
		if (left) sprites_camera.scroll.x -= scroll_speed * elapsed;
		if (right) sprites_camera.scroll.x += scroll_speed * elapsed;
    
		// Scroll the mouse to zoom in-or-out
		zoom += FlxG.mouse.wheel * 0.2;
		zoom = FlxMath.bound(zoom, 0.5, 8);
		sprites_camera.zoom += (zoom - sprites_camera.zoom) * lerp;
	}

	function refresh_sprite()
	{
		sprites.forEach(sprite -> sprite.kill());

		var title = 'Stackr - ';

		if (file_path != null)
		{
			title += new Path(file_path).file;
			var img = BitmapData.fromFile(file_path);
			if (img != null)
			{
				if (sprite_width > 0 && sprite_height > 0 && img.width % sprite_width == 0 && img.height % sprite_height == 0)
				{
					var frames = Std.int((img.width / sprite_width) * (img.height / sprite_height));
					for (i in 0...frames)
					{
						var sprite = sprites.recycle(FlxSprite);
						sprite.loadGraphic(img, true, sprite_width, sprite_height);
						sprite.animation.frameIndex = i;
						sprite.x = FlxG.width * 0.5 - sprite.width * 0.5;
						sprite.y = sprites_camera.height * 0.5 - sprite.height * 0.5;
						sprite.y -= i * sprite_offset;

						save_file.data.file_path = file_path;
						save_file.data.sprite_width = sprite_width;
						save_file.data.sprite_height = sprite_height;
						save_file.flush();
					}

					FlxG.stage.application.window.title = title;

					default_sprites.exists = false;
					if (!sprites.exists) {
						scale_up(sprites);
						sprites.exists = true;
					}

					return;
				}
				else title += ' (Invalid Width/Height)';
			}
			else title += ' (Invalid File Loaded)';
		}
		else title += 'No File Loaded';

		FlxG.stage.application.window.title = title;

		if (!default_sprites.exists) {
			scale_up(default_sprites);
			default_sprites.exists = true;
		}
		sprites.exists = false;
	}

	function open_file()
	{
		#if sys
		var filters = {
			count: 1, 
			descriptions: ["PNG files", "JPEG files"],
			extensions: ["*.png","*.jpg;*.jpeg"]
		};

		var result = Dialogs.openFile('Open spritesheet', 'Open the spritesheet to preview', filters);

		if (result != null && result.length > 0)
		{
			file_path = result[0];
			refresh_sprite();
		}
		#end
	}

	function toggle_filter()
	{
		sprites_camera.filtersEnabled = !sprites_camera.filtersEnabled;
	}

	function init_ui()
	{	
		var ui_top = FlxG.height - ui_height;

		var font_size = 16;

		var ui_camera = FlxG.camera;
		ui_camera.setSize(FlxG.width, ui_height);
		ui_camera.y = ui_top;
		ui_camera.bgColor = Colors.MEDGREY;

		var ui_load_btn = new FlxButton(ui_padding, ui_padding, 'Load', open_file);
		ui_load_btn.label.setFormat(FlxAssets.FONT_DEFAULT, font_size);
		ui_load_btn.loadGraphic(AssetPaths.button__png, true, 60, 24);
		ui_load_btn.camera = ui_camera;

		var ui_filter_btn = new FlxButton(ui_padding,  ui_padding + ui_load_btn.height + ui_padding, 'Filter', toggle_filter);
		ui_filter_btn.label.setFormat(FlxAssets.FONT_DEFAULT, font_size);
		ui_filter_btn.loadGraphic(AssetPaths.button__png, true, 60, 24);
		ui_filter_btn.camera = ui_camera;

		var ui_width_text = new FlxText(ui_load_btn.x + ui_load_btn.width + ui_padding + 64, ui_padding, 64, 'width:', font_size);
		ui_width_text.alignment = FlxTextAlign.RIGHT;
		ui_width_text.camera = ui_camera;

		var ui_height_text = new FlxText(ui_width_text.x, ui_width_text.y + ui_width_text.height + ui_padding, 64, 'height:', font_size);
		ui_height_text.alignment = FlxTextAlign.RIGHT;
		ui_height_text.camera = ui_camera;

		var ui_width_text_number = new FlxInputText(ui_height_text.x + ui_height_text.width + ui_padding, ui_width_text.y, 36, '$sprite_width', font_size, FlxColor.WHITE, Colors.GREY);
		ui_width_text_number.alignment = FlxTextAlign.RIGHT;
		ui_width_text_number.filterMode = FlxInputText.ONLY_NUMERIC;
		ui_width_text_number.fieldBorderThickness = 0;
		ui_width_text_number.callback = (text, action) -> {
			var w = Std.parseInt(text);
			sprite_width = w == null ? 0 : w;
		}
		ui_width_text_number.camera = ui_camera;

		var ui_height_text_number = new FlxInputText(ui_width_text_number.x, ui_height_text.y, 36, '$sprite_height', font_size, FlxColor.WHITE, Colors.GREY);
		ui_height_text_number.alignment = FlxTextAlign.RIGHT;
		ui_height_text_number.filterMode = FlxInputText.ONLY_NUMERIC;
		ui_height_text_number.fieldBorderThickness = 0;
		ui_height_text_number.callback = (text, action) -> {
			var h = Std.parseInt(text);
			sprite_height = h == null ? 0 : h;
		}
		ui_height_text_number.camera = ui_camera;

		add(ui_load_btn);
		add(ui_filter_btn);
		add(ui_width_text);
		add(ui_width_text_number);
		add(ui_height_text_number);
		add(ui_height_text);
	}

	function scale_up(sprites:FlxTypedGroup<FlxSprite>) 
	{
		for (i in 0...sprites.members.length) 
		{
			sprites.members[i].scale.set(0, 0);
			FlxTween.tween(sprites.members[i].scale, { x: 1, y: 1}, Math.max(1.5 - i * 0.1, 0.5), { ease: FlxEase.elasticOut, startDelay: i * 0.013});
		}
	}

	function set_file_path(v:String)
	{
		if (file_watcher == null) 
		{
			file_watcher = new FileWatcher();
			file_watcher.onModify.add(path -> if (path == file_path) refresh_sprite());
		}
		file_watcher.removeDirectory(new Path(file_path).dir);
		file_watcher.addDirectory(new Path(v).dir);

		return file_path = v;
	}

	function set_sprite_width(v:Int)
	{
		sprite_width = v;
		refresh_sprite();
		return sprite_width;
	}

	function set_sprite_height(v:Int)
	{
		sprite_height = v;
		refresh_sprite();
		return sprite_height;
	}

	function set_sprite_offset(v:Float)
	{
		sprite_offset = v;
		if (sprites != null) for (i in 0...sprites.members.length) sprites.members[i].y = FlxG.camera.height * 0.5 - sprites.members[i].height * 0.5 - i * v;
		return sprite_offset;
	}

	function set_sprite_rotation(v:Float) 
	{
		if (sprites != null) sprites.forEach(s -> s.angle = v);
		if (default_sprites != null) default_sprites.forEach(s -> s.angle = v);
		return sprite_rotation = v;
	}
}
