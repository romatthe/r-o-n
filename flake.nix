{
  description = "Following the Rust On Nails tutorial";
   
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    utils.url = "github:numtide/flake-utils";
  };
  
  outputs = { self, nixpkgs, rust-overlay, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };
        pkg-version = (builtins.fromTOML (builtins.readFile ./Cargo.toml)).package.version;
        rust-version = "1.74.0";
        rust-dist = pkgs.rust-bin.stable.${rust-version}.default.override {
          extensions = [ "clippy" "rust-src" "rustfmt" "rust-analyzer" ];
          targets = [ "x86_64-unknown-linux-gnu" ];
        };
      in {
        defaultPackage = with pkgs; rustPlatform.buildRustPackage {
          pname = "r-o-n";
          version = pkg-version;
          src = ./.;

          cargoLock = {
            lockFile = ./Cargo.lock;
          };

          nativeBuildInputs = [
            rust-dist
          ];
        };
  
        defaultApp = utils.lib.mkApp {
          drv = self.defaultPackage."${system}";
        };

        devShell = with pkgs; mkShell {
          buildInputs = [
            # Project tools
            cargo-msrv
            nixfmt
            rust-dist

            # Postgres client
            postgresql
          ];

          shellHook = ''
            echo "Welcome to Rust-on-Nails"
          '';
  
          RUST_BACKTRACE = "1";
          PGDATA = "${toString ./.}/.pg";
        };

        devScript = pkgs.writeShellScriptBin "pg" ''
          pg up
          pg down
          pg status
        '';

        postgresConf =
          pkgs.writeText "postgresql.conf" ''
            log_min_messages = warning
            log_min_error_statement = error
            log_min_duration_statement = 100  # ms
            log_connections = on
            log_disconnections = on
            log_duration = on
            log_timezone = 'UTC'
            log_statement = 'all'
            log_directory = 'pg_log'
            log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
            logging_collector = on
            log_min_error_statement = error
          '';
      }
    );
  }