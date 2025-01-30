{
  description = "NixOS mail server flake";

  inputs = {
    nixos-mailserver = {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    y-util = {
      url = "github:yukkop/y.util.nix";
      inputs.nixpkgs.follows = "nixpkgs"; 
    };
  };

  outputs = { self, nixpkgs, deploy-rs, y-util, nixos-mailserver }:
    let
      lib = nixpkgs.lib;

      overlays = [ ];

      forAllSystemsWithPkgs = y-util.lib.forAllSystemsWithPkgs overlays;
    in
    forAllSystemsWithPkgs ({ system, pkgs }:
    {
      packages.${system} = { };
      devShells.${system}.default = pkgs.mkShell { };
      nixosModules.${system} = {
        mailserver = import ./mail.nix;
      };
  }) // {
      # test on vm
      # `nix run .#nixosConfigurations.default.config.system.build.vm`
      nixosConfigurations.default =
      let
        system = "x86_64-linux";
      in
      nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ( nixos-mailserver.nixosModules.mailserver )
          ( import ./mail.nix )
          ({ pkgs, modulesPath, ... }: {
            imports = [
            ];

            environment.systemPackages = with pkgs; [ 
              curl
              neovim
            ];

            # Autologin root in the VM
            services.getty.autologinUser = "root";

            virtualisation.vmVariant = {
              virtualisation.qemu.options = [
                "-nographic" 
                "-display" "curses"
                "-append" "console=ttyS0"
                "-serial" "mon:stdio"
                "-vga" "qxl"
              ];
              virtualisation.forwardPorts = [
                { from = "host"; host.port = 40500; guest.port = 22; }
              ];
            };

            users.users.root.openssh.authorizedKeys.keys = [
                ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH+jOR9gh9SqcqJDh1PqKkXDYbfjf22MhcqL6OTfUEvG yukkop@nixos''
                ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFouceNUxI3bGC24/hfA8J3VuBpvTcZh3KhixgrMiLte snuff@jorge-desktop''
            ];

            services.openssh = {
              enable = true;
              settings = {
                PasswordAuthentication = true;
              };
            };

	    # hetzner settings
            boot.loader.grub.device = "/dev/sda";
            boot.initrd.availableKernelModules = [
              "ata_piix"
              "uhci_hcd"
              "xen_blkfront"
              "vmw_pvscsi"
            ];

            networking.firewall = {
              enable = true;
              allowedTCPPorts = [
                80
                443
                53     # DNS
              ];
            };
            services.mailserver.enable = true;
            services.mailserver.domain = "hectic-lab.com";
            services.mailserver.loginAccounts = {
              "security" = {
                hashedPassword = "$2b$05$Y48Db1heT.GRgQQKjS88w.ZW0f2hDrS3Z3MOeGbyRIsIrS1hOGqOe";
              };
              "yukkop" = {
                hashedPassword = "$2b$05$RqChHPfJv9Q.eizwDbayk.u5UTmD3OSCfLHkBB2ixbd6VvRHfu8Xy";
              };
              "snuff" = {
                hashedPassword = "$2b$05$fcnxDZwkv8rWCll4FPP8hupmDPDoty01FrarPSf1cIYtdbCO6XHSa";
              };
              "antosha" = {
                hashedPassword = "$2b$05$yxgVqFP2OF6xV/m5xcXu2ORwJ4Q2qdAgYX9v4t.mpZMKEqmne3GQe";
              };
            };

            boot.initrd.kernelModules = [ "nvme" ];
            fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };

            system.stateVersion = "24.05";
          })
        ];
        pkgs = import nixpkgs {
          inherit system;
        };
      };

      deploy.nodes.default = let
        inherit (self.nixosConfigurations.default.config.nixpkgs) system;
      in {
        hostname = "lab";
        fastConnection = true;
        profilesOrder = [ "system" ];
        sshOpts = [ ];
        profiles."system" = {
          sshUser = "root";
          path = deploy-rs.lib.${system}.activate.nixos
            self.nixosConfigurations.default;
          user = "root";
        };
      };
  };
}

