{ nixpkgs ? import <nixpkgs> { } }:
let pkgs = {
  atomi = (
    with import (fetchTarball "https://github.com/kirinnee/test-nix-repo/archive/refs/tags/v9.0.0.tar.gz");
    {
      inherit pls;
    }
  );
  "Unstable 17th May 2022" = (
    with import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/1d7db1b9e4cf.tar.gz") { };
    {
      inherit
        docker
        pre-commit
        git
        shfmt
        shellcheck
        nixpkgs-fmt
        bash
        hadolint
        coreutils
        jq
        gnused
        gnugrep;

      prettier = nodePackages.prettier;
    }
  );
}; in
with pkgs;
pkgs.atomi // pkgs."Unstable 17th May 2022"
