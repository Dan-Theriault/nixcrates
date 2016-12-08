with import <nixpkgs> { };
with stdenv.lib;

let
  allCrates = recurseIntoAttrs (callPackage nix-crates-index/all-carg-packages.nix { });
  normalizeName = builtins.replaceStrings [ "-"] ["_"];
  depsStringCalc = pkgs.lib.fold ( dep: str: "${str} --extern ${normalizeName dep.name}=${dep}/lib${normalizeName dep.name}.rlib") "";

  # symlinkCalc creates a mylibs folder and symlinks all the buildInputs's libraries from there for rustc to link them into the final binary
  symlinkCalc = pkgs.lib.fold ( dep: str: "${str} ln -s ${dep}/lib${normalizeName dep.name}.rlib mylibs/ \n") "mkdir mylibs\n ";
in

{

  nix-crates = stdenv.mkDerivation rec {
    name = "nix-crates";
    src = ./src;

    crates = depsStringCalc [ allCrates.walkdir allCrates.rustc-serialize allCrates.rustache ];
    buildInputs = with allCrates; [ ]; 
    buildPhase = ''
      ${symlinkCalc buildInputs}

      ${rustc}/bin/rustc $src/main.rs --crate-type "bin" --emit=dep-info,link --crate-name nix_crates -L dependency=mylibs ${crates}
    '';
  };

  getopts-example = stdenv.mkDerivation rec {
    name = "getopts-example";
    src = ./example/src;

    depsString = depsStringCalc buildInputs;
    buildInputs = with allCrates; [ getopts ];

    buildPhase = ''
      ${rustc}/bin/rustc $src/main.rs ${depsString}
      ./main 
      exit 1
    '';
  };

  # flate2 example uses native c code (not using nipxkgs's packages but brings its own bundled c-code instead)
  # FIXME still fails to build
  flate2-example = stdenv.mkDerivation rec {
    name = "flate2-example";
    src = ./example/src2;
    depsString = depsStringCalc buildInputs;
    buildInputs = with allCrates; [ flate2 libc miniz-sys gcc ];

    buildPhase = ''
      ${symlinkCalc buildInputs}
      du -a mylibs
      ls -lathr mylibs
      echo ${depsString}
# [pid 14162] execve("/nix/store/fff3jbf9vbqhmf6qjrmzhliq516x7yrf-rustc-1.11.0/bin/rustc", ["rustc", "src/main.rs", "--crate-name", "hello_flate2", "--crate-type", "bin", "-g", "--out-dir", "/home/joachim/Desktop/projects/fractalide/fetchUrl/hello_flate2/target/debug", "--emit=dep-info,link", "-L", "dependency=/home/joachim/Desktop/projects/fractalide/fetchUrl/hello_flate2/target/debug", "-L", "dependency=/home/joachim/Desktop/projects/fractalide/fetchUrl/hello_flate2/target/debug/deps", "--extern", "flate2=/home/joachim/Desktop/projects/fractalide/fetchUrl/hello_flate2/target/debug/deps/libflate2-d719035eaa7c6a88.rlib", "-L", "native=/home/joachim/Desktop/projects/fractalide/fetchUrl/hello_flate2/target/debug/build/miniz-sys-60c8d67696f63a43/out"], [/* 105 vars */]) = 0

      ${rustc}/bin/rustc $src/main.rs --crate-type "bin" --emit=dep-info,link --crate-name main -L dependency=mylibs ${depsString} -L native= #flate2=${allCrates.flate2_0_2_14}/libflate2.rlib
      ./main 
      exit 1
    '';
  };

  tar-example = stdenv.mkDerivation rec {
    name = "tar-example";
    src = ./example/src3;
    buildInputs = with allCrates; [ tar filetime libc xattr ]; 
    buildPhase = ''
      ${symlinkCalc buildInputs}

      echo "hu" > file1.txt
      echo "bar" > file2.txt
      echo "batz" > file3.txt 

      ${rustc}/bin/rustc $src/main.rs --crate-type "bin" --emit=dep-info,link --crate-name main -L dependency=mylibs --extern tar=${allCrates.tar_0_4_9}/libtar.rlib
#       du -a
#       /run/current-system/sw/bin/ldd ./main
      ./main
      du -a 
      if [ -f foo.tar ]; then
        echo -e "---------\nSUCCESS: tar-example was executed successfully!   \n--------"
      else
        echo "FAIL: not working!"
      fi
      exit 1
    '';
  };
  # with this you can do: ix-build -A allCrates.getopts to compile single dependencies
  inherit allCrates;
}