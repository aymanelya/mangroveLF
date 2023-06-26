const fs = require('fs');
const path = require('path');
const glob = require('glob');

const artifactsDirectory = path.join(__dirname, '../artifacts/contracts');
const remappings = {
  'mgv_src/': '../node_modules/@mangrovedao/mangrove-core/src/',
  'mgv_lib/': '../node_modules/@mangrovedao/mangrove-core/lib/',
  'mgv_test/': '../node_modules/@mangrovedao/mangrove-core/test/',
  'mgv_script/': '../node_modules/@mangrovedao/mangrove-core/script/',
};

glob.sync('**/*.json', { cwd: artifactsDirectory }).forEach((file) => {
  const artifactPath = path.join(artifactsDirectory, file);
  let artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));

  if (artifact.sourceName) {
    for (const [find, replacement] of Object.entries(remappings)) {
      artifact.sourceName = artifact.sourceName.replace(find, replacement);
    }

    fs.writeFileSync(artifactPath, JSON.stringify(artifact, null, 2));
  }
});
