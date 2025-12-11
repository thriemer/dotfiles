{
  description = "flake for linus-x1";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.05";
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs: {
    nixosConfigurations."linus-x1" = nixpkgs.lib.nixosSystem {
      specialArgs = {inherit inputs;};
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
      ];
    };
  };
}
