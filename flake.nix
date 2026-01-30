{
  description = "Singularity Mod Manager - Nix Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        pname = "singularitymm";
        version = "dev";
        src = ./.;
        cargoHash = "sha256-WZ8J4tq3ksnx+7beTGYCjho0MXAD6XIoj3r31O6AIcI=";
        npmDeps = pkgs.fetchNpmDeps {
          name = "${pname}-${version}-npm-deps";
          inherit src;
          hash = "sha256-kerJjj8fg6nPcJHvqcz8jWBbYkvc61pY8TR7wJ77tc0=";
        };
      in
      {
        packages.default = pkgs.rustPlatform.buildRustPackage (finalAttrs: {
          inherit pname version src cargoHash npmDeps;
          nativeBuildInputs = [
            pkgs.cargo-tauri.hook
            pkgs.nodejs
            pkgs.npmHooks.npmConfigHook
            pkgs.pkg-config
          ] ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.wrapGAppsHook4 ];
          buildInputs = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
            pkgs.glib-networking
            pkgs.openssl
            pkgs.webkitgtk_4_1
          ];
          cargoRoot = "src-tauri";
          buildAndTestSubdir = "src-tauri";
          tauriBuildFlags = [ "--config" src-tauri/tauri.conf.json ];
          tauriBundleType = "appimage"; # Don't need deb or rpm
        });

        packages.flatpakBundle = pkgs.stdenv.mkDerivation {
          pname = "singularitymm-flatpak";
          version = version;
          src = ./.;
          buildInputs = [ pkgs.flatpak pkgs.flatpak-builder pkgs.bash pkgs.coreutils pkgs.gawk pkgs.findutils pkgs.gnused pkgs.gnutar pkgs.gzip pkgs.jq pkgs.which ];
          nativeBuildInputs = [ ];
          unpackPhase = ":";
          buildPhase = ''
            set -e
            export PATH=$PATH:${pkgs.coreutils}/bin:${pkgs.gnused}/bin:${pkgs.gawk}/bin:${pkgs.findutils}/bin:${pkgs.gnutar}/bin:${pkgs.gzip}/bin:${pkgs.jq}/bin:${pkgs.which}/bin

            # Clean previous build artifacts
            echo "Cleaning previous build artifacts..."
            rm -rf flatpak-build flatpak-repo .flatpak-builder flatpak-source

            # 1. Build the Tauri project (Rust binary + resources)
            ./scripts/flatpak/build-binary.sh

            # 2. Prepare flatpak-source directory and copy all resources
            ./scripts/flatpak/copy-resources.sh

            # 3. Build the Flatpak bundle
            ./scripts/flatpak/build-flatpak.sh
          '';
          installPhase = ''
            mkdir -p $out
            cp SingularityMM.flatpak $out/
          '';
        };
      }
    );
}
