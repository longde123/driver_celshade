package celshade.renderpath;

import iron.RenderPath;
import armory.renderpath.Inc;

class RenderPathCreator {

	static var path:RenderPath;

	public static function get():RenderPath {
		path = new RenderPath();
		Inc.init(path);
		init();
		path.commands = commands;
		return path;
	}

	static function init() {

		// #if (rp_shadowmap && kha_webgl)
		// Inc.initEmpty();
		// #end

		#if (rp_background == "World")
		{
			path.loadShader("shader_datas/world_pass/world_pass");
		}
		#end

		#if rp_render_to_texture
		{
			path.createDepthBuffer("main", "DEPTH24");

			{
				var t = new RenderTargetRaw();
				t.name = "lbuf";
				t.width = 0;
				t.height = 0;
				t.format = getHdrFormat();
				t.displayp = getDisplayp();
				var ss = getSuperSampling();
				if (ss != 1) t.scale = ss;
				t.depth_buffer = "main";
				path.createRenderTarget(t);
			}

			#if rp_compositornodes
			{
				path.loadShader("shader_datas/compositor_pass/compositor_pass");
			}
			#else
			{
				path.loadShader("shader_datas/copy_pass/copy_pass");
			}
			#end

			#if (rp_supersampling == 4)
			{
				var t = new RenderTargetRaw();
				t.name = "buf";
				t.width = 0;
				t.height = 0;
				t.format = 'RGBA32';
				t.displayp = getDisplayp();
				var ss = getSuperSampling();
				if (ss != 1) t.scale = ss;
				t.depth_buffer = "main";
				path.createRenderTarget(t);

				path.loadShader("shader_datas/supersample_resolve/supersample_resolve");
			}
			#end
		}
		#end

		#if ((rp_antialiasing == "SMAA") || (rp_antialiasing == "TAA"))
		{
			var t = new RenderTargetRaw();
			t.name = "bufa";
			t.width = 0;
			t.height = 0;
			t.displayp = getDisplayp();
			t.format = "RGBA32";
			var ss = getSuperSampling();
			if (ss != 1) t.scale = ss;
			path.createRenderTarget(t);
		}
		{
			var t = new RenderTargetRaw();
			t.name = "bufb";
			t.width = 0;
			t.height = 0;
			t.displayp = getDisplayp();
			t.format = "RGBA32";
			var ss = getSuperSampling();
			if (ss != 1) t.scale = ss;
			path.createRenderTarget(t);
		}
		{
			path.loadShader("shader_datas/smaa_edge_detect/smaa_edge_detect");
			path.loadShader("shader_datas/smaa_blend_weight/smaa_blend_weight");
			path.loadShader("shader_datas/smaa_neighborhood_blend/smaa_neighborhood_blend");

			#if (rp_antialiasing == "TAA")
			{
				path.loadShader("shader_datas/taa_pass/taa_pass");
			}
			#end
		}
		#end

		#if rp_volumetriclight
		{
			path.loadShader("shader_datas/volumetric_light/volumetric_light");
			path.loadShader("shader_datas/blur_bilat_pass/blur_bilat_pass_x");
			path.loadShader("shader_datas/blur_bilat_blend_pass/blur_bilat_blend_pass_y");
			{
				var t = new RenderTargetRaw();
				t.name = "singlea";
				t.width = 0;
				t.height = 0;
				t.displayp = getDisplayp();
				t.format = "R8";
				path.createRenderTarget(t);
			}
			{
				var t = new RenderTargetRaw();
				t.name = "singleb";
				t.width = 0;
				t.height = 0;
				t.displayp = getDisplayp();
				t.format = "R8";
				path.createRenderTarget(t);
			}
		}
		#end

		#if rp_bloom
		{
			var t = new RenderTargetRaw();
			t.name = "bloomtex";
			t.width = 0;
			t.height = 0;
			t.scale = 0.25;
			t.format = getHdrFormat();
			path.createRenderTarget(t);
		}

		{
			var t = new RenderTargetRaw();
			t.name = "bloomtex2";
			t.width = 0;
			t.height = 0;
			t.scale = 0.25;
			t.format = getHdrFormat();
			path.createRenderTarget(t);
		}

		{
			path.loadShader("shader_datas/bloom_pass/bloom_pass");
			path.loadShader("shader_datas/blur_gaus_pass/blur_gaus_pass_x");
			path.loadShader("shader_datas/blur_gaus_pass/blur_gaus_pass_y");
			path.loadShader("shader_datas/blur_gaus_pass/blur_gaus_pass_y_blend");
		}
		#end
	}

