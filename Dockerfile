FROM nixos/nix:2.10.3
VOLUME /var/lib/docker
VOLUME /nix

CMD ["nix-shell", "-p", "docker", "--run", "dockerd"]
