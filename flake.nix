{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            zig
            iverilog
            gtkwave
            yosys
            tcl

            gnumake
            gcc
          ];

          shellHook = ''
            export TCL_TCLSH=${pkgs.tcl}/bin/tclsh
          '';
        };
      });
}
