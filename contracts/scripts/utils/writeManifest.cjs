// scripts/utils/writeManifest.cjs
const fs = require("fs");

function writeManifest(path, networkEntry) {
  let manifest = { manifestVersion: "1.0.0", dao: {}, networks: [] };
  if (fs.existsSync(path)) manifest = JSON.parse(fs.readFileSync(path, "utf8"));

  // upsert by chainId
  const idx = manifest.networks.findIndex(n => n.chainId === networkEntry.chainId);
  if (idx >= 0) manifest.networks[idx] = networkEntry; else manifest.networks.push(networkEntry);

  fs.writeFileSync(path, JSON.stringify(manifest, null, 2));
  console.log(`Updated manifest: ${path}`);
}

module.exports = { writeManifest };
