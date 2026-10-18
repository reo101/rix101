{
  systems = { stdenv, ... }: stdenv.hostPlatform.isLinux;
  curried = true;
}
