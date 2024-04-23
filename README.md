# nix-develop (for GitHub Actions)

This is the most explicit and compatible way I know of to load a nix shell environment into a GitHub Actions job.

## Why?

Why would you load a nix shell environment into a GitHub Actions job?

If you haven't heard about nix, I highly recommend reading [a good introduction for it elsewhere](https://zero-to-nix.com/), but its relevant feature for our purposes right now is that you can use it to write succint and reliably reproducible cross-platform shell environments, and this can help you [manage build dependencies very well](https://determinate.systems/posts/nix-github-actions).  Currently this action cannot help you, so I wish you luck on your journey of discovery.

If you have heard about nix, and you already have all your builds and tests expressed as derivations, then you do not need this action!  Your GitHub CI workflows are just checking out the code and running `nix-build` or `nix flake check`, and they benefit from result caching and build-skipping that the rest of us can only dream of!  Currently this action cannot help you, so only keep reading if you're curious.

But finally, for the rest of us who already know the value of specifying shell environments in nix and using `nix develop`, and need to run commands in GitHub actions other _besides_ `nix-build` and `nix flake check`, this action is a better


## How?

How can you use this action usefully, and how does it interact with the rest of your system?

Think of it like running `nix develop` in a way that works exactly like any other `setup-*` action:

- In the step where you `use:` this action, it will run `nix develop`, which evaluates and build the `devShells.default` attribute of your repository's `flake.nix` file (or its `packages.default` attribute, or any other flake reference you like, (see below)). This will download any needed packages.
- In all subsequent steps in that job, **including ones that `use:` third-party actions**, dependencies in that flake output will be added to PATH, and all environment variables in it will be present.

(I bolded that last part because it isn't a feature I've seen in any other approach, and it's a feature I needed to install yarn via nix and then `use: actions/setup-node` to handle yarn caching.  Thanks for reading!)

In other words, rather than [this](https://github.com/DeterminateSystems/nix-github-actions/blob/main/.github/workflows/nix.yml)...
```yaml
      - run: |
          nix develop --command \
            cargo fmt --check
      - run: |
          nix develop --command \
            cargo-deny check
      - run: |
          nix develop --command \
            eclint \
              -exclude "Cargo.lock"
      - run: |
          nix develop --command \
            codespell \
              --skip target,.git \
              --ignore-words-list crate
```

...or even this:
```yaml
      - run: cargo fmt --check
        shell: nix develop --command bash -e {0}
      - run: cargo-deny check
        shell: nix develop --command bash -e {0}
      - run: eclint \
               -exclude "Cargo.lock"
        shell: nix develop --command bash -e {0}
      - run: codespell \
              --skip target,.git \
              --ignore-words-list crate
        shell: nix develop --command bash -e {0}
```

...you can do this:
```yaml
      - uses: nicknovitski/nix-develop@v1
      - run: cargo fmt --check
      - run: cargo-deny check
      - run: eclint \
               -exclude "Cargo.lock"
      - run: codespell \
              --skip target,.git \
              --ignore-words-list crate
```

You can also pass arbitrary arguments, like using another flake reference:

```yaml 
  - uses: nicknovitski/nix-develop@v1
    with:
      arguments: "github:DeterminateSystems/zero-to-nix#multi"
```


But in addition to being a github action, this repository is a nix flake.  So you could just do this:

```yaml
  - run: nix run github:nicknovitski/nix-develop -- github:DeterminateSystems/zero-to-nix#multi
```

And if you want to be sure you're controlling the version of this script and its dependencies, you can use nix!

```nix
# flake.nix
{
  inputs = {
    nix-develop-gha.url = "github:nicknovitski/nix-develop";
    nix-develop-gha.inputs.nixpkgs.follows = "nixpkgs"; # match your own "nixpkgs" input
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    nix-develop-gha,
  }:
    flake-utils.lib.eachDefaultSystem
    (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      # expose your locked version of the action locally
      packages.nix-develop-gha = nix-develop-gha.packages.${system}.default;
      # don't forget your development shell!
      devShells = {
        default = pkgs.mkShell {
          packages = [
            pkgs.yarn
            pkgs.nodejs
          ];
        };
      };
    });
}
```

...and then you can use the pinned package in your workflows like this:
```yaml
  - uses: actions/checkout@v4
  - run: nix run .#nix-develop-gha
```

## Contributing

Feel free!  The script can be run locally with any arguments you want to test, and unsurprisingly, running `nix develop` will give you the same dependencies used to test changes in CI.

If you use [direnv](https://direnv.net), you can also bring those dependencies into your own shell with `nix-direnv-reload`.
