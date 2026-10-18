{ lib, aspectLibrary }:

let
  resolveModules = class: aspects: aspectLibrary.resolve class [ ] { includes = aspects; };
in
{
  inherit resolveModules;

  resolveHost =
    {
      class,
      meta,
      userNames,
      homePath ? user: [
        "home-manager"
        "users"
        user
      ],
    }:
    let
      selectedUsers = builtins.attrNames meta.users;
      unknownUsers = lib.subtractLists userNames selectedUsers;
      userAspects = lib.concatMap (user: user.aspects) (builtins.attrValues meta.users);
      homeModules = aspectLibrary.forward {
        each = selectedUsers;
        fromClass = _: "homeManager";
        intoClass = _: class;
        intoPath = homePath;
        fromAspect = user: { includes = meta.users.${user}.aspects; };
      };
    in
    assert lib.assertMsg (unknownUsers == [ ])
      "Aspect bindings reference users without home configurations: ${lib.concatStringsSep ", " unknownUsers}";
    resolveModules class (meta.aspects ++ userAspects ++ [ homeModules ]);
}
