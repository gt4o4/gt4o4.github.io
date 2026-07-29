# Package universe for building the site locally on the Nix-on-Droid phone.
#
# Taken from the evaluated Android host configuration itself
# (~/.config/nix-on-droid → nixOnDroidConfigurations.default), which
# exposes:
#
#   pkgs  — the exact package set the system is built from
#           (nixpkgs-25_11 pin: glibc 2.40 to match the Android-patched
#           glibc, plus the full overlay stack from common/factory.nix)
#   graft — config.build.replaceAndroidDependencies: the NixOS-style
#           grafting used at `nix-on-droid switch` time (patchnar rewrites
#           ELF interpreters/RPATHs of a whole closure to the Android
#           glibc; see common/modules/android/android-integration.nix)
#
# Nothing is mirrored or duplicated here — if the host config changes its
# pin or overlays, this picks it up on the next evaluation. The price is
# that every evaluation runs the full nix-on-droid module eval (slower
# than a bare nixpkgs import) plus grafting IFD on first use of a new
# tool closure; both are cached by the nix store afterwards.
let
  configFlake = builtins.getFlake ("path:" + builtins.getEnv "HOME" + "/.config/nix-on-droid");
  droid = configFlake.nixOnDroidConfigurations.default;
in
{
  inherit (droid) pkgs;
  graft = droid.config.build.replaceAndroidDependencies;
}
