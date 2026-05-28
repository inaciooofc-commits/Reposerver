# To learn more about how to use Nix to configure your environment
# see: https://firebase.google.com/docs/studio/customize-workspace
{ pkgs, ... }: {
  # Which nixpkgs channel to use.
  channel = "unstable"; # or "unstable"

  # Use https://search.nixos.org/packages to find packages
  packages = [
    (pkgs.python311.withPackages (ps: with ps; [
      flask
      flask-socketio
      gunicorn
      python-dotenv
      eventlet
      google-api-python-client
      python-socketio # Pacote cliente para o teste automatizado
      pybind11
    ]))
    pkgs.nodejs_20
    pkgs.gcc
    pkgs.gnumake
  ];

  # Sets environment variables in the workspace
  env = {};
  idx = {
    # Search for the extensions you want on https://open-vsx.org/ and use "publisher.id"
    extensions = [
      "ms-python.python"
      "ms-python.debugpy"
    ];

    # Enable previews
    previews = {
      enable = true;
      previews = [{
          command = [ "python" "run.py" ];
          manager = "web";
        }];
    };

    # Workspace lifecycle hooks
    workspace = {
      # Runs when a workspace is first created
      onCreate = {
        build-cpp = "bash scripts/build_cpp.sh";
      };
      # Runs when the workspace is (re)started
      onStart = {};
    };
  };
}
