{
  description = "flake for linus-x1";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-26.05";
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    #    llama-cpp.url = "github:ggml-org/llama.cpp";
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
