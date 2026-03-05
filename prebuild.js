const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const input = JSON.parse(fs.readFileSync(0, "utf8"));

const srcDir = path.join(process.cwd(), "src");
const buildDir = path.join(process.cwd(), "_build", "prebuild");
fs.mkdirSync(buildDir, { recursive: true });

const output = { link_configs: [] };

const libco_asm = path.join(buildDir,
  process.platform === "win32" ? "co_asm.lib" : "libco_asm.a");

if (process.platform === "win32") {
  const shiftObj = path.join(buildDir, "co_shift.obj");
  const resetObj = path.join(buildDir, "co_reset.obj");
  execFileSync("ml64", [
    "/nologo", "/c",
    `/Fo${shiftObj}`,
    path.join(srcDir, "co_shift.asm"),
  ]);
  execFileSync("ml64", [
    "/nologo", "/c",
    `/Fo${resetObj}`,
    path.join(srcDir, "co_reset.asm"),
  ]);
  execFileSync("lib", [
    "/nologo",
    `/out:${libco_asm}`,
    shiftObj,
    resetObj,
  ]);
} else {
  const shiftObj = path.join(buildDir, "co_shift.o");
  const resetObj = path.join(buildDir, "co_reset.o");
  execFileSync("cc", ["-c", "-o", shiftObj, path.join(srcDir, "co_shift.S")]);
  execFileSync("cc", ["-c", "-o", resetObj, path.join(srcDir, "co_reset.S")]);
  execFileSync("ar", ["rcs", libco_asm, shiftObj, resetObj]);
}

const libPath = libco_asm.replace(/\\/g, "/");
output.link_configs.push({
  package: "tonyfettes/co",
  link_flags: libPath,
});

console.log(JSON.stringify(output));
