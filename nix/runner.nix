# The bench server: a Hetzner Cloud VM that exists for one benchmark run.
#
# The workflow creates it from Ubuntu, installs this config with nixos-anywhere, runs the
# benchmark containers over SSH, copies the results back and deletes the server. Nothing here is
# secret: the Hetzner token arrives over SSH at run time (see bench-selfdestruct below).
{ modulesPath, pkgs, ... }:
let
  metadata = "http://169.254.169.254/hetzner/v1/metadata";

  # Deleting the server is the only thing that stops Hetzner billing; a powered-off server is
  # still billed. The workflow deletes it in an always() step, but a cancelled job skips that.
  # This timer is the backstop: it deletes the server itself after selfDestructAfter.
  selfDestructAfter = "14h";
  tokenFile = "/var/lib/bench/hcloud-token";
in
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  system.stateVersion = "26.05";
  networking.hostName = "bench-runner";

  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  # IPv4 by DHCP is enough: the server only pulls images and talks to the workflow.
  networking.useNetworkd = true;
  systemd.network.networks."10-uplink" = {
    matchConfig.Name = "en* eth*";
    networkConfig.DHCP = "ipv4";
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  # The workflow creates a fresh SSH key per run and attaches it to the server. Hetzner publishes
  # it in the metadata service, so the installed system reads it from there at boot instead of
  # baking a key into this public config.
  systemd.services.bench-ssh-keys = {
    description = "Install root SSH keys from Hetzner metadata";
    wantedBy = [ "multi-user.target" ];
    before = [ "sshd.service" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig.Type = "oneshot";
    path = [ pkgs.curl pkgs.jq ];
    script = ''
      install -d -m 700 /root/.ssh
      curl -fsS --retry 10 --retry-connrefused ${metadata}/public-keys \
        | jq -r '.[]' > /root/.ssh/authorized_keys
      chmod 600 /root/.ssh/authorized_keys
    '';
  };

  systemd.timers.bench-selfdestruct = {
    wantedBy = [ "timers.target" ];
    timerConfig.OnBootSec = selfDestructAfter;
  };
  systemd.services.bench-selfdestruct = {
    description = "Delete this Hetzner server";
    serviceConfig.Type = "oneshot";
    path = [ pkgs.curl ];
    script = ''
      id=$(curl -fsS ${metadata}/instance-id)
      if [ -r ${tokenFile} ]; then
        curl -fsS -X DELETE -H "Authorization: Bearer $(cat ${tokenFile})" \
          "https://api.hetzner.cloud/v1/servers/$id"
      else
        # No token means the workflow died before it reached the server; the daily sweep
        # deletes it. Power off so it at least stops using CPU.
        echo "no token at ${tokenFile}; leaving deletion to the sweep" >&2
        systemctl poweroff
      fi
    '';
  };
  # The workflow writes the token here (mode 0400, root). Containers never mount /var/lib/bench,
  # because they run third-party VM code.
  systemd.tmpfiles.rules = [ "d /var/lib/bench 0700 root root -" ];

  # Rootful Docker: the benchmark compose file needs cap_add SYS_NICE.
  virtualisation.docker.enable = true;

  # A constant clock speed makes runs comparable. On a VM without cpufreq this does nothing.
  powerManagement.cpuFreqGovernor = "performance";

  environment.systemPackages = with pkgs; [
    curl
    git
    jq
    rsync
    docker-compose
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
