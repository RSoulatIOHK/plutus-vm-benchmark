{
  description = "Plutus VM benchmark: NixOS config of the throwaway Hetzner bench server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, disko, ... }:
    {
      # Installed on a fresh Hetzner Cloud Ubuntu server by nixos-anywhere on every run:
      #   nixos-anywhere --flake .#bench-runner --build-on remote root@<ip>
      # The server lives for one benchmark run and is then deleted. See nix/runner.nix.
      nixosConfigurations.bench-runner = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          ./nix/disko.nix
          ./nix/runner.nix
        ];
      };
    };
}
