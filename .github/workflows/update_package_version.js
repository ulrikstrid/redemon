const Child_process = require("child_process");
const Fs = require("fs");
const Path = require("path");

const version = Fs.readFileSync(Path.resolve("VERSION"), { encoding: "utf8" })
  .toString()
  .trim();

const updateEsyVersion = (file, version) => {
  const packageJson = Fs.readFileSync(file, { encoding: "utf-8" });
  const updatedPackageJson = {
    ...JSON.parse(packageJson),
    version,
  };

  Fs.writeFileSync(file, JSON.stringify(updatedPackageJson, null, 2) + "\n");
};

const updateDuneVersion = (version) => {
  const duneProjectPath = Path.resolve("dune-project");
  const duneProject = Fs.readFileSync(duneProjectPath, { encoding: "utf-8" });

  const nextDuneProject = duneProject.replace(
    /\(version [0-9\.]+\)/g,
    `(version ${version})`
  );
  Fs.writeFileSync(duneProjectPath, nextDuneProject);
  Child_process.execSync("dune build --auto-promote");
};

updateEsyVersion("package.json", version);
updateDuneVersion(version);
