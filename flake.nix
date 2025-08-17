{
  description = "Zulkray Raytracer";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }@inputs:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        formatter = pkgs.nixfmt-rfc-style;

        # Development Shell.
        # $> nix develop
        devShells.default = pkgs.mkShell rec {
          buildInputs = (with pkgs; [ ]);

          nativeBuildInputs = (with pkgs; [ ]);

          propogatedBuildInputs = (with pkgs; [ ]);

          packages = with pkgs; [
            # Zig and tools
            zig
            zig-zlint
            zls
            # Hardware abstraction
            sdl3
            # Vulkan
            # https://discourse.nixos.org/t/setting-up-vulkan-for-development/11715/3
            renderdoc # graphics debugger
            shaderc # glslc, GLSL to SPIRV compiler
            tracy # graphics profiler
            vulkan-headers
            vulkan-loader
            vulkan-tools # vulkaninfo
            vulkan-tools-lunarg # vkconfig
            vulkan-validation-layers
          ];

          VULKAN_SDK = "${pkgs.vulkan-headers}";
          VK_LAYER_PATH = "${pkgs.vulkan-validation-layers}/share/vulkan/explicit_layer.d";

          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath packages;
        };
      }
    );
}
