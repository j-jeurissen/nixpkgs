# Created by: https://github.com/malob
# Inspired by: https://github.com/lccambiaghi/nixpkgs/blob/main/modules/homebrew.nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.brew-bundle;

  brewfileSection = heading: type: entries:
    if entries != [] then
      "# ${heading}\n" + (concatMapStrings (name: "${type} \"${name}\"\n") entries) + "\n"
    else "";

  masBrewfileSection = entries:
    if entries != {} then
      "# Mac App Store apps\n" +
      concatStringsSep "\n" (mapAttrsToList (name: id: ''mas "${name}", id: ${toString id}'') entries) +
      "\n"
    else "";

  brewfile = pkgs.writeText "Brewfile" (
    (brewfileSection "Taps" "tap" cfg.taps) +
    (brewfileSection "Brews" "brew" cfg.brews) +
    (brewfileSection "Casks" "cask" cfg.casks) +
    (masBrewfileSection cfg.masApps) +
    (brewfileSection "Docker contrainers" "whalebrew" cfg.whalebrews) +
    (if cfg.extraConfig != "" then "# Extra config\n" + cfg.extraConfig else "")
  );

  brew-bunble-options =
    "--file='${brewfile}' --no-lock" +
    (if cfg.cleanupType == "uninstall" || cfg.cleanupType == "zap" then " --cleanup" else "") +
    (if cfg.cleanupType == "zap" then " --zap" else "");

in

{
  options.programs.brew-bundle = {
    enable = mkEnableOption ''
      configuring your Brewfile, and installing/updating the formulas therein via
      the <command>brew bundle</command> command, using <command>nix-darwin</command>.

      Note that enabling this option does not install Homebrew. See the Homebrew website for
      installation instructions: https://brew.sh
    '';

    cleanupType = mkOption {
      type = with types; enum [ "none" "uninstall" "zap" ];
      default = "none";
      example = "uninstall";
      description = ''
        This option manages what happens to formulas installed by Homebrew, that aren't present in
        the Brewfile generated by this module.

        When set to <literal>"none"</literal> (the default), formulas not present in the generated
        Brewfile are left installed.

        When set to <literal>"uninstall"</literal>, <command>nix-darwin</command> invokes
        <command>brew bundle install</command> with the <command>--cleanup</command> flag. This
        uninstalls all formulas not listed in generate Brewfile, i.e.,
        <command>brew uninstall</command> is run for those formulas.

        When set to <literal>"zap"</literal>, <command>nix-darwin</command> invokes
        <command>brew bundle install</command> with the <command>--cleanup --zap</command>
        flags. This uninstalls all forumalas not listed in the generated Brewfile, and if the
        formula is a cask, removes all files associated with the cask. In other words,
        <command>brew uninstall --zap</command> is run for all those formulas.

        If you plan on exclusively using <command>nix-darwin</command> to manage formulas installed
        by Homebrew, you probably want to set this option to <literal>"uninstall"</literal> or
        <literal>"zap"</literal>.
      '';
    };

    setNoLockEnvvar = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Sets the <literal>HOMEBREW_BUNDLE_NO_LOCK</literal> enviroment variable, by adding it to
        <option>environment.variables</option>, so that lock files aren't generated when/if you run
        the <command>brew bundle</command> command yourself.
      '';
    };

    setBrewfileEnvvar = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Sets the <literal>HOMEBREW_BUNDLE_FILE</literal> enviroment variable to the path of the
        Brewfile in the Nix store that this module generates, by adding it to
        <option>environment.variables</option>.

        With this option enabled, <command>brew bundle</command> commands will automatically use
        the Brewfile in the Nix store that this module generates.
      '';
    };

    taps = mkOption {
      type = with types; listOf str;
      default = [];
      example = [ "homebrew/cask-fonts" ];
      description = "Homebrew formula repositories to tap";
    };

    brews = mkOption {
      type = with types; listOf str;
      default = [];
      example = [ "mas" ];
      description = "Homebrew brews to install";
    };

    casks = mkOption {
      type = with types; listOf str;
      default = [];
      example = [ "hammerspoon" "virtualbox" ];
      description = "Homebrew casks to install";
    };

    masApps = mkOption {
      type = with types; attrsOf int;
      default = {};
      example = {
        "1Password" = 1107421413;
        Xcode = 497799835;
      };
      description = ''
        Applications to install from Mac App Store using <command>mas</command>.

        When this option is used, <literal>"mas"</literal> is automatically added to
        <option>programs.brew-bundle.brews</option>.

        Note that you need to be signed into the Mac App Store for <command>mas</command> to
        successfully install and upgrade applications, and that unfortunately apps removed from this
        option will not be uninstalled automatically even if
        <option>programs.brew-bundle.cleanupType</option> is set to <literal>"uninstall"</literal>
        or <literal>"zap"</literal> (this is currently a limitation of Homebrew Bundle).

        For more information on <command>mas</command> see: https://github.com/mas-cli/mas
      '';
    };

    whalebrews = mkOption {
      type = with types; listOf str;
      default = [];
      example = [ "whalebrew/wget" ];
      description = ''
        Docker images to install using <command>whalebrew</command>.

        When this option is used, <literal>"whalebrew"</literal> is automatically added to
        <option>programs.brew-bundle.brews</option>.

        For more information on <command>whalebrew</command> see:
        https://github.com/whalebrew/whalebrew
      '';
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      example = ''
        # 'brew tap' with custom Git URL
        tap "user/tap-repo", "https://user@bitbucket.org/user/homebrew-tap-repo.git"

        # set arguments for all 'brew cask install' commands
        cask_args appdir: "~/Applications", require_sha: true

        # 'brew install --with-rmtp', 'brew services restart' on version changes
        brew "denji/nginx/nginx-full", args: ["with-rmtp"], restart_service: :changed
        # 'brew install', always 'brew services restart', 'brew link', 'brew unlink mysql' (if it is installed)
        brew "mysql@5.6", restart_service: true, link: true, conflicts_with: ["mysql"]

        # 'brew cask install --appdir=~/my-apps/Applications'
        cask "firefox", args: { appdir: "~/my-apps/Applications" }
        # 'brew cask install' only if '/usr/libexec/java_home --failfast' fails
        cask "java" unless system "/usr/libexec/java_home --failfast"
      '';
      description = "Extra lines to be added verbatim to the generated Brewfile.";
    };
  };

  config = {
    assertions = mkIf cfg.enable [
      {
        assertion = builtins.pathExists /usr/local/bin/brew;
        message = ''
          Homebrew not installed.

          Please install Homebrew yourself before using the programs.brew-bundle module.

          See installation instructions at: https://brew.sh
        '';
      }
    ];

    programs.brew-bundle.brews =
      optional (cfg.masApps != {}) "mas" ++
      optional (cfg.whalebrews != []) "whalebrew";

    environment.variables = mkIf cfg.enable (
      (if cfg.setNoLockEnvvar then { HOMEBREW_BUNDLE_NO_LOCK = "1"; } else {}) //
      (if cfg.setBrewfileEnvvar then { HOMEBREW_BUNDLE_FILE = "${brewfile}"; } else {})
    );

    system.activationScripts.extraUserActivation.text = mkIf cfg.enable ''
      # Homebrew Bundle
      echo >&2 "Homebrew bundle..."
      PATH=/usr/local/bin:$PATH brew update > /dev/null
      PATH=/usr/local/bin:$PATH brew bundle ${brew-bunble-options}
    '';
  };

}
