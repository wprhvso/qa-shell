{
  description = "qa-shell — единый QA для shell и YAML (shellcheck, shfmt, actionlint, yamllint)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (
        pkgs:
        let
          wrapped =
            pkgs.runCommand "qa-shell"
              {
                nativeBuildInputs = [ pkgs.makeWrapper ];
                meta = {
                  description = "Единый QA для shell и YAML";
                  homepage = "https://github.com/wprhvso/qa-shell";
                  mainProgram = "qa-shell";
                };
              }
              ''
                mkdir -p "$out/share/qa-shell"
                cp -r ${./config} "$out/share/qa-shell/config"
                cp -r ${./scripts} "$out/share/qa-shell/scripts"
                install -Dm755 ${./scripts/local.sh} "$out/bin/qa-shell"
                wrapProgram "$out/bin/qa-shell" \
                  --set QA_LOCAL "$out/share/qa-shell" \
                  --prefix PATH : ${
                    lib.makeBinPath [
                      pkgs.actionlint
                      pkgs.git
                      pkgs.shellcheck
                      pkgs.shfmt
                      pkgs.yamllint
                    ]
                  }
              '';
        in
        {
          default = wrapped;
          qa-shell = wrapped;
        }
      );

      apps = forAllSystems (pkgs: {
        default = {
          type = "app";
          program = "${self.packages.${pkgs.system}.default}/bin/qa-shell";
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt);

      checks = forAllSystems (pkgs: {
        package = self.packages.${pkgs.system}.default;
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.actionlint
            pkgs.nixfmt
            pkgs.shellcheck
            pkgs.shfmt
            pkgs.yamllint
          ];
        };
      });
    };
}