	static function commands() {

		#if rp_shadowmap
		{
			Inc.drawShadowMap();
		}
		#end

		#if rp_render_to_texture
		{
			path.setTarget("lbuf");
		}
		#else
		{
			path.setTarget("");
		}
		#end

		#if (rp_background == "Clear")
		{
			path.clearTarget(-1, 1.0);
		}
		#else
		{
			path.clearTarget(null, 1.0);
		}
		#end

		#if rp_shadowmap
		{
			Inc.bindShadowMap();
		}
		#end

		path.drawMeshes("mesh");
		#if (rp_background == "World")
		{
			path.drawSkydome("shader_datas/world_pass/world_pass");
		}
		#end

		#if rp_render_to_texture
		{
			#if rp_bloom
			{
				path.setTarget("bloomtex");
				path.bindTarget("lbuf", "tex");
				path.drawShader("shader_datas/bloom_pass/bloom_pass");

				path.setTarget("bloomtex2");
				path.bindTarget("bloomtex", "tex");
				path.drawShader("shader_datas/blur_gaus_pass/blur_gaus_pass_x");

				path.setTarget("bloomtex");
				path.bindTarget("bloomtex2", "tex");
				path.drawShader("shader_datas/blur_gaus_pass/blur_gaus_pass_y");

				path.setTarget("bloomtex2");
				path.bindTarget("bloomtex", "tex");
				path.drawShader("shader_datas/blur_gaus_pass/blur_gaus_pass_x");

				path.setTarget("bloomtex");
				path.bindTarget("bloomtex2", "tex");
				path.drawShader("shader_datas/blur_gaus_pass/blur_gaus_pass_y");

				path.setTarget("bloomtex2");
				path.bindTarget("bloomtex", "tex");
				path.drawShader("shader_datas/blur_gaus_pass/blur_gaus_pass_x");

				path.setTarget("bloomtex");
				path.bindTarget("bloomtex2", "tex");
				path.drawShader("shader_datas/blur_gaus_pass/blur_gaus_pass_y");

				path.setTarget("bloomtex2");
				path.bindTarget("bloomtex", "tex");
				path.drawShader("shader_datas/blur_gaus_pass/blur_gaus_pass_x");

				path.setTarget("lbuf");
				path.bindTarget("bloomtex2", "tex");
				path.drawShader("shader_datas/blur_gaus_pass/blur_gaus_pass_y_blend");
			}
			#end

			#if rp_volumetriclight
			{
				path.setTarget("singlea");
				path.bindTarget("_main", "gbufferD");
				Inc.bindShadowMap();
				path.drawShader("shader_datas/volumetric_light/volumetric_light");

				path.setTarget("singleb");
				path.bindTarget("singlea", "tex");
				path.drawShader("shader_datas/blur_bilat_pass/blur_bilat_pass_x");

				path.setTarget("lbuf");
				path.bindTarget("singleb", "tex");
				path.drawShader("shader_datas/blur_bilat_blend_pass/blur_bilat_blend_pass_y");
			}
			#end

			#if (rp_supersampling == 4)
			var framebuffer = "buf";
			#else
			var framebuffer = "";
			#end

			#if ((rp_antialiasing == "Off") || (rp_antialiasing == "FXAA"))
			{
				path.setTarget(framebuffer);
			}
			#else
			{
				path.setTarget("buf");
			}
			#end

			path.bindTarget("lbuf", "tex");

			#if rp_compositordepth
			{
				path.bindTarget("_main", "gbufferD");
			}
			#end

			#if rp_compositornodes
			{
				path.drawShader("shader_datas/compositor_pass/compositor_pass");
			}
			#else
			{
				path.drawShader("shader_datas/copy_pass/copy_pass");
			}
			#end

			#if ((rp_antialiasing == "SMAA") || (rp_antialiasing == "TAA"))
			{
				path.setTarget("bufa");
				path.clearTarget(0x00000000);
				path.bindTarget("lbuf", "colorTex");
				path.drawShader("shader_datas/smaa_edge_detect/smaa_edge_detect");

				path.setTarget("bufb");
				path.clearTarget(0x00000000);
				path.bindTarget("bufa", "edgesTex");
				path.drawShader("shader_datas/smaa_blend_weight/smaa_blend_weight");

				path.setTarget(framebuffer);
				path.bindTarget("lbuf", "colorTex");
				path.bindTarget("bufb", "blendTex");
				path.drawShader("shader_datas/smaa_neighborhood_blend/smaa_neighborhood_blend");
			}
			#end

			#if (rp_supersampling == 4)
			{
				var finalTarget = "";
				path.setTarget(finalTarget);
				path.bindTarget(framebuffer, "tex");
				path.drawShader("shader_datas/supersample_resolve/supersample_resolve");
			}
			#end
		}
		#end
	}

	static inline function getSuperSampling():Int {
		#if (rp_supersampling == 2)
		return 2;
		#elseif (rp_supersampling == 4)
		return 4;
		#else
		return 1;
		#end
	}

	static inline function getHdrFormat():String {
		#if rp_hdr
		return "RGBA64";
		#else
		return "RGBA32";
		#end
	}

	public static inline function getDisplayp():Null<Int> {
		#if rp_resolution_filter // Custom resolution set
		return Main.resolutionSize;
		#else
		return null;
		#end
	}
}
