let
  pkgs = import <nixpkgs> {};
  rubyPkgs =
    import (builtins.fetchTarball {
      name = "nixos-release-17.03";
      url = https://github.com/nixos/nixpkgs/archive/13b0e47ed65c4a29727c53a68b0302b95dec68c6.tar.gz;
      # Hash obtained using `nix-prefetch-url --unpack <url>`
      sha256 = "0mi29naca4r611jl9hndvnhnfwlhcvbgfn51kq3hs94ni7bd3fsc";
    }) {};

  stdenv = pkgs.stdenv;

  ruby = rubyPkgs.ruby_2_2;
  rubygems = (pkgs.rubygems.override { ruby = ruby; });

in stdenv.mkDerivation rec {
  name = "blog";
  buildInputs = [
    ruby
    rubyPkgs.bundler
    pkgs.libxml2
    pkgs.libxslt
    pkgs.zlib
    pkgs.bzip2
    pkgs.openssl
    pkgs.imagemagickBig
    pkgs.pkgconfig
  ];

  shellHook = ''
    export PKG_CONFIG_PATH=${pkgs.libxml2}/lib/pkgconfig:${pkgs.libxslt}/lib/pkgconfig:${pkgs.zlib}/lib/pkgconfig:${pkgs.imagemagickBig}/lib/pkgconfig

    mkdir -p .nix-gems
    export GEM_HOME=$PWD/.nix-gems
    export GEM_PATH=$GEM_HOME
    export PATH=$GEM_HOME/bin:$PATH
  '';

}
