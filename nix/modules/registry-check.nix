{
  lib,
  runCommand,
  registry,
  sopsConfig,
}:

let
  inherit (registry) nodes;

  trustedNames = lib.attrNames (lib.filterAttrs (_: n: n.trusted) nodes);
  untrustedNames = lib.attrNames (lib.filterAttrs (_: n: !n.trusted) nodes);

  ageOf = name: nodes.${name}.age;

  malformed = lib.filterAttrs (
    _: n:
    !(lib.hasPrefix "ssh-ed25519 AAAA" n.hostKey)
    || !(lib.hasPrefix "age1" n.age)
    || n.addresses == [ ]
  ) nodes;

  allAddresses = lib.concatMap (n: n.addresses) (lib.attrValues nodes);

  duplicateAddresses = lib.unique (
    lib.filter (addr: lib.count (other: other == addr) allAddresses > 1) allAddresses
  );

  allAliases = lib.concatMap (n: n.aliases or [ ]) (lib.attrValues nodes);

  duplicateAliases = lib.unique (
    lib.filter (a: lib.count (other: other == a) allAliases > 1) allAliases
  );

  aliasesShadowingNames = lib.unique (lib.filter (a: nodes ? ${a}) allAliases);
in
runCommand "mesh-registry-check"
  {
    inherit sopsConfig;
    mustDecrypt = lib.concatStringsSep "\n" (map ageOf trustedNames);
    mustNotDecrypt = lib.concatStringsSep "\n" (map ageOf untrustedNames);

    nixErrors = lib.concatStringsSep "\n" (
      lib.optional (malformed != { })
        "nodes with a missing or malformed hostKey/age/addresses: ${lib.concatStringsSep ", " (lib.attrNames malformed)}"
      ++ lib.optional (duplicateAddresses != [ ])
        "addresses claimed by more than one node: ${lib.concatStringsSep ", " duplicateAddresses}"
      ++ lib.optional (duplicateAliases != [ ])
        "aliases claimed by more than one node: ${lib.concatStringsSep ", " duplicateAliases}"
      ++ lib.optional (aliasesShadowingNames != [ ])
        "aliases that are also node names: ${lib.concatStringsSep ", " aliasesShadowingNames}"
      ++ lib.optional (trustedNames == [ ]) "no trusted nodes: the mesh would be empty"
    );
  }
  ''
    fail=0

    if [ -n "$nixErrors" ]; then
      echo "nix/nodes.nix:" >&2
      echo "$nixErrors" | sed 's/^/  /' >&2
      fail=1
    fi

    # Compare against the recipient list rather than parsing YAML: the anchors
    # in .sops.yaml are plain text and a substring match is enough to tell
    # present from absent.
    while read -r key; do
      [ -n "$key" ] || continue
      if ! grep -qF "$key" "$sopsConfig"; then
        echo "nix/.sops.yaml: trusted node recipient $key is missing -- it will not be able to decrypt the mesh key" >&2
        fail=1
      fi
    done <<< "$mustDecrypt"

    while read -r key; do
      [ -n "$key" ] || continue
      if grep -qF "$key" "$sopsConfig"; then
        echo "nix/.sops.yaml: $key belongs to an untrusted node but is a recipient -- it can decrypt the mesh key" >&2
        fail=1
      fi
    done <<< "$mustNotDecrypt"

    if [ "$fail" -ne 0 ]; then
      echo >&2
      echo "run 'mesh check' for the same report against the working tree." >&2
      exit 1
    fi

    echo "registry ok: ${toString (lib.length trustedNames)} trusted, ${toString (lib.length untrustedNames)} untrusted" | tee "$out"
  ''
