{
  systems = { lib, stdenv, ... }: stdenv.buildPlatform.isDarwin;
}
