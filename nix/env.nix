{ nixpkgs ? import <nixpkgs> { } }:
let pkgs = import ./packages.nix { inherit nixpkgs; }; in
with pkgs;
{
  system = [
    coreutils
    gnugrep
    gnused
  ];

  dev = [
    git
  ];

  main = [
    pls
    docker
    jq
  ];

  lint = [
    pre-commit
    nixpkgs-fmt
    prettier
    shfmt
    shellcheck
    hadolint
  ];

}
