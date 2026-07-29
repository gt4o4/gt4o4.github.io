# Build shell for the blog — used by every Makefile target.
# Packages come from the evaluated Android host configuration via
# nix/pkgs.nix (see comments there).
#
# The RUNTIME tool (ruby) is grafted through
# config.build.replaceAndroidDependencies — the same patchnar treatment
# installed system packages get, so its ELF interpreter/RPATHs point
# at the Android glibc instead of relying on fakechroot's exec-time
# substitution. The COMPILE-TIME inputs for `bundle install` native
# extensions (pkg-config, openssl, zlib, libyaml) stay vanilla: the
# graft memo maps single store paths and would break multi-output .dev
# resolution that mkShell's dependency machinery uses, and compiled gems
# run fine against vanilla libs (sonames dedupe onto the loaded Android
# glibc at runtime).
#
# Node is NOT provided here: the PurgeCSS step (`make purge`) uses the
# system profile's node/npx, and there is no JS build step otherwise
# (the site loads ES modules via an import map — see CLAUDE.md).
#
# rubyAttr: nixpkgs attribute name of the Ruby to use. ruby_4_0 needs
# google-protobuf >= 4.35 (pulled in via sass-embedded; the 4.33
# precompiled gems cap ruby at < 3.5). CI pins the same 4.0.x
# (.github/workflows/jekyll.yml); ruby_3_3 remains as a fallback.
{
  rubyAttr ? "ruby_4_0",
}:
let
  inherit (import ./pkgs.nix) pkgs graft;

  runtimeTools = [
    pkgs.${rubyAttr}
  ];

  patched = graft (pkgs.buildEnv {
    name = "wenri-blog-tools";
    paths = runtimeTools;
  }) { };
in
pkgs.mkShell {
  packages = map patched.getPkg runtimeTools ++ [
    # native-extension build deps for `bundle install` (vanilla — see above)
    pkgs.pkg-config
    pkgs.openssl
    pkgs.zlib
    pkgs.libyaml
  ];
}
